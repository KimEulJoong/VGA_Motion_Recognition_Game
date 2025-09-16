# utils/neon.py
import pygame

def draw_neon_text(surface, font, text, base_color, glow_color, rect, glow_layers=6, alpha=40):
    """네온 글로우 텍스트. rect는 반드시 font.size(text)로 만든 크기를 권장."""
    glow = font.render(text, True, glow_color).convert_alpha()
    glow.set_alpha(alpha)
    for i in range(1, glow_layers + 1):
        surface.blit(glow, rect.move( i, 0)); surface.blit(glow, rect.move(-i, 0))
        surface.blit(glow, rect.move(0,  i)); surface.blit(glow, rect.move(0, -i))
        surface.blit(glow, rect.move( i,  i)); surface.blit(glow, rect.move(-i, -i))
        surface.blit(glow, rect.move( i, -i)); surface.blit(glow, rect.move(-i,  i))
    base = font.render(text, True, base_color)
    surface.blit(base, rect)