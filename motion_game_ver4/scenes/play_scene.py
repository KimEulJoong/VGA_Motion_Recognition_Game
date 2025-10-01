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
    def __init__(self, port: Optional[str], baud: int, 
                 out_q: "queue.Queue",
                 setting_q: Optional["queue.Queue"]=None,
                 parse_mode: str="ascii",
                 pause_byte: int=0x7E, debug: bool=False):
        super().__init__()
        self.port, self.baud = port, baud
        self.q = out_q
        self.q_setting = setting_q
        self.mode, self.pause_byte, self.debug = parse_mode, pause_byte, debug
        self._stop = threading.Event()
        self.ser=None
        self._lock = threading.Lock()

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

                    # --- 세팅 진입용 펄스(홀드 대상) ---
                    elif s in ("PAUSE","MENU","GEAR","SETTING","SET"):
                        self.q.put({"type":"pause_pulse","ts":time.monotonic()})

                    # --- SETTING 화면용 명령(즉시 실행) ---
                    elif s in ("RESTART","RESUME"):
                        if self.q_setting:
                            self.q_setting.put({"type":"setting_pulse","value":"RESTART","ts":time.monotonic()})
                    elif s in ("FINISH","QUIT","EXIT"):
                        if self.q_setting:
                            self.q_setting.put({"type":"setting_pulse","value":"FINISH","ts":time.monotonic()})
        try:
            if self.ser: self.ser.close()
        except Exception:
            pass

    def send_line(self, s: str):
        """개행 포함 라인 송신"""
        if self.ser is None:
            print(f"[UART][FAKE TX LINE] {s}")
            return
        with self._lock:
            try:
                self.ser.write((s+"\n").encode())
                if self.debug:
                    print(f"[UART][TX LINE] {s}")
            except Exception as e:
                print(f"[UART] write err: {e}", file=sys.stderr)

    def send_byte(self, b):
        """문자 1개 또는 바이트 1개를 그대로 송신"""
        # b는 's' 같은 str 1글자, 또는 int(0..255), 또는 bytes/bytearray 중 하나를 허용
        if isinstance(b, str):
            payload = b.encode(errors="ignore")[:1]
        elif isinstance(b, int):
            payload = bytes([b & 0xFF])
        elif isinstance(b, (bytes, bytearray)):
            payload = bytes(b[:1])
        else:
            raise TypeError("send_byte expects str|int|bytes|bytearray")

        if not payload:
            return

        if self.ser is None:
            v = payload[0]
            ch = chr(v) if 32 <= v <= 126 else "?"
            print(f"[UART][FAKE TX BYTE] 0x{v:02X} ({ch!r})")
            return

        with self._lock:
            try:
                self.ser.write(payload)
                v = payload[0]
                ch = chr(v) if 32 <= v <= 126 else "?"
                print(f"[UART][TX BYTE] 0x{v:02X} ({ch!r})")  # ★ 터미널 로그
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
    def __init__(self, W:int, H:int, *, assets_dir: Path,
                 overlay_dir: Optional[Path] = None, 
                 port: Optional[str]=None, baud:int=115200,
                 prep_seconds: float=5.0, result_hold: float=3.0,
                 result_delay: float = 1.0,
                 pause_hold: float=1.0, pause_timeout: float=0.25,
                 parse_mode: str="ascii", debug: bool=False,
                 pre_start_seconds: float = 0.0, start_token: str = "game_start",
                 start_char:str | None = None, done_char:str | None = "f",
                 result_bytes: dict | None = None,          # ★ 추가
                 ending_byte: bytes | None = b"e"           # ★ 추가
                 ):
        self.W, self.H = W, H
        self.assets_dir = Path(assets_dir)
        self.overlay_dir = Path(overlay_dir) if overlay_dir else self.assets_dir.parent
        self.port, self.baud, self.parse_mode, self.debug = port, baud, parse_mode, debug
        self.prep_s = prep_seconds
        self.res_hold = result_hold
        self.result_delay_s = result_delay
        self.score_map = {"P":10, "G":7, "B":3}
        self.done_char = done_char

        # 레이아웃
        self.VGA_RECT = pygame.Rect(960, 240, 1600, 1200)
        self.LEFT_RECT = pygame.Rect(0, 240, 960, 1200)
        self.MOTION_POS = (220, 450)
        self.SCORE_POS = (W//2, 80)

        # 상태
        self.score = 0
        self.motion_paths: List[Path] = self._find_motion_images(self.assets_dir)
        self.motion_imgs = self._load_motion_surfaces(self.motion_paths)
        self.motion_idx = 0
        self.pre_start_s = pre_start_seconds
        self.start_token = start_token
        self.start_char  = start_char
        self.done_char = done_char
        self.result_bytes = (result_bytes or {"P": b"P", "G": b"G", "B": b"B"})  # ★ 추가
        self.ending_byte  = ending_byte       
        self._start_sent = False
        self.state = "prepare"  # prepare -> await_result -> show_result -> done
        self.t0 = time.monotonic()
        self.result_value = None
        self._pending_result = None

        # 일시정지 홀드
        self.pause = _Hold(pause_hold, pause_timeout)
        self.pause_requested=False
        self._pause_ratio = 0.0
        self._kb_pause = False
        self._score_mark_sent = False # 결과 문자(P/G/B) 1회만 송신

        # 결과 오버레이: PNG 대소문자 무시 + 곡 폴더 → 루트 assets 순으로 탐색
        self.result_assets = {}
        W, H = self.VGA_RECT.width, self.VGA_RECT.height

        def _lookup(stem):
            # 곡 폴더에서 먼저 찾고, 없으면 루트 assets에서도 찾아본다
            return (self._find_png_ci(self.assets_dir, stem) or
                    self._find_png_ci(self.overlay_dir, stem))

        for k, stem in (("P","perfect"), ("G","good"), ("B","bad")):
            p = _lookup(stem)
            if p:
                try:
                    surf = pygame.image.load(str(p)).convert_alpha()
                    if (surf.get_width(), surf.get_height()) != (W, H):
                        surf = pygame.transform.smoothscale(surf, (W, H))
                    self.result_assets[k] = surf
                except Exception as e:
                    if self.debug: print(f"[PLAY] overlay load fail {p}: {e}")

        # (옵션) 빌더는 끈 상태라 PNG가 없으면 폴백 텍스트 사용
        if self.debug and len(self.result_assets) < 3:
            print("[PLAY] some overlays missing; fallback text will be used.")

        # UI 리소스
        self.score_font = pygame.font.SysFont("Arial", 150, bold=True)
        self.label_font = pygame.font.SysFont("Arial", 150, bold=True)
        self.label_rect = self.label_font.render("Follow Motion", True, WHITE).get_rect(center=(470, H - 1100))

        # UART
        self.q: "queue.Queue" = queue.Queue()
        self.setting_q: "queue.Queue" = queue.Queue()
        self.uart=None

        # --- gear icon for pause (대소문자 무시 + 곡 폴더 → 루트) ---
        self.label_font = pygame.font.SysFont("Arial", 150, bold=True)
        self.label_gap = 24  # 모션 이미지 위로 띄울 간격(px)
        p_gear = _lookup("gear")
        if p_gear:
            try:
                img = pygame.image.load(str(p_gear)).convert_alpha()
                self.gear_img = pygame.transform.smoothscale(img, (90, 90))
                self.gear_rect = self.gear_img.get_rect(topleft=(24, 18))
            except Exception as e:
                if self.debug: print(f"[WARN] gear load fail {p_gear}: {e}")

    # ---------- lifecycle ----------
    def enter(self):
        # --- 지난 판에서 남은 큐 메시지 완전 제거 ---
        try:
            while True:
                self.q.get_nowait()
        except queue.Empty:
            pass
        try:
            while True:
                self.setting_q.get_nowait()
        except queue.Empty:
            pass

        # --- 상태/타이밍 초기화 ---
        self.state = "prestart" if self.pre_start_s > 0 else "prepare"
        self.t0 = time.monotonic()

        # --- 게임 진행 관련 변수 초기화 ---
        self.result_value = None
        self._pending_result = None
        self.motion_idx = 0
        self.score = 0

        # --- 일시정지/홀드 관련 플래그 초기화 ---
        self.pause_requested = False
        self._kb_pause = False
        self.pause.p = 0.0
        self.pause.last = -1.0

        # --- 송수신/라운드 경계 플래그 초기화 ---
        self._start_sent = False
        self._score_mark_sent = False   # (혹시 남아있을 수 있는 플래그 정리)
        self._round_active = False      # prepare→await_result에서 'p' 전송 후 True, 결과 종료 시 False

        # --- UART 스레드 시작 (필요 시만) ---
        if self.port and serial is not None:
            # 이미 이전 스레드가 있다면 정리(안전)
            if getattr(self, "uart", None):
                try:
                    self.uart.stop()
                    self.uart.join(timeout=1.0)
                except Exception:
                    pass
                self.uart = None

            self.uart = _Uart(self.port, self.baud,
                            out_q=self.q,
                            setting_q=self.setting_q,
                            parse_mode=self.parse_mode,
                            debug=self.debug)
            self.uart.start()

    # ★ NEW: SETTING 씬이 부르는 폴링 함수 (pulse를 모두 소모)
    def poll_setting_pulse(self):
        """
        큐에서 setting pulse(RESTART/FINISH)를 모두 꺼내
        마지막에 본 value를 반환하거나 None.
        """
        last = None
        try:
            while True:
                m = self.setting_q.get_nowait()
                if m.get("type") == "setting_pulse":
                    last = m.get("value")    # 최근 pulse만 쓰면 됨
        except queue.Empty:
            pass
        return last

    def exit(self):
        if self.uart:
            self.uart.stop()
            self.uart.join(timeout=1.0)
            self.uart=None

    # ---------- helpers ----------
    def _find_png_ci(self, folder: Path, stem_lower: str) -> Path | None:
        """folder 안에서 .png 파일을 이름(확장자 제외) 대소문자 무시로 찾아서 Path 반환"""
        try:
            want = stem_lower.lower()
            for p in folder.iterdir():
                if p.is_file() and p.suffix.lower()==".png" and p.stem.lower()==want:
                    return p
        except Exception:
            pass
        return None

    def _find_motion_images(self, root: Path) -> list[Path]:
        rx1 = re.compile(r'^(?:G|S|M)(\d+)\.png$', re.IGNORECASE)
        rx2 = re.compile(r'^(\d+)\.png$', re.IGNORECASE)

        items = []
        for p in root.iterdir():
            if not p.is_file(): 
                continue
            m = rx1.match(p.name) or rx2.match(p.name)
            if m:
                items.append((int(m.group(1)), p))
        items.sort(key=lambda t: t[0])
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

    # [추가] 파일명 대소문자 무시로 .png 찾기
    def _find_png_ci(self, folder: Path, stem_lower: str) -> Path | None:
        try:
            for p in folder.iterdir():
                if p.is_file() and p.suffix.lower()==".png" and p.stem.lower()==stem_lower:
                    return p
        except Exception:
            pass
        return None

    def _build_missing_overlays(self):
        """Perfect/Good/Bad 모듈의 build_surface()를 이용해 부족한 오버레이를 런타임 생성."""
        #W, H = self.VGA_RECT.width, self.VGA_RECT.height
        # import은 옵셔널
        #try:
        #    from Perfect import build_surface as build_p
        #except Exception:
        #    build_p = None
        #try:
        #    from Good import build_surface as build_g
        #except Exception:
        #    build_g = None
        #try:
        #    from Bad import build_surface as build_b
        #except Exception:
        #    build_b = None
#
        #mapping = {
        #    "P": (build_p, "perfect.png"),
        #    "G": (build_g, "Good.png"),
        #    "B": (build_b, "Bad.png"),
        #}
        #for k, (builder, src_name) in mapping.items():
        #    if k in self.result_assets:
        #        continue
        #    if builder is None:
        #        continue
        #    src = self.assets_dir / src_name
        #    if not src.exists():
        #        if self.debug:
        #            print(f"[PLAY] missing source for {k}: {src_name}")
        #        continue
        #    try:
        #        surf = builder(W, H, str(src)).convert_alpha()
        #        self.result_assets[k] = surf
        #        if self.debug:
        #            print(f"[PLAY] overlay built from {src_name}")
        #    except Exception as e:
        if self.debug:
            print("[PLAY] overlay builders disabled; using PNGs only.")

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
                if e.key==pygame.K_p: self._pending_result = ("P", now)
                elif e.key==pygame.K_g: self._pending_result = ("G", now)
                elif e.key==pygame.K_b: self._pending_result = ("B", now)

            # ★ 세팅(일시정지) 테스트: M 키를 '홀드'로 사용
            if e.key==pygame.K_m:
                self._kb_pause = True      # 누르는 동안 유지
                self.pause.pulse(now)      # 누른 순간 1회 즉시 펄스

        # ★ 키를 뗄 때 중지
        elif e.type==pygame.KEYUP:
            if e.key==pygame.K_m:
                self._kb_pause = False

    def _drain_uart(self, now):
        try:
            while True:
                m = self.q.get_nowait()
                t = m.get("type")

                if t == "result" and self.state == "await_result":
                    code = m.get("value")
                    self._pending_result = (code, now)

                elif t == "pause_pulse":
                    self.pause.pulse(now)

        except queue.Empty:
            pass

    # ---------- update/draw ----------
    def update(self, dt: float, now: float):
        # UART 메시지 처리
        self._drain_uart(now)

        # ★ 키보드 M을 누르고 있는 동안에는 매 프레임 pulse 유지
        if self._kb_pause:
            self.pause.pulse(now)

        # 일시정지 홀드 업데이트
        pr, _, p_done = self.pause.update(dt, now)
        self._pause_ratio = pr
        if p_done and not self.pause_requested:
            self.pause_requested = True
            print("NEXT_PAGE:pause")
        
        # ⬇️ 여기 추가: 결과 보류가 있고, 딜레이가 지났으면 결과 표시로 전환
        if self.state == "await_result" and self._pending_result:
            code, ts = self._pending_result
            if (now - ts) >= self.result_delay_s:
                self.result_value = code
                self.score += self.score_map.get(self.result_value, 0)
                self.state = "show_result"
                self.t0 = now
                self._pending_result = None   # 보류 비우기

        # ⬇️ prestart 상태 처리: 3..2..1 대기 → 끝나면 UART로 start 토큰 1회 송신
        if self.state == "prestart":
            t_left = max(0.0, self.pre_start_s - (now - self.t0))
            if t_left <= 0.0:
                if not self._start_sent:
                    # ★ 여기에서 's' 1바이트 보내기 (uart 없으면 콘솔에 FAKE 로그)
                    if self.uart:
                        if self.start_char:   # 단일 문자 우선
                            self.uart.send_byte(self.start_char)
                        else:                 # 아니면 라인 송신
                            self.uart.send_line(self.start_token)
                    else:
                        if self.start_char:
                            print(f"[START] (fake) send byte '{self.start_char}'")
                        else:
                            print(f"[START] (fake) send line '{self.start_token}'")
                    self._start_sent = True
                # 본래 준비상태로 전환
                self.state = "prepare"
                self.t0 = now
            return
        
        # 상태 머신
        elif self.state == "prepare":
            t_left = max(0.0, self.prep_s - (now - self.t0))
            if t_left <= 0.0:
                # 5..4..3..2..1 끝난 직후 하드웨어에 'p' 전송
                if self.uart:
                    self.uart.send_byte('p')          # 1바이트 전송
                else:
                    print("[PREP DONE] (fake) send byte 'p'")

                self._round_active = True
                self.state = "await_result"
                self.t0 = now

        elif self.state=="show_result":
            if (now - self.t0) >= self.res_hold:
                total   = len(self.motion_paths)
                is_last = (self.motion_idx >= total - 1)

                # 선택적으로 mN_done 라인 알림 유지
                if self.motion_idx < total:
                    mname = self.motion_paths[self.motion_idx].name
                    mnum  = int(re.findall(r"\d+", mname)[0])
                    if self.uart: self.uart.send_line(f"m{mnum}_done")
                    else:         print(f"[ACK] m{mnum}_done")

                # 마지막이면 'e', 아니면 'f'만 전송
                if self.uart:
                    if is_last:
                        if self.ending_byte: self.uart.send_byte(self.ending_byte)
                    else:
                        if self.done_char:   self.uart.send_byte(self.done_char)
                else:
                    tag = "e" if is_last else (self.done_char or "")
                    if tag: print(f"[ACK] (fake) send byte '{tag}'")

                self._round_active = False

                if is_last:
                    self.state = "done"
                else:
                    self.motion_idx += 1
                    self.result_value = None
                    self.state = "prepare"
                    self.t0 = now

    def draw(self, screen: "pygame.Surface", frame_bgr):
        # 좌측 반투명 오버레이
        s = pygame.Surface((self.LEFT_RECT.width, self.LEFT_RECT.height), pygame.SRCALPHA)
        s.fill((255,255,255,180))
        screen.blit(s, self.LEFT_RECT.topleft)

        # 우측 VGA 영역
        pygame.draw.rect(screen, (0,0,0), self.VGA_RECT)

        # 점수
        score_text = f"Score : {self.score}"
        score_rect = self.score_font.render(score_text, True, WHITE).get_rect(center=self.SCORE_POS)
        draw_neon_text(screen, self.score_font, score_text, WHITE, NEON_BLUE, score_rect)

        # 라벨
        label_x = self.MOTION_POS[0] + 550 // 2
        label_y = self.MOTION_POS[1] - self.label_gap
        label_rect = self.label_font.render("Follow Motion", True, WHITE)\
                    .get_rect(midbottom=(label_x, label_y))
        draw_neon_text(screen, self.label_font, "Follow Motion", WHITE, NEON_RED, label_rect)

        # 현재 모션 이미지
        if self.motion_idx < len(self.motion_paths):
            key = self.motion_paths[self.motion_idx].name
            img = self.motion_imgs.get(key)
            if img:
                screen.blit(img, self.MOTION_POS)

        # ⬇️ prestart: 중앙에 숫자 카운트다운
        if self.state == "prestart":
            t_left = max(0.0, self.pre_start_s - (time.monotonic() - self.t0))
            secs = max(0, int(t_left + 0.999))
            font_big = pygame.font.SysFont("Arial", 280, bold=True)
            rect = font_big.render("0", True, WHITE).get_rect(center=(self.W//2, self.H//2))
            draw_neon_text(screen, font_big, str(secs), WHITE, NEON_YELLOW, rect)
            return  # prestart는 여기서 그리기 끝

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

    def poll_setting_cmd(self) -> Optional[str]:
        """SETTING 화면에서 호출: UART로부터 'RESTART'/'FINISH' 명령을 비동기 수신"""
        try:
            while True:
                m = self.setting_q.get_nowait()
                if m.get("type")=="setting_cmd":
                    return m.get("value")
        except queue.Empty:
            return None

    def restart_stage(self, now: float):
        """현재 스테이지를 5초 카운트다운부터 다시 시작"""
        self.state = "prepare"
        self.result_value = None
        self.t0 = now
        # 세팅 링/플래그 정리
        self.pause.p = 0.0
        self.pause.last = -1.0
        self.pause_requested = False
        self._kb_pause = False
        self._round_active = False
    
    def reset_pause_hold(self):
        """일시정지 홀드와 키보드 상태, 남아있는 pause 펄스를 모두 리셋"""
        self._kb_pause = False
        self.pause.p = 0.0
        self.pause.last = -1.0
        # q 안의 pause_pulse만 버리고 나머지는 보존
        tmp = []
        try:
            while True:
                m = self.q.get_nowait()
                if m.get("type") != "pause_pulse":
                    tmp.append(m)
        except queue.Empty:
            pass
        for m in tmp:
            self.q.put(m)

    def snap_time(self, now: float):
        """외부 화면 전환 후 복귀 시 타이머 기준을 현재로 고정"""
        self.t0 = now

    def send_uart(self, data):
        """
        data: str(1글자) | int(0..255) | bytes/bytearray
        SettingScene이나 main에서 호출해서 UART로 보내기 위함.
        """
        if not data:
            return

        # uart 스레드가 아직 없다면 FAKE 로그만
        if not getattr(self, "uart", None):
            # 보기 좋게 바이트 로그
            if isinstance(data, int):
                vs = [data & 0xFF]
            elif isinstance(data, str):
                vs = list(data.encode(errors="ignore")[:1])
            elif isinstance(data, (bytes, bytearray)):
                vs = list(data[:])
            else:
                vs = []
            for v in vs:
                ch = chr(v) if 32 <= v <= 126 else '.'
                print(f"[UART][FAKE TX BYTE] 0x{v:02x} ('{ch}')")
            print("[UART] send skipped (uart thread not started)")
            return

        # _Uart의 안전한 송신 API 사용(락/플러시 포함)
        try:
            if isinstance(data, int):
                self.uart.send_byte(data & 0xFF)
            elif isinstance(data, str):
                # 1글자면 바이트, 1글자보다 길면 라인으로
                if len(data) == 1:
                    self.uart.send_byte(data)
                else:
                    # 개행이 필요한 경우 라인 송신
                    self.uart.send_line(data)
            elif isinstance(data, (bytes, bytearray)):
                # bytes면 바이트 단위로 모두 전송
                for v in data:
                    self.uart.send_byte(v)
            else:
                s = str(data)
                if s:
                    self.uart.send_line(s)
        except Exception as e:
            print(f"[UART] send_uart error: {e}")