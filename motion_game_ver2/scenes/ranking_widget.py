# ranking_widget.py
from __future__ import annotations
import time
import pygame

# ----- 가벼운 UART 송신 헬퍼 (pyserial 있으면 사용, 없으면 FAKE 로그) -----
class SerialSender:
    def __init__(self, port: str | None, baud: int = 115200, *, debug: bool = False):
        self.port = port
        self.baud = baud
        self.debug = debug
        self.ser = None

    def open(self):
        if not self.port:
            return
        try:
            import serial  # pyserial
        except Exception:
            if self.debug:
                print("[UART][FAKE] pyserial 미설치: 실제 전송은 생략됩니다.")
            return
        try:
            self.ser = serial.Serial(self.port, self.baud, timeout=0)
            if self.debug:
                print(f"[UART] Open {self.port} @ {self.baud}")
        except Exception as e:
            self.ser = None
            if self.debug:
                print(f"[UART] Open 실패: {e}")

    # 바이트 로그 포맷터: [UART][TX BYTE] 0x74 ('t')
    def _fmt_tx_byte(self, v: int) -> str:
        ch = chr(v) if 32 <= v <= 126 else '.'
        return f"[UART][TX BYTE] 0x{v:02x} ('{ch}')"

    def send(self, b: bytes):
        if not b:
            return
        if self.ser and getattr(self.ser, "is_open", False):
            try:
                n = self.ser.write(b)
                self.ser.flush()  # 출력 버퍼 비우기(즉시 송신 보장)
                if self.debug:
                    # 바이트별 로그 출력
                    for v in b:
                        print(self._fmt_tx_byte(v))
                    # 필요하면 총괄 로그도 추가 가능:
                    # print(f"[UART][TX] wrote={n} -> {self.port}")
            except Exception as e:
                if self.debug:
                    print(f"[UART] write 실패: {e}")
        else:
            # 포트가 열려있지 않을 때도 동일 포맷으로 FAKE 로그
            if self.debug:
                for v in b:
                    print(self._fmt_tx_byte(v))

    def close(self):
        if self.ser:
            try:
                self.ser.close()
                if self.debug:
                    print("[UART] Closed")
            except Exception:
                pass
            self.ser = None


# ----- 랭킹 씬 -----
class RankingScene:
    def __init__(self, W, H, rankings, *,
                 show_seconds: float = 8.0,
                 port: str | None = None, baud: int = 115200,
                 send_byte: bytes = b't',
                 debug: bool = False,
                 title_px: int | None = None,
                 item_px:  int | None = None,
                 line_gap: int = 16,
                 font_name: str | None = "malgun gothic",
                 font_bold: bool = False,
                 font_path: str | None = None,
                 use_shadow: bool = True,             # ← 얇은 외곽 느낌 켬
                 shadow_color: tuple[int,int,int] = (85, 140, 255),
                 shadow_radius: int = 2,              # ← 2px이면 “적당히” 두께감
                 shadow_offset: tuple[int,int] = (0, 1),  # 살짝 아래로
                 title_color: tuple[int,int,int] = (255, 255, 255),
                 item_color:  tuple[int,int,int] = (220, 220, 240),
                 bg_color:    tuple[int,int,int] = (20, 20, 20),
                 items_top_offset: int = 120
                 ):
        self.W, self.H = W, H
        self.rankings = list(rankings)
        self.show_seconds = show_seconds
        self.finished = False
        self.start_time = None
        self._items_top_offset = items_top_offset

        self.debug = debug
        self._uart = SerialSender(port, baud, debug=debug)
        self._send_byte = send_byte
        self._sent = False

        # 폰트/표시 파라미터
        self._title_px = title_px if title_px is not None else max(48, int(H * 0.12))
        self._item_px  = item_px  if item_px  is not None else max(36, int(H * 0.07))
        self._line_gap = line_gap
        self._font_name = font_name
        self._font_bold = font_bold
        self._font_path = font_path

        # 색/그림자
        self._use_shadow   = use_shadow
        self._shadow_color = shadow_color
        self._shadow_radius = shadow_radius
        self._shadow_offset = shadow_offset
        self._title_color  = title_color
        self._item_color   = item_color
        self._bg_color     = bg_color

        # 폰트 핸들
        self._font_big = None
        self._font_small = None

    def _build_font(self, size):
        if self._font_path:
            return pygame.font.Font(self._font_path, size)
        name = self._font_name or "segoe ui"
        return pygame.font.SysFont(name, size, bold=self._font_bold)

    def enter(self):
        self._font_big   = self._build_font(self._title_px)
        self._font_small = self._build_font(self._item_px)
        self.start_time = time.monotonic()
        if self.debug:
            print("[RANKING] enter")

    def update(self, dt, now):
        if self.start_time is None:
            self.start_time = now
        if (now - self.start_time) > self.show_seconds:
            self.finished = True

    def _blit_center(self, screen, surf, y):
        screen.blit(surf, (self.W // 2 - surf.get_width() // 2, y))

    def _draw_title_with_soft_outline(self, screen, text, y):
        # 본문 먼저 계산해 중앙 x를 고정
        main = self._font_big.render(text, True, self._title_color)
        x = self.W // 2 - main.get_width() // 2

        if self._use_shadow and self._shadow_radius > 0:
            r = self._shadow_radius
            ox, oy = self._shadow_offset
            # 소프트하게 8방향 + 대각 1칸 더 (얇은 테두리 느낌)
            offsets = {(ox, oy)}
            for dx in (-r, 0, r):
                for dy in (-r, 0, r):
                    if dx == 0 and dy == 0: 
                        continue
                    offsets.add((dx + ox, dy + oy))
            for dx, dy in offsets:
                stk = self._font_big.render(text, True, self._shadow_color)
                screen.blit(stk, (x + dx, y + dy))

        screen.blit(main, (x, y))

    def draw(self, screen):
        screen.fill(self._bg_color)

        # 제목 (흰색 본문 + 파란빛 얇은 외곽)
        self._draw_title_with_soft_outline(screen, "Ranking Board", 70)

        # 항목
        y0 = 70 + self._title_px + self._items_top_offset
        step = self._item_px + self._line_gap

        for i, (name, score) in enumerate(self.rankings, start=1):
            line = self._font_small.render(
                f"{i}. {name} - {score}",
                True,
                (255, 215, 0)
            )
            self._blit_center(screen, line, y0 + (i-1) * step)

    def done(self) -> bool:
        return self.finished

    def exit(self):
        try:
            if not self._sent and self._send_byte:
                self._uart.open()
                self._uart.send(self._send_byte)
                self._sent = True
        finally:
            self._uart.close()
            if self.debug:
                print("[RANKING] exit (sent on exit)")
