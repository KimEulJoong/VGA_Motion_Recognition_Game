import pygame

def make_font_to_fit_rect(text: str,
                          rect: pygame.Rect,
                          font_name: str = "Arial",
                          bold: bool = True,
                          max_size: int = 180,
                          inner_pad: int = 14,
                          glow_layers: int = 6) -> pygame.font.Font:
    """
    rect 안에 네온 글로우까지 고려해 글자가 들어오도록 폰트 크기 자동 결정.
    - inner_pad: 게이지 배경과 같은 내부 패딩(좌우/상하)
    - glow_layers: draw_neon_text에서 번지는 픽셀 수(양쪽으로 i픽셀씩 번짐)
    """
    # 글로우가 네 방향으로 번지므로 여유를 빼고 사용 가능한 영역 계산
    avail_w = rect.width  - 2*inner_pad - 2*glow_layers
    avail_h = rect.height - 2*inner_pad - 2*glow_layers
    if avail_w <= 0 or avail_h <= 0:
        return pygame.font.SysFont(font_name, 8, bold=bold)

    lo, hi, best = 8, max_size, 8
    while lo <= hi:                        # 이진탐색으로 가장 큰 글자 크기 찾기
        mid  = (lo + hi) // 2
        font = pygame.font.SysFont(font_name, mid, bold=bold)
        tw, th = font.size(text)
        if tw <= avail_w and th <= avail_h:
            best = mid; lo = mid + 1
        else:
            hi = mid - 1
    return pygame.font.SysFont(font_name, best, bold=bold)

def _stroke_rect(surface, rect, color, width=6, radius=20):
    pygame.draw.rect(surface, color, rect, width, border_radius=radius)

def _glow_rect(surface, rect, color, radius=20, layers=3):
    # 네온 번짐: 반투명 레이어를 바깥쪽으로 깔기
    for i in range(1, layers+1):
        s = pygame.Surface((rect.width + i*8, rect.height + i*8), pygame.SRCALPHA)
        a = max(20, 80 - i*20)  # 점점 옅게
        pygame.draw.rect(s, (*color, a), s.get_rect(), width=8, border_radius=radius + i*3)
        surface.blit(s, (rect.x - 4*i, rect.y - 4*i))