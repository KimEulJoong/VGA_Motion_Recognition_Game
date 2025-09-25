
"""
Perfect.py — build the PERFECT overlay asset for Play.py

- Input image (default): perfect.png
- Output image (default): Perfect.png (capital P, to match Play.py)
- Target size (default): 1600x1200 (VGA_RECT in Play.py)
- Behavior: center-crop & scale the input to fill the target (object-fit: cover)

Usage
    python Perfect.py               # generates Perfect.png (1600x1200) from perfect.png
    python Perfect.py --w 1600 --h 1200 --img my_perfect.png --out Perfect.png
    python Perfect.py --preview     # quick preview in a pygame window

Import (optional, from Play.py or elsewhere)
    from Perfect import build_surface
    surf = build_surface(1600, 1200, "perfect.png")  # returns pygame.Surface with RGBA
"""

import argparse
from pathlib import Path

from PIL import Image
import pygame

def cover_resize(img: Image.Image, tw: int, th: int) -> Image.Image:
    """Scale to cover target size then center-crop."""
    sw, sh = img.size
    scale = max(tw / sw, th / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    img = img.resize((nw, nh), Image.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return img.crop((left, top, left + tw, top + th))

def build_surface(w: int = 1600, h: int = 1200, img_path: str = "perfect.png") -> pygame.Surface:
    """Return a pygame.Surface (RGBA) with the composed PERFECT overlay, no display needed."""
    path = Path(img_path)
    if not path.exists():
        raise FileNotFoundError(f"Input image not found: {path}")
    img = Image.open(path).convert("RGBA")
    img = cover_resize(img, w, h)
    mode = img.mode
    data = img.tobytes()
    return pygame.image.fromstring(data, (w, h), mode)

def save_png(out_path: str = "Perfect.png", w: int = 1600, h: int = 1200, img_path: str = "perfect.png") -> Path:
    surf = build_surface(w, h, img_path)
    # Save via pygame.image.save to preserve alpha (though not needed for full overlay)
    out = Path(out_path)
    pygame.image.save(surf, str(out))
    return out

def parse_args():
    p = argparse.ArgumentParser(description="Generate Perfect.png overlay from perfect.png")
    p.add_argument("--img", type=str, default="perfect.png", help="Input image path")
    p.add_argument("--out", type=str, default="Perfect.png", help="Output image path")
    p.add_argument("--w", type=int, default=1600, help="Width of output")
    p.add_argument("--h", type=int, default=1200, help="Height of output")
    p.add_argument("--preview", action="store_true", help="Show a preview window after saving")
    return p.parse_args()

def main():
    args = parse_args()
    pygame.init()  # needed for pygame.image.save/fromstring
    out = save_png(args.out, args.w, args.h, args.img)
    print(f"[Perfect] Saved: {out.resolve()} ({args.w}x{args.h})")
    if args.preview:
        screen = pygame.display.set_mode((args.w, args.h))
        pygame.display.set_caption("Perfect Preview")
        surf = build_surface(args.w, args.h, args.img)
        screen.blit(surf, (0, 0))
        pygame.display.flip()
        # Wait a short time or until any key
        import time
        t0 = time.time()
        running = True
        while running and time.time() - t0 < 3.0:
            for e in pygame.event.get():
                if e.type == pygame.QUIT or (e.type == pygame.KEYDOWN):
                    running = False
        pygame.quit()

if __name__ == "__main__":
    main()
