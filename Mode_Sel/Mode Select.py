from PIL import Image, ImageDraw
import pygame

# --------------------------
# 경로 설정
# --------------------------
bg_path = "./background.png"  # 배경
char1_path = "./1p.png"        # 1p
char2_path = "./2p.png"        # 2p

# 색상
WHITE = (255, 255, 255)
NEON_BLUE = (100, 150, 255)   # "Motion Game" 네온 효과 색상
NEON_RED = (255, 80, 80)      # 1P, 2P 네온 효과 색상

# --------------------------
# 캔버스 생성 (2560x1440)
# --------------------------
W, H = 2560, 1440
bg = Image.open(bg_path).convert("RGBA").resize((W, H))

draw = ImageDraw.Draw(bg)

# --------------------------
# 중앙 VGA 영역 (검은색)
# --------------------------
#vga_x0, vga_y0 = 530, 315
#vga_x1, vga_y1 = 2030, 1440
vga_x0, vga_y0 = 530, 200
vga_x1, vga_y1 = 2030, 1325
draw.rectangle([vga_x0, vga_y0, vga_x1, vga_y1], fill="black")

# --------------------------
# 캐릭터 배치
# --------------------------
char1 = Image.open(char1_path).convert("RGBA").resize((550, 900))
char2 = Image.open(char2_path).convert("RGBA").resize((500, 900))

bg.paste(char1, (0, 450), char1)             # 왼쪽
bg.paste(char2, (W - 500, 450), char2)        # 오른쪽

# --------------------------
# pygame 초기화
# --------------------------
pygame.init()
screen = pygame.display.set_mode((W, H))
pygame.display.set_caption("Motion Game Intro")

# PIL → pygame 변환
mode = bg.mode
size = bg.size
data = bg.tobytes()
surface = pygame.image.fromstring(data, size, mode)

# --------------------------
# 네온 텍스트 함수
# --------------------------
def draw_neon_text(surface, font, text, base_color, glow_color, rect, glow_layers=6):
    for i in range(1, glow_layers+1):
        glow = font.render(text, True, glow_color)
        glow.set_alpha(40)
        surface.blit(glow, rect.move(i, 0))
        surface.blit(glow, rect.move(-i, 0))
        surface.blit(glow, rect.move(0, i))
        surface.blit(glow, rect.move(0, -i))
        surface.blit(glow, rect.move(i, i))
        surface.blit(glow, rect.move(-i, -i))
        surface.blit(glow, rect.move(i, -i))
        surface.blit(glow, rect.move(-i, i))

    base = font.render(text, True, base_color)
    surface.blit(base, rect)

# --------------------------
# 폰트 & 텍스트 위치
# --------------------------
title_font = pygame.font.SysFont("Arial", 180, bold=True)
title_text = "Mode Select"
title_base = title_font.render(title_text, True, WHITE)
title_rect = title_base.get_rect(center=(W // 2, 100))

p1_font = pygame.font.SysFont("Arial", 150, bold=True)
p1_text = "1p"
p1_base = p1_font.render(p1_text, True, WHITE)
p1_rect = p1_base.get_rect(center=(280, H - 1050))

p2_font = pygame.font.SysFont("Arial", 150, bold=True)
p2_text = "1p"
p2_base = p2_font.render(p2_text, True, WHITE)
p2_rect = p2_base.get_rect(center=(2320, H - 1050))

# --------------------------
# 메인 루프
# --------------------------
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False

    screen.blit(surface, (0, 0))

    # 네온 텍스트 출력
    draw_neon_text(screen, title_font, "Mode Select", WHITE, NEON_BLUE, title_rect)
    draw_neon_text(screen, p1_font, "1P", WHITE, NEON_RED, p1_rect)
    draw_neon_text(screen, p2_font, "2P", WHITE, NEON_RED, p2_rect)

    pygame.display.flip()

pygame.quit()

