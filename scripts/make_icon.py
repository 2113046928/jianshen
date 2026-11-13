# -*- coding: utf-8 -*-
"""生成 1024×1024 App 图标（杠铃图形，无文字，小尺寸也认得出）。

用法：python scripts/make_icon.py
依赖：Pillow
"""
import os

from PIL import Image, ImageDraw

SIZE = 1024
BG = (28, 28, 30)
PLATE = (245, 242, 234)
ACCENT = (232, 89, 12)

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Sources", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png",
)


def rounded(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def main():
    image = Image.new("RGB", (SIZE, SIZE), BG)
    draw = ImageDraw.Draw(image)
    cy = SIZE // 2

    # 杠铃杆
    draw.rectangle([168, cy - 15, 856, cy + 15], fill=PLATE)

    # 内侧配重片
    rounded(draw, [300, cy - 116, 372, cy + 116], 18, PLATE)
    rounded(draw, [652, cy - 116, 724, cy + 116], 18, PLATE)

    # 外侧配重片（强调色）
    rounded(draw, [206, cy - 84, 284, cy + 84], 18, ACCENT)
    rounded(draw, [740, cy - 84, 816, cy + 84], 18, ACCENT)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    image.save(OUT, "PNG")
    print("saved:", OUT)


if __name__ == "__main__":
    main()
