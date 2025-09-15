# start_hold_widget.py
# UART(또는 키보드) 기반 3초 홀드 START 위젯
# - pygame은 호출 측에서 init/set_mode를 끝낸 뒤 사용하세요.

from __future__ import annotations
import time, threading, queue
from dataclasses import dataclass

try:
    import serial  # optional
except Exception:
    serial = None

import pygame  # required

class UartReader(threading.Thread):
    """UART 수신 스레드: anybyte / startline / binary01 모드로 이벤트를 큐로 전달."""
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

            now = time.monotonic()
            if self.mode == "anybyte":
                # 아무 바이트든 들어오면 pulse
                self.q.put({"type": "pulse", "ts": now})
                if self.debug:
                    print(f"[UART] pulse ({len(data)}B)")
            else:
                buf.extend(data)
                while b"\n" in buf:
                    line, _, rest = buf.partition(b"\n")
                    buf = bytearray(rest)
                    s = line.strip().decode(errors="ignore")
                    if self.debug:
                        print(f"[UART] line='{s}'")
                    if self.mode == "startline":
                        if s.upper() == "START":
                            self.q.put({"type": "pulse", "ts": now})
                    elif self.mode == "binary01":
                        if s == "1":
                            self.q.put({"type": "pressed", "val": 1, "ts": now})
                        elif s == "0":
                            self.q.put({"type": "pressed", "val": 0, "ts": now})

        try:
            if self.ser:
                self.ser.close()
        except Exception:
            pass

    def stop(self):
        self._stop.set()


@dataclass
class HoldState:
    progress: float = 0.0
    last_pulse_ts: float = -1.0
    explicitly_pressed: bool = False


class HoldDetector:
    """펄스/상태 입력을 받아 'hold_seconds' 동안 유지되면 완료 플래그를 반환."""
    def __init__(self, hold_seconds: float, timeout: float, debug: bool = False):
        self.hold_s, self.timeout, self.debug = hold_seconds, timeout, debug
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
        just_done = False
        holding = self.state.explicitly_pressed or (
            self.state.last_pulse_ts >= 0 and (now - self.state.last_pulse_ts) <= self.timeout
        )
        prev = self.state.progress
        self.state.progress = min(self.hold_s, (self.state.progress + dt) if holding else 0.0)
        if prev < self.hold_s and self.state.progress >= self.hold_s:
            just_done = True
        ratio = 0.0 if self.hold_s <= 0 else max(0.0, min(1.0, self.state.progress / self.hold_s))
        return ratio, holding, just_done


def draw_neon_text(surface: "pygame.Surface", font: "pygame.font.Font", text: str,
                   base_color, glow_color, rect: "pygame.Rect", glow_layers: int = 6):
    """네온 느낌 텍스트(고정 텍스트는 호출 측에서 미리 렌더 캐싱 권장)."""
    for i in range(1, glow_layers + 1):
        glow = font.render(text, True, glow_color)
        glow.set_alpha(40)
        surface.blit(glow, rect.move( i, 0)); surface.blit(glow, rect.move(-i, 0))
        surface.blit(glow, rect.move(0,  i)); surface.blit(glow, rect.move(0, -i))
        surface.blit(glow, rect.move( i,  i)); surface.blit(glow, rect.move(-i, -i))
        surface.blit(glow, rect.move( i, -i)); surface.blit(glow, rect.move(-i,  i))
    base = font.render(text, True, base_color)
    surface.blit(base, rect)


class StartHoldWidget:
    """인트로 화면용 '3초 홀드 → START' 버튼 위젯"""
    def __init__(self, screen_size: tuple[int, int],
                 port: str | None = None, baud: int = 115200, parse_mode: str = "anybyte",
                 hold_s: float = 3.0, timeout: float = 0.25, debug: bool = False):
        self.W, self.H = screen_size
        self.hold = HoldDetector(hold_s, timeout, debug)
        self.q: "queue.Queue" = queue.Queue()
        self.reader: UartReader | None = None
        if port and serial is not None:
            self.reader = UartReader(port, baud, parse_mode, self.q, debug)
            self.reader.start()

        # 스타일
        self.WHITE = (255, 255, 255); self.NEON_RED = (255, 80, 80)
        self.ACTIVE = (130, 170, 255); self.IDLE = (80, 80, 100)
        self.DONE = (90, 200, 140); self.BORDER = (30, 30, 40); self.GBG = (25, 25, 30)

        self.title_font = pygame.font.SysFont("Arial", 120, bold=True)
        self.btn_font   = pygame.font.SysFont("Arial", 96, bold=True)
        self.hint_font  = pygame.font.SysFont("Arial", 28)

        # 버튼 위치 (좌하단)
        self.btn_rect_base = pygame.Rect(60, self.H - 180, 420, 130)

        self._ratio = 0.0
        self._active = False
        self._completed = False

    # --------- I/O ---------
    def handle_event(self, event: "pygame.event.Event"):
        """키보드 테스트: SPACE를 누르면 pulse."""
        if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
            self.hold.on_pulse(time.monotonic())

    def pump_uart(self):
        """UART 이벤트 큐 비우기 (프레임마다 호출)."""
        try:
            while True:
                m = self.q.get_nowait()
                now = time.monotonic()
                if m["type"] == "pulse":
                    self.hold.on_pulse(now)
                elif m["type"] == "pressed":
                    self.hold.set_explicit(m.get("val", 0), now)
        except queue.Empty:
            pass
            
    # --------- UPDATE / DRAW ---------
    def update(self, dt: float) -> bool:
        """dt 갱신. 완료 시 True 반환(씬 전환용)."""
        if self._completed:
            return True
        ratio, active, just_done = self.hold.update(dt, time.monotonic())
        self._ratio, self._active = ratio, active
        if just_done:
            self._completed = True
        return self._completed

    def draw(self, surface: "pygame.Surface",
             title: str = "Motion Game: Intro",
             hint: str = "손을 START 영역에 3초 유지 · Space=테스트 · ESC=종료"):
        # 타이틀
        tw, th = self.title_font.size(title)
        title_rect = pygame.Rect(0, 0, tw, th)
        title_rect.center = (self.W // 2, 100)
        draw_neon_text(surface, self.title_font, title, self.WHITE, (100, 150, 255), title_rect)

        # 버튼 + 게이지
        scale = 1.05 if self._active else 1.0
        r = self.btn_rect_base.copy()
        cx, cy = r.center
        r.width = int(r.width * scale); r.height = int(r.height * scale); r.center = (cx, cy)

        fill = self.DONE if self._completed else (self.ACTIVE if self._active else self.IDLE)
        pygame.draw.rect(surface, fill, r, border_radius=20)
        pygame.draw.rect(surface, self.BORDER, r, width=4, border_radius=20)

        pad = 12
        gbg = r.inflate(-pad * 2, -pad * 2)
        pygame.draw.rect(surface, self.GBG, gbg, border_radius=16)

        filled = gbg.copy()
        filled.width = max(0, int(gbg.width * self._ratio))
        pygame.draw.rect(surface, self.NEON_RED, filled, border_radius=16)

        text = "Start!!" if not self._completed else "Ready!"
        lw, lh = self.btn_font.size(text)
        lbl_rect = pygame.Rect(0, 0, lw, lh); lbl_rect.center = r.center
        draw_neon_text(surface, self.btn_font, text, self.WHITE, self.NEON_RED, lbl_rect)

        # 힌트
        hs = self.hint_font.render(hint, True, (230, 230, 230))
        surface.blit(hs, hs.get_rect(midbottom=(self.W // 2, self.H - 16)))
        

    # --------- STATE / CLEANUP ---------
    def completed(self) -> bool:
        return self._completed

    def stop(self):
        if self.reader:
            self.reader.stop()
            self.reader.join(timeout=0.5)
