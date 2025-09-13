import pygame
import sys

pygame.init()

# 화면 크기
WIDTH, HEIGHT = 640, 480
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Game Start Screen")

# 경로
BG_PATH   = "./background.png"
CHAR_PATH = "./aaa.png"

# 색상
LIGHT_YELLOW = (255, 255, 200)
WHITE = (255, 255, 255)
NEON_PINK = (255, 100, 100)
NEON_BLUE = (100, 150, 255)   # Motion Game 네온 효과 색상

# ---------------- 텍스트 설정 ----------------
# Motion Game (네온 효과용)
title_font = pygame.font.SysFont("Arial", 80, bold=True)
title_text = "Motion Game"
title_base = title_font.render(title_text, True, WHITE)
title_rect = title_base.get_rect(center=(WIDTH // 2, 60))

# Start (네온 효과용)
button_font = pygame.font.SysFont("Arial", 60, bold=True)
button_text = "Start"
button_base = button_font.render(button_text, True, WHITE)
button_rect = button_base.get_rect(topleft=(80, 240))

glow_layers = 6  # 네온 효과 레이어 수

# ---------------- 배경 이미지 ----------------
bg_img = pygame.image.load(BG_PATH).convert_alpha()
bg_img = pygame.transform.smoothscale(bg_img, (WIDTH, HEIGHT))
bg_alpha = 128

# ---------------- 캐릭터 이미지 ----------------
character = pygame.image.load(CHAR_PATH).convert_alpha()
char_w, char_h = 400, 400
character = pygame.transform.smoothscale(character, (char_w, char_h))
character.set_alpha(220)
char_rect = character.get_rect(bottomright=(WIDTH - 10, HEIGHT - 10))

clock = pygame.time.Clock()

while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit(); sys.exit()

        # 버튼 클릭 이벤트
        if event.type == pygame.MOUSEBUTTONDOWN:
            if button_rect.collidepoint(event.pos):
                print("게임 시작!")

    # 1) 배경
    screen.fill(LIGHT_YELLOW)
    temp_bg = bg_img.copy()
    temp_bg.set_alpha(bg_alpha)
    screen.blit(temp_bg, (0, 0))

    # 2) 캐릭터
    screen.blit(character, char_rect)

    # 3) Motion Game 네온 효과
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
    screen.blit(title_base, title_rect)  # 중앙 흰색 본문

    # 4) Start 네온 효과
    for i in range(1, glow_layers+1):
        glow = button_font.render(button_text, True, NEON_PINK)
        glow.set_alpha(40)
        screen.blit(glow, button_rect.move(i, 0))
        screen.blit(glow, button_rect.move(-i, 0))
        screen.blit(glow, button_rect.move(0, i))
        screen.blit(glow, button_rect.move(0, -i))
        screen.blit(glow, button_rect.move(i, i))
        screen.blit(glow, button_rect.move(-i, -i))
        screen.blit(glow, button_rect.move(i, -i))
        screen.blit(glow, button_rect.move(-i, i))
    screen.blit(button_base, button_rect)  # 중앙 흰색 본문

    pygame.display.flip()
    clock.tick(60)
