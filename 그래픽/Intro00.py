
import argparse
import sys
import time
import threading
import queue
from dataclasses import dataclass

import pygame

# --------------------------
# CLI
# --------------------------
def parse_args():
    p = argparse.ArgumentParser(description="Intro page with UART-driven 3s hold START button")
    p.add_argument("--port", type=str, default=None, help="Serial port (e.g., COM5 or /dev/ttyUSB0). If omitted, keyboard test mode.")
    p.add_argument("--baud", type=int, default=115200, help="UART baud rate")
    p.add_argument("--hold", type=float, default=3.0, help="Seconds required to confirm START")
    p.add_argument("--timeout", type=float, default=0.25, help="No pulse for this long → reset gauge")
    p.add_argument("--fps", type=int, default=60, help="Target FPS")
    p.add_argument("--parse", type=str, default="anybyte", choices=["anybyte","startline","binary01"],
                   help="UART parse: anybyte → any byte is pulse; startline → 'START\\n'; binary01 → '1'/'0' lines")
    p.add_argument("--quit-on-complete", action="store_true", help="Quit window automatically when START completes")
    p.add_argument("--debug", action="store_true", help="Print debug logs")
    p.add_argument("--w", type=int, default=2560, help="Window width")
    p.add_argument("--h", type=int, default=1440, help="Window height")
    return p.parse_args()

# --------------------------
# UART Reader (optional)
# --------------------------
try:
    import serial
except Exception:
    serial = None

class UartReader(threading.Thread):
    daemon = True
    def __init__(self, port, baud, parse_mode, out_q, debug=False):
        super().__init__()
        self.port = port
        self.baud = baud
        self.mode = parse_mode
        self.q = out_q
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

            if self.mode == "anybyte":
                self.q.put({"type":"pulse","ts":time.monotonic()})
                if self.debug:
                    print(f"[UART] Pulse ({len(data)} bytes)")
            else:
                buf.extend(data)
                while b"\n" in buf:
                    line, _, rest = buf.partition(b"\n")
                    buf = bytearray(rest)
                    s = line.strip().decode(errors="ignore")
                    if self.debug:
                        print(f"[UART] Line='{s}'")
                    if self.mode == "startline":
                        if s.upper() == "START":
                            self.q.put({"type":"pulse","ts":time.monotonic()})
                    elif self.mode == "binary01":
                        if s == "1":
                            self.q.put({"type":"pressed","val":1,"ts":time.monotonic()})
                        elif s == "0":
                            self.q.put({"type":"pressed","val":0,"ts":time.monotonic()})
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
    explicitly_pressed: bool = False

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

    def set_explicit(self, val, now):
        self.state.explicitly_pressed = bool(val)
        if val:
            self.state.last_pulse_ts = now
        if self.debug:
            print(f"[Hold] explicit={val}")

    def update(self, dt, now):
        just_done = False
        holding = False
        if self.state.explicitly_pressed:
            holding = True
        else:
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
NEON_RED = (255, 80, 80)

# --------------------------
# Neon text
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
# Intro Page (with gauge/button)
# --------------------------
def run_intro(args):
    pygame.init()
    W, H = args.w, args.h
    screen = pygame.display.set_mode((W, H))
    pygame.display.set_caption("Motion Game Intro (UART)")
    clock = pygame.time.Clock()

    # Load images placed next to this script
    # background.png, 1.png, 2.png
    bg = pygame.image.load("background.png").convert()
    bg = pygame.transform.smoothscale(bg, (W, H))

    char1 = pygame.image.load("1.png").convert_alpha()
    char1 = pygame.transform.smoothscale(char1, (600, 900))
    char2 = pygame.image.load("2.png").convert_alpha()
    char2 = pygame.transform.smoothscale(char2, (600, 900))

    # Fonts & title
    title_font = pygame.font.SysFont("Arial", 180, bold=True)
    title_surface = title_font.render("Motion Game", True, WHITE)
    title_rect = title_surface.get_rect(center=(W//2, 110))

    # START button metrics (bottom-left)
    start_font = pygame.font.SysFont("Arial", 150, bold=True)
    start_text = "Start!!"

    # Button rectangle around bottom-left area
    btn_rect_base = pygame.Rect(60, H - 260, 520, 170)
    idle_color = (80, 80, 100)
    active_color = (130, 170, 255)
    done_color = (90, 200, 140)
    border_color = (30, 30, 40)
    gauge_bg = (25, 25, 30)

    # VGA black area
    vga_rect = pygame.Rect(530, 200, 1500, 1125)

    # Serial thread (optional)
    uart_q = queue.Queue()
    reader = None
    if args.port and serial is not None:
        reader = UartReader(args.port, args.baud, args.parse, uart_q, debug=args.debug)
        reader.start()
    else:
        if args.port and serial is None:
            print("[WARN] pyserial missing; keyboard-only mode")
        else:
            print("[INFO] Keyboard-only mode: hold SPACE to simulate pulses")

    hold = HoldDetector(args.hold, args.timeout, debug=args.debug)

    completed_once = False
    running = True
    last = time.monotonic()

    while running:
        now = time.monotonic()
        dt = min(0.1, now - last)
        last = now

        # Events
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    hold.on_pulse(now)

        # Drain UART
        try:
            while True:
                m = uart_q.get_nowait()
                if m["type"] == "pulse":
                    hold.on_pulse(now)
                elif m["type"] == "pressed":
                    hold.set_explicit(m.get("val",0), now)
        except queue.Empty:
            pass

        # Update hold
        ratio, active, just_done = hold.update(dt, now)
        if just_done:
            completed_once = True
            print("[INTRO] START confirmed (3s). Proceed to MODE.")
            if args.quit_on_complete:
                running = False

        # Draw frame
        screen.blit(bg, (0, 0))
        pygame.draw.rect(screen, (0,0,0), vga_rect)  # VGA window

        # Characters
        screen.blit(char1, (50, 400))
        screen.blit(char2, (W - 650, 350))

        # Title (neon)
        draw_neon_text(screen, title_font, "Motion Game", WHITE, NEON_BLUE, title_rect)

        # START button with gauge
        scale = 1.05 if active else 1.0
        btn_rect = btn_rect_base.copy()
        cx, cy = btn_rect.center
        btn_rect.width = int(btn_rect.width * scale)
        btn_rect.height = int(btn_rect.height * scale)
        btn_rect.center = (cx, cy)

        fill_color = done_color if completed_once else (active_color if active else idle_color)
        pygame.draw.rect(screen, fill_color, btn_rect, border_radius=24)
        pygame.draw.rect(screen, border_color, btn_rect, width=4, border_radius=24)

        pad = 14
        gauge_rect_bg = btn_rect.inflate(-pad*2, -pad*2)
        pygame.draw.rect(screen, gauge_bg, gauge_rect_bg, border_radius=16)
        filled = gauge_rect_bg.copy()
        filled.width = max(0, int(gauge_rect_bg.width * ratio))
        pygame.draw.rect(screen, NEON_RED, filled, border_radius=16)

        # Label
        lbl_surface = start_font.render(start_text, True, WHITE)
        lbl_rect = lbl_surface.get_rect(center=btn_rect.center)
        draw_neon_text(screen, start_font, start_text, WHITE, NEON_RED, lbl_rect)

        # Hint
        hint_font = pygame.font.SysFont("Arial", 36)
        hint_txt = "손바닥을 START 영역에 3초 유지 (UART 유지) · Space=테스트 · ESC=종료"
        hint_surf = hint_font.render(hint_txt, True, (230,230,230))
        hint_rect = hint_surf.get_rect(midbottom=(W//2, H-20))
        screen.blit(hint_surf, hint_rect)

        pygame.display.flip()
        clock.tick(args.fps)

    if reader:
        reader.stop()
        reader.join(timeout=1.0)
    pygame.quit()

def main():
    args = parse_args()
    run_intro(args)

if __name__ == "__main__":
    main()
