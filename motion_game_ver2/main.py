# main.py
from PIL import Image, ImageDraw
from pathlib import Path
import time
import pygame
import cv2
import numpy as np
import os

from widgets import StartHoldWidget
from scenes.ranking_widget import RankingScene  # ★ 추가
# from scenes.mode_select_scene import ModeSelectScene
from scenes.music_select_scene import MusicSelectScene
from scenes.play_scene import PlayScene
from scenes.setting_scene import SettingScene
from scenes.ending_scene import EndingScene
from utils.music import SoundManager

# ----------------- Ranking -----------------
RANKINGS = []   # [(이름, 점수), ...] 최대 5명 유지

# ---------------- Paths ----------------
BASE_DIR = Path(__file__).resolve().parent 
ASSETS   = BASE_DIR / "assets"    
bg_path    = ASSETS / "background.png"
char1_path = ASSETS / "1.png"
char2_path = ASSETS / "2.png"

sound = SoundManager(ASSETS)

# 폴더/토큰 매핑
FOLDER_MAP     = {"GOLDEN": "golden", "SODA": "sodapop", "SODAPOP": "sodapop"}
START_CHAR_MAP = {"GOLDEN": "g",      "SODA": "s",       "SODAPOP": "s"}

# -------------- Layout -----------------
W, H = 2560, 1440
vga_x0, vga_y0 = 530, 200
vga_x1, vga_y1 = 2030, 1325
vga_w, vga_h   = (vga_x1 - vga_x0), (vga_y1 - vga_y0)

# ------------- Pygame ------------------
pygame.mixer.pre_init(44100, -16, 2, 512)  # 옵션: 레이턴시↓
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
    port="COM21", baud=115200, parse_mode="token",
    hold_s=2.0, timeout=0.25, debug=True
    # label_idle="Start!!", label_done="Ready!",
    # title_default="Motion Game",
    # btn_rect=(60, H-180, 420, 130),
    # title_pos=(W//2, 100)
)


# --------------- Main Loop -------------
STATE = "INTRO"
intro_block_until = 0.0 
# mode_scene = None
running = True
last = time.monotonic()

sound.play_menu(vol=1.0)

# mode_scene = None
music_scene = None
play_scene = None
setting_scene = None
current_song = None
ending_scene = None     
ranking_scene = None

# ---------------- Main Loop ----------------
while running:
    now = time.monotonic()
    dt  = min(0.1, now - last)
    last = now

    # 1️⃣ 이벤트 처리 (한 번만)
    for e in pygame.event.get():
        if e.type == pygame.QUIT:
            running = False
        elif e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE:
            running = False

        # 상태별 이벤트 처리
        if STATE == "INTRO":
            start_widget.handle_event(e)
        elif STATE == "MUSIC" and music_scene:
            music_scene.handle_event(e, now)
        elif STATE == "PLAY" and play_scene:
            play_scene.handle_event(e, now)
        elif STATE == "SETTING" and setting_scene:
            setting_scene.handle_event(e, now)
        elif STATE == "ENDING" and ending_scene:
            ending_scene.handle_event(e)  # 이제 e만 전달

    # 2️⃣ 배경 그리기
    if STATE in ("INTRO", "MODE", "MUSIC"):
        screen.blit(bg_layout_surf, (0, 0))
    else:
        screen.blit(bg_plain_surf, (0, 0))

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
        if time.monotonic() >= intro_block_until:
            start_widget.pump_uart()
            if start_widget.update(dt):
                # INTRO → MODE 전환 (같은 창)
                start_widget.stop()    # UART 쓰고 있으면 정리
                music_scene = MusicSelectScene(W, H, assets_dir=ASSETS, 
                                                port="COM21", baud=115200,
                                                hold=2.0, timeout=0.25, debug=True,
                                                confirm_show=1.0)
                music_scene.enter()
                STATE = "MUSIC"
        start_widget.draw(screen, title="Motion Game",
                          hint=None)
    
    # ------------- MODE -------------
    #elif STATE == "MODE":
    #    # 카메라
    #    ok, frame = cap.read()
    #    if ok:
    #        blit_cam_into_rect(screen, frame, (vga_x0, vga_y0, vga_w, vga_h))
    #    else:
    #        pygame.draw.rect(screen, (0,0,0), (vga_x0, vga_y0, vga_w, vga_h))
    #
    #    mode_scene.update(dt, now)
    #    mode_scene.draw(screen)
    #    if mode_scene.done():
    #        res = mode_scene.get_result()   # 'single' or 'Multi'
    #        mode_scene.exit()
    #        if res == "Single":
    #            # MUSIC 씬 시작
    #            music_scene = MusicSelectScene(W, H, assets_dir=ASSETS, 
    #                                           port="COM21", baud=115200,
    #                                           hold=2.0, timeout=0.25, debug=True,
    #                                           confirm_show=1.0)
    #            music_scene.enter()
    #            STATE = "MUSIC"
    #            continue
    #        elif res == "Multi":
    #            # TODO: 바로 게임(single)로 가고 싶다면 여기서 single 씬 생성
    #            running = False
    
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
            selected = music_scene.get_result()  # 'GOLDEN' / 'SODA' / ...
            current_song = selected
            print("SELECTED SONG:", selected)
            music_scene.exit(); music_scene = None

            # ⬇️ 추가: 선택된 곡 바로 재생 (Golden.ogg / Sodapop.ogg)
            if selected.upper().startswith("GOLD"):
                sound.play_title("Golden", vol=0.7, loop=-1)     # assets/music/Golden.ogg
            else:
                sound.play_title("Sodapop", vol=0.7, loop=-1)    # assets/music/Sodapop.ogg

            # 선택된 곡에 따른 assets 폴더 결정
            subdir = FOLDER_MAP.get(selected)
            if not subdir:
                print("[WARN] unknown selection; fallback to golden")
                subdir = "golden"
            play_assets = ASSETS / subdir
            start_char_out = START_CHAR_MAP.get(selected)

            print(f"[MUSIC→PLAY] assets_dir={play_assets}")

            # PLAY 씬 준비만 하고, 렌더/업데이트는 다음 프레임부터 정상 루프에서 돌림
            play_scene = PlayScene(
                W, H,
                assets_dir=play_assets,
                overlay_dir=ASSETS,
                port="COM21", baud=115200,
                prep_seconds=5.0, result_hold=3.0,
                pause_hold=1.0, pause_timeout=0.25,
                parse_mode="ascii", debug=False,
                pre_start_seconds=3.0, start_char=start_char_out,
                done_char="f",
                result_bytes={"P": b'p', "G": b'g', "B": b'b'},  # 예: 소문자 사용
                ending_byte=b"e"
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
                W, H, assets_dir=ASSETS, port="COM21", baud=115200,
                prep_seconds=5.0, result_hold=3.0,
                pause_hold=1.0, pause_timeout=0.25,
                parse_mode="ascii", debug=False
            )
            play_scene.enter()

        # ★ 매 프레임 호출
        play_scene.update(dt, now)
        play_scene.draw(screen, frame if ok else None)

        if getattr(play_scene, "pause_requested", False):
            play_scene.pause_requested = False   # 플래그 소모
            play_scene.reset_pause_hold()

            setting_scene = SettingScene(
                W, H,
                play_scene=play_scene,
                title="Settings",
                hold_s=2.0, timeout=0.25,
                cover_ratio=0.25,
                vga_rect=(vga_x0, vga_y0, vga_w, vga_h), # 실제로 화면에 쓰는 VGA 직사각형 전달
                debug=True,
                assets_dir=ASSETS
            )
            sound.pause()
            setting_scene.enter()
            STATE = "SETTING"
            continue

        if play_scene.done():
            res = play_scene.get_result()   # {'score': ..., ...}
            final_score = int(res.get("score", 0))
            play_scene.exit(); play_scene = None

             # ★ 엔딩씬 생성
            ending_scene = EndingScene(
                W, H,
                assets_dir=ASSETS,
                song=current_song or "GOLDEN",
                score=final_score,
                show_seconds=10.0
            )
            ending_scene.enter()
            STATE = "ENDING"
            continue

    # ------------- SETTING -------------
    elif STATE == "SETTING":
        # 카메라는 원하면 계속 blit 가능(정지 화면 원하면 생략)
        ok, frame = cap.read()
        if ok:
            blit_cam_into_rect(screen, frame, (vga_x0, vga_y0, vga_w, vga_h))
        else:
            pygame.draw.rect(screen, (0,0,0), (vga_x0, vga_y0, vga_w, vga_h))

        setting_scene.update(dt, now)
        setting_scene.draw(screen)

        if setting_scene.done():
            act = setting_scene.get_action()
            setting_scene.exit(); setting_scene = None

            if act == "restart":
                # 현재 스테이지를 5초 카운트다운부터 다시
                if play_scene:
                    play_scene.reset_pause_hold()
                    play_scene.restart_stage(now)
                    sound.resume()
                    STATE = "PLAY"
                    continue

            elif act == "finish":
                # 게임 종료 → INTRO(IDLE)로 복귀
                if play_scene:
                    play_scene.exit(); play_scene = None

                # StartHoldWidget을 다시 쓸 거면 재생성 권장(예전에 stop() 했으니)
                start_widget = StartHoldWidget(
                    (W, H),
                    port="COM21", baud=115200, parse_mode="token",
                    hold_s=2.0, timeout=0.25, debug=True
                )
                sound.play_menu(vol=1.0)
                STATE = "INTRO"
                continue
    
    # ------------- ENDING -------------
    elif STATE == "ENDING":
        if ending_scene:
            ending_scene.update(dt, now)
            ending_scene.draw(screen)

            if ending_scene.done():
                # 결과 가져오기
                res = ending_scene.get_result()
                name, score = res["name"], res["score"]

                # 랭킹 갱신
                RANKINGS.append((name, score))
                RANKINGS.sort(key=lambda x: x[1], reverse=True)
                RANKINGS[:] = RANKINGS[:5]  # 상위 5명만

                # 엔딩 씬 정리
                ending_scene = None

                # 랭킹 씬 생성
                ranking_scene = RankingScene(
                    W, H, RANKINGS,
                    show_seconds=8.0,
                    port="COM21", baud=115200,
                    send_byte=b't',
                    debug=True,
                    title_px=220,            # 제목 크기
                    item_px=120,             # 항목 크기
                    line_gap=28,
                    # 폰트: Regular (너무 얇지도 굵지도 않게)
                    font_name="segoe ui",    # 또는 "malgun gothic" / 폰트파일이면 Pretendard-Medium.ttf 추천
                    font_bold=False,
                    # 얇은 파란빛 외곽(2px)
                    use_shadow=True,
                    shadow_color=(85, 140, 255),
                    shadow_radius=2,
                    shadow_offset=(0, 1),
                    # 색상
                    title_color=(255, 255, 255),
                    item_color=(220, 220, 240),
                    bg_color=(20, 20, 20),
                    items_top_offset=140
                )

                ranking_scene._font_name = "segoe ui semilight"
                ranking_scene.enter()
                STATE = "RANKING"
                continue

    # ---------------- RANKING ----------------
    elif STATE == "RANKING":
        if ranking_scene:
            ranking_scene.update(dt, now)
            ranking_scene.draw(screen)

            if ranking_scene.done():
                ranking_scene.exit()   # ★ 정리
                ranking_scene = None

                # INTRO용 StartHoldWidget 재생성 (그대로 유지)
                start_widget = StartHoldWidget(
                    (W, H),
                    port="COM21",
                    baud=115200,
                    parse_mode="token",
                    hold_s=2.0,
                    timeout=0.25,
                    debug=True
                )
                sound.play_menu(vol=1.0)
                start_widget.reset()
                intro_block_until = time.monotonic() + 1.2
                pygame.event.clear()
                STATE = "INTRO"
                continue

    pygame.display.flip()
    clock.tick(60)

# -------------- Cleanup ----------------
start_widget.stop()
if cap: cap.release()
pygame.quit()
