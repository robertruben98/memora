"""Genera el icono y splash de Memora desde Pillow.

Crea:
  - assets/icon/icon.png        (1024x1024, gradient violeta -> azul, "M" blanca)
  - assets/icon/icon_fg.png     (1024x1024 transparente con la "M" centrada,
                                 para el adaptive foreground en Android)
  - assets/icon/splash.png      (768x768 logo con fondo transparente para splash)
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT_DIR = Path(__file__).parent
SIZE = 1024
SPLASH_SIZE = 768


def gradient_bg(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    pix = img.load()
    # Gradient diagonal violeta (#7C5CFF) -> azul (#4F8AFF)
    a = (0x7C, 0x5C, 0xFF)
    b = (0x4F, 0x8A, 0xFF)
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            r = int(a[0] + (b[0] - a[0]) * t)
            g = int(a[1] + (b[1] - a[1]) * t)
            bl = int(a[2] + (b[2] - a[2]) * t)
            pix[x, y] = (r, g, bl)
    return img


def find_font(preferred_size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            return ImageFont.truetype(p, preferred_size)
    return ImageFont.load_default()


def draw_letter(img: Image.Image, letter: str, color=(255, 255, 255, 255)) -> None:
    size = img.size[0]
    font = find_font(int(size * 0.55))
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), letter, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]
    draw.text((x, y), letter, font=font, fill=color)


def round_corners(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (0, 0, img.size[0], img.size[1]), radius=radius, fill=255
    )
    out = img.copy().convert("RGBA")
    out.putalpha(mask)
    return out


def main() -> None:
    # icon.png — fondo + letra + esquinas redondeadas
    bg = gradient_bg(SIZE)
    rgba = bg.convert("RGBA")
    draw_letter(rgba, "M")
    icon = round_corners(rgba, radius=int(SIZE * 0.22))
    icon.save(OUT_DIR / "icon.png", "PNG")

    # icon_fg.png — solo la M sobre transparente para foreground adaptable
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_letter(fg, "M", color=(255, 255, 255, 255))
    fg.save(OUT_DIR / "icon_fg.png", "PNG")

    # splash.png — versión más pequeña y centrada para splash screen
    splash = Image.new("RGBA", (SPLASH_SIZE, SPLASH_SIZE), (0, 0, 0, 0))
    inner = round_corners(
        gradient_bg(SPLASH_SIZE).convert("RGBA"),
        radius=int(SPLASH_SIZE * 0.22),
    )
    draw_letter(inner, "M")
    splash.paste(inner, (0, 0), inner)
    splash.save(OUT_DIR / "splash.png", "PNG")

    print(f"Generated icons in {OUT_DIR}")


if __name__ == "__main__":
    main()
