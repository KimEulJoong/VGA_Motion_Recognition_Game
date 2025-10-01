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
                 debug: bool = False):
        self.W, self.H = W, H
        self.rankings = list(rankings)  # [(name, score), ...]
        self.show_seconds = show_seconds
        self.finished = False
        self.start_time = None

        self.debug = debug
        self._uart = SerialSender(port, baud, debug=debug)
        self._send_byte = send_byte
        self._sent = False

        # 폰트는 pygame.init 이후 생성 가능
        self._font_big = None
        self._font_small = None

    def enter(self):
        if self._font_big is None:
            self._font_big = pygame.font.SysFont(None, 90)
        if self._font_small is None:
            self._font_small = pygame.font.SysFont(None, 60)

        self.start_time = time.monotonic()
        if self.debug:
            print("[RANKING] enter")

    def update(self, dt, now):
        if self.start_time is None:
            self.start_time = now
        if (now - self.start_time) > self.show_seconds:
            self.finished = True

    def draw(self, screen):
        screen.fill((20, 20, 20))
        title_txt = self._font_big.render("Ranking Board", True, (255, 215, 0))
        screen.blit(title_txt, (self.W // 2 - title_txt.get_width() // 2, 80))

        for i, (name, score) in enumerate(self.rankings, start=1):
            line = self._font_small.render(f"{i}. {name} - {score}", True, (200, 200, 255))
            screen.blit(line, (self.W // 2 - line.get_width() // 2, 200 + i * 70))

    def done(self) -> bool:
        return self.finished

    def exit(self):
        # ★ 랭킹 화면이 끝나는 순간 전송
        try:
            if not self._sent and self._send_byte:
                self._uart.open()
                self._uart.send(self._send_byte)
                self._sent = True
        finally:
            self._uart.close()
            if self.debug:
                print("[RANKING] exit (sent on exit)")
