import pygame
import sys

pygame.init()

# 화면 크기
WIDTH, HEIGHT = 640, 480
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Attack Motion Screen")

# 경로
BG_PATH = "./background.png"
IMG1 = "./1.png"
IMG2 = "./2.png"
IMG3 = "./3.png"
IMG4 = "./4.png"

# 색상
LIGHT_YELLOW = (255, 255, 200)
WHITE = (255, 255, 255)
NEON_BLUE = (100, 150, 255)   # "Attack Motion" 네온 효과 색상

# ---------------- 텍스트 설정 ----------------
title_font = pygame.font.SysFont("Arial", 80, bold=True)
title_text = "Attack Motion"
title_base = title_font.render(title_text, True, WHITE)
title_rect = title_base.get_rect(center=(WIDTH // 2, 60))

glow_layers = 6  # 네온 효과 레이어 수

# ---------------- 배경 이미지 ----------------
bg_img = pygame.image.load(BG_PATH).convert_alpha()
bg_img = pygame.transform.smoothscale(bg_img, (WIDTH, HEIGHT))
bg_alpha = 128

# ---------------- 4개 이미지 불러오기 ----------------
img1 = pygame.image.load(IMG1).convert_alpha()
img2 = pygame.image.load(IMG2).convert_alpha()
img3 = pygame.image.load(IMG3).convert_alpha()
img4 = pygame.image.load(IMG4).convert_alpha()

# 크기 통일 (120x120 정도로 리사이즈)
target_w, target_h = 120, 120
img1 = pygame.transform.smoothscale(img1, (target_w, target_h))
img2 = pygame.transform.smoothscale(img2, (target_w, target_h))
img3 = pygame.transform.smoothscale(img3, (target_w, target_h))
img4 = pygame.transform.smoothscale(img4, (target_w, target_h))

# ---------------- 배치 계산 ----------------
# 사용할 공간: title_rect.bottom ~ HEIGHT
top_area = title_rect.bottom + 20
bottom_area = HEIGHT - 20
available_height = bottom_area - top_area

# 2행 배치 → 총 높이 = 이미지(120) * 2 + 행 간격(40)
rows = 2
cols = 2
img_gap_y = 40
img_gap_x = 80
block_height = target_h * rows + img_gap_y
block_width = target_w * cols + img_gap_x

# 블록 전체를 세로/가로 가운데 정렬
block_top = top_area + (available_height - block_height) // 2
block_left = (WIDTH - block_width) // 2

# 각 위치 계산
rect1 = img1.get_rect(topleft=(block_left, block_top))
rect2 = img2.get_rect(topleft=(block_left + target_w + img_gap_x, block_top))
rect3 = img3.get_rect(topleft=(block_left, block_top + target_h + img_gap_y))
rect4 = img4.get_rect(topleft=(block_left + target_w + img_gap_x, block_top + target_h + img_gap_y))

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

    # 2) Attack Motion 네온 효과
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

    # 3) 4개 이미지 출력
    screen.blit(img1, rect1)
    screen.blit(img2, rect2)
    screen.blit(img3, rect3)
    screen.blit(img4, rect4)

    pygame.display.flip()
    clock.tick(60)
