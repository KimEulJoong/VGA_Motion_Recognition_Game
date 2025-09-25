# scenes/play_scene.py
# PlayScene: motion gameplay with UART-driven scoring and optional pause hold
import sys, time, threading, queue, re, math
from pathlib import Path
from typing import Optional, List

import pygame
import numpy as np

try:
    import serial
except Exception:
    serial = None

# 프로젝트 util (없으면 폴백)
try:
    from utils.neon import draw_neon_text
except Exception:
    def draw_neon_text(surface, font, text, base_color, glow_color, rect, glow_layers=6):
        base = font.render(text, True, base_color)
        surface.blit(base, rect)

WHITE=(255,255,255)
NEON_BLUE=(100,150,255)
NEON_RED=(255,80,80)
NEON_GREEN=(90,200,140)
NEON_YELLOW=(255,220,120)
BORDER=(30,30,40)
GAUGE_BG=(25,25,30)


# ---------------- UART ----------------
class _Uart(threading.Thread):
    """
    UART 수신 스레드 (기본: ASCII 라인 기반)
    - 결과: 'P'/'G'/'B' 또는 'PERFECT'/'GOOD'/'BAD'
    - 일시정지 펄스: 'PAUSE'/'MENU'/'GEAR'
    - byte 모드: pause_byte(기본 0x7E) 수신 → pause_pulse, 1/2/3 바이트 → P/G/B
    """
    daemon=True
    def __init__(self, port: Optional[str], baud: int, out_q: "queue.Queue", parse_mode: str="ascii",
                 pause_byte: int=0x7E, debug: bool=False):
        super().__init__()
        self.port, self.baud, self.q = port, baud, out_q
        self.mode, self.pause_byte, self.debug = parse_mode, pause_byte, debug
        self._stop = threading.Event()
        self.ser=None

    def run(self):
        if self.port is None or serial is None:
            return
        try:
            self.ser = serial.Serial(self.port, self.baud, timeout=0.01)
        except Exception as e:
            print(f"[UART] open fail: {e}", file=sys.stderr); return

        buf=bytearray()
        while not self._stop.is_set():
            try:
                data=self.ser.read(1024)
            except Exception as e:
                print(f"[UART] read err: {e}", file=sys.stderr)
                break
            if not data:
                continue

            if self.mode=="byte":
                for b in data:
                    if b==self.pause_byte:
                        self.q.put({"type":"pause_pulse","ts":time.monotonic()})
                    elif b==1: self.q.put({"type":"result","value":"P","ts":time.monotonic()})
                    elif b==2: self.q.put({"type":"result","value":"G","ts":time.monotonic()})
                    elif b==3: self.q.put({"type":"result","value":"B","ts":time.monotonic()})
            else:
                # ASCII 라인 모드: CR만 올 수 있어 치환
                buf.extend(data)
                # CR만 반복되는 환경 보호: CR -> LF 변환
                while b"\r" in buf and b"\n" not in buf:
                    i = buf.find(b"\r"); buf[i:i+1] = b"\n"
                while b"\n" in buf:
                    line, _, rest = buf.partition(b"\n"); buf=bytearray(rest)
                    s = line.strip().decode(errors="ignore").upper()
                    if not s: 
                        continue
                    if self.debug: 
                        print(f"[UART] '{s}'")
                    if s in ("P","PERFECT"):
                        self.q.put({"type":"result","value":"P","ts":time.monotonic()})
                    elif s in ("G","GOOD"):
                        self.q.put({"type":"result","value":"G","ts":time.monotonic()})
                    elif s in ("B","BAD"):
                        self.q.put({"type":"result","value":"B","ts":time.monotonic()})
                    elif s in ("PAUSE","MENU","GEAR"):
                        self.q.put({"type":"pause_pulse","ts":time.monotonic()})

        try:
            if self.ser: self.ser.close()
        except Exception:
            pass

    def send_line(self, s: str):
        if self.ser is None:
            print(f"[UART][FAKE TX] {s}")
            return
        try:
            self.ser.write((s+"\n").encode())
        except Exception as e:
            print(f"[UART] write err: {e}", file=sys.stderr)

    def stop(self):
        self._stop.set()


# -------------- Hold for Pause ----------
class _Hold:
    """일시정지 확인용 홀드(1초 등)"""
    def __init__(self, hold_s: float, timeout: float):
        self.hold_s = hold_s
        self.timeout = timeout
        self.p=0.0
        self.last=-1.0
    def pulse(self, t): 
        self.last=t
    def update(self, dt, now):
        holding = (self.last>=0 and (now-self.last)<=self.timeout)
        prev=self.p
        self.p = min(self.hold_s, self.p+dt) if holding else 0.0
        just = (prev<self.hold_s and self.p>=self.hold_s)
        r = 0.0 if self.hold_s<=0 else max(0.0, min(1.0, self.p/self.hold_s))
        return r, holding, just


# -------------- Play Scene --------------
class PlayScene:
    """
    - 좌측: 현재 Motion 이미지 (M1..M*.png 자동 탐색)
    - 상단: 카운트다운 숫자(우상단), 게이지 바
    - 우측 VGA 영역: 카메라 or (결과) Perfect/Good/Bad 오버레이
    - UART: P/G/B 라인 수신 → 결과 표시 result_hold초 → mN_done 송신
    - UART: PAUSE/MENU/GEAR 펄스 pause_hold초 유지 → pause 요청 (콘솔 로그)
    인터페이스:
      enter()/exit()/handle_event(e, now)/update(dt, now)/draw(screen, frame_bgr)/done()/get_result()
    """
    def __init__(self, W:int, H:int, *, assets_dir: Path, port: Optional[str]=None, baud:int=115200,
                 prep_seconds: float=5.0, result_hold: float=3.0,
                 pause_hold: float=1.0, pause_timeout: float=0.25,
                 parse_mode: str="ascii", debug: bool=False):
        self.W, self.H = W, H
        self.assets_dir = Path(assets_dir)
        self.port, self.baud, self.parse_mode, self.debug = port, baud, parse_mode, debug
        self.prep_s = prep_seconds
        self.res_hold = result_hold
        self.score_map = {"P":10, "G":7, "B":3}

        # 레이아웃
        self.VGA_RECT = pygame.Rect(960, 240, 1600, 1200)
        self.LEFT_RECT = pygame.Rect(0, 240, 960, 1200)
        self.MOTION_POS = (220, 450)
        self.SCORE_POS = (W//2, 120)

        # 상태
        self.score = 0
        self.motion_paths: List[Path] = self._find_motion_images(self.assets_dir)
        self.motion_imgs = self._load_motion_surfaces(self.motion_paths)
        self.motion_idx = 0
        self.state = "prepare"  # prepare -> await_result -> show_result -> done
        self.t0 = time.monotonic()
        self.result_value = None

        # 일시정지 홀드
        self.pause = _Hold(pause_hold, pause_timeout)
        self.pause_requested=False
        self._pause_ratio = 0.0

        # 결과 오버레이: 있으면 로드 / 없으면 빌드
        self.result_assets = {}
        # 먼저 파일이 있으면 로드
        for k, name in (("P","Perfect.png"),("G","Good.png"),("B","Bad.png")):
            p = self.assets_dir / name
            if p.exists():
                try:
                    surf = pygame.image.load(str(p)).convert_alpha()
                    # 크기 보정
                    if (surf.get_width(), surf.get_height()) != (self.VGA_RECT.width, self.VGA_RECT.height):
                        surf = pygame.transform.smoothscale(surf, (self.VGA_RECT.width, self.VGA_RECT.height))
                    self.result_assets[k] = surf
                except Exception:
                    pass
        # 빠진 항목은 빌더로 생성
        if len(self.result_assets) < 3:
            self._build_missing_overlays()

        # UI 리소스
        self.score_font = pygame.font.SysFont("Arial", 150, bold=True)
        self.label_font = pygame.font.SysFont("Arial", 150, bold=True)
        self.label_rect = self.label_font.render("Follow Motion", True, WHITE).get_rect(center=(470, H - 1100))

        # UART
        self.q: "queue.Queue" = queue.Queue()
        self.uart=None

        # --- gear icon for pause ---
        self.gear_img = None
        self.gear_rect = None
        p_gear = self.assets_dir / "gear.png"
        if p_gear.exists():
            try:
                img = pygame.image.load(str(p_gear)).convert_alpha()
                self.gear_img = pygame.transform.smoothscale(img, (90, 90))
                self.gear_rect = self.gear_img.get_rect(topleft=(24, 18))
            except Exception as e:
                print(f"[WARN] gear load fail: {e}")

    # ---------- lifecycle ----------
    def enter(self):
        # 상태/타이밍을 입장 시점 기준으로 리셋
        self.state = "prepare"
        self.t0 = time.monotonic()
        self.result_value = None
        self.motion_idx = 0
        self.pause_requested = False
        self.pause.p = 0.0
        self.pause.last = -1.0

        if self.port and serial is not None:
            self.uart = _Uart(self.port, self.baud, self.q, parse_mode=self.parse_mode, debug=self.debug)
            self.uart.start()

    def exit(self):
        if self.uart:
            self.uart.stop()
            self.uart.join(timeout=1.0)
            self.uart=None

    # ---------- helpers ----------
    def _find_motion_images(self, root: Path) -> List[Path]:
        items=[]
        for p in root.iterdir():
            if p.is_file() and re.match(r"^M\d+\.png$", p.name, re.I):
                n = int(re.findall(r"\d+", p.name)[0])
                items.append((n, p))
        items.sort()
        return [p for _, p in items]

    def _load_motion_surfaces(self, paths: List[Path]):
        out={}
        for p in paths:
            try:
                img = pygame.image.load(str(p)).convert_alpha()
                img = pygame.transform.smoothscale(img, (550, 900))
                out[p.name] = img
            except Exception as e:
                print(f"[WARN] image load fail {p}: {e}")
        return out

    def _build_missing_overlays(self):
        """Perfect/Good/Bad 모듈의 build_surface()를 이용해 부족한 오버레이를 런타임 생성."""
        W, H = self.VGA_RECT.width, self.VGA_RECT.height
        # import은 옵셔널
        try:
            from Perfect import build_surface as build_p
        except Exception:
            build_p = None
        try:
            from Good import build_surface as build_g
        except Exception:
            build_g = None
        try:
            from Bad import build_surface as build_b
        except Exception:
            build_b = None

        mapping = {
            "P": (build_p, "perfect.png"),
            "G": (build_g, "Good.png"),
            "B": (build_b, "Bad.png"),
        }
        for k, (builder, src_name) in mapping.items():
            if k in self.result_assets:
                continue
            if builder is None:
                continue
            src = self.assets_dir / src_name
            if not src.exists():
                if self.debug:
                    print(f"[PLAY] missing source for {k}: {src_name}")
                continue
            try:
                surf = builder(W, H, str(src)).convert_alpha()
                self.result_assets[k] = surf
                if self.debug:
                    print(f"[PLAY] overlay built from {src_name}")
            except Exception as e:
                if self.debug:
                    print(f"[PLAY] overlay build fail {src_name}: {e}")

    def _blit_cam(self, surface: "pygame.Surface", frame_bgr, rect: pygame.Rect):
        """OpenCV BGR 프레임을 rect 안에 비율 유지로 렌더."""
        pygame.draw.rect(surface, (0,0,0), rect)
        if frame_bgr is None:
            return
        if not isinstance(frame_bgr, np.ndarray) or frame_bgr.ndim!=3 or frame_bgr.shape[2]!=3:
            return
        # BGR -> RGB
        rgb = frame_bgr[:, :, ::-1]
        h, w = rgb.shape[:2]
        s = min(rect.width / w, rect.height / h)
        nw, nh = max(1, int(w*s)), max(1, int(h*s))
        rgb_resized = pygame.transform.smoothscale(
            pygame.image.frombuffer(rgb.tobytes(), (w, h), "RGB"), (nw, nh)
        )
        ox = rect.x + (rect.width - nw)//2
        oy = rect.y + (rect.height - nh)//2
        surface.blit(rgb_resized, (ox, oy))

    def _draw_top_timer(self, surface, t_left, t_total):
        font_num = pygame.font.SysFont("Arial", 140, bold=True)
        secs = max(0, int(t_left + 0.999))
        num_rect = font_num.render("0", True, WHITE).get_rect(topright=(self.W - 60, 20))
        draw_neon_text(surface, font_num, str(secs), WHITE, NEON_YELLOW, num_rect)

        bar_rect = pygame.Rect(60, 190, self.W - 120, 24)
        pygame.draw.rect(surface, GAUGE_BG, bar_rect, border_radius=12)
        ratio = 0.0 if t_total <= 0 else max(0.0, min(1.0, (t_total - t_left)/t_total))
        fill = bar_rect.copy(); fill.width = int(bar_rect.width * ratio)
        pygame.draw.rect(surface, NEON_RED, fill, border_radius=12)
        pygame.draw.rect(surface, BORDER, bar_rect, width=3, border_radius=12)

    def _draw_result_overlay(self, surface, rect, result):
        img = self.result_assets.get(result)
        if img:
            # 이미 정사이즈로 보정됨
            surface.blit(img, rect.topleft)
        else:
            # 폴백 텍스트
            font = pygame.font.SysFont("Arial", 220, bold=True)
            txt = {"P":"PERFECT","G":"GOOD","B":"BAD"}[result]
            r = font.render(txt, True, WHITE).get_rect(center=rect.center)
            glow = {"P":NEON_GREEN,"G":NEON_BLUE,"B":NEON_RED}[result]
            draw_neon_text(surface, font, txt, WHITE, glow, r)

    # ---------- event ----------
    def handle_event(self, e, now):
        if e.type==pygame.KEYDOWN:
            # 결과 키보드 테스트 (await_result 상태에서만 반영)
            if self.state=="await_result":
                if e.key==pygame.K_p: self.q.put({"type":"result","value":"P","ts":now})
                elif e.key==pygame.K_g: self.q.put({"type":"result","value":"G","ts":now})
                elif e.key==pygame.K_b: self.q.put({"type":"result","value":"B","ts":now})
            # 일시정지 테스트: M 키를 pause pulse로 사용
            if e.key==pygame.K_m:
                self.pause.pulse(now)

    def _drain_uart(self, now):
        try:
            while True:
                m = self.q.get_nowait()
                if m.get("type")=="result" and self.state=="await_result":
                    self.result_value = m.get("value")
                    self.score += self.score_map.get(self.result_value, 0)
                    self.state="show_result"; self.t0=now
                elif m.get("type")=="pause_pulse":
                    self.pause.pulse(now)
        except queue.Empty:
            pass

    # ---------- update/draw ----------
    def update(self, dt: float, now: float):
        # UART 메시지 처리
        self._drain_uart(now)

        # 일시정지 홀드 업데이트
        pr, _, p_done = self.pause.update(dt, now)
        self._pause_ratio = pr
        if p_done and not self.pause_requested:
            self.pause_requested = True
            print("NEXT_PAGE:pause")

        # 상태 머신
        if self.state=="prepare":
            t_left = max(0.0, self.prep_s - (now - self.t0))
            if t_left<=0.0:
                self.state="await_result"; self.t0=now

        elif self.state=="show_result":
            if (now - self.t0) >= self.res_hold:
                # ack 보내고 다음 동작
                if self.motion_idx < len(self.motion_paths):
                    mname = self.motion_paths[self.motion_idx].name
                    mnum = int(re.findall(r"\d+", mname)[0])
                    if self.uart: self.uart.send_line(f"m{mnum}_done")
                    else: print(f"[ACK] m{mnum}_done")

                self.motion_idx += 1
                if self.motion_idx >= len(self.motion_paths):
                    self.state="done"
                else:
                    self.state="prepare"; self.result_value=None; self.t0=now

    def draw(self, screen: "pygame.Surface", frame_bgr):
        # 좌측 반투명 오버레이
        s = pygame.Surface((self.LEFT_RECT.width, self.LEFT_RECT.height), pygame.SRCALPHA)
        s.fill((255,255,255,180))
        screen.blit(s, self.LEFT_RECT.topleft)

        # 우측 VGA 영역
        pygame.draw.rect(screen, (0,0,0), self.VGA_RECT)

        # 점수
        draw_neon_text(screen, self.score_font, f"Score : {self.score}", WHITE, NEON_BLUE,
                       self.score_font.render("0", True, WHITE).get_rect(center=self.SCORE_POS))

        # 라벨
        draw_neon_text(screen, self.label_font, "Follow Motion", WHITE, NEON_RED, self.label_rect)

        # 현재 모션 이미지
        if self.motion_idx < len(self.motion_paths):
            key = self.motion_paths[self.motion_idx].name
            img = self.motion_imgs.get(key)
            if img:
                screen.blit(img, self.MOTION_POS)

        # 상단 타이머(prepare 동안만)
        if self.state=="prepare":
            t_left = max(0.0, self.prep_s - (time.monotonic()-self.t0))
            self._draw_top_timer(screen, t_left, self.prep_s)

        # 우측 VGA: 결과 오버레이 or 카메라
        if self.state=="show_result" and self.result_value in ("P","G","B"):
            self._draw_result_overlay(screen, self.VGA_RECT, self.result_value)
        else:
            self._blit_cam(screen, frame_bgr, self.VGA_RECT)

        # 좌상단 기어 + pause 링
        if self.gear_img:
            screen.blit(self.gear_img, self.gear_rect.topleft)
            center = self.gear_rect.center
        else:
            center = (60, 60)
        
        radius = 60
        thick  = 10
        pygame.draw.circle(screen, (80,80,90), center, radius, thick)
        
        if self._pause_ratio > 0:
            r = max(0.0, min(1.0, self._pause_ratio))
            start = -math.pi/2
            end   = start + r*2*math.pi
            rect = pygame.Rect(0,0, radius*2, radius*2); rect.center = center
            pygame.draw.arc(screen, NEON_BLUE, rect, start, end, thick)

    def done(self) -> bool:
        # 모든 모션 종료
        return self.state=="done"

    def get_result(self):
        # 전체 모션 완료 후 반환할 결과(점수 등)
        return {"score": self.score, "motions": len(self.motion_paths), "pause": self.pause_requested}
