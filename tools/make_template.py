# 剪纸坊
# make_template.py - 图片转样稿
import argparse
import os
import sys

from PIL import Image, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "templates")

ASPECT = {
    "none": 1.0, "half": 1.0, "four": 1.0, "eight": 1.0,
    "five": 951.04 / 904.49, "twelve": 866 / 1000, "sixteen": 1.0, "accordion": 960 / 320,
}
PAPERS = ["red", "peach", "wannian", "white", "gold", "glossy", "indigo", "ink", "foil"]


def to_mask(img, keep, threshold):
    img = img.convert("RGB")
    if max(img.size) > 1200:
        img.thumbnail((1200, 1200))
    if keep == "red":
        px = img.load()
        out = Image.new("L", img.size, 0)
        po = out.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b = px[x, y]
                redness = r - (g + b) / 2
                dark = 255 - (r + g + b) / 3
                po[x, y] = 255 if (redness > 60 or dark > threshold) else 0
        return out
    gray = ImageOps.grayscale(img)
    if keep == "dark":
        return gray.point(lambda v: 255 if v < threshold else 0)
    return gray.point(lambda v: 255 if v >= threshold else 0)


def fit_to_aspect(mask, aspect, margin, background):
    w, h = mask.size
    content_w = w * (1 + margin * 2)
    content_h = h * (1 + margin * 2)
    if content_w / content_h > aspect:
        cw, ch = content_w, content_w / aspect
    else:
        cw, ch = content_h * aspect, content_h
    canvas = Image.new("L", (round(cw), round(ch)), background)
    canvas.paste(mask, (round((cw - w) / 2), round((ch - h) / 2)))
    scale = 800 / max(canvas.size)
    return canvas.resize((max(8, round(canvas.width * scale)), max(8, round(canvas.height * scale))), Image.NEAREST)


def main():
    ap = argparse.ArgumentParser(description="把剪纸图片转换成照样剪纸模板")
    ap.add_argument("image")
    ap.add_argument("--id", help="模板文件名（英文/数字），默认取图片文件名")
    ap.add_argument("--name", required=True, help="游戏里显示的名字")
    ap.add_argument("--fold", default="none", choices=list(ASPECT.keys()))
    ap.add_argument("--paper", default="red", choices=PAPERS)
    ap.add_argument("--difficulty", type=int, default=3)
    ap.add_argument("--price", type=int, default=100)
    ap.add_argument("--desc", default="")
    ap.add_argument("--keep", default="red", choices=["red", "dark", "light"])
    ap.add_argument("--threshold", type=int, default=128)
    ap.add_argument("--margin", type=float, default=0.03)
    a = ap.parse_args()

    tid = a.id or os.path.splitext(os.path.basename(a.image))[0]
    if not tid.isascii() or " " in tid:
        sys.exit("--id 只能用英文、数字、下划线，例如 --id fish2")
    mask = to_mask(Image.open(a.image), a.keep, a.threshold)
    background = 255 if a.fold == "none" else 0
    mask = fit_to_aspect(mask, ASPECT[a.fold], a.margin, background)

    os.makedirs(OUT, exist_ok=True)
    mask.save(os.path.join(OUT, tid + ".png"))
    with open(os.path.join(OUT, tid + ".cfg"), "w", encoding="utf-8") as f:
        f.write("[template]\n")
        f.write(f'name="{a.name}"\nfold="{a.fold}"\npaper="{a.paper}"\n')
        f.write(f"difficulty={max(1, min(5, a.difficulty))}\nprice={max(0, a.price)}\n")
        f.write(f'desc="{a.desc}"\n')
    print(f"已生成 templates/{tid}.png 和 templates/{tid}.cfg")
    print("打开 png 检查：白色 = 留下的纸，黑色 = 要剪掉。不对的话换 --keep 或调 --threshold 再试。")


if __name__ == "__main__":
    main()
