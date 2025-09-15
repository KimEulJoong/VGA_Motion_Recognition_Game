# scenes/mode_select_scene.py
import sys, time, threading, queue
import pygame
from utils.neon import draw_neon_text

try:
    import serial
except Exception:
    serial = None

WHITE=(255,255,255); NEON_BLUE=(100,150,255); NEON_RED=(255,80,80); NEON_GREEN=(90,200,140)

class _Hold:
    def __init__(self, hold_s, timeout):
        self.hold_s=hold_s; self.timeout=timeout
        self.p=0.0; self.last=-1.0
    def pulse(self, t): self.last=t
    def update(self, dt, now):
        holding = (self.last>=0 and (now-self.last)<=self.timeout)
        self.p = min(self.hold_s, self.p+dt) if holding else 0.0
        r = 0.0 if self.hold_s<=0 else max(0.0, min(1.0, self.p/self.hold_s))
        return r, holding, (self.p>=self.hold_s)

class _Uart(threading.Thread):
    daemon=True
    def __init__(self, port, baud, parse_mode, out_q, W, debug=False):
        super().__init__(); self.port=port; self.baud=baud; self.mode=parse_mode
        self.q=out_q; self.W=W; self.debug=debug; self._stop=threading.Event(); self.ser=None
    def run(self):
        if self.port is None or serial is None: return
        try: self.ser=serial.Serial(self.port, self.baud, timeout=0.01)
        except Exception as e: print(f"[UART] open fail: {e}", file=sys.stderr); return
        buf=bytearray()
        while not self._stop.is_set():
            try: data=self.ser.read(1024)
            except Exception as e: print(f"[UART] read err: {e}", file=sys.stderr); break
            if not data: continue
            buf.extend(data)
            while b"\n" in buf:
                line, _, rest = buf.partition(b"\n"); buf=bytearray(rest)
                s=line.strip().decode(errors="ignore")
                if not s: continue
                side=None
                if self.mode=="token":
                    t=s.upper()
                    if t in ("1","1P","P1","L","LEFT"): side="left"
                    elif t in ("2","2P","P2","R","RIGHT"): side="right"
                else:  # "xy"
                    try:
                        x=float(s.replace(" ","").split(",")[0])
                        side="left" if x<self.W/2 else "right"
                    except Exception: pass
                if side: self.q.put({"type":"pulse","side":side,"ts":time.monotonic()})
        try:
            if self.ser: self.ser.close()
        except Exception: pass
    def stop(self): self._stop.set()

class ModeSelectScene:
    """한 창에서 동작하는 1P/2P 2초 홀드 선택 씬"""
    def __init__(self, W, H, *, port=None, baud=115200, parse="token", hold=2.0, timeout=0.25, debug=False,
                 assets_dir="assets/motion_game"):
        self.W=W; self.H=H
        self.port, self.baud, self.parse, self.hold_s, self.timeout, self.debug = port, baud, parse, hold, timeout, debug

        self.title_font = pygame.font.SysFont("Arial", 180, bold=True)
        self.p_font     = pygame.font.SysFont("Arial", 150, bold=True)
        self.title_rect = self.title_font.render("Mode Select", True, WHITE).get_rect(center=(W//2, 100))
        self.p1_rect    = self.p_font.render("1P", True, WHITE).get_rect(center=(280, 390))
        self.p2_rect    = self.p_font.render("2P", True, WHITE).get_rect(center=(W-240, 390))

        # 캐릭터
        left_img  = pygame.image.load(f"{assets_dir}/1p.png").convert_alpha()
        right_img = pygame.image.load(f"{assets_dir}/2p.png").convert_alpha()
        self.left_img  = pygame.transform.smoothscale(left_img, (550, 900))
        self.right_img = pygame.transform.smoothscale(right_img, (500, 900))

        self.left_dim  = self.left_img.copy();  self.left_dim.fill((100,100,100,255),  special_flags=pygame.BLEND_RGBA_MULT)
        self.right_dim = self.right_img.copy(); self.right_dim.fill((100,100,100,255), special_flags=pygame.BLEND_RGBA_MULT)

        self.left_red   = self._solid_from_alpha(self.left_img,  NEON_RED)
        self.right_red  = self._solid_from_alpha(self.right_img, NEON_RED)
        self.left_green = self._solid_from_alpha(self.left_img,  NEON_GREEN)
        self.right_green= self._solid_from_alpha(self.right_img, NEON_GREEN)

        self.left_pos  = (0, 450)
        self.right_pos = (W - self.right_img.get_width(), 450)

        self.q = queue.Queue(); self.reader=None
        self.h1 = _Hold(self.hold_s, self.timeout); self.h2 = _Hold(self.hold_s, self.timeout)
        self._r1=0.0; self._r2=0.0
        self.result=None; self._running=False

    def _solid_from_alpha(self, src, color):
        w,h = src.get_width(), src.get_height()
        overlay = pygame.Surface((w,h), pygame.SRCALPHA); overlay.fill((*color,0))
        try:
            import numpy as _np  # optional
            a = pygame.surfarray.pixels_alpha(src).copy()
            ad = pygame.surfarray.pixels_alpha(overlay); ad[:] = a[:]; del ad; del a
        except Exception:
            overlay.blit(src, (0,0), special_flags=pygame.BLEND_RGBA_MULT)
        return overlay

    # Scene lifecycle
    def enter(self):
        if self.port and serial is not None:
            self.reader = _Uart(self.port, self.baud, self.parse, self.q, self.W, self.debug); self.reader.start()
        self._running=True

    def exit(self):
        if self.reader: self.reader.stop(); self.reader.join(timeout=1.0); self.reader=None
        self._running=False

    def handle_event(self, e, now):
        if e.type==pygame.KEYDOWN:
            if e.key==pygame.K_1: self.h1.pulse(now)
            elif e.key==pygame.K_2: self.h2.pulse(now)

    def _drain_uart(self, now):
        try:
            while True:
                m=self.q.get_nowait()
                if m.get("side")=="left":  self.h1.pulse(now)
                elif m.get("side")=="right": self.h2.pulse(now)
        except queue.Empty:
            pass

    def update(self, dt, now):
        if not self._running: return
        self._drain_uart(now)
        r1,_,d1 = self.h1.update(dt, now)
        r2,_,d2 = self.h2.update(dt, now)
        self._r1, self._r2 = r1, r2
        if self.result is None:
            if d1: self.result="play"
            elif d2: self.result="motion_sel"

    def draw(self, screen):
        draw_neon_text(screen, self.title_font, "Mode Select", WHITE, NEON_BLUE, self.title_rect)
        draw_neon_text(screen, self.p_font, "1P", WHITE, NEON_RED, self.p1_rect)
        draw_neon_text(screen, self.p_font, "2P", WHITE, NEON_RED, self.p2_rect)
        self._gauge(screen, self.left_pos,  self.left_dim,  self.left_green if self.result=="play" else self.left_red,  self._r1)
        self._gauge(screen, self.right_pos, self.right_dim, self.right_green if self.result=="motion_sel" else self.right_red, self._r2)
        hint_font=pygame.font.SysFont("Arial", 36)
        hint="1P: LEFT · 2P: RIGHT · 2초 유지로 선택 · 1/2 키 테스트 · ESC 종료"
        hs=hint_font.render(hint, True, (230,230,230))
        screen.blit(hs, hs.get_rect(midbottom=(self.W//2, self.H-20)))

    def _gauge(self, screen, pos, base, overlay, ratio):
        x,y=pos; screen.blit(base, (x,y))
        ratio=max(0.0, min(1.0, ratio))
        if ratio<=0: return
        w,h=overlay.get_width(), overlay.get_height()
        fill_h=int(h*ratio); area=pygame.Rect(0,h-fill_h,w,fill_h)
        screen.blit(overlay, (x, y+(h-fill_h)), area=area)

    def done(self): return self.result is not None
    def get_result(self): return self.result
