# scenes/setting_scene.py
import time
import pygame
from pathlib import Path

WHITE=(255,255,255); ACCENT=(255,220,120)

class _Hold:
    def __init__(self, hold=2.0, timeout=0.25):
        self.hold, self.timeout = hold, timeout
        self.p=0.0; self.last=-1.0
    def pulse(self, ts): self.last = ts
    def update(self, dt, now):
        holding = (self.last>=0 and (now-self.last)<=self.timeout)
        prev=self.p
        self.p = min(self.hold, self.p+dt) if holding else 0.0
        just = (prev<self.hold and self.p>=self.hold)
        ratio = 0.0 if self.hold<=0 else max(0.0, min(1.0, self.p/self.hold))
        return ratio, holding, just

class SettingScene:
    """
    왼쪽=다시 시작(5s), 오른쪽=종료(INTRO)
    - UART: 'restart' / 'finish' 가 들어올 때마다 pulse
    - Keyboard: R/F '누르고 있는 동안' pulse
    - Mouse: 좌/우 카드를 '누르고 있는 동안' pulse
    → 2초 찼을 때 확정
    """
    def __init__(self, W, H, *, play_scene, title="Settings",
                 hold_s=2.0, timeout=0.25, cover_ratio=0.25, 
                 debug=False, vga_rect=None,
                 assets_dir: Path | None = None,           # ★ 추가
                 left_img_name: str = "derpy.png",         # ★ 추가
                 right_img_name: str = "sussie.png",
                 resume_byte: bytes = b'r',   # ★ 추가: Resume 확정 시 전송
                 quit_byte:   bytes = b't'    # ★ 추가: Quit  확정 시 전송
                 ):
        
        self.W, self.H = W, H
        self.play_scene = play_scene
        self.title = title
        self.font_title = pygame.font.SysFont("Arial", 160, bold=True)
        self.font_big   = pygame.font.SysFont("Arial", 80, bold=True)
        self.font_small = pygame.font.SysFont("Arial", 48, bold=True)
        self._font_path = None      # ← 폰트 파일 경로(없으면 None)
        self._font_name = None      # ← 시스템 폰트 이름(없으면 None)

        self.left_box  = None
        self.right_box = None

        self.hold_l = _Hold(hold_s, timeout)
        self.hold_r = _Hold(hold_s, timeout)

        self._kb_side = None          # "L" / "R" (키보드 홀드)
        self._mouse_side = None       # "L" / "R" (마우스 홀드)

        self._done = False
        self._action = None           # "restart" | "finish"
        self.cover_ratio = cover_ratio
        self.debug = debug

        # 이 씬에서 사용할 카메라(Rect). 없으면 play_scene의 것을 사용
        if vga_rect is not None:
            # tuple|(x,y,w,h) 모두 허용
            self.cam_rect = pygame.Rect(*vga_rect)
        else:
            self.cam_rect = play_scene.VGA_RECT

        self.assets_dir = Path(assets_dir) if assets_dir else None
        self.left_img_name  = left_img_name
        self.right_img_name = right_img_name
        self.left_img_surf  = None
        self.right_img_surf = None
        self.resume_byte    = resume_byte  
        self.quit_byte      = quit_byte    

    def enter(self):
        # 없을 수도 있으니 getattr로 안전하게 꺼내기
        font_path = getattr(self, "_font_path", None)
        font_name = getattr(self, "_font_name", None)

        if font_path:
            self._font_big   = pygame.font.Font(font_path, self._title_px)
            self._font_small = pygame.font.Font(font_path, self._item_px)
        else:
            name = font_name or "segoe ui semilight"  # 윈도우 얇은 계열
            self._font_big   = pygame.font.SysFont(name, self._title_px, bold=False)
            self._font_small = pygame.font.SysFont(name, self._item_px,  bold=False)

        self.start_time = time.monotonic()

    def exit(self): pass

    # ---- input ----
    def handle_event(self, e, now):
        # ⬇ 방향키만 지원 (R/F, 마우스 제거)
        if e.type == pygame.KEYDOWN:
            if e.key == pygame.K_LEFT:
                self._kb_side = "L"
            elif e.key == pygame.K_RIGHT:
                self._kb_side = "R"
        elif e.type == pygame.KEYUP:
            if e.key in (pygame.K_LEFT, pygame.K_RIGHT):
                self._kb_side = None

    # ---- update/draw ----
    def update(self, dt, now):
        # 1) UART pulse → 해당 홀드에 pulse
        v = self.play_scene.poll_setting_pulse()
        if v == "RESTART": self.hold_l.pulse(now)
        elif v == "FINISH": self.hold_r.pulse(now)

        # 2) Keyboard hold
        if self._kb_side == "L": self.hold_l.pulse(now)
        elif self._kb_side == "R": self.hold_r.pulse(now)

        # 3) Mouse hold
        if self._mouse_side == "L": self.hold_l.pulse(now)
        elif self._mouse_side == "R": self.hold_r.pulse(now)

        # 4) 게이지 업데이트 & 확정 체크
        rl, _, left_done  = self.hold_l.update(dt, now)
        rr, _, right_done = self.hold_r.update(dt, now)

        if not self._done and left_done:
            self._action="restart"; 
            self._done=True
            self._send_byte_via_play(self.resume_byte)

        if not self._done and right_done:
            self._action="finish";
            self._done=True
            self._send_byte_via_play(self.quit_byte)

        # 비율 저장(그리기용)
        self._ratio_l, self._ratio_r = rl, rr

    # 카드 배경/테두리
    def _draw_card(self, screen, rect,
               title: str,
               subtitle: str | None = None,
               desc: str | None = None,
               gauge_ratio: float = 0.0,
               selected: bool = False):

        # 카드 배경
        body = pygame.Surface(rect.size, pygame.SRCALPHA)
        body.fill((0, 0, 0, 150))
        pygame.draw.rect(body, (255, 255, 255, 90), body.get_rect(), width=3, border_radius=24)
        screen.blit(body, rect.topleft)

        # 제목만 상단 중앙
        f_title = pygame.font.SysFont("Arial", 80, bold=True)  # 기존 72 → 80 (가독성)
        r = f_title.render(title, True, (255, 255, 255))
        title_margin_top = 18
        screen.blit(r, (rect.centerx - r.get_width() // 2, rect.top + title_margin_top))

        # 게이지(하단)
        g_h = 18
        g_rect = pygame.Rect(rect.left + 24, rect.bottom - 28 - g_h, rect.width - 48, g_h)
        pygame.draw.rect(screen, (60, 60, 70), g_rect, border_radius=9)
        ratio = max(0.0, min(1.0, gauge_ratio))
        fill = g_rect.copy()
        fill.width = int(g_rect.width * ratio)
        pygame.draw.rect(screen, (255, 220, 120), fill, border_radius=9)

        if selected:
            pygame.draw.rect(screen, (255, 255, 255), rect, width=4, border_radius=24)

    def draw(self, screen):
        # 반투명 덮개
        s = pygame.Surface((self.W, self.H), pygame.SRCALPHA); s.fill((0,0,0,180))
        screen.blit(s, (0,0))

        # 타이틀(조금 더 위로)
        title_rect = self.font_title.render("Settings", True, WHITE).get_rect(midtop=(self.W//2, 12))  # ★ top 12
        screen.blit(self.font_title.render("Settings", True, WHITE), title_rect.topleft)

        # 카드(텍스트만: Resume / Quit)
        self._draw_card(screen, self.left_box,  "Resume",  None, None, getattr(self, "_ratio_l", 0.0))
        self._draw_card(screen, self.right_box, "Quit",    None, None, getattr(self, "_ratio_r", 0.0))

        # 카드 이미지 블릿 : 카드 센터 기준 위로 올려 배치
        def blit_center_upper(img: pygame.Surface | None, card: pygame.Rect, offset_y: int = -120):
            if not img: 
                return
            r = img.get_rect()
            r.centerx = card.centerx
            r.centery = card.centery + offset_y   # 가운데에서 위로(음수일수록 더 위)
            # 타이틀 영역과 겹치지 않게 최소 상단 보정
            top_reserved = 120
            if r.top < card.top + top_reserved:
                r.top = card.top + top_reserved
            screen.blit(img, r.topleft)

        blit_center_upper(self.left_img_surf,  self.left_box,  offset_y=-40)
        blit_center_upper(self.right_img_surf, self.right_box, offset_y=-40)


    def _compute_layout(self):
        # R = self.play_scene.VGA_RECT          # (x, y, w, h)  ← 제거
        R = self.cam_rect                        # ← 실제 카메라 rect 사용!

        band_w = int(R.width * self.cover_ratio)
        pad    = 20

        left_x  = max(0, R.left - band_w)
        right_x = min(self.W - band_w, R.right)

        self.left_box  = pygame.Rect(left_x  + pad, R.top + pad,
                                    band_w - 2*pad, R.height - 2*pad)
        self.right_box = pygame.Rect(right_x + pad, R.top + pad,
                                    band_w - 2*pad, R.height - 2*pad)

        if self.debug:
            print(f"[SETTING] R={R} left_box={self.left_box} right_box={self.right_box}")

    # 카드용 이미지 로드 & 리사이즈
    def _load_card_images(self):
        if not self.assets_dir:
            return

        def load_and_fit(png_path: Path, card_rect: pygame.Rect):
            try:
                if not png_path.exists():
                    return None
                img = pygame.image.load(str(png_path)).convert_alpha()
                iw, ih = img.get_size()

                # 카드 내부에서 이미지가 들어갈 영역 계산 (타이틀/게이지 여백 제외)
                top_reserved = 120      # 타이틀 높이+여백
                bottom_reserved = 70    # 하단 게이지 높이+여백
                pad = 20

                area_w = card_rect.width  - 2*pad
                area_h = card_rect.height - (top_reserved + bottom_reserved)

                if area_w <= 0 or area_h <= 0:
                    return None

                s = min(area_w / iw, area_h / ih, 1.0)
                new_size = (max(1, int(iw*s)), max(1, int(ih*s)))
                fitted = pygame.transform.smoothscale(img, new_size)
                return fitted
            except Exception:
                return None

        if self.left_box and self.right_box:
            lp = self.assets_dir / self.left_img_name
            rp = self.assets_dir / self.right_img_name
            self.left_img_surf  = load_and_fit(lp,  self.left_box)
            self.right_img_surf = load_and_fit(rp, self.right_box)


    # ---- query ----
    def done(self): return self._done
    def get_action(self): return self._action

    def _send_byte_via_play(self, b: bytes):
        if not b:
            return
        ps = self.play_scene
        try:
            # 보내기 전에 보기 좋게 로그
            self._log_tx_bytes(b)

            # 1) 위젯/씬 스타일 API
            if hasattr(ps, "send_uart") and callable(ps.send_uart):
                ps.send_uart(b)
                if self.debug: print(f"[SETTING] path=send_uart size={len(b)}")
                return
            if hasattr(ps, "send_bytes") and callable(ps.send_bytes):
                ps.send_bytes(b)
                if self.debug: print(f"[SETTING] path=send_bytes size={len(b)}")
                return

            # 2) 직접 시리얼 핸들
            ser = getattr(ps, "ser", None)
            if ser and hasattr(ser, "write"):
                ser.write(b)
                if hasattr(ser, "flush"):
                    ser.flush()
                if self.debug: print(f"[SETTING] path=ser.write size={len(b)}")
                return

            if self.debug:
                print("[SETTING] no UART path found (send skipped)")

        except Exception as e:
            if self.debug:
                print(f"[SETTING] UART send failed: {e}")

    # scenes/setting_scene.py (클래스 안 아무 데나)
    def _log_tx_bytes(self, data: bytes, prefix="[UART][TX BYTE]"):
        if not self.debug or not data:
            return
        for v in data:
            ch = chr(v) if 32 <= v <= 126 else '.'
            print(f"{prefix} 0x{v:02x} ('{ch}')")