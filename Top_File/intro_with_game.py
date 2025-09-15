# intro_with_cam.py
from PIL import Image, ImageDraw
from start_hold_widget import StartHoldWidget

import time
import pygame
import cv2
import numpy as np

# --------------------------
# 경로 설정
# --------------------------
bg_path    = "./motion_game/background.png"  # 배경
char1_path = "./motion_game/1.png"          # 왼쪽 캐릭터
char2_path = "./motion_game/2.png"          # 오른쪽 캐릭터

WHITE     = (255, 255, 255)
#NEON_BLUE = (100, 150, 255)
#NEON_RED  = (255, 80, 80)

# --------------------------
# 레이아웃
# --------------------------
W, H = 2560, 1440
vga_x0, vga_y0 = 530, 200
vga_x1, vga_y1 = 2030, 1325
vga_w, vga_h   = (vga_x1 - vga_x0), (vga_y1 - vga_y0)

# --------------------------
# pygame 초기화
# --------------------------
pygame.init()
screen = pygame.display.set_mode((W, H))
pygame.display.set_caption("Motion Game Intro")
clock = pygame.time.Clock()

# StartHoldWidget
start_widget = StartHoldWidget((W, H),
                               port=None,             # Basys3 연결 시 "COM5" 등으로 변경
                               baud=230400,
                               parse_mode="anybyte",  # "binary01"도 가능
                               hold_s=2.0,
                               timeout=0.25)          # 250ms
STATE = "INTRO"  # INTRO -> GAME
last = time.monotonic()

# --------------------------
# 배경(PIL로 합성) → pygame Surface
# --------------------------
bg = Image.open(bg_path).convert("RGBA").resize((W, H))
draw = ImageDraw.Draw(bg)
draw.rectangle([vga_x0, vga_y0, vga_x1, vga_y1], fill="black")  # 카메라 영역(검정)
bg_surf = pygame.image.fromstring(bg.tobytes(), bg.size, bg.mode)

# --------------------------
# 캐릭터(반드시 display 생성 뒤 convert_alpha)
# --------------------------
char1_surf = pygame.image.load(str(char1_path)).convert_alpha()
char1_surf = pygame.transform.smoothscale(char1_surf, (600, 900))
char2_surf = pygame.image.load(str(char2_path)).convert_alpha()
char2_surf = pygame.transform.smoothscale(char2_surf, (600, 900))

# 네온 텍스트
#def draw_neon_text(surface, font, text, base_color, glow_color, rect, glow_layers=6):
#    for i in range(1, glow_layers+1):
#        glow = font.render(text, True, glow_color); glow.set_alpha(40)
#        surface.blit(glow, rect.move( i,  0))
#        surface.blit(glow, rect.move(-i,  0))
#        surface.blit(glow, rect.move( 0,  i))
#        surface.blit(glow, rect.move( 0, -i))
#        surface.blit(glow, rect.move( i,  i))
#       surface.blit(glow, rect.move(-i, -i))
#       surface.blit(glow, rect.move( i, -i))
#       surface.blit(glow, rect.move(-i,  i))
#   base = font.render(text, True, base_color)
#   surface.blit(base, rect)

# title_font = pygame.font.SysFont("Arial", 180, bold=True)
# start_font = pygame.font.SysFont("Arial", 150, bold=True)
# title_rect = title_font.render("Motion Game", True, WHITE).get_rect(center=(W//2, 100))
# start_rect = start_font.render("Start!!", True, WHITE).get_rect(center=(300, H - 150))

# 2) 배경(PIL로 합성) → pygame Surface
bg = Image.open("./motion_game/background.png").convert("RGBA").resize((W, H))
draw = ImageDraw.Draw(bg)
draw.rectangle([vga_x0, vga_y0, vga_x1, vga_y1], fill="black")
bg_surf = pygame.image.fromstring(bg.tobytes(), bg.size, bg.mode)

# 3) 캐릭터는 화면 생성 후에 convert_alpha()
char1_surf = pygame.image.load("./motion_game/1.png").convert_alpha()
char1_surf = pygame.transform.smoothscale(char1_surf, (600, 900))
char2_surf = pygame.image.load("./motion_game/2.png").convert_alpha()
char2_surf = pygame.transform.smoothscale(char2_surf, (600, 900))

# --------------------------
# 카메라 열기 (index=1)
# --------------------------
cap = cv2.VideoCapture(1, cv2.CAP_DSHOW)     # 인덱스 1, DirectShow
cap.set(cv2.CAP_PROP_FRAME_WIDTH,  640)      # 캡처보드/컨버터에 맞춰 조정
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
cap.set(cv2.CAP_PROP_FPS,          60)
cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'YUY2'))  # 안 되면 'MJPG' 시도
cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)          # 지연 줄이기(플랫폼 따라 무시될 수 있음)

if not cap.isOpened():
    print("[ERR] 카메라(index=1) 열기 실패. 인덱스/백엔드/해상도 확인!")

def blit_cam_into_rect(surface, frame_bgr, rect):
    """frame_bgr(OpenCV) 을 rect 안에 비율 유지로 넣기(레터박스)."""
    x0, y0, w, h = rect
    # BGR → RGB
    rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
    fh, fw = rgb.shape[:2]
    # 스케일(레터박스)
    s = min(w / fw, h / fh)
    nw, nh = max(1, int(fw * s)), max(1, int(fh * s))
    rgb_resized = cv2.resize(rgb, (nw, nh), interpolation=cv2.INTER_LINEAR)

    # Pygame Surface로 변환
    cam_surf = pygame.image.frombuffer(rgb_resized.tobytes(), (nw, nh), "RGB")
    # 박스 배경(검정) 지우고 중앙 정렬 배치
    pygame.draw.rect(surface, (0,0,0), (x0, y0, w, h))
    ox, oy = x0 + (w - nw)//2, y0 + (h - nh)//2
    surface.blit(cam_surf, (ox, oy))

# --------------------------
# 메인 루프
# --------------------------
clock = pygame.time.Clock()
running = True
while running:
    # dt 계산
    now = time.monotonic()
    dt  = min(0.1, now - last)
    last = now

    for e in pygame.event.get():
        if e.type == pygame.QUIT: running = False
        elif e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE:
            running = False
        
         # 인트로 상태에서만 위젯에 키보드 이벤트(스페이스) 전달
        if STATE == "INTRO":
            start_widget.handle_event(e)

    # 배경 먼저
    screen.blit(bg_surf, (0, 0))

    # 카메라 프레임 그리기
    ok, frame = cap.read()
    if ok:
        blit_cam_into_rect(screen, frame, (vga_x0, vga_y0, vga_w, vga_h))
    else:
        # 실패 시 박스를 검정으로 유지
        pygame.draw.rect(screen, (0,0,0), (vga_x0, vga_y0, vga_w, vga_h))

    
    screen.blit(char1_surf, (50, 400))                         # 3) 캐릭터(왼쪽) ↑위로
    screen.blit(char2_surf, (W - 650, 350))                    #    캐릭터(오른쪽)

    # 위젯 UART 폼프 + 업데이트 + 그리기
    if STATE == "INTRO":
        start_widget.pump_uart()     # UART 이벤트 큐 비우기
        if start_widget.update(dt):  # 3초 채워지면 True
            STATE = "GAME"           # 다음 씬으로 전환 (원하면 효과/사운드 넣기)
        # 오버레이 렌더 (타이틀/게이지/힌트)
        start_widget.draw(screen, title="Motion Game",
                          hint="손을 START 영역에 3초 유지 · Space=테스트 · ESC=종료")
    else:
        # STATE == "GAME" 에서는 자유롭게 게임 화면 그리면 됨.
        # (예: 'Ready!' 1초 표시 후 본 게임으로 넘어가도 좋음)
        pass

    pygame.display.flip()
    clock.tick(60)

start_widget.stop()
cap.release()
pygame.quit()