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


def japanese_font(size, weight="regular"):
    # AppleSDGothicNeo.ttc is a Korean system font — it only covers kanji
    # that overlap Unicode's Han-unification subset with Hanja, so common
    # Japanese-only characters (々, 学, 静, 禅, 桜, 暦, confirmed missing by
    # rendering a comparison strip) came out as tofu boxes. Hiragino Kaku
    # Gothic ProN is the actual Japanese system UI font and covers all of
    # them; it ships as separate per-weight files rather than one indexed
    # .ttc, so weight selects the file, not an index.
    paths = {
        "regular": "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
        "bold": "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
    }
    try:
        return ImageFont.truetype(paths[weight], size=size, index=0)
    except Exception:
        return font(size, "bold" if weight == "bold" else "regular")


FONT_LABEL = font(28, "bold")
FONT_SMALL = font(20)
FONT_TITLE = font(56, "bold")
FONT_JP_TITLE = japanese_font(42, "bold")
FONT_JP_LABEL = japanese_font(26, "bold")
FONT_JP_BODY = japanese_font(22)


def open_image(name):
    return Image.open(IMAGES / name).convert("RGBA")


def branded_window(image, title="Hibimekuri"):
    branded = image.copy()
    draw = ImageDraw.Draw(branded)
    x = 118
    y = 12
    draw.rounded_rectangle(
        (90, y - 4, 430, y + 28),
        radius=5,
        fill=(255, 255, 252, 246),
    )
    draw.text((x, y), title, fill=INK, font=font(16, "bold"))
    return branded


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


def bilingual_heading(draw, xy, japanese, english):
    x, y = xy
    draw.text((x, y), japanese, fill=INK, font=FONT_JP_TITLE)
    draw.text((x, y + 52), english, fill=INK, font=FONT_TITLE)


def bilingual_copy(draw, xy, japanese, english):
    x, y = xy
    draw.multiline_text((x, y), japanese, fill=MUTED, font=FONT_JP_BODY, spacing=7)
    japanese_height = draw.multiline_textbbox((x, y), japanese, font=FONT_JP_BODY, spacing=7)[3] - y
    draw.multiline_text((x, y + japanese_height + 10), english, fill=MUTED, font=FONT_SMALL, spacing=7)


def save(img, name):
    out = IMAGES / name
    img.convert("RGB").save(out, quality=96, optimize=True)
    print(out)


def hero():
    base = Image.new("RGBA", (1600, 1060), BG + (255,))
    draw = ImageDraw.Draw(base)
    draw.text((112, 128), "Hibimekuri", fill=INK, font=FONT_TITLE)
    draw.text((116, 196), "日々めくり", fill=MUTED, font=FONT_JP_LABEL)
    draw.text((116, 238), "ページをめくる。今日を残す。", fill=INK, font=FONT_JP_BODY)
    draw.text((118, 276), "Turn the page. Keep the day.", fill=MUTED, font=FONT_SMALL)
    draw.line((116, 330, 292, 330), fill=HAIRLINE, width=2)
    draw.multiline_text(
        (116, 366),
        "一日一枚。\n今日を終えたら、\nそっとめくる。",
        fill=INK,
        font=FONT_JP_LABEL,
        spacing=12,
    )
    draw.multiline_text(
        (118, 500),
        "One page per day.\nTear it off when\nthe day is done.",
        fill=MUTED,
        font=FONT_SMALL,
        spacing=10,
    )
    draw.multiline_text(
        (118, 620),
        "ローカル保存。静かに、\n毎日の小さな儀式として。",
        fill=MUTED,
        font=FONT_JP_BODY,
        spacing=8,
    )
    draw.multiline_text(
        (118, 682),
        "Local-first, quiet, and built\naround a small ritual.",
        fill=MUTED,
        font=FONT_SMALL,
        spacing=8,
    )

    app = fit(branded_window(open_image("screenshot-extended.png")), width=960)
    paste_shadowed(base, app, (520, 160), radius=30, shadow=30, offset=(0, 12))
    save(base, "readme-hero.png")


def daily_page():
    base = Image.new("RGBA", (1600, 920), BG + (255,))
    draw = ImageDraw.Draw(base)
    bilingual_heading(draw, (105, 66), "今日の一枚", "The Daily Page")
    bilingual_copy(
        draw,
        (108, 178),
        "日付、暦、文学、メモ、そして日を終えるためのめくり。",
        "Date, almanac, literature, notes, and the tear-off ritual in one calm surface.",
    )

    ext = branded_window(open_image("screenshot-extended.png"))
    left = crop(ext, (0, 50, 560, 955))
    left = fit(left, height=660)
    paste_shadowed(base, left, (110, 250), radius=24, shadow=28, offset=(0, 12))

    notes = [
        ("暦", "KOYOMI", "干支、六曜、旧暦、\n月相と年号。", "Kanshi, rokuyo, lunar date,\nmoon phase, and era year."),
        ("文学", "LITERATURE", "短い日本語の一節に、\n静かな英訳を添えて。", "A short line of Japanese text\nwith a quiet English reading."),
        ("めくる", "TEAR-OFF", "今日を閉じて、\n明日を静かに開く。", "Close today with one deliberate\naction, then reveal tomorrow."),
    ]
    for index, (japanese, english, japanese_body, english_body) in enumerate(notes):
        y = 270 + index * 180
        draw.text((820, y), japanese, fill=INK, font=FONT_JP_LABEL)
        draw.text((820, y + 36), english, fill=MUTED, font=FONT_LABEL)
        draw.line((820, y + 78, 1040, y + 78), fill=HAIRLINE, width=2)
        draw.multiline_text((820, y + 96), japanese_body, fill=INK, font=FONT_JP_BODY, spacing=6)
        draw.multiline_text((820, y + 148), english_body, fill=MUTED, font=FONT_SMALL, spacing=6)
    save(base, "readme-daily-page.png")


def tasks_settings():
    base = Image.new("RGBA", (1600, 920), BG + (255,))
    draw = ImageDraw.Draw(base)
    bilingual_heading(draw, (105, 66), "タスクは日々とともに", "Tasks Stay With You")
    bilingual_copy(
        draw,
        (108, 178),
        "先送り、復元、書き出し。データは手元のJSONに。",
        "Carry work forward, defer it, restore deletions, and keep the data in plain files.",
    )

    ext = branded_window(open_image("screenshot-extended.png"))
    tasks = crop(ext, (590, 105, 1370, 935))
    tasks = fit(tasks, width=780)
    paste_shadowed(base, tasks, (100, 255), radius=24, shadow=26, offset=(0, 12))

    settings = branded_window(open_image("screenshot-settings.png"), "Hibimekuri Settings")
    settings = fit(settings, width=470)
    paste_shadowed(base, settings, (1000, 250), radius=28, shadow=26, offset=(0, 12))

    draw.rounded_rectangle((1005, 724, 1470, 880), radius=16, fill=PAPER, outline=HAIRLINE, width=1)
    draw.text((1034, 744), "entries.json", fill=INK, font=FONT_SMALL)
    draw.text((1218, 744), "tasks.json", fill=INK, font=FONT_SMALL)
    # Split across two lines and the box heightened accordingly — one line
    # of this Japanese copy at FONT_JP_BODY runs wider than the box's
    # ~410px usable width (only looked fine while japanese_font() was
    # silently substituting narrower tofu-box glyphs for the missing kanji).
    draw.multiline_text(
        (1034, 778),
        "いつでも書き出し。\nアカウントもサーバーも不要。",
        fill=MUTED,
        font=FONT_JP_BODY,
        spacing=6,
    )
    draw.text((1034, 850), "Export anytime. No account, no backend.", fill=MUTED, font=FONT_SMALL)
    save(base, "readme-tasks-data.png")


def themes():
    base = Image.new("RGBA", (1600, 900), BG + (255,))
    draw = ImageDraw.Draw(base)
    bilingual_heading(draw, (105, 66), "六つの紙の表情", "Six Paper Moods")
    bilingual_copy(
        draw,
        (108, 178),
        "紙色、墨色、差し色、挿絵まで静かに変わるテーマ。",
        "Minimal themes, each with its own paper color, ink, accent, and illustration.",
    )

    sakura = fit(branded_window(open_image("screenshot-sakura.png")), width=920)
    paste_shadowed(base, sakura, (100, 250), radius=28, shadow=26, offset=(0, 12))

    settings = crop(branded_window(open_image("screenshot-settings.png"), "Hibimekuri Settings"), (18, 215, 606, 372))
    settings = fit(settings, width=390)
    paste_shadowed(base, settings, (1110, 275), radius=18, shadow=20, offset=(0, 10))

    swatches = [
        ("Classic", "クラシック", (244, 244, 241), (43, 43, 40)),
        ("Matcha", "抹茶", (239, 237, 219), (47, 89, 55)),
        ("Washi", "和紙", (239, 228, 209), (150, 105, 41)),
        ("Sumi", "墨", (250, 250, 248), (0, 0, 0)),
        ("Zen", "禅", (226, 230, 224), (72, 86, 76)),
        ("Sakura", "桜", (250, 237, 237), ACCENT),
    ]
    x0, y0 = 1110, 520
    for i, (name, japanese, color, dot) in enumerate(swatches):
        x = x0 + (i % 2) * 205
        y = y0 + (i // 2) * 92
        draw.rounded_rectangle((x, y, x + 170, y + 58), radius=12, fill=color, outline=HAIRLINE, width=1)
        draw.ellipse((x + 20, y + 18, x + 42, y + 40), fill=dot)
        draw.text((x, y + 66), japanese, fill=MUTED, font=FONT_JP_BODY)
        # Offset by the Japanese label's actual measured width, not a fixed
        # 44px — a fixed gap only worked while japanese_font() was silently
        # substituting narrower tofu-box glyphs for missing kanji; label
        # lengths vary a lot here (墨 vs. クラシック).
        japanese_width = draw.textlength(japanese, font=FONT_JP_BODY)
        draw.text((x + japanese_width + 8, y + 68), name, fill=MUTED, font=font(16))
    save(base, "readme-themes.png")


def main():
    hero()
    daily_page()
    tasks_settings()
    themes()


if __name__ == "__main__":
    main()
