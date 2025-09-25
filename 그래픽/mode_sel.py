
"""
mode_sel.py — Mode Select page with character-as-gauge (solid color overlay)
- Character icons are dimmed base images.
- A solid-color overlay (Start gauge-like red) fills from bottom→top per hold ratio.
- On completion, overlay switches to green for that side.
- 2s continuous UART pulse → 1P→play, 2P→motion_sel.
- Timeout resets only that side.

Keyboard test: '1' for 1P pulse, '2' for 2P pulse, ESC to quit.
UART parse: --parse token (default) or --parse xy
"""

import argparse
import sys
import time
import threading
import queue
from dataclasses import dataclass

import pygame

try:
    import numpy as np
    HAVE_NP = True
except Exception:
    HAVE_NP = False

try:
    from PIL import Image, ImageDraw
except Exception:
    Image = None
    ImageDraw = None

# --------------------------
# CLI
# --------------------------
def parse_args():
    p = argparse.ArgumentParser(description="Mode Select (character overlay gauge, UART 2s hold)")
    p.add_argument("--port", type=str, default=None, help="Serial port (e.g., COM5 or /dev/ttyUSB0). If omitted, keyboard test mode.")
    p.add_argument("--baud", type=int, default=115200, help="UART baud rate")
    p.add_argument("--hold", type=float, default=2.0, help="Seconds required to confirm selection")
    p.add_argument("--timeout", type=float, default=0.25, help="No pulse for this long → reset gauge")
    p.add_argument("--fps", type=int, default=60, help="Target FPS")
    p.add_argument("--parse", type=str, default="token", choices=["token","xy"],
                   help="UART parse: token={1,1P,P1,L,LEFT}/{2,2P,P2,R,RIGHT} or xy='x,y'")
    p.add_argument("--w", type=int, default=2560, help="Window width")
    p.add_argument("--h", type=int, default=1440, help="Window height")
    p.add_argument("--quit-on-complete", action="store_true", help="Auto-quit on selection (for chaining pages)")
    p.add_argument("--debug", action="store_true", help="Print debug logs")
    return p.parse_args()

# --------------------------
# UART Reader
# --------------------------
try:
    import serial
except Exception:
    serial = None

class UartReader(threading.Thread):
    daemon = True
    def __init__(self, port, baud, parse_mode, out_q, w, debug=False):
        super().__init__()
        self.port = port
        self.baud = baud
        self.mode = parse_mode
        self.q = out_q
        self.W = w
        self.debug = debug
        self._stop = threading.Event()
        self.ser = None

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

            buf.extend(data)
            while b"\\n" in buf:
                line, _, rest = buf.partition(b"\\n")
                buf = bytearray(rest)
                s = line.strip().decode(errors="ignore")
                if not s:
                    continue
                if self.debug:
                    print(f"[UART] Line='{s}'")

                side = None
                if self.mode == "token":
                    tok = s.strip().upper()
                    if tok in ("1","1P","P1","L","LEFT"):
                        side = "left"
                    elif tok in ("2","2P","P2","R","RIGHT"):
                        side = "right"
                elif self.mode == "xy":
                    try:
                        parts = s.replace(" ", "").split(",")
                        if len(parts) == 2:
                            x = float(parts[0])
                            side = "left" if x < self.W/2 else "right"
                    except Exception:
                        pass

                if side:
                    self.q.put({"type":"pulse","side":side,"ts":time.monotonic()})

        try:
            if self.ser:
                self.ser.close()
        except Exception:
            pass

    def stop(self):
        self._stop.set()

# --------------------------
# Hold Detector
# --------------------------
@dataclass
class HoldState:
    progress: float = 0.0
    last_pulse_ts: float = -1.0

class HoldDetector:
    def __init__(self, hold_seconds, timeout, debug=False):
        self.hold_s = hold_seconds
        self.timeout = timeout
        self.state = HoldState()
        self.debug = debug

    def on_pulse(self, now):
        self.state.last_pulse_ts = now
        if self.debug:
            print(f"[Hold] pulse @ {now:.3f}")

    def update(self, dt, now):
        just_done = False
        holding = False
        if self.state.last_pulse_ts >= 0 and (now - self.state.last_pulse_ts) <= self.timeout:
            holding = True

        if holding:
            prev = self.state.progress
            self.state.progress = min(self.hold_s, self.state.progress + dt)
            if prev < self.hold_s and self.state.progress >= self.hold_s:
                just_done = True
        else:
            if self.state.progress != 0 and self.debug:
                print("[Hold] release -> reset")
            self.state.progress = 0.0

        ratio = 0.0 if self.hold_s <= 0 else max(0.0, min(1.0, self.state.progress / self.hold_s))
        return ratio, holding, just_done

# --------------------------
# Colors
# --------------------------
WHITE = (255, 255, 255)
NEON_BLUE = (100, 150, 255)
NEON_RED = (255, 80, 80)   # same style as Start gauge
NEON_GREEN = (90, 200, 140)

# --------------------------
# Background (no characters; characters drawn as gauges)
# --------------------------
def build_background(W, H):
    bg_path = "./background.png"
    if Image is not None:
        bg = Image.open(bg_path).convert("RGBA").resize((W, H))
        draw = ImageDraw.Draw(bg)
        vga_x0, vga_y0 = 530, 200
        vga_w, vga_h = 1500, 1125
        draw.rectangle([vga_x0, vga_y0, vga_x0+vga_w, vga_y0+vga_h], fill="black")
        mode = bg.mode; size = bg.size; data = bg.tobytes()
        return pygame.image.fromstring(data, size, mode)
    else:
        bg = pygame.image.load(bg_path).convert()
        bg = pygame.transform.smoothscale(bg, (W, H))
        surface = pygame.Surface((W, H), pygame.SRCALPHA)
        surface.blit(bg, (0, 0))
        pygame.draw.rect(surface, (0,0,0), pygame.Rect(530, 200, 1500, 1125))
        return surface

# --------------------------
# Neon text helper
# --------------------------
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

# --------------------------
# Build a solid-color overlay surface using the character's alpha as mask
# --------------------------
def make_solid_overlay_from_alpha(char_img, color):
    w, h = char_img.get_width(), char_img.get_height()
    overlay = pygame.Surface((w, h), pygame.SRCALPHA)

    if HAVE_NP:
        # Copy per-pixel alpha from character to the overlay
        alpha_src = pygame.surfarray.pixels_alpha(char_img).copy()
        # Fill RGB with color
        overlay.fill((*color, 0))
        # Assign alpha
        alpha_dst = pygame.surfarray.pixels_alpha(overlay)
        alpha_dst[:] = alpha_src[:]
        del alpha_dst
    else:
        # Fallback: tint the original image heavily toward the target color
        overlay = char_img.copy()
        overlay.fill(color + (0,), special_flags=pygame.BLEND_RGBA_MULT)
    return overlay

# --------------------------
# Draw character gauge (dim base + colored overlay cropped by ratio from bottom)
# --------------------------
def draw_character_gauge(screen, pos, base_dim, overlay_color_surface, ratio):
    x, y = pos
    screen.blit(base_dim, (x, y))

    if ratio <= 0.0:
        return
    ratio = max(0.0, min(1.0, ratio))

    w, h = overlay_color_surface.get_width(), overlay_color_surface.get_height()
    fill_h = int(h * ratio)
    if fill_h <= 0:
        return

    area = pygame.Rect(0, h - fill_h, w, fill_h)
    screen.blit(overlay_color_surface, (x, y + (h - fill_h)), area=area)

# --------------------------
# Main
# --------------------------
def run_mode(args):
    pygame.init()
    W, H = args.w, args.h
    screen = pygame.display.set_mode((W, H))
    pygame.display.set_caption("Mode Select (Character Overlay Gauge)")
    clock = pygame.time.Clock()

    base_surface = build_background(W, H)

    # Title & labels
    title_font = pygame.font.SysFont("Arial", 180, bold=True)
    title_rect = title_font.render("Mode Select", True, WHITE).get_rect(center=(W//2, 100))

    p_font = pygame.font.SysFont("Arial", 150, bold=True)
    p1_rect = p_font.render("1P", True, WHITE).get_rect(center=(280, 390))
    p2_rect = p_font.render("2P", True, WHITE).get_rect(center=(W - 240, 390))

    # Load characters
    left_img = pygame.image.load("1p.png").convert_alpha()
    left_img = pygame.transform.smoothscale(left_img, (550, 900))
    right_img = pygame.image.load("2p.png").convert_alpha()
    right_img = pygame.transform.smoothscale(right_img, (500, 900))

    # Dim bases
    left_dim = left_img.copy();  left_dim.fill((100,100,100,255), special_flags=pygame.BLEND_RGBA_MULT)
    right_dim = right_img.copy(); right_dim.fill((100,100,100,255), special_flags=pygame.BLEND_RGBA_MULT)

    # Overlays (solid color using alpha mask)
    left_overlay_red  = make_solid_overlay_from_alpha(left_img, NEON_RED)
    right_overlay_red = make_solid_overlay_from_alpha(right_img, NEON_RED)
    left_overlay_green  = make_solid_overlay_from_alpha(left_img, NEON_GREEN)
    right_overlay_green = make_solid_overlay_from_alpha(right_img, NEON_GREEN)

    # Positions
    left_pos  = (0, 450)
    right_pos = (W - right_img.get_width(), 450)

    # UART
    uart_q = queue.Queue()
    reader = None
    if args.port and serial is not None:
        reader = UartReader(args.port, args.baud, args.parse, uart_q, W, debug=args.debug)
        reader.start()
    else:
        if args.port and serial is None:
            print("[WARN] pyserial missing; keyboard-only mode")
        else:
            print("[INFO] Keyboard-only mode: '1' for 1P pulse, '2' for 2P pulse")

    # Hold detectors for each side
    hold_left  = HoldDetector(args.hold, args.timeout, debug=args.debug)
    hold_right = HoldDetector(args.hold, args.timeout, debug=args.debug)

    next_page = None  # 'play' or 'motion_sel'

    running = True
    last = time.monotonic()

    while running:
        now = time.monotonic()
        dt = min(0.1, now - last)
        last = now

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_1:
                    hold_left.on_pulse(now)
                elif event.key == pygame.K_2:
                    hold_right.on_pulse(now)

        # UART drain
        try:
            while True:
                m = uart_q.get_nowait()
                if m["type"] == "pulse":
                    if m.get("side") == "left":
                        hold_left.on_pulse(now)
                    elif m.get("side") == "right":
                        hold_right.on_pulse(now)
        except queue.Empty:
            pass

        # Update holds
        r1, a1, done1 = hold_left.update(dt, now)
        r2, a2, done2 = hold_right.update(dt, now)

        if next_page is None:
            if done1:
                next_page = "play"
                print("[MODE] 1P confirmed (2s). NEXT: play")
                if args.quit_on_complete:
                    running = False
            elif done2:
                next_page = "motion_sel"
                print("[MODE] 2P confirmed (2s). NEXT: motion_sel")
                if args.quit_on_complete:
                    running = False

        # Draw
        screen.blit(base_surface, (0, 0))

        # Title + labels
        draw_neon_text(screen, title_font, "Mode Select", WHITE, NEON_BLUE, title_rect)
        draw_neon_text(screen, p_font, "1P", WHITE, NEON_RED, p1_rect)
        draw_neon_text(screen, p_font, "2P", WHITE, NEON_RED, p2_rect)

        # Choose overlay color (red during fill, green if completed side)
        left_overlay  = left_overlay_green if next_page == "play" else left_overlay_red
        right_overlay = right_overlay_green if next_page == "motion_sel" else right_overlay_red

        # Character overlay gauges
        draw_character_gauge(screen, left_pos,  left_dim,  left_overlay,  r1)
        draw_character_gauge(screen, right_pos, right_dim, right_overlay, r2)

        # Hint
        hint_font = pygame.font.SysFont("Arial", 36)
        hint_txt = "1P: LEFT · 2P: RIGHT · 2초 유지로 선택 · 1/2 키 테스트 · ESC 종료"
        hint_surf = hint_font.render(hint_txt, True, (230,230,230))
        hint_rect = hint_surf.get_rect(midbottom=(W//2, H-20))
        screen.blit(hint_surf, hint_rect)

        pygame.display.flip()
        clock.tick(args.fps)

    if reader:
        reader.stop()
        reader.join(timeout=1.0)
    pygame.quit()

    if next_page:
        print(f"NEXT_PAGE:{next_page}")

def main():
    args = parse_args()
    run_mode(args)

if __name__ == "__main__":
    main()
