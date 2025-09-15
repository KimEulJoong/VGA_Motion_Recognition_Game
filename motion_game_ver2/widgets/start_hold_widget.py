# widgets/start_hold_widget.py
from __future__ import annotations
import time, threading, queue
from dataclasses import dataclass
from typing import Optional, Tuple

import pygame
from utils.neon import draw_neon_text
from utils.helpers import make_font_to_fit_rect

try:
    import serial  # optional
except Exception:
    serial = None


# ---------------- UART ----------------
class UartReader(threading.Thread):
    """parse_mode: anybyte | startline | binary01"""
    daemon = True
    def __init__(self, port: str, baud: int, parse_mode: str, out_q: "queue.Queue", debug: bool = False):
        super().__init__()
        self.port, self.baud, self.mode, self.q, self.debug = port, baud, parse_mode, out_q, debug
        self._stop = threading.Event()
        self.ser = None

    def run(self):
        if self.port is None or serial is None:
            return
        try:
            self.ser = serial.Serial(self.port, self.baud, timeout=0.01)
        except Exception as e:
            print(f"[UART] Open failed: {e}")
            return

        buf = bytearray()
        while not self._stop.is_set():
            try:
                data = self.ser.read(1024)
            except Exception as e:
                print(f"[UART] Read error: {e}")
                break
            if not data:
                continue

            if self.mode == "anybyte":
                self.q.put({"type": "pulse", "ts": time.monotonic()})
                if self.debug:
                    print(f"[UART] pulse ({len(data)}B)")
            else:
                buf.extend(data)
                while b"\n" in buf:  # 정확한 줄바꿈
                    line, _, rest = buf.partition(b"\n")
                    buf = bytearray(rest)
                    s = line.strip().decode(errors="ignore")
                    if not s:
                        continue
                    if self.mode == "startline":
                        if s.upper() == "START":
                            self.q.put({"type": "pulse", "ts": time.monotonic()})
                    elif self.mode == "binary01":
                        if s == "1":
                            self.q.put({"type": "pressed", "val": 1, "ts": time.monotonic()})
                        elif s == "0":
                            self.q.put({"type": "pressed", "val": 0, "ts": time.monotonic()})

        try:
            if self.ser:
                self.ser.close()
        except Exception:
            pass

    def stop(self):
        self._stop.set()


# --------------- Hold -----------------
@dataclass
class HoldState:
    progress: float = 0.0
    last_pulse_ts: float = -1.0
    explicitly_pressed: bool = False

class HoldDetector:
    def __init__(self, hold_seconds: float, timeout: float, debug: bool = False):
        self.hold_s = hold_seconds
        self.timeout = timeout
        self.debug = debug
        self.state = HoldState()

    def on_pulse(self, now: float):
        self.state.last_pulse_ts = now
        if self.debug:
            print(f"[Hold] pulse @ {now:.3f}")

    def set_explicit(self, val: int, now: float):
        self.state.explicitly_pressed = bool(val)
        if val:
            self.state.last_pulse_ts = now
        if self.debug:
            print(f"[Hold] explicit={val}")

    def update(self, dt: float, now: float):
        holding = self.state.explicitly_pressed or (
            self.state.last_pulse_ts >= 0 and (now - self.state.last_pulse_ts) <= self.timeout
        )
        prev = self.state.progress
        self.state.progress = min(self.hold_s, (self.state.progress + dt) if holding else 0.0)
        just_done = prev < self.hold_s and self.state.progress >= self.hold_s
        ratio = 0.0 if self.hold_s <= 0 else max(0.0, min(1.0, self.state.progress / self.hold_s))
        return ratio, holding, just_done


# --------------- Widget ---------------
class StartHoldWidget:
    """N초 홀드 → 완료 버튼. 한 창/한 루프 재사용 가능(reset)."""
    WHITE=(255,255,255); NEON_RED=(255,80,80)
    ACTIVE=(130,170,255); IDLE=(80,80,100); DONE=(90,200,140)
    BORDER=(30,30,40); GBG=(25,25,30)

    def __init__(self, screen_size: Tuple[int,int],
                 port: Optional[str] = None, baud: int = 115200, parse_mode: str = "anybyte",
                 hold_s: float = 3.0, timeout: float = 0.25, debug: bool = False,
                 label_idle: str = "Start!!", label_done: str = "Ready!",
                 title_default: str = "Motion Game: Intro",
                 btn_rect: Optional[Tuple[int,int,int,int]] = None,
                 title_pos: Optional[Tuple[int,int]] = None):
        self.W, self.H = screen_size
        self.hold = HoldDetector(hold_s, timeout, debug)
        self.q: "queue.Queue" = queue.Queue()
        self.reader: Optional[UartReader] = None
        if port and serial is not None:
            self.reader = UartReader(port, baud, parse_mode, self.q, debug)
            self.reader.start()

        self.title_font = pygame.font.SysFont("Arial", 180, bold=True)
        self.btn_font   = pygame.font.SysFont("Arial", 150, bold=True)
        self.hint_font  = pygame.font.SysFont("Arial", 36)

        self.label_idle = label_idle
        self.label_done = label_done
        self.title_default = title_default

        self.btn_rect_base = pygame.Rect(60, self.H - 180, 420, 130) if btn_rect is None else pygame.Rect(*btn_rect)
        self.title_center  = (self.W // 2, 100) if title_pos is None else title_pos

        self._ratio = 0.0
        self._active = False
        self._completed = False

    # lifecycle
    def reset(self):
        self.hold.state = HoldState()
        self._ratio = 0.0; self._active = False; self._completed = False

    def stop(self):
        if self.reader:
            self.reader.stop()
            self.reader.join(timeout=0.5)
            self.reader = None

    # input
    def handle_event(self, e: "pygame.event.Event"):
        if e.type == pygame.KEYDOWN and e.key == pygame.K_SPACE:
            self.hold.on_pulse(time.monotonic())

    def pump_uart(self):
        try:
            while True:
                m = self.q.get_nowait()
                now = time.monotonic()
                if m["type"] == "pulse":
                    self.hold.on_pulse(now)
                elif m["type"] == "pressed":
                    self.hold.set_explicit_pressed(bool(m.get("val", 0)), now)  # ← 함수명 수정
        except queue.Empty:
            pass

    # update/draw
    def update(self, dt: float) -> bool:
        if self._completed:
            return True
        ratio, active, just_done = self.hold.update(dt, time.monotonic())
        self._ratio, self._active = ratio, active
        if just_done:
            self._completed = True
        return self._completed

    def draw(self, surface: "pygame.Surface",
             title: Optional[str] = None,
             hint: str = "손을 START 영역에 유지 · Space=테스트 · ESC=종료"):
        if title is None:
            title = self.title_default
        if title:
            tw, th = self.title_font.size(title)
            title_rect = pygame.Rect(0,0,tw,th); title_rect.center = self.title_center
            draw_neon_text(surface, self.title_font, title, self.WHITE, (100,150,255), title_rect)

        r = self.btn_rect_base
        fill = self.DONE if self._completed else (self.ACTIVE if self._active else self.IDLE)
        pygame.draw.rect(surface, fill, r, border_radius=24)
        pygame.draw.rect(surface, self.BORDER, r, width=4, border_radius=24)

        pad = 14
        gbg = r.inflate(-pad*2, -pad*2)
        pygame.draw.rect(surface, self.GBG, gbg, border_radius=16)
        filled = gbg.copy(); filled.width = max(0, int(gbg.width * self._ratio))
        pygame.draw.rect(surface, self.NEON_RED, filled, border_radius=16)

        # text = self.label_idle if not self._completed else self.label_done
        # lw, lh = self.btn_font.size(text)
        # lbl_rect = pygame.Rect(0,0,lw,lh); lbl_rect.center = r.center
        # draw_neon_text(surface, self.btn_font, text, self.WHITE, self.NEON_RED, lbl_rect)

        # ── Label (여기서 'text'를 먼저 정의!) ───────────────
        text = self.label_done if self._completed else self.label_idle
    
        # 버튼 사각형(r) 안에 들어오도록 폰트 크기 자동 조정
        font = make_font_to_fit_rect(
            text=text,
            rect=r,
            font_name="Arial",
            bold=True,
            max_size=150,      # 필요하면 상한 조절
            inner_pad=pad,
            glow_layers=6
        )
    
        lw, lh = font.size(text)
        lbl_rect = pygame.Rect(0, 0, lw, lh); lbl_rect.center = r.center
        draw_neon_text(surface, font, text, self.WHITE, self.NEON_RED, lbl_rect, glow_layers=6)

        if hint:
            hs = self.hint_font.render(hint, True, (230,230,230))
            surface.blit(hs, hs.get_rect(midbottom=(self.W//2, self.H-20)))

        text = self.label_idle if not self._completed else self.label_done
