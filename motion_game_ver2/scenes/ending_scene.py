# scenes/ending_scene.py
# scenes/ending_scene.py
from __future__ import annotations
import time
from pathlib import Path
from typing import Optional
import pygame
from PIL import Image

try:
    from utils.neon import draw_neon_text
except Exception:
    def draw_neon_text(surface, font, text, base_color, glow_color, rect, glow_layers=6):
        base = font.render(text, True, base_color)
        surface.blit(base, rect)

WHITE      = (255, 255, 255)
NEON_BLUE  = (100, 150, 255)
NEON_YEL   = (255, 220, 120)
NEON_GREEN = (0, 255, 0)

class EndingScene:
    """곡별 엔딩 + 이름 입력 + 점수 표시"""
    def __init__(self, W:int, H:int, *, assets_dir:Path, song:str, score:int,
                 show_seconds:float=6.0, name_maxlen:int=10):
        self.W, self.H = W, H
        self.assets_dir = Path(assets_dir)
        self.song = (song or "").upper()
        if self.song == "SODAPOP":
            self.song = "SODA"
        self.score = int(score)
        self.show_seconds = show_seconds

        # 폰트
        self.title_font = pygame.font.SysFont("Arial", 180, bold=True)
        self.score_font = pygame.font.SysFont("Arial", 140, bold=True)
        self.input_font = pygame.font.SysFont("Arial", 100, bold=True)

        # 배경 합성용
        self.surface: Optional[pygame.Surface] = None

        # 시간
        self.t0 = time.monotonic()
        self._done = False

        # 유저 이름 입력
        self.player_name = ""
        self.name_maxlen = name_maxlen

    def enter(self):
        self.surface = self._build_composited_surface()
        self.t0 = time.monotonic()

    def exit(self): 
        pass

    def handle_event(self, e, now=None):
        if e.type == pygame.KEYDOWN:
            if e.key in (pygame.K_RETURN, pygame.K_SPACE):
                if not self.player_name:
                    self.player_name = "PLAYER"
                self._done = True
            elif e.key == pygame.K_BACKSPACE:
                self.player_name = self.player_name[:-1]
            else:
                ch = e.unicode
                if ch.isalnum() and len(self.player_name) < self.name_maxlen:
                    self.player_name += ch
        elif e.type == pygame.QUIT:
            self._done = True

    def update(self, dt, now):
        if (now - self.t0) >= self.show_seconds:
            if not self.player_name:
                self.player_name = "PLAYER"
            self._done = True

    def draw(self, screen: "pygame.Surface"):
        # 배경 + 캐릭터
        if self.surface:
            screen.blit(self.surface, (0, 0))

        # 타이틀
        title_rect = self.title_font.render("Ending", True, WHITE).get_rect(midtop=(self.W//2, 24))
        draw_neon_text(screen, self.title_font, "Ending", WHITE, NEON_BLUE, title_rect)

        # 점수
        score_text = f"Score : {self.score}"
        score_rect = self.score_font.render(score_text, True, WHITE).get_rect(midtop=(self.W//2, 230))
        draw_neon_text(screen, self.score_font, score_text, WHITE, NEON_YEL, score_rect)

        # 이름 입력
        name_display = self.player_name or "_"
        name_rect = self.input_font.render(name_display, True, WHITE).get_rect(midtop=(self.W//2, 400))
        draw_neon_text(screen, self.input_font, name_display, WHITE, NEON_GREEN, name_rect)

    def _build_composited_surface(self) -> pygame.Surface:
        W, H = self.W, self.H
        bg = Image.open(self.assets_dir / "background.png").convert("RGBA").resize((W, H))

        if self.song == "GOLDEN":
            def _load(name, size):
                p = self.assets_dir / f"golden_ending_{name}.png"
                return Image.open(p).convert("RGBA").resize(size)
            c1 = _load("1", (800, 1000))
            c2 = _load("2", (800, 1000))
            c3 = _load("3", (800, 1000))
            bg.paste(c1, (100, 400), c1)
            bg.paste(c2, (W - 850, 350), c2)
            bg.paste(c3, (1250, 500), c3)
        else:  # SODA
            def _load(name, size):
                p = self.assets_dir / f"sodapop_ending_{name}.png"
                return Image.open(p).convert("RGBA").resize(size)
            c1 = _load("1", (800, 1000))
            c2 = _load("2", (800, 1000))
            c4 = _load("4", (500, 600))
            c3 = _load("3", (500, 500))
            c5 = _load("5", (600, 800))
            bg.paste(c1, (50, 400), c1)
            bg.paste(c2, (W - 850, 350), c2)
            bg.paste(c4, (450, 900), c4)
            bg.paste(c3, (1820, 950), c3)
            bg.paste(c5, (1300, 720), c5)

        return pygame.image.fromstring(bg.tobytes(), bg.size, bg.mode)

    def done(self) -> bool:
        return self._done

    def get_result(self):
        return {"name": self.player_name, "score": self.score}
