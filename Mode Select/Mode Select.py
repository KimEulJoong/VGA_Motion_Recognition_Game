import pygame
import sys

pygame.init()

# 화면 크기
WIDTH, HEIGHT = 640, 480
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Mode Select Screen")

# 경로
BG_PATH = "./background.png"
IMG_1P = "./1p.png"
IMG_2P = "./2p.png"

# 색상
LIGHT_YELLOW = (255, 255, 200)
WHITE = (255, 255, 255)
NEON_BLUE = (100, 150, 255)   # "Mode Select" 네온 효과 색상
NEON_RED = (255, 80, 80)      # 1P, 2P 네온 효과 색상

# ---------------- 텍스트 설정 ----------------
title_font = pygame.font.SysFont("Arial", 80, bold=True)
title_text = "Mode Select"
title_base = title_font.render(title_text, True, WHITE)
title_rect = title_base.get_rect(center=(WIDTH // 2, 80))

# 1P, 2P 텍스트
player_font = pygame.font.SysFont("Arial", 48, bold=True)
text_1p = "1P"
text_2p = "2P"
text_1p_base = player_font.render(text_1p, True, WHITE)
text_2p_base = player_font.render(text_2p, True, WHITE)

glow_layers = 6  # 네온 효과 레이어 수

# ---------------- 배경 이미지 ----------------
bg_img = pygame.image.load(BG_PATH).convert_alpha()
bg_img = pygame.transform.smoothscale(bg_img, (WIDTH, HEIGHT))
bg_alpha = 128

# ---------------- 1P, 2P 이미지 ----------------
img_1p = pygame.image.load(IMG_1P).convert_alpha()
img_2p = pygame.image.load(IMG_2P).convert_alpha()

# 2P 크기 기준으로 리사이즈
target_w, target_h = 180, 180
img_2p = pygame.transform.smoothscale(img_2p, (target_w, target_h))
w, h = img_2p.get_size()
img_1p = pygame.transform.smoothscale(img_1p, (w, h))

# ---------------- 배치 계산 ----------------
# Mode Select 아래에서 화면 하단까지의 영역 중심에 맞춤
available_top = title_rect.bottom + 20
available_bottom = HEIGHT - 20
available_center_y = (available_top + available_bottom) // 2

# 이미지와 텍스트 묶음의 높이 = 텍스트(50) + 간격(20) + 이미지(180)
block_height = 50 + 20 + h

# 묶음의 top 좌표
block_top = available_center_y - block_height // 2

# 텍스트 위치 (아이콘 위쪽)
text_1p_rect = text_1p_base.get_rect(center=(WIDTH // 3, block_top + 25))
text_2p_rect = text_2p_base.get_rect(center=(WIDTH * 2 // 3, block_top + 25))

# 이미지 위치 (텍스트 밑에)
rect_1p = img_1p.get_rect(center=(WIDTH // 3, text_1p_rect.bottom + h // 2 + 10))
rect_2p = img_2p.get_rect(center=(WIDTH * 2 // 3, text_2p_rect.bottom + h // 2 + 10))

clock = pygame.time.Clock()

while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit(); sys.exit()

    # 1) 배경
    screen.fill(LIGHT_YELLOW)
    temp_bg = bg_img.copy()
    temp_bg.set_alpha(bg_alpha)
    screen.blit(temp_bg, (0, 0))

    # 2) Mode Select 네온 효과 (파랑)
    for i in range(1, glow_layers+1):
        glow = title_font.render(title_text, True, NEON_BLUE)
        glow.set_alpha(40)
        screen.blit(glow, title_rect.move(i, 0))
        screen.blit(glow, title_rect.move(-i, 0))
        screen.blit(glow, title_rect.move(0, i))
        screen.blit(glow, title_rect.move(0, -i))
        screen.blit(glow, title_rect.move(i, i))
        screen.blit(glow, title_rect.move(-i, -i))
        screen.blit(glow, title_rect.move(i, -i))
        screen.blit(glow, title_rect.move(-i, i))
    screen.blit(title_base, title_rect)

    # 3) 1P 네온 텍스트
    for i in range(1, glow_layers+1):
        glow = player_font.render(text_1p, True, NEON_RED)
        glow.set_alpha(40)
        screen.blit(glow, text_1p_rect.move(i, 0))
        screen.blit(glow, text_1p_rect.move(-i, 0))
        screen.blit(glow, text_1p_rect.move(0, i))
        screen.blit(glow, text_1p_rect.move(0, -i))
        screen.blit(glow, text_1p_rect.move(i, i))
        screen.blit(glow, text_1p_rect.move(-i, -i))
        screen.blit(glow, text_1p_rect.move(i, -i))
        screen.blit(glow, text_1p_rect.move(-i, i))
    screen.blit(text_1p_base, text_1p_rect)

    # 4) 2P 네온 텍스트
    for i in range(1, glow_layers+1):
        glow = player_font.render(text_2p, True, NEON_RED)
        glow.set_alpha(40)
        screen.blit(glow, text_2p_rect.move(i, 0))
        screen.blit(glow, text_2p_rect.move(-i, 0))
        screen.blit(glow, text_2p_rect.move(0, i))
        screen.blit(glow, text_2p_rect.move(0, -i))
        screen.blit(glow, text_2p_rect.move(i, i))
        screen.blit(glow, text_2p_rect.move(-i, -i))
        screen.blit(glow, text_2p_rect.move(i, -i))
        screen.blit(glow, text_2p_rect.move(-i, i))
    screen.blit(text_2p_base, text_2p_rect)

    # 5) 이미지
    screen.blit(img_1p, rect_1p)
    screen.blit(img_2p, rect_2p)

    pygame.display.flip()
    clock.tick(60)
