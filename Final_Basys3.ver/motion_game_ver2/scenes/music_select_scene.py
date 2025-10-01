# scenes/music_select_scene.py
import time, queue, threading
from dataclasses import dataclass
from pathlib import Path
import pygame

try:
    import serial
except Exception:
    serial = None

WHITE=(255,255,255); NEON_BLUE=(100,150,255); NEON_RED=(255,80,80); NEON_YELLOW=(255,220,120)

# --- UART: 줄 단위. (개행 없이 오면 안 잡힘 → 아래 주석의 대안 참고) ---
class UartReader(threading.Thread):
    daemon=True
    def __init__(self, port, baud, out_q, debug=False):
        super().__init__()
        self.port, self.baud, self.q, self.debug = port, baud, out_q, debug
        self._stop = threading.Event(); self.ser=None
    def run(self):
        if self.port is None or serial is None: return
        try:
            self.ser = serial.Serial(self.port, self.baud, timeout=0.01)
        except Exception as e:
            print(f"[UART] open failed: {e}"); return
        buf = bytearray()
        while not self._stop.is_set():
            data = self.ser.read(1024)
            if not data: continue
            buf.extend(data)
            # CR만 오는 경우도 있으니 CR→LF 치환(선택)
            while b"\r" in buf and b"\n" not in buf:
                i = buf.find(b"\r"); buf[i:i+1] = b"\n"
            while b"\n" in buf:
                line, _, rest = buf.partition(b"\n"); buf = bytearray(rest)
                s = line.strip().decode(errors="ignore").upper()
                if self.debug: print(f"[UART] '{s}'")
                self.q.put(("line", s, time.monotonic()))
        try:
            if self.ser: self.ser.close()
        except Exception: pass
    def stop(self): self._stop.set()

# ---- 간단 Hold ----
class Hold:
    def __init__(self, hold=2.0, timeout=0.25):
        self.hold, self.timeout = hold, timeout
        self.progress = 0.0; self.last=-1.0
    def pulse(self, ts): self.last = ts
    def update(self, dt, now):
        holding = (self.last>=0 and (now-self.last)<=self.timeout)
        prev = self.progress
        self.progress = min(self.hold, self.progress+dt) if holding else 0.0
        done = (prev<self.hold and self.progress>=self.hold)
        ratio = 0.0 if self.hold<=0 else max(0.0, min(1.0, self.progress/self.hold))
        return ratio, holding, done

@dataclass
class Choice:
    key: str
    label: str
    img: pygame.Surface
    base_rect: pygame.Rect
    text_rect: pygame.Rect
    hold: Hold
    scale_on_hold: float = 1.25
    enabled: bool = True

# ---- 텍스트/그림 도우미 (필요한 것만) ----
def draw_neon_text(surface, font, text, base_color, glow_color, rect, glow_layers=6):
    for i in range(1, glow_layers+1):
        g = font.render(text, True, glow_color); g.set_alpha(40)
        for dx,dy in ((i,0),(-i,0),(0,i),(0,-i),(i,i),(-i,-i),(i,-i),(-i,i)): surface.blit(g, rect.move(dx,dy))
    surface.blit(font.render(text, True, base_color), rect)

def draw_fill_text(surface, font, text, rect, ratio, base_color=WHITE, fill_color=NEON_YELLOW):
    base = font.render(text, True, base_color); base_rect = base.get_rect(center=rect.center)
    surface.blit(base, base_rect.topleft)
    ratio=max(0.0,min(1.0,ratio)); 
    if ratio<=0: return
    fill = font.render(text, True, fill_color)
    clip_w = int(fill.get_width()*ratio)
    surface.set_clip(pygame.Rect(base_rect.x, base_rect.y, clip_w, fill.get_height()))
    surface.blit(fill, base_rect.topleft); surface.set_clip(None)

def load_image(path: Path, size=None, alpha=True):
    img = pygame.image.load(str(path)).convert_alpha() if alpha else pygame.image.load(str(path)).convert()
    return pygame.transform.smoothscale(img, size) if size else img

class MusicSelectScene:
    """
    인터페이스:
      - enter() / exit()
      - handle_event(e, now)
      - update(dt, now)
      - draw(screen)
      - done() -> bool
      - get_result() -> str (예: 'GOLDEN'/'SODA'/...)
    """
    def __init__(self, W, H, *, assets_dir: Path, port=None, baud=115200, hold=2.0, timeout=0.25, debug=False, confirm_show: float = 1.0):
        self.W, self.H = W, H
        self.assets = Path(assets_dir)
        self.port, self.baud, self.debug = port, baud, debug
        self.hold_s, self.timeout = hold, timeout

        self.q = queue.Queue(); self.uart=None
        self._selected=None; self._confirm_t=0.0
        self._entered=False
        self.confirm_show = confirm_show
        self._kb_hold = None

    def enter(self):
        # 배경/이미지/폰트
        W,H = self.W, self.H
        self.bg = load_image(self.assets/"background.png", size=(W,H), alpha=False)
        golden = load_image(self.assets/"golden.png", size=(530,500), alpha=True)
        soda   = load_image(self.assets/"soda_pop.png", size=(530,500), alpha=True)
        ques   = load_image(self.assets/"ques.png", size=(530,500), alpha=True)

        self.title_font = pygame.font.SysFont("Arial", 180, bold=True)
        self.title_rect = self.title_font.render("Music Select", True, WHITE).get_rect(center=(W//2, 100))

        rect_lt = pygame.Rect(0, 300, 530, 500)
        rect_rt = pygame.Rect(W-530, 300, 530, 500)
        rect_lb = pygame.Rect(0, 910, 530, 500)
        rect_rb = pygame.Rect(W-530, 910, 530, 500)

        lbl_big = pygame.font.SysFont("Arial", 110, bold=True)
        lbl_mid = pygame.font.SysFont("Arial", 100, bold=True)
        t_g = lbl_big.render("Golden", True, WHITE).get_rect(center=(rect_lt.centerx, rect_lt.top-40))
        t_s = lbl_big.render("Soda Pop", True, WHITE).get_rect(center=(rect_rt.centerx, rect_rt.top-40))
        t_c1= lbl_mid.render("Coming Soon", True, WHITE).get_rect(center=(rect_lb.centerx, rect_lb.top-40))
        t_c2= lbl_mid.render("Coming Soon", True, WHITE).get_rect(center=(rect_rb.centerx, rect_rb.top-40))

        self.choices = [
            Choice("GOLDEN","Golden",     golden, rect_lt, t_g, Hold(self.hold_s, self.timeout), enabled=True),
            Choice("SODA",  "Soda Pop",   soda,   rect_rt, t_s, Hold(self.hold_s, self.timeout), enabled=True),
            Choice("COMING1","Coming Soon",ques,  rect_lb, t_c1, Hold(self.hold_s, self.timeout), enabled=False),
            Choice("COMING2","Coming Soon",ques,  rect_rb, t_c2, Hold(self.hold_s, self.timeout), enabled=False),
        ]

        # UART
        if self.port and serial is not None:
            self.uart = UartReader(self.port, self.baud, self.q, debug=self.debug)
            self.uart.start()

        self._entered=True

    def exit(self):
        if self.uart:
            self.uart.stop(); self.uart.join(timeout=1.0)
            self.uart=None
        self._entered=False

    def _pulse(self, name, ts):
        for ch in self.choices:
            if ch.key == name and ch.enabled:   # ★ enabled만 펄스
                ch.hold.pulse(ts)

    def handle_event(self, e, now):
        if e.type == pygame.KEYDOWN:
            if e.key==pygame.K_1: self._kb_hold = "GOLDEN"
            elif e.key==pygame.K_2: self._kb_hold = "SODA"
            elif e.key==pygame.K_3: self._kb_hold = "COMING1"
            elif e.key==pygame.K_4: self._kb_hold = "COMING2"
        elif e.type == pygame.KEYUP:
            # 1~4 키를 떼면 중지
            if e.key in (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4):
                self._kb_hold = None

    def _drain_uart(self):
        try:
            while True:
                _typ, s, ts = self.q.get_nowait()
                su = s.upper()
                if su in ("GOLDEN","G","LT","LEFTTOP","LEFT_TOP"):
                    self._pulse("GOLDEN", ts)
                elif su in ("SODA","SODAPOP","SODA_POP","S","RT","RIGHTTOP","RIGHT_TOP"):  # ★ SODAPOP 추가
                    self._pulse("SODA", ts)
                elif su in ("COMING1","C1","LB","LEFTBOTTOM","LEFT_BOT"):
                    self._pulse("COMING1", ts)
                elif su in ("COMING2","C2","RB","RIGHTBOTTOM","RIGHT_BOT"):
                    self._pulse("COMING2", ts)
        except queue.Empty:
            pass

    def update(self, dt, now):
        if not self._entered: return
        self._drain_uart()
        # 키를 누르고 있는 동안 지속 펄스
        if self._kb_hold:
            self._pulse(self._kb_hold, now)

        if self._selected is None:
            for ch in self.choices:
                _,_,done = ch.hold.update(dt, now)
                if done and ch.enabled and self._selected is None:
                    self._selected = ch.key
                    self._confirm_t = 0.0
        else:
            self._confirm_t += dt

    def draw(self, screen):
        draw_neon_text(screen, self.title_font, "Music Select", WHITE, NEON_BLUE, self.title_rect)
        now = time.monotonic()

        for ch in self.choices:
            ratio, holding, _ = ch.hold.update(0, now)

            # 비활성: 반투명하게, 게이지/스케일 효과 금지
            if not ch.enabled:
                img = ch.img.copy()
                img.set_alpha(120)
                rect = img.get_rect(center=ch.base_rect.center)
                screen.blit(img, rect.topleft)
                # 회색 라벨
                font = pygame.font.SysFont("Arial", 100, bold=True)
                draw_neon_text(screen, font, ch.label, (180,180,180), (60,60,60), ch.text_rect)
                # 자물쇠 모양(간단 박스)
                lock = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
                pygame.draw.rect(lock, (0,0,0,80), lock.get_rect(), border_radius=20)
                screen.blit(lock, rect.topleft)
                continue

            # 활성 카드: 기존 로직 그대로
            scale = ch.scale_on_hold if (holding or (self._selected==ch.key)) else 1.0
            if self._selected == ch.key and self.confirm_show > 0:
                t = min(1.0, self._confirm_t / self.confirm_show)
                scale = ch.scale_on_hold - 0.1 * t

            img = ch.img
            if scale != 1.0:
                sw, sh = int(img.get_width()*scale), int(img.get_height()*scale)
                simg = pygame.transform.smoothscale(img, (sw, sh))
                rect = simg.get_rect(center=ch.base_rect.center)
                screen.blit(simg, rect.topleft)
            else:
                rect = ch.base_rect
                screen.blit(img, rect.topleft)

            font = pygame.font.SysFont("Arial", 110, bold=True)
            draw_neon_text(screen, font, ch.label, WHITE, NEON_RED, ch.text_rect)
            fill_ratio = 1.0 if (self._selected==ch.key) else ratio
            if fill_ratio > 0.0:
                draw_fill_text(screen, font, ch.label, ch.text_rect, fill_ratio)

            if self._selected == ch.key and self.confirm_show > 0:
                t = min(1.0, self._confirm_t / self.confirm_show)
                flash_alpha = int(180 * (1.0 - t))
                if flash_alpha > 0:
                    s = pygame.Surface((rect.width+30, rect.height+30), pygame.SRCALPHA)
                    s.fill((255,255,255, flash_alpha))
                    r = s.get_rect(center=rect.center)
                    screen.blit(s, r.topleft)

    def done(self): 
        # 선택 후 1초 보여주고 끝내고 싶다면:
        return self._selected is not None and self._confirm_t >= 1.0

    def get_result(self):
        return self._selected
