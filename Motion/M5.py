from PIL import Image, ImageDraw
import pygame

# --------------------------
# 경로 설정
# --------------------------
bg_path = "./background.png"  # 배경
char1_path = "./M5.png"        # 1p

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
vga_x0, vga_y0 = 960, 240
vga_x1, vga_y1 = 2560, 1440
draw.rectangle([vga_x0, vga_y0, vga_x1, vga_y1], fill=(0, 0, 0, 255))  # 불투명 검은색

# --------------------------
# 왼쪽 VGA 영역 (흰색 + 투명도)
# --------------------------
vga1_x0, vga1_y0 = 0, 240
vga1_x1, vga1_y1 = 960, 1440
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))  # 투명 캔버스
overlay_draw = ImageDraw.Draw(overlay)
overlay_draw.rectangle([vga1_x0, vga1_y0, vga1_x1, vga1_y1], fill=(255, 255, 255, 180))  

# 원본 bg 위에 합성
bg = Image.alpha_composite(bg, overlay)

# --------------------------
# 캐릭터 배치
# --------------------------
char1 = Image.open(char1_path).convert("RGBA").resize((550, 900))

bg.paste(char1, (200, 450), char1)             # 왼쪽

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
Score_font = pygame.font.SysFont("Arial", 150, bold=True)
Score_text = "Score : x"
Score_base = Score_font.render(Score_text, True, WHITE)
Score_rect = Score_base.get_rect(center=(W // 2, 120))

p1_font = pygame.font.SysFont("Arial", 150, bold=True)
p1_text = "Follow Motion"
p1_base = p1_font.render(p1_text, True, WHITE)
p1_rect = p1_base.get_rect(center=(470, H - 1100))

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
    draw_neon_text(screen, Score_font, "Score : x", WHITE, NEON_BLUE, Score_rect)
    draw_neon_text(screen, p1_font, "Follow Motion", WHITE, NEON_RED, p1_rect)

    pygame.display.flip()

pygame.quit()
