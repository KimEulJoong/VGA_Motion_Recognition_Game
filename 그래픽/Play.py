"""
Play.py — Motion gameplay with UART scoring + pause trigger (gear, 1s hold)

Changes in this version:
- Countdown number moved to top-right corner (padding 60,20).
- Top-left corner shows gear.png; receiving continuous UART "pause" pulses for
  --pause-hold seconds (default 1.0s) confirms and triggers pause.
- On pause confirm:
    * Prints NEXT_PAGE:pause to stdout
    * If --quit-on-pause is given, the window closes (so an external launcher can open pause.py)

Pause pulse protocol (ASCII mode):
- Send any of: PAUSE, MENU, GEAR
Byte mode:
- Map a byte to "pause" using --pause-byte (default 0x7E).

Other behavior unchanged:
- 5s prep timer + progress bar
- Wait for UART results P/G/B → show overlay in VGA area 3s → send mN_done
"""

import argparse
import os
import re
import sys
import time
import queue
import threading
from pathlib import Path
import math

import pygame

try:
    from PIL import Image  # noqa: F401
    HAVE_PIL = True
except Exception:
    HAVE_PIL = False

# --------------------------
# CLI
# --------------------------
def parse_args():
    p = argparse.ArgumentParser(description="Play screen (motions, UART scoring + pause)")
    p.add_argument("--assets", type=str, default=None, help="Folder containing background.png, M*.png, Perfect/Good/Bad.png, gear.png")
    p.add_argument("--port", type=str, default=None, help="Serial port (COM5 or /dev/ttyUSB0). If omitted, keyboard test mode.")
    p.add_argument("--baud", type=int, default=115200, help="UART baud rate")
    p.add_argument("--fps", type=int, default=60, help="Target FPS")
    p.add_argument("--w", type=int, default=2560, help="Window width")
    p.add_argument("--h", type=int, default=1440, help="Window height")

    # Timing
    p.add_argument("--prep", type=float, default=5.0, help="Seconds to pose before result is requested")
    p.add_argument("--result_hold", type=float, default=3.0, help="Seconds to show Perfect/Good/Bad overlay before ack")

    # UART parsing
    p.add_argument("--parse", type=str, default="ascii", choices=["ascii","byte"], help="Result parse mode")
    p.add_argument("--byte_map", type=str, default="1:P,2:G,3:B", help="Mapping for --parse byte, format '1:P,2:G,3:B'")

    # Score
    p.add_argument("--score_values", type=str, default="P:10,G:7,B:3", help="Score mapping e.g. 'P:10,G:7,B:3'")

    # Pause detection
    p.add_argument("--pause-hold", type=float, default=1.0, help="Seconds to confirm pause")
    p.add_argument("--pause-timeout", type=float, default=0.25, help="Pause pulses gap allowed before reset")
    p.add_argument("--pause-byte", type=lambda s: int(s,0), default=0x7E, help="In byte mode, this byte means 'pause'")
    p.add_argument("--quit-on-pause", action="store_true", help="Quit app when pause confirmed (prints NEXT_PAGE:pause)")

    p.add_argument("--debug", action="store_true")
    return p.parse_args()

# --------------------------
# UART reader/writer
# --------------------------
try:
    import serial
except Exception:
    serial = None

class UartRW(threading.Thread):
    daemon = True
    def __init__(self, port, baud, out_q, parse_mode="ascii", byte_map=None, pause_byte=0x7E, debug=False):
        super().__init__()
        self.port = port
        self.baud = baud
        self.out_q = out_q
        self.parse_mode = parse_mode
        self.byte_map = byte_map or {1:"P",2:"G",3:"B"}
        self.pause_byte = pause_byte
        self.debug = debug
        self._stop = threading.Event()
        self.ser = None
        self.lock = threading.Lock()

    def run(self):
        if self.port is None or serial is None:
            return
        try:
            self.ser = serial.Serial(self.port, self.baud, timeout=0.01)
        except Exception as e:
            print(f"[UART] Open failed: {e}", file=sys.stderr)
            return

        buf = bytearray()
        while not self._stop.is_set():
            try:
                data = self.ser.read(1024)
            except Exception as e:
                print(f"[UART] Read error: {e}", file=sys.stderr)
                break
            if not data:
                continue

            if self.parse_mode == "byte":
                for b in data:
                    if b == self.pause_byte:
                        self.out_q.put({"type":"pause_pulse","ts":time.monotonic()})
                        if self.debug: print("[UART] Pause byte received")
                        continue
                    res = self.byte_map.get(b)
                    if res in ("P","G","B"):
                        if self.debug:
                            print(f"[UART] Byte->{res} (0x{b:02X})")
                        self.out_q.put({"type":"result","value":res,"ts":time.monotonic()})
            else:
                buf.extend(data)
                while b"\n" in buf:
                    line, _, rest = buf.partition(b"\n")
                    buf = bytearray(rest)
                    s = line.strip().decode(errors="ignore").upper()
                    if self.debug:
                        print(f"[UART] Line='{s}'")
                    if s in ("P", "PERFECT"):
                        self.out_q.put({"type":"result","value":"P","ts":time.monotonic()})
                    elif s in ("G", "GOOD"):
                        self.out_q.put({"type":"result","value":"G","ts":time.monotonic()})
                    elif s in ("B", "BAD"):
                        self.out_q.put({"type":"result","value":"B","ts":time.monotonic()})
                    elif s in ("PAUSE","MENU","GEAR"):
                        self.out_q.put({"type":"pause_pulse","ts":time.monotonic()})

    def send_line(self, s: str):
        if self.ser is None:
            print(f"[UART][FAKE TX] {s}")
            return
        with self.lock:
            try:
                self.ser.write((s + "\n").encode())
                if self.debug:
                    print(f"[UART][TX] {s}")
            except Exception as e:
                print(f"[UART] Write error: {e}", file=sys.stderr)

    def stop(self):
        self._stop.set()

# --------------------------
# Hold detector
# --------------------------
class HoldDetector:
    def __init__(self, hold_seconds, timeout, debug=False):
        self.hold_s = hold_seconds
        self.timeout = timeout
        self.progress = 0.0
        self.last_ts = -1.0
        self.debug = debug

    def on_pulse(self, now):
        self.last_ts = now

    def update(self, dt, now):
        just_done = False
        holding = (self.last_ts >= 0 and (now - self.last_ts) <= self.timeout)
        if holding:
            prev = self.progress
            self.progress = min(self.hold_s, self.progress + dt)
            if prev < self.hold_s and self.progress >= self.hold_s:
                just_done = True
        else:
            self.progress = 0.0
        ratio = 0.0 if self.hold_s <= 0 else max(0.0, min(1.0, self.progress / self.hold_s))
        return ratio, holding, just_done

# --------------------------
# Helpers
# --------------------------
def load_image(path: Path, size=None, alpha=True):
    img = pygame.image.load(str(path)).convert_alpha() if alpha else pygame.image.load(str(path)).convert()
    if size:
        img = pygame.transform.smoothscale(img, size)
    return img

def auto_find_motions(root: Path):
    items = []
    for f in root.iterdir():
        if not f.is_file():
            continue
        if re.match(r"^M\d+\.png$", f.name, re.I):
            n = int(re.findall(r"\d+", f.name)[0])
            items.append((n, f))
    items.sort()
    return [p for _, p in items]

def parse_byte_map(s):
    d = {}
    for pair in s.split(","):
        if ":" not in pair: continue
        k, v = pair.split(":")
        try:
            b = int(k.strip(), 0)
        except Exception:
            continue
        v = v.strip().upper()
        if v in ("P","G","B"):
            d[b] = v
    return d

def parse_score_map(s):
    d = {}
    for pair in s.split(","):
        if ":" not in pair: continue
        k, v = pair.split(":")
        k = k.strip().upper()
        try:
            d[k] = int(v.strip())
        except Exception:
            pass
    return d

# --------------------------
# Draw utilities
# --------------------------
WHITE = (255,255,255)
NEON_BLUE = (100,150,255)
NEON_RED = (255,80,80)
NEON_GREEN = (90,200,140)
NEON_YELLOW = (255,220,120)
GAUGE_BG = (25,25,30)
BORDER = (30,30,40)

def draw_neon_text(surface, font, text, base_color, glow_color, rect, glow_layers=6):
    for i in range(1, glow_layers+1):
        glow = font.render(text, True, glow_color)
        glow.set_alpha(40)
        surface.blit(glow, rect.move(i, 0))
        surface.blit(glow, rect.move(-i, 0))
        surface.blit(glow, rect.move(0, i))
        surface.blit(glow, rect.move(0, -i))
        surface.blit(glow, rect.move(i, i))
        surface.blit(glow, rect.move(-i, -i))
        surface.blit(glow, rect.move(i, -i))
        surface.blit(glow, rect.move(-i, i))
    base = font.render(text, True, base_color)
    surface.blit(base, rect)

def draw_top_timer(surface, W, left_margin, right_margin, t_left, t_total):
    # Countdown number at top-right
    font_num = pygame.font.SysFont("Arial", 140, bold=True)
    secs = max(0, int(t_left + 0.999))
    num_surface = font_num.render(str(secs), True, WHITE)
    num_rect = num_surface.get_rect(topright=(W - 60, 20))
    draw_neon_text(surface, font_num, str(secs), WHITE, NEON_YELLOW, num_rect)

    # Gauge bar across the top
    bar_rect = pygame.Rect(left_margin, 190, W - left_margin - right_margin, 24)
    pygame.draw.rect(surface, GAUGE_BG, bar_rect, border_radius=12)
    ratio = 0.0 if t_total <= 0 else max(0.0, min(1.0, (t_total - t_left)/t_total))
    fill = bar_rect.copy(); fill.width = int(bar_rect.width * ratio)
    pygame.draw.rect(surface, NEON_RED, fill, border_radius=12)
    pygame.draw.rect(surface, BORDER, bar_rect, width=3, border_radius=12)

def draw_result_overlay(surface, rect, result, assets):
    img = assets.get(result)
    if img:
        img_scaled = pygame.transform.smoothscale(img, (rect.width, rect.height))
        surface.blit(img_scaled, rect.topleft)
    else:
        font = pygame.font.SysFont("Arial", 220, bold=True)
        txt = {"P":"PERFECT","G":"GOOD","B":"BAD"}[result]
        r = font.render(txt, True, WHITE).get_rect(center=rect.center)
        glow = {"P":NEON_GREEN,"G":NEON_BLUE,"B":NEON_RED}[result]
        draw_neon_text(surface, font, txt, WHITE, glow, r)

def draw_ring_progress(surface, center, radius, thickness, ratio, color_fg, color_bg=(80,80,90)):
    # background ring
    pygame.draw.circle(surface, color_bg, center, radius, thickness)
    if ratio <= 0: return
    ratio = max(0.0, min(1.0, ratio))
    start_angle = -math.pi/2
    end_angle = start_angle + ratio * 2*math.pi
    rect = pygame.Rect(0,0, radius*2, radius*2)
    rect.center = center
    pygame.draw.arc(surface, color_fg, rect, start_angle, end_angle, thickness)

# --------------------------
# Main
# --------------------------
def main():
    args = parse_args()

    # Asset root
    script_dir = Path(__file__).resolve().parent
    asset_root = Path(args.assets).resolve() if args.assets else script_dir
    print(f"[ASSETS] Root: {asset_root}")

    # Window & pygame must be initialized BEFORE we load/convert images
    W, H = args.w, args.h
    pygame.init()
    screen = pygame.display.set_mode((W, H))
    pygame.display.set_caption("Play (motions + UART scoring + pause)")
    clock = pygame.time.Clock()

    # Score map & byte map
    score_map = parse_score_map(args.score_values)
    byte_map = parse_byte_map(args.byte_map)

    # Motions list
    motions = auto_find_motions(asset_root)
    print(f"[ASSETS] Found motions: {[p.name for p in motions]}")
    if not motions:
        print("No motion images found (M1.png ...). Place them in the asset root or pass --assets PATH.")
        return

    # Load images
    bg = load_image(asset_root / "background.png", size=(W, H), alpha=False)

    # Preload motion images
    motion_imgs = {}
    for path in motions:
        try:
            img = load_image(path, size=(550, 900), alpha=True)
            motion_imgs[path.name] = img
        except Exception as e:
            print(f"[WARN] Could not load {path}: {e}")

    # Optional result assets
    assets = {}
    for k, name in (("P","Perfect.png"),("G","Good.png"),("B","Bad.png")):
        p = asset_root / name
        if p.exists():
            try:
                assets[k] = load_image(p, alpha=True)
            except Exception:
                pass

    # Gear icon
    gear_path = asset_root / "gear.png"
    gear_img = None
    gear_rect = None
    if gear_path.exists():
        gear_img = load_image(gear_path, size=(90, 90), alpha=True)
        gear_rect = gear_img.get_rect(topleft=(24, 18))

    # Layout
    VGA_RECT = pygame.Rect(960, 240, 1600, 1200)   # right panel
    LEFT_OVERLAY = pygame.Rect(0, 240, 960, 1200)  # left translucent area
    MOTION_POS = (220, 450)  # where to blit 550x900
    SCORE_POS = (W//2, 120)

    score = 0
    motion_index = 0
    state = "prepare"   # prepare -> await_result -> show_result
    timer_start = time.monotonic()
    result_value = None

    # UART
    q = queue.Queue()
    uart = None
    if args.port and serial is not None:
        uart = UartRW(args.port, args.baud, q, parse_mode=args.parse, byte_map=byte_map, pause_byte=args.pause_byte, debug=args.debug)
        uart.start()
    else:
        if args.port and serial is None:
            print("[WARN] pyserial missing; running without UART")
        else:
            print("[INFO] No port provided; keyboard-only test mode.")

    # Pause hold detector
    pause_hold = HoldDetector(args.pause_hold, args.pause_timeout, debug=args.debug)

    # Fonts
    score_font = pygame.font.SysFont("Arial", 150, bold=True)
    label_font = pygame.font.SysFont("Arial", 150, bold=True)
    label_rect = label_font.render("Follow Motion", True, WHITE).get_rect(center=(470, H - 1100))

    running = True
    while running:
        now = time.monotonic()
        dt = clock.tick(args.fps) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                # Keyboard test: simulate pause pulses with key 'M'
                elif event.key == pygame.K_m:
                    pause_hold.on_pulse(now)
                elif state == "await_result":
                    if event.key == pygame.K_p:
                        q.put({"type":"result","value":"P","ts":now})
                    elif event.key == pygame.K_g:
                        q.put({"type":"result","value":"G","ts":now})
                    elif event.key == pygame.K_b:
                        q.put({"type":"result","value":"B","ts":now})
                elif event.key == pygame.K_n:
                    state = "show_result"; result_value = "G"; timer_start = now

        # UART queue
        try:
            while True:
                msg = q.get_nowait()
                if msg.get("type") == "result" and state == "await_result":
                    result_value = msg.get("value")
                    score += score_map.get(result_value, 0)
                    state = "show_result"
                    timer_start = now
                elif msg.get("type") == "pause_pulse":
                    pause_hold.on_pulse(now)
        except queue.Empty:
            pass

        # Update pause hold detector
        pause_ratio, pause_active, pause_done = pause_hold.update(dt, now)
        if pause_done:
            print("[PLAY] Pause confirmed.")
            print("NEXT_PAGE:pause")
            if args.quit_on_pause:
                running = False

        # State timing
        if state == "prepare":
            t_elapsed = now - timer_start
            t_left = max(0.0, args.prep - t_elapsed)
            if t_left <= 0.0:
                state = "await_result"
                timer_start = now

        elif state == "show_result":
            if now - timer_start >= args.result_hold:
                mname = motions[motion_index].name
                mnum = int(re.findall(r"\d+", mname)[0])
                ack = f"m{mnum}_done"
                if uart:
                    uart.send_line(ack)
                else:
                    print(f"[ACK] {ack}")

                motion_index += 1
                if motion_index >= len(motions):
                    print("[PLAY] All motions done.")
                    running = False
                else:
                    state = "prepare"
                    result_value = None
                    timer_start = now

        # ----- Draw frame -----
        screen.blit(bg, (0,0))

        # Left translucent overlay
        s = pygame.Surface((LEFT_OVERLAY.width, LEFT_OVERLAY.height), pygame.SRCALPHA)
        s.fill((255,255,255,180))
        screen.blit(s, LEFT_OVERLAY.topleft)

        # Right VGA area (black background)
        pygame.draw.rect(screen, (0,0,0), VGA_RECT)

        # Score
        draw_neon_text(screen, score_font, f"Score : {score}", WHITE, NEON_BLUE, score_font.render("0", True, WHITE).get_rect(center=SCORE_POS))

        # Follow Motion label
        draw_neon_text(screen, label_font, "Follow Motion", WHITE, NEON_RED, label_rect)

        # Current motion image
        if motion_index < len(motions):
            key = motions[motion_index].name
            img = motion_imgs.get(key)
            if img:
                screen.blit(img, MOTION_POS)

        # Top timer (during prepare)
        if state == "prepare":
            t_left = max(0.0, args.prep - (now - timer_start))
            draw_top_timer(screen, W, left_margin=60, right_margin=60, t_left=t_left, t_total=args.prep)

        # Result overlay in VGA area only
        if state == "show_result" and result_value in ("P","G","B"):
            draw_result_overlay(screen, VGA_RECT, result_value, assets)

        # Draw gear + progress ring (top-left)
        if gear_img:
            screen.blit(gear_img, gear_rect.topleft)
            center = (gear_rect.centerx, gear_rect.centery)
            draw_ring_progress(screen, center, radius=60, thickness=10,
                               ratio=pause_ratio, color_fg=NEON_BLUE)

        pygame.display.flip()

    if uart:
        uart.stop()
        uart.join(timeout=1.0)
    pygame.quit()

if __name__ == "__main__":
    main()
