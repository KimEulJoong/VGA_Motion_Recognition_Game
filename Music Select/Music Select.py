from PIL import Image, ImageDraw
import pygame

# --------------------------
# 경로 설정
# --------------------------
bg_path = "./background.png"  # 배경
char1_path = "./golden.png"        #
char2_path = "./soda_pop.png"       
char3_path = "./ques.png"        

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
# 반투명 네모
# --------------------------
vga1_x0, vga1_y0 = 0, 240
vga1_x1, vga1_y1 = 960, 1440
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
overlay_draw = ImageDraw.Draw(overlay)
# char3 (왼쪽 하단 물음표)의 위치 (0, 900) ~ (530, 1400)
overlay_draw.rectangle([0, 930, 530, 1340], fill=(255, 255, 255, 180))
# char4 (오른쪽 하단 물음표)의 위치 (W - 530, 900) ~ (W, 1400)
overlay_draw.rectangle([W - 530, 930, W, 1340], fill=(255, 255, 255, 180))
# 원본과 합성
bg = Image.alpha_composite(bg, overlay)

# --------------------------
# 캐릭터 배치
# --------------------------
char1 = Image.open(char1_path).convert("RGBA").resize((530, 500))
char2 = Image.open(char2_path).convert("RGBA").resize((530, 500))
char3 = Image.open(char3_path).convert("RGBA").resize((530, 500))
char4 = Image.open(char3_path).convert("RGBA").resize((530, 500))

bg.paste(char1, (0, 300), char1)             # 왼쪽
bg.paste(char2, (W - 530, 300), char2)        # 오른쪽
bg.paste(char3, (0, 910), char3)             # 왼쪽
bg.paste(char4, (W - 530, 910), char4)        # 오른쪽

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
title_text = "Music Select"
title_base = title_font.render(title_text, True, WHITE)
title_rect = title_base.get_rect(center=(W // 2, 100))

p1_font = pygame.font.SysFont("Arial", 110, bold=True)
p1_text = "Golden"
p1_base = p1_font.render(p1_text, True, WHITE)
p1_rect = p1_base.get_rect(center=(260, H - 1200))

p2_font = pygame.font.SysFont("Arial", 110, bold=True)
p2_text = "Soda Pop"
p2_base = p2_font.render(p2_text, True, WHITE)
p2_rect = p2_base.get_rect(center=(2300, H - 1200))

p3_font = pygame.font.SysFont("Arial", 100, bold=True)
p3_text = "coming Soon"
p3_base = p1_font.render(p1_text, True, WHITE)
p3_rect = p1_base.get_rect(center=(150, H - 570))

p4_font = pygame.font.SysFont("Arial", 100, bold=True)
p4_text = "coming Soon"
p4_base = p1_font.render(p1_text, True, WHITE)
p4_rect = p1_base.get_rect(center=(2180, H - 570))

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
    draw_neon_text(screen, title_font, "Music Select", WHITE, NEON_BLUE, title_rect)
    draw_neon_text(screen, p1_font, "Golden", WHITE, NEON_RED, p1_rect)
    draw_neon_text(screen, p2_font, "Soda Pop", WHITE, NEON_RED, p2_rect)
    draw_neon_text(screen, p3_font, "Coming Soon", WHITE, NEON_RED, p3_rect)
    draw_neon_text(screen, p4_font, "Coming Soon", WHITE, NEON_RED, p4_rect)

    pygame.display.flip()

pygame.quit()
