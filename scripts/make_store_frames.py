# -*- coding: utf-8 -*-
"""把原始模拟器截图合成为 App Store 成品图（带标题排版）。

用法：
    python scripts/make_store_frames.py

输入：docs/app-store/raw/{today,workout,report,phase,history}.png
输出：docs/app-store/final/*.png（1290×2796，6.7" 规格）

缺少原图时会生成占位图，方便先确认排版，不会冒充真实截图。
依赖：Pillow
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, "docs", "app-store", "raw")
OUT_DIR = os.path.join(ROOT, "docs", "app-store", "final")

CANVAS_W, CANVAS_H = 1290, 2796
INK = (28, 28, 30)
PAPER = (250, 248, 243)
ACCENT = (232, 89, 12)
GREY = (150, 146, 138)

MARGIN = 90
HEADLINE_SIZE = 92
SUB_SIZE = 44
SHOT_TOP_MIN = 640
BRAND_HEIGHT = 200

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\msyhbd.ttc",
    r"C:\Windows\Fonts\msyh.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
]

SLIDES = [
    ("today", "今天练什么\n打开就知道", "不用翻备忘录，也不用临场想动作"),
    ("workout", "组间休息自动计时", "锁屏和灵动岛上都能看到进度"),
    ("report", "容量、PR、完成率", "一张图讲完这周练得怎么样"),
    ("phase", "减脂期，别掉肌肉", "力量保持率，只有练账算得出来"),
    ("history", "每一次训练都在账上", "数据只存在本机，换机可导出恢复"),
]


def font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255
    )
    return mask


def placeholder(index):
    image = Image.new("RGB", (1290, 2796), PAPER)
    draw = ImageDraw.Draw(image)
    draw.text((70, 90), "占位截图", font=font(72), fill=(196, 192, 184))
    draw.text((70, 200), "运行 scripts/screenshots.sh 生成真实图", font=font(38), fill=(206, 202, 194))
    draw.rounded_rectangle([70, 300, 1220, 2700], radius=44, outline=(224, 220, 212), width=4)
    return image


def load_screenshot(name, index):
    path = os.path.join(RAW_DIR, f"{name}.png")
    if os.path.exists(path):
        return Image.open(path).convert("RGB"), True
    return placeholder(index), False


def compose(name, headline, subline, index, is_real):
    canvas = Image.new("RGB", (CANVAS_W, CANVAS_H), INK)
    draw = ImageDraw.Draw(canvas)

    # 标题块：先量高度，再放副标题，避免压字
    headline_font = font(HEADLINE_SIZE)
    head_y = 150
    bbox = draw.multiline_textbbox(
        (MARGIN, head_y), headline, font=headline_font, spacing=22
    )
    draw.multiline_text((MARGIN, head_y), headline, font=headline_font, fill=(255, 255, 255), spacing=22)
    head_bottom = bbox[3]

    sub_y = head_bottom + 34
    draw.text((MARGIN + 2, sub_y), subline, font=font(SUB_SIZE), fill=GREY)
    sub_bottom = draw.textbbox((MARGIN, sub_y), subline, font=font(SUB_SIZE))[3]

    # 截图区：按可用高度等比缩放，确保不越界
    area_top = max(SHOT_TOP_MIN, sub_bottom + 90)
    area_bottom = CANVAS_H - BRAND_HEIGHT
    area_h = area_bottom - area_top

    shot, _ = load_screenshot(name, index)
    scale = min((CANVAS_W - 2 * MARGIN) / shot.width, area_h / shot.height)
    shot_w = int(shot.width * scale)
    shot_h = int(shot.height * scale)
    shot = shot.resize((shot_w, shot_h), Image.LANCZOS)

    radius = 54
    mask = rounded_mask((shot_w, shot_h), radius)
    x = (CANVAS_W - shot_w) // 2
    y = area_top

    shadow = Image.new("RGBA", (shot_w + 140, shot_h + 140), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [70, 70, 70 + shot_w, 70 + shot_h], radius=radius, fill=(0, 0, 0, 170)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(38))
    canvas.paste(shadow, (x - 70, y - 20), shadow)

    canvas.paste(shot, (x, y), mask)

    # 底部品牌
    brand_y = CANVAS_H - BRAND_HEIGHT + 40
    draw.text((MARGIN, brand_y), "练账", font=font(54), fill=ACCENT)
    draw.text((MARGIN + 132, brand_y + 12), "· 力量训练记录与决策", font=font(38), fill=GREY)

    if not is_real:
        draw.text(
            (MARGIN, sub_bottom + 26),
            "排版占位图，需用真实截图替换",
            font=font(34),
            fill=(150, 108, 66),
        )

    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"{index + 1:02d}-{name}.png")
    canvas.save(out, "PNG")
    return out, is_real


def main():
    results = []
    for index, (name, headline, subline) in enumerate(SLIDES):
        real = os.path.exists(os.path.join(RAW_DIR, f"{name}.png"))
        out, real = compose(name, headline, subline, index, real)
        results.append((out, real))
        print(("真实截图 " if real else "占位图   ") + out)
    print(f"\n共 {len(results)} 张，输出目录：{OUT_DIR}")


if __name__ == "__main__":
    main()
