import pygame
import sys

pygame.init()

# 화면 크기
WIDTH, HEIGHT = 640, 480
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Game Start Screen")

# 색상
BLUE = (50, 100, 200)
WHITE = (255, 255, 255)
LIGHT_GREEN = (180, 255, 180)

# 큰 텍스트 (Motion Game)
big_font = pygame.font.SysFont("Arial", 72, bold=True)
title_text = big_font.render("Motion Game", True, BLUE)
title_rect = title_text.get_rect(center=(WIDTH // 2, 80))

# 배경 이미지 불러오기 (절대 경로)
background = pygame.image.load("./background.jpg")
background = pygame.transform.scale(background, (WIDTH, HEIGHT))
background = background.convert_alpha()
background.set_alpha(30)  # 0~255 → 128은 0.5 투명도

# 캐릭터 이미지 불러오기
character = pygame.image.load("./aaa.png")
char_w, char_h = 400, 400
character = pygame.transform.scale(character, (char_w, char_h))
character = character.convert_alpha()
character.set_alpha(179)  # 약 0.7 투명도
char_rect = character.get_rect(bottomright=(WIDTH - 10, HEIGHT - 10))

# 버튼 설정
button_rect = pygame.Rect(80, 260, 200, 80)
button_font = pygame.font.SysFont("Arial", 40, bold=True)
button_text = button_font.render("Start", True, WHITE)
button_text_rect = button_text.get_rect(center=button_rect.center)

# 메인 루프
while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit()
            sys.exit()

        # 버튼 클릭 이벤트
        if event.type == pygame.MOUSEBUTTONDOWN:
            if button_rect.collidepoint(event.pos):
                print("게임 시작!")

    # 배경 이미지 출력
    screen.blit(background, (0, 0))

    # 캐릭터 출력
    screen.blit(character, char_rect)

    # 타이틀 텍스트
    screen.blit(title_text, title_rect)

    # 버튼 (연한 초록 배경 + 파란 테두리 + 텍스트)
    pygame.draw.rect(screen, LIGHT_GREEN, button_rect, border_radius=10)
    pygame.draw.rect(screen, BLUE, button_rect, 3, border_radius=10)
    screen.blit(button_text, button_text_rect)

    pygame.display.flip()
