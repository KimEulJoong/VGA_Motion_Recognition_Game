# main.py
from PIL import Image, ImageDraw
from pathlib import Path
import time
import pygame
import cv2
import numpy as np

from widgets import StartHoldWidget
from scenes.mode_select_scene import ModeSelectScene
from scenes.music_select_scene import MusicSelectScene
from scenes.play_scene import PlayScene

# ---------------- Paths ----------------
BASE_DIR = Path(__file__).resolve().parent 
ASSETS   = BASE_DIR / "assets"    
bg_path    = ASSETS / "background.png"
char1_path = ASSETS / "1.png"
char2_path = ASSETS / "2.png"

# -------------- Layout -----------------
W, H = 2560, 1440
vga_x0, vga_y0 = 530, 200
vga_x1, vga_y1 = 2030, 1325
vga_w, vga_h   = (vga_x1 - vga_x0), (vga_y1 - vga_y0)

# ------------- Pygame ------------------
pygame.init()
screen = pygame.display.set_mode((W, H))
pygame.display.set_caption("Motion Game")
clock = pygame.time.Clock()

# --------- Background (PIL→Surface) ----
bg_layout = Image.open(bg_path).convert("RGBA").resize((W, H))
draw = ImageDraw.Draw(bg_layout)
draw.rectangle([vga_x0, vga_y0, vga_x1, vga_y1], fill="black")
bg_layout_surf = pygame.image.fromstring(bg_layout.tobytes(), bg_layout.size, bg_layout.mode)

# PLAY용: 검정 사각형 없는 ‘깨끗한’ 배경
bg_plain = Image.open(bg_path).convert("RGBA").resize((W, H))
bg_plain_surf = pygame.image.fromstring(bg_plain.tobytes(), bg_plain.size, bg_plain.mode)

# --------------- Characters ------------
char1_surf = pygame.image.load(char1_path).convert_alpha()
char1_surf = pygame.transform.smoothscale(char1_surf, (600, 900))
char2_surf = pygame.image.load(char2_path).convert_alpha()
char2_surf = pygame.transform.smoothscale(char2_surf, (600, 900))

# -------------- Camera -----------------
def open_cam(index=1, width=640, height=480, fps=60):
    cap = cv2.VideoCapture(index, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
    cap.set(cv2.CAP_PROP_FPS,          fps)
    # FOURCC 설정: 우선 MJPG, 실패 시 무시
    cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    return cap

cap = open_cam(1)

def blit_cam_into_rect(surface, frame_bgr, rect):
    x0, y0, w, h = rect
    rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
    fh, fw = rgb.shape[:2]
    s = min(w / fw, h / fh)
    nw, nh = max(1, int(fw * s)), max(1, int(fh * s))
    rgb_resized = cv2.resize(rgb, (nw, nh), interpolation=cv2.INTER_LINEAR)
    cam_surf = pygame.image.frombuffer(rgb_resized.tobytes(), (nw, nh), "RGB")
    pygame.draw.rect(surface, (0,0,0), (x0, y0, w, h))
    ox, oy = x0 + (w - nw)//2, y0 + (h - nh)//2
    surface.blit(cam_surf, (ox, oy))

if not cap.isOpened():
    print("[WARN] Camera open failed: index=1")

# ------------- Start Widget ------------
start_widget = StartHoldWidget(
    (W, H),
    port="COM17", baud=115200, parse_mode="token",
    hold_s=2.0, timeout=0.25, debug=True
    # label_idle="Start!!", label_done="Ready!",
    # title_default="Motion Game",
    # btn_rect=(60, H-180, 420, 130),
    # title_pos=(W//2, 100)
)

# --------------- Main Loop -------------
STATE = "INTRO"
mode_scene = None
running = True
last = time.monotonic()

mode_scene = None
music_scene = None
play_scene = None

while running:
    now = time.monotonic()
    dt  = min(0.1, now - last); last = now

    for e in pygame.event.get():
        if e.type == pygame.QUIT: running = False
        elif e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE: running = False

        if STATE == "INTRO":
            start_widget.handle_event(e)
        elif STATE == "MODE" and mode_scene:
            mode_scene.handle_event(e, now)  
        elif STATE == "MUSIC" and music_scene:
            music_scene.handle_event(e, now)
        elif STATE == "PLAY" and play_scene:
            play_scene.handle_event(e, now)

    # 공통 배경
    if STATE in ("INTRO", "MODE", "MUSIC"):
        screen.blit(bg_layout_surf, (0, 0))   # 기존 레이아웃 배경
    else:  # PLAY 배경
        screen.blit(bg_plain_surf, (0, 0))    # 깨끗한 배경

    # ------------ INTRO ------------
    if STATE == "INTRO":
        # 카메라
        ok, frame = cap.read()
        if ok:
            blit_cam_into_rect(screen, frame, (vga_x0, vga_y0, vga_w, vga_h))
        else:
            pygame.draw.rect(screen, (0,0,0), (vga_x0, vga_y0, vga_w, vga_h))

        # 캐릭터 스프라이트 고정 렌더링
        screen.blit(char1_surf, (50, 400))
        screen.blit(char2_surf, (W - 650, 350))

        # Start 홀드 UI
        start_widget.pump_uart()    # 입력 이벤트 수집 단
        if start_widget.update(dt):
            # INTRO → MODE 전환 (같은 창)
            start_widget.stop()    # UART 쓰고 있으면 정리
            mode_scene = ModeSelectScene(W, H, port="COM17", baud=115200, parse="token", hold=2.0, timeout=0.25, assets_dir=ASSETS)
            mode_scene.enter()
            STATE = "MODE"
        start_widget.draw(screen, title="Motion Game",
                          hint="손을 START 영역에 2초 유지 · Space=테스트 · ESC=종료")

    # ------------- MODE -------------
    elif STATE == "MODE":
        # 카메라
        ok, frame = cap.read()
        if ok:
            blit_cam_into_rect(screen, frame, (vga_x0, vga_y0, vga_w, vga_h))
        else:
            pygame.draw.rect(screen, (0,0,0), (vga_x0, vga_y0, vga_w, vga_h))

        mode_scene.update(dt, now)
        mode_scene.draw(screen)
        if mode_scene.done():
            res = mode_scene.get_result()   # 'single' or 'Multi'
            mode_scene.exit()
            if res == "Single":
                # MUSIC 씬 시작
                music_scene = MusicSelectScene(W, H, assets_dir=ASSETS, 
                                               port="COM17", baud=115200,
                                               hold=2.0, timeout=0.25, debug=True,
                                               confirm_show=1.0)
                music_scene.enter()
                STATE = "MUSIC"
                continue
            elif res == "Multi":
                # TODO: 바로 게임(single)로 가고 싶다면 여기서 single 씬 생성
                running = False
    
    # ------------ MUSIC -------------
    elif STATE == "MUSIC":
        ok, frame = cap.read()
        if ok:
            blit_cam_into_rect(screen, frame, (vga_x0, vga_y0, vga_w, vga_h))
        else:
            pygame.draw.rect(screen, (0,0,0), (vga_x0, vga_y0, vga_w, vga_h))

        music_scene.update(dt, now)
        music_scene.draw(screen)

        if music_scene.done():
            selected_song = music_scene.get_result()  # 'GOLDEN' / 'SODA' / ...
            print("SELECTED SONG:", selected_song)
            music_scene.exit(); music_scene = None

            # PLAY 씬 준비만 하고, 렌더/업데이트는 다음 프레임부터 정상 루프에서 돌림
            play_scene = PlayScene(
                W, H, assets_dir=ASSETS, port="COM17", baud=115200,
                prep_seconds=5.0, result_hold=3.0,
                pause_hold=1.0, pause_timeout=0.25,
                parse_mode="ascii", debug=False,
                pre_start_seconds=3.0, start_char='s'
            )
            play_scene.enter()
            STATE = "PLAY"
            continue

    # ------------- PLAY -------------
    elif STATE == "PLAY":
        ok, frame = cap.read()
        # 씬 인스턴스가 없으면 안전하게 생성(이상 케이스 대비)
        if play_scene is None:
            play_scene = PlayScene(
                W, H, assets_dir=ASSETS, port="COM17", baud=115200,
                prep_seconds=5.0, result_hold=3.0,
                pause_hold=1.0, pause_timeout=0.25,
                parse_mode="ascii", debug=False
            )
            play_scene.enter()

        # ★ 매 프레임 호출 ★
        play_scene.update(dt, now)
        play_scene.draw(screen, frame if ok else None)

        if play_scene.done():
            print("PLAY_DONE:", play_scene.get_result())
            play_scene.exit(); play_scene = None
            # 다음 상태로 갈 게 있으면 바꿔주고, 데모면 종료
            running = False

    pygame.display.flip()
    clock.tick(60)

# -------------- Cleanup ----------------
start_widget.stop()
if cap: cap.release()
pygame.quit()
