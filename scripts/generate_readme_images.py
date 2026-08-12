#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "docs" / "images"

BG = (246, 243, 237)
PAPER = (255, 255, 252)
INK = (42, 42, 39)
MUTED = (126, 125, 118)
HAIRLINE = (210, 205, 196)
ACCENT = (196, 89, 124)


def font(size, weight="regular"):
    candidates = {
        "regular": [
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/SFNS.ttf",
        ],
        "bold": [
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/SFNS.ttf",
        ],
        "serif": [
            "/System/Library/Fonts/NewYork.ttf",
            "/System/Library/Fonts/Times.ttc",
        ],
    }[weight]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size, index=1 if weight == "bold" else 0)
        except Exception:
            pass
    return ImageFont.load_default(size=size)


FONT_LABEL = font(28, "bold")
FONT_SMALL = font(20)
FONT_TITLE = font(56, "bold")
FONT_JP = font(32, "bold")


def open_image(name):
    return Image.open(IMAGES / name).convert("RGBA")


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def paste_shadowed(base, image, xy, radius=28, shadow=30, offset=(0, 12), border=True):
    x, y = xy
    mask = rounded_mask(image.size, radius)
    shadow_layer = Image.new("RGBA", image.size, (0, 0, 0, 34))
    alpha = mask.filter(ImageFilter.GaussianBlur(shadow))
    shadow_layer.putalpha(alpha.point(lambda value: min(value, 46)))
    base.alpha_composite(shadow_layer, (x + offset[0], y + offset[1]))
    clipped = Image.new("RGBA", image.size, (0, 0, 0, 0))
    clipped.alpha_composite(image)
    clipped.putalpha(mask)
    base.alpha_composite(clipped, (x, y))
    if border:
        draw = ImageDraw.Draw(base)
        draw.rounded_rectangle((x, y, x + image.width - 1, y + image.height - 1), radius=radius, outline=(216, 211, 202), width=1)


def fit(image, width=None, height=None):
    w, h = image.size
    if width is None:
        scale = height / h
    else:
        scale = width / w
    return image.resize((round(w * scale), round(h * scale)), Image.Resampling.LANCZOS)


def crop(image, box):
    return image.crop(box)


def label(draw, xy, title, body=None):
    x, y = xy
    draw.text((x, y), title.upper(), fill=MUTED, font=FONT_LABEL)
    draw.line((x, y + 44, x + 160, y + 44), fill=HAIRLINE, width=2)
    if body:
        draw.multiline_text((x, y + 70), body, fill=INK, font=FONT_SMALL, spacing=8)


def save(img, name):
    out = IMAGES / name
    img.convert("RGB").save(out, quality=96, optimize=True)
    print(out)


def hero():
    base = Image.new("RGBA", (1600, 1060), BG + (255,))
    draw = ImageDraw.Draw(base)
    draw.text((112, 128), "TearOffDiary", fill=INK, font=FONT_TITLE)
    draw.text((116, 198), "Himekuri journal for macOS", fill=MUTED, font=FONT_SMALL)
    draw.line((116, 260, 292, 260), fill=HAIRLINE, width=2)
    draw.multiline_text(
        (116, 300),
        "One page per day.\nTear it off when\nthe day is done.",
        fill=INK,
        font=FONT_JP,
        spacing=12,
    )
    draw.multiline_text(
        (118, 462),
        "Local-first,\nquiet, and built\naround a small\nritual.",
        fill=MUTED,
        font=FONT_SMALL,
        spacing=10,
    )

    app = fit(open_image("screenshot-extended.png"), width=960)
    paste_shadowed(base, app, (520, 160), radius=30, shadow=30, offset=(0, 12))
    save(base, "readme-hero.png")


def daily_page():
    base = Image.new("RGBA", (1600, 920), BG + (255,))
    draw = ImageDraw.Draw(base)
    draw.text((105, 86), "The Daily Page", fill=INK, font=FONT_TITLE)
    draw.text((108, 154), "Date, almanac, literature, notes, and the tear-off ritual in one calm surface.", fill=MUTED, font=FONT_SMALL)

    ext = open_image("screenshot-extended.png")
    left = crop(ext, (0, 50, 560, 955))
    left = fit(left, height=660)
    paste_shadowed(base, left, (110, 220), radius=24, shadow=28, offset=(0, 12))

    notes = [
        ("KOYOMI", "Kanshi, rokuyo, lunar date,\nmoon phase, and era year."),
        ("LITERATURE", "A short line of Japanese text\nwith a quiet English reading."),
        ("TEAR-OFF", "Close today with one deliberate\naction, then reveal tomorrow."),
    ]
    for index, (title, body) in enumerate(notes):
        y = 270 + index * 180
        draw.text((820, y), title, fill=MUTED, font=FONT_LABEL)
        draw.line((820, y + 48, 1040, y + 48), fill=HAIRLINE, width=2)
        draw.multiline_text((820, y + 76), body, fill=INK, font=FONT_SMALL, spacing=8)
    save(base, "readme-daily-page.png")


def tasks_settings():
    base = Image.new("RGBA", (1600, 920), BG + (255,))
    draw = ImageDraw.Draw(base)
    draw.text((105, 86), "Tasks Stay With You", fill=INK, font=FONT_TITLE)
    draw.text((108, 154), "Carry work forward, defer it, restore deletions, and keep the data in plain files.", fill=MUTED, font=FONT_SMALL)

    ext = open_image("screenshot-extended.png")
    tasks = crop(ext, (590, 105, 1370, 935))
    tasks = fit(tasks, width=780)
    paste_shadowed(base, tasks, (100, 230), radius=24, shadow=26, offset=(0, 12))

    settings = open_image("screenshot-settings.png")
    settings = fit(settings, width=470)
    paste_shadowed(base, settings, (1000, 210), radius=28, shadow=26, offset=(0, 12))

    draw.rounded_rectangle((1005, 746, 1470, 830), radius=16, fill=PAPER, outline=HAIRLINE, width=1)
    draw.text((1034, 768), "entries.json", fill=INK, font=FONT_SMALL)
    draw.text((1218, 768), "tasks.json", fill=INK, font=FONT_SMALL)
    draw.text((1034, 800), "Export anytime. No account, no backend.", fill=MUTED, font=FONT_SMALL)
    save(base, "readme-tasks-data.png")


def themes():
    base = Image.new("RGBA", (1600, 900), BG + (255,))
    draw = ImageDraw.Draw(base)
    draw.text((105, 86), "Six Paper Moods", fill=INK, font=FONT_TITLE)
    draw.text((108, 154), "Minimal themes, each with its own paper color, ink, accent, and illustration.", fill=MUTED, font=FONT_SMALL)

    sakura = fit(open_image("screenshot-sakura.png"), width=920)
    paste_shadowed(base, sakura, (100, 230), radius=28, shadow=26, offset=(0, 12))

    settings = crop(open_image("screenshot-settings.png"), (18, 215, 606, 372))
    settings = fit(settings, width=390)
    paste_shadowed(base, settings, (1110, 255), radius=18, shadow=20, offset=(0, 10))

    swatches = [
        ("Classic", (244, 244, 241), (43, 43, 40)),
        ("Matcha", (239, 237, 219), (47, 89, 55)),
        ("Washi", (239, 228, 209), (150, 105, 41)),
        ("Sumi", (250, 250, 248), (0, 0, 0)),
        ("Zen", (226, 230, 224), (72, 86, 76)),
        ("Sakura", (250, 237, 237), ACCENT),
    ]
    x0, y0 = 1110, 520
    for i, (name, color, dot) in enumerate(swatches):
        x = x0 + (i % 2) * 205
        y = y0 + (i // 2) * 92
        draw.rounded_rectangle((x, y, x + 170, y + 58), radius=12, fill=color, outline=HAIRLINE, width=1)
        draw.ellipse((x + 20, y + 18, x + 42, y + 40), fill=dot)
        draw.text((x, y + 66), name, fill=MUTED, font=FONT_SMALL)
    save(base, "readme-themes.png")


def main():
    hero()
    daily_page()
    tasks_settings()
    themes()


if __name__ == "__main__":
    main()
