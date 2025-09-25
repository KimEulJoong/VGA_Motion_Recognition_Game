
"""
music_sel.py — Music selection page (UART-driven)
Patch:
- "Coming Soon" 라벨이 왼쪽으로 잘리던 문제 수정: 각 라벨 x좌표를 해당 이미지 rect의 centerx로 정렬.
- 게이지바 대신 "문자 자체가" 다른 색으로 채워지는 채움 효과 추가(2초 홀드에 맞춰 좌→우로 채움).
"""

import argparse
import time
import math
import queue
import threading
from dataclasses import dataclass
from pathlib import Path

import pygame

# --------------------------
# CLI
# --------------------------
def parse_args():
    p = argparse.ArgumentParser(description="Music select page (UART pulses)")
    p.add_argument("--assets", type=str, default=None, help="Folder with background.png, golden.png, soda_pop.png, ques.png")
    p.add_argument("--w", type=int, default=2560)
    p.add_argument("--h", type=int, default=1440)
    p.add_argument("--fps", type=int, default=60)

    # Hold / timing
    p.add_argument("--hold", type=float, default=2.0, help="Seconds to confirm selection")
    p.add_argument("--timeout", type=float, default=0.25, help="Gap allowed between pulses before reset")
    p.add_argument("--confirm_show", type=float, default=1.0, help="Seconds to show confirm effect before exiting")

    # UART
    p.add_argument("--port", type=str, default=None, help="Serial port (COM5 or /dev/ttyUSB0). If omitted, keyboard test mode.")
    p.add_argument("--baud", type=int, default=115200)
    p.add_argument("--debug", action="store_true")

    p.add_argument("--quit-on-select", action="store_true", help="Exit after selection confirmed")

    return p.parse_args()

# --------------------------
# UART (ASCII lines)
# --------------------------
try:
    import serial
except Exception:
    serial = None

class UartReader(threading.Thread):
    daemon = True
    def __init__(self, port, baud, q, debug=False):
        super().__init__()
        self.port = port
        self.baud = baud
        self.q = q
        self.debug = debug
        self.stop_ev = threading.Event()
        self.ser = None
    def run(self):
        if self.port is None or serial is None:
            return
        try:
            self.ser = serial.Serial(self.port, self.baud, timeout=0.01)
        except Exception as e:
            print(f"[UART] open failed: {e}")
            return
        buf = bytearray()
        while not self.stop_ev.is_set():
            data = self.ser.read(1024)
            if not data: 
                continue
            buf.extend(data)
            while b"\\n" in buf:
                line, _, rest = buf.partition(b"\\n")
                buf = bytearray(rest)
                s = line.strip().decode(errors="ignore").upper()
                if self.debug:
                    print(f"[UART] '{s}'")
                self.q.put(("line", s, time.monotonic()))
        try:
            if self.ser:
                self.ser.close()
        except Exception:
            pass
    def stop(self):
        self.stop_ev.set()

# --------------------------
# Helpers & drawing utils
# --------------------------
WHITE = (255,255,255)
NEON_BLUE = (100,150,255)
NEON_RED = (255,80,80)
NEON_YELLOW = (255,220,120)
NEON_GREEN = (90,200,140)
BORDER = (30,30,40)

def load_image(path: Path, size=None, alpha=True) -> pygame.Surface:
    img = pygame.image.load(str(path)).convert_alpha() if alpha else pygame.image.load(str(path)).convert()
    if size:
        img = pygame.transform.smoothscale(img, size)
    return img

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

def draw_fill_text(surface, font, text, rect, ratio, base_color=WHITE, fill_color=NEON_RED):
    """문자 자체가 좌→우로 채워지는 효과. ratio: 0.0~1.0"""
    # draw base (dim white)
    base = font.render(text, True, base_color)
    base_rect = base.get_rect(center=rect.center) if rect.center != (0,0) else rect
    surface.blit(base, base_rect.topleft)
    # draw filled portion
    ratio = max(0.0, min(1.0, ratio))
    if ratio <= 0: 
        return
    fill = font.render(text, True, fill_color)
    clip_w = int(fill.get_width() * ratio)
    if clip_w <= 0:
        return
    clip = pygame.Rect(0, 0, clip_w, fill.get_height())
    surface.set_clip(pygame.Rect(base_rect.topleft, (clip_w, fill.get_height())))
    surface.blit(fill, base_rect.topleft)
    surface.set_clip(None)

def draw_glow_rect(surface, rect, color=(255,255,255), layers=6):
    # soft outer glow by drawing multiple rects growing outward with alpha
    for i in range(layers, 0, -1):
        alpha = int(18 * i)
        s = pygame.Surface((rect.width + i*4, rect.height + i*4), pygame.SRCALPHA)
        pygame.draw.rect(s, (*color, alpha), s.get_rect(), width=6, border_radius=18)
        surface.blit(s, (rect.x - i*2, rect.y - i*2))

# --------------------------
# Hold detector
# --------------------------
class Hold:
    def __init__(self, hold=2.0, timeout=0.25):
        self.hold = hold
        self.timeout = timeout
        self.progress = 0.0
        self.last_ts = -1.0
    def pulse(self, ts):
        self.last_ts = ts
    def update(self, dt, now):
        holding = self.last_ts >= 0 and (now - self.last_ts) <= self.timeout
        just_done = False
        if holding:
            prev = self.progress
            self.progress = min(self.hold, self.progress + dt)
            if prev < self.hold and self.progress >= self.hold:
                just_done = True
        else:
            self.progress = 0.0
        ratio = 0.0 if self.hold <= 0 else max(0.0, min(1.0, self.progress / self.hold))
        return ratio, holding, just_done

@dataclass
class Choice:
    key: str
    label: str
    img: pygame.Surface
    base_rect: pygame.Rect
    text_rect: pygame.Rect
    hold: Hold
    scale_on_hold: float = 1.25

# --------------------------
# Main
# --------------------------
def main():
    args = parse_args()
    W, H = args.w, args.h

    # Assets root
    script_dir = Path(__file__).resolve().parent
    asset_root = Path(args.assets).resolve() if args.assets else script_dir
    print(f"[ASSETS] {asset_root}")

    pygame.init()
    screen = pygame.display.set_mode((W, H))
    pygame.display.set_caption("Music Select")
    clock = pygame.time.Clock()

    # Background
    bg = load_image(asset_root / "background.png", size=(W, H), alpha=False)

    # Load images
    golden_img = load_image(asset_root / "golden.png", size=(530, 500), alpha=True)
    soda_img   = load_image(asset_root / "soda_pop.png", size=(530, 500), alpha=True)
    ques_img   = load_image(asset_root / "ques.png", size=(530, 500), alpha=True)

    # Layout rects
    rect_lt = pygame.Rect(0, 300, 530, 500)            # GOLDEN
    rect_rt = pygame.Rect(W - 530, 300, 530, 500)      # SODA
    rect_lb = pygame.Rect(0, 910, 530, 500)            # COMING1
    rect_rb = pygame.Rect(W - 530, 910, 530, 500)      # COMING2

    # Fonts and title
    title_font = pygame.font.SysFont("Arial", 180, bold=True)
    title_rect = title_font.render("Music Select", True, WHITE).get_rect(center=(W // 2, 100))

    lbl_font_big = pygame.font.SysFont("Arial", 110, bold=True)
    lbl_font_mid = pygame.font.SysFont("Arial", 100, bold=True)

    # --- Label rects: 각 이미지의 centerx로 정렬 + 이미지 위쪽에 위치 ---
    golden_text_rect = lbl_font_big.render("Golden", True, WHITE).get_rect(center=(rect_lt.centerx, rect_lt.top - 40))
    soda_text_rect   = lbl_font_big.render("Soda Pop", True, WHITE).get_rect(center=(rect_rt.centerx, rect_rt.top - 40))
    c1_text_rect     = lbl_font_mid.render("Coming Soon", True, WHITE).get_rect(center=(rect_lb.centerx, rect_lb.top - 40))
    c2_text_rect     = lbl_font_mid.render("Coming Soon", True, WHITE).get_rect(center=(rect_rb.centerx, rect_rb.top - 40))

    # Build choices
    choices = [
        Choice("GOLDEN", "Golden", golden_img, rect_lt, golden_text_rect, Hold(args.hold, args.timeout)),
        Choice("SODA",   "Soda Pop", soda_img, rect_rt, soda_text_rect,   Hold(args.hold, args.timeout)),
        Choice("COMING1","Coming Soon", ques_img, rect_lb, c1_text_rect,  Hold(args.hold, args.timeout)),
        Choice("COMING2","Coming Soon", ques_img, rect_rb, c2_text_rect,  Hold(args.hold, args.timeout)),
    ]

    # UART
    q = queue.Queue()
    uart = None
    if args.port and serial is not None:
        uart = UartReader(args.port, args.baud, q, debug=args.debug)
        uart.start()
    else:
        if args.port and serial is None:
            print("[WARN] pyserial not available; keyboard-only mode")
        else:
            print("[INFO] No --port; keyboard-only mode")

    selected_key = None
    confirm_timer = 0.0

    running = True
    last_time = time.monotonic()
    while running:
        now = time.monotonic()
        dt = now - last_time
        last_time = now

        for e in pygame.event.get():
            if e.type == pygame.QUIT:
                running = False
            elif e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    running = False
                # keyboard pulses for testing
                elif e.key == pygame.K_1:
                    q.put(("line","GOLDEN", now))
                elif e.key == pygame.K_2:
                    q.put(("line","SODA", now))
                elif e.key == pygame.K_3:
                    q.put(("line","COMING1", now))
                elif e.key == pygame.K_4:
                    q.put(("line","COMING2", now))

        # UART queue
        try:
            while True:
                _typ, s, ts = q.get_nowait()
                s_up = s.upper()
                def pulse(name):
                    for ch in choices:
                        if ch.key == name:
                            ch.hold.pulse(ts)
                if s_up in ("GOLDEN","G","LT","LEFTTOP","LEFT_TOP"):
                    pulse("GOLDEN")
                elif s_up in ("SODA","SODA_POP","S","RT","RIGHTTOP","RIGHT_TOP"):
                    pulse("SODA")
                elif s_up in ("COMING1","C1","LB","LEFTBOTTOM","LEFT_BOT"):
                    pulse("COMING1")
                elif s_up in ("COMING2","C2","RB","RIGHTBOTTOM","RIGHT_BOT"):
                    pulse("COMING2")
        except queue.Empty:
            pass

        # Update / confirm
        if selected_key is None:
            for ch in choices:
                ratio, holding, done = ch.hold.update(dt, now)
                if done and selected_key is None:
                    selected_key = ch.key
                    confirm_timer = 0.0
                    print(f"SELECTED:{selected_key}")
        else:
            confirm_timer += dt
            if confirm_timer >= args.confirm_show:
                print("NEXT_PAGE:play")
                if args.quit_on_select:
                    running = False

        # --------------- draw ---------------
        screen.blit(bg, (0,0))
        # central VGA region (black) for consistency
        pygame.draw.rect(screen, (0,0,0), pygame.Rect(530, 200, 1500, 1125))

        draw_neon_text(screen, title_font, "Music Select", WHITE, NEON_BLUE, title_rect)

        for ch in choices:
            # determine ratio
            ratio, holding, _ = ch.hold.update(0, now)  # query without advancing
            scale = ch.scale_on_hold if (holding or (selected_key == ch.key)) else 1.0
            if selected_key == ch.key:
                # small bounce during confirm
                t = min(1.0, confirm_timer)
                scale = ch.scale_on_hold - 0.1 * (t)  # 1.25 -> 1.15

            img = ch.img
            if scale != 1.0:
                sw = int(img.get_width() * scale)
                sh = int(img.get_height() * scale)
                simg = pygame.transform.smoothscale(img, (sw, sh))
                # center over the base_rect
                rect = simg.get_rect(center=ch.base_rect.center)
                screen.blit(simg, rect.topleft)
                # glow outline
                draw_glow_rect(screen, rect, color=WHITE, layers=6)
            else:
                screen.blit(img, ch.base_rect.topleft)

            # label with fill effect
            font = pygame.font.SysFont("Arial", 110, bold=True) if ch.key in ("GOLDEN","SODA") else pygame.font.SysFont("Arial", 100, bold=True)
            # 베이스 글자 + 네온 글로우 (연출), 그 위에 채움 효과
            draw_neon_text(screen, font, ch.label, WHITE, NEON_RED, ch.text_rect)
            fill_ratio = 1.0 if (selected_key == ch.key) else (ratio if (holding or ratio > 0.0) else 0.0)
            if fill_ratio > 0.0:
                draw_fill_text(screen, font, ch.label, ch.text_rect, fill_ratio, base_color=WHITE, fill_color=NEON_YELLOW)

            # confirm flash overlay for the selected choice
            if selected_key == ch.key:
                flash_alpha = int(180 * max(0.0, 1.0 - confirm_timer))  # fade out over 1s
                if flash_alpha > 0:
                    s = pygame.Surface((ch.base_rect.width+30, ch.base_rect.height+30), pygame.SRCALPHA)
                    s.fill((255,255,255, flash_alpha))
                    r = s.get_rect(center=ch.base_rect.center)
                    screen.blit(s, r.topleft)

        pygame.display.flip()
        clock.tick(args.fps)

    if uart:
        uart.stop()
        uart.join(timeout=1.0)
    pygame.quit()

if __name__ == "__main__":
    main()
