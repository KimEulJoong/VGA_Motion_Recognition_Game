# music.py
from __future__ import annotations
from pathlib import Path
import pygame

AUDIO_EXTS = (".mp3", ".ogg", ".wav")

def _find_audio_any(stem_path: Path) -> Path | None:
    # stem_path: 확장자 제외 경로 (예: assets/music/Golden)
    for ext in AUDIO_EXTS:
        p = stem_path.with_suffix(ext)
        if p.exists():
            return p
    # 대소문자 섞여 있을 수 있으니 폴더를 스캔해 스템명으로 매칭
    folder = stem_path.parent
    stem_lower = stem_path.name.lower()
    if folder.exists():
        for f in folder.iterdir():
            if f.suffix.lower() in AUDIO_EXTS and f.stem.lower() == stem_lower:
                return f
    return None

class SoundManager:
    def __init__(self, assets_dir: Path, volume: float = 0.65):
        self.assets = Path(assets_dir)
        self.current_key = None
        self._vol = volume
        pygame.mixer.get_init() or pygame.mixer.pre_init(44100, -16, 2, 512)
        pygame.mixer.init()

        # 메뉴 BGM
        self.menu_bgm = _find_audio_any(self.assets / "music" / "Out_of_Flux")

    def _play(self, path: Path | None, loop=-1, fade_ms=600, vol=None):
        if path is None: 
            print("[AUDIO] file not found"); return
        if vol is None: vol = self._vol
        if self.current_key == str(path) and pygame.mixer.music.get_busy():
            return
        pygame.mixer.music.fadeout(250)
        pygame.mixer.music.load(str(path))
        pygame.mixer.music.set_volume(vol)
        pygame.mixer.music.play(loops=loop, fade_ms=fade_ms)
        self.current_key = str(path)

    # ----- 공개 API -----
    def play_menu(self): self._play(self.menu_bgm, loop=-1, fade_ms=600, vol=0.55)
    def pause(self): pygame.mixer.music.pause()
    def resume(self): pygame.mixer.music.unpause()
    def fadeout(self, ms=600): pygame.mixer.music.fadeout(ms); self.current_key=None
    def stop(self): pygame.mixer.music.stop(); self.current_key=None

    def play_title(self, title: str, loop: int = 0, fade_ms: int = 350, vol: float | None = 0.75):
        """
        assets/music/<title>.(ogg|mp3|wav) 를 찾아 재생.
        대소문자/확장자 자동 탐색.
        """
        path = _find_audio_any(self.assets / "music" / title)
        self._play(path, loop=loop, fade_ms=fade_ms, vol=vol if vol is not None else self._vol)

    def get_bgm_volume(self) -> float:
        return pygame.mixer.music.get_volume()

    def set_bgm_volume(self, v: float):
        v = max(0.0, min(1.0, float(v)))
        self._vol = v
        pygame.mixer.music.set_volume(v)

    # ← play_menu가 고정 0.55라면, 인자로도 바꿀 수 있게 수정 추천
    def play_menu(self, vol: float | None = None):
        self._play(self.menu_bgm, loop=-1, fade_ms=600, vol=(0.55 if vol is None else vol))