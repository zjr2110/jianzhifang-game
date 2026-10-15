# 剪纸坊
# gen_builtin_templates.py - 内置样稿生成
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "templates")

BOUNDS = {
    "none": (-500, -500, 1000, 1000),
    "half": (-500, -500, 1000, 1000),
    "four": (-500, -500, 1000, 1000),
    "eight": (-500, -500, 1000, 1000),
    "five": (-475.52, -500, 951.04, 904.49),
    "twelve": (-433, -500, 866, 1000),
    "sixteen": (-462, -462, 924, 924),
    "accordion": (-480, -160, 960, 320),
}
SCALE = 0.8

FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc",
    "C:/Windows/Fonts/msyhbd.ttc",
    "C:/Windows/Fonts/simhei.ttf",
    "/System/Library/Fonts/PingFang.ttc",
]


class Canvas:
    def __init__(self, fold, background):
        self.bx, self.by, bw, bh = BOUNDS[fold]
        self.img = Image.new("L", (round(bw * SCALE), round(bh * SCALE)), 255 if background == "keep" else 0)
        self.d = ImageDraw.Draw(self.img)

    def P(self, x, y):
        return ((x - self.bx) * SCALE, (y - self.by) * SCALE)

    def poly(self, pts, keep):
        self.d.polygon([self.P(x, y) for x, y in pts], fill=255 if keep else 0)

    def circle(self, cx, cy, r, keep):
        x0, y0 = self.P(cx - r, cy - r)
        x1, y1 = self.P(cx + r, cy + r)
        self.d.ellipse([x0, y0, x1, y1], fill=255 if keep else 0)

    def ellipse(self, cx, cy, rx, ry, rot_deg, keep, n=72):
        a = math.radians(rot_deg)
        pts = []
        for i in range(n):
            t = 2 * math.pi * i / n
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
        self.poly(pts, keep)

    def line(self, pts, width, keep):
        self.d.line([self.P(x, y) for x, y in pts], fill=255 if keep else 0, width=round(width * SCALE), joint="curve")
        for x, y in (pts[0], pts[-1]):
            self.circle(x, y, width / 2, keep)

    def rect(self, x0, y0, x1, y1, keep):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], keep)

    def drop(self, cx, cy, ang_deg, r, tip, keep):
        a = math.radians(ang_deg)
        pts = []
        for i in range(48):
            t = 2 * math.pi * i / 48
            pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
        self.poly(pts, keep)
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        self.poly([(cx + px * r * 0.95, cy + py * r * 0.95), (cx + ux * (r + tip), cy + uy * (r + tip)),
                   (cx - px * r * 0.95, cy - py * r * 0.95)], keep)

    def crescent(self, cx, cy, ang_deg, r, keep):
        a = math.radians(ang_deg)
        self.circle(cx, cy, r, keep)
        self.circle(cx + math.cos(a) * r * 0.45, cy + math.sin(a) * r * 0.45, r * 0.85, not keep)

    def glyph(self, ch, cx, cy, size, keep):
        font = None
        for f in FONT_CANDIDATES:
            if os.path.exists(f):
                font = ImageFont.truetype(f, round(size * SCALE))
                break
        if font is None:
            sys.exit("找不到中文字体，请在 FONT_CANDIDATES 里加一个本机字体路径")
        x, y = self.P(cx, cy)
        self.d.text((x, y), ch, font=font, fill=255 if keep else 0, anchor="mm")

    def save(self, name, meta):
        os.makedirs(OUT, exist_ok=True)
        self.img.save(os.path.join(OUT, name + ".png"))
        lines = ["[template]"]
        for k, v in meta.items():
            lines.append(f"{k}={v}" if isinstance(v, (int, float)) else f'{k}="{v}"')
        with open(os.path.join(OUT, name + ".cfg"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print("wrote", name)


def mirror_x(fn):
    fn(1)
    fn(-1)


def butterfly():
    c = Canvas("half", "cut")
    def wing(s):
        c.ellipse(s * 235, -175, 235, 165, s * -28, True)
        c.ellipse(s * 185, 175, 170, 125, s * 32, True)
        c.line([(s * 18, -270), (s * 80, -380), (s * 150, -455)], 18, True)
        c.circle(s * 150, -455, 28, True)
    mirror_x(wing)
    c.ellipse(0, 40, 36, 270, 0, True)
    c.circle(0, -255, 52, True)
    def holes(s):
        c.circle(s * 255, -190, 72, False)
        c.circle(s * 385, -265, 30, False)
        c.circle(s * 145, -275, 28, False)
        c.drop(s * 205, 195, s * 32 if s > 0 else 180 - 32, 46, 40, False)
        c.circle(s * 105, 245, 22, False)
    mirror_x(holes)
    c.save("butterfly", {"name": "蝴蝶", "fold": "half", "paper": "red", "difficulty": 2, "price": 0,
                         "desc": "对折剪出一只蝴蝶，翅膀上镂几个孔"})


def rabbit():
    c = Canvas("half", "cut")
    c.circle(0, -80, 155, True)
    mirror_x(lambda s: c.ellipse(s * 72, -330, 52, 150, s * 10, True))
    c.ellipse(0, 235, 235, 215, 0, True)
    mirror_x(lambda s: c.ellipse(s * 135, 430, 95, 48, 0, True))
    mirror_x(lambda s: c.circle(s * 62, -100, 22, False))
    mirror_x(lambda s: c.ellipse(s * 74, -330, 18, 100, s * 10, False))
    c.poly([(-16, -45), (16, -45), (0, -25)], False)
    for k in range(5):
        a = math.radians(-90 + 72 * k)
        c.circle(55 * math.cos(a), 235 + 55 * math.sin(a), 30, False)
    c.circle(0, 235, 16, False)
    c.save("rabbit", {"name": "玉兔", "fold": "half", "paper": "white", "difficulty": 3, "price": 150,
                      "desc": "对折剪的兔子剪影，肚子上一朵梅花"})


def goldfish():
    c = Canvas("half", "cut")
    c.ellipse(0, -110, 150, 225, 0, True)
    mirror_x(lambda s: c.ellipse(s * 150, 265, 140, 225, s * -25, True))
    c.ellipse(0, 140, 95, 125, 0, True)
    mirror_x(lambda s: c.ellipse(s * 175, -55, 72, 40, s * 30, True))
    mirror_x(lambda s: c.circle(s * 120, -275, 72, True))
    mirror_x(lambda s: c.circle(s * 120, -275, 32, False))
    for x, y in [(50, -80), (-50, -80), (0, -10), (95, -10), (-95, -10), (50, 60), (-50, 60)]:
        c.crescent(x, y, -90, 26, False)
    mirror_x(lambda s: c.ellipse(s * 165, 280, 22, 130, s * -25, False))
    mirror_x(lambda s: c.ellipse(s * 95, 330, 17, 85, s * -12, False))
    c.save("goldfish", {"name": "金鱼", "fold": "half", "paper": "peach", "difficulty": 3, "price": 120,
                        "desc": "俯视的金鱼，大尾巴上有几道纹"})


def xi():
    c = Canvas("none", "keep")
    c.glyph("囍", 0, 10, 690, False)
    for sx in (1, -1):
        for sy in (1, -1):
            c.poly([(sx * 500, sy * 500), (sx * 380, sy * 500), (sx * 500, sy * 380)], False)
    c.save("xi", {"name": "囍字", "fold": "none", "paper": "red", "difficulty": 4, "price": 200,
                  "desc": "不折纸，把囍字的笔画刻掉（阴刻），用直线刻刀最顺手"})


def fu():
    c = Canvas("none", "keep")
    for sx in (1, -1):
        for sy in (1, -1):
            c.poly([(sx * 500, sy * 500), (0, sy * 500), (sx * 500, 0)], False)
    c.glyph("福", 0, 12, 470, False)
    c.save("fu", {"name": "斗方福", "fold": "none", "paper": "wannian", "difficulty": 4, "price": 200,
                  "desc": "剪去四角成斗方，再把福字刻掉"})


def plum():
    c = Canvas("five", "cut")
    pts = []
    for i in range(360):
        t = math.radians(i)
        r = 362 + 26 * math.cos(10 * (t + math.pi / 2))
        pts.append((r * math.cos(t), r * math.sin(t)))
    c.poly(pts, True)
    for k in range(5):
        a = math.radians(-90 + 72 * k)
        c.circle(105 * math.cos(a), 105 * math.sin(a), 52, False)
        b = math.radians(-90 + 36 + 72 * k)
        c.crescent(192 * math.cos(b), 192 * math.sin(b), math.degrees(b), 38, False)
    c.circle(0, 0, 22, False)
    for k in range(10):
        a = math.radians(-90 + 36 * k)
        c.drop(262 * math.cos(a), 262 * math.sin(a), math.degrees(a), 26, 38, False)
    c.save("plum", {"name": "梅花团花", "fold": "five", "paper": "red", "difficulty": 3, "price": 180,
                    "desc": "五角折，五瓣梅花配一圈水滴"})


def snowflake():
    c = Canvas("twelve", "cut")
    c.circle(0, 0, 80, True)
    for k in range(6):
        a = math.radians(60 * k)
        ux, uy = math.cos(a), math.sin(a)
        c.line([(0, 0), (ux * 400, uy * 400)], 38, True)
        for d, ln, w in [(170, 115, 26), (285, 80, 22)]:
            bx, by = ux * d, uy * d
            for s in (1, -1):
                b = a + s * math.radians(60)
                c.line([(bx, by), (bx + math.cos(b) * ln, by + math.sin(b) * ln)], w, True)
        c.poly([(ux * 360 - uy * 30, uy * 360 + ux * 30), (ux * 440, uy * 440),
                (ux * 360 + uy * 30, uy * 360 - ux * 30), (ux * 330, uy * 330)], True)
    pts_o = [(220 * math.cos(math.radians(i)), 220 * math.sin(math.radians(i))) for i in range(0, 360, 3)]
    c.poly(pts_o, True)
    pts_i = [(196 * math.cos(math.radians(i)), 196 * math.sin(math.radians(i))) for i in range(0, 360, 3)]
    c.poly(pts_i, False)
    c.circle(0, 0, 80, True)
    for k in range(6):
        a = math.radians(60 * k)
        c.line([(0, 0), (math.cos(a) * 220, math.sin(a) * 220)], 38, True)
        b = math.radians(30 + 60 * k)
        c.drop(130 * math.cos(b), 130 * math.sin(b), math.degrees(b), 22, 30, True)
    c.circle(0, 0, 26, False)
    c.save("snowflake", {"name": "六角雪花", "fold": "twelve", "paper": "white", "difficulty": 4, "price": 260,
                         "desc": "六角窗花折法，剪出雪花的六条枝杈"})


def eight_flower():
    c = Canvas("eight", "keep")
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        c.circle(78 * math.cos(a), 78 * math.sin(a), 22, False)
        b = math.radians(45 * k)
        c.drop(200 * math.cos(b), 200 * math.sin(b), 45 * k, 38, 55, False)
        c.crescent(305 * math.cos(a), 305 * math.sin(a), math.degrees(a), 42, False)
    c.circle(0, 0, 20, False)
    for sx in (1, -1):
        for sy in (1, -1):
            c.circle(sx * 500, sy * 500, 125, False)
    for k in range(4):
        a = math.radians(90 * k)
        c.circle(500 * math.cos(a), 500 * math.sin(a), 62, False)
    c.save("eight_flower", {"name": "八角团花", "fold": "eight", "paper": "red", "difficulty": 3, "price": 0,
                            "desc": "最经典的八折团花：水滴、月牙、小圆孔"})


def ruyi():
    c = Canvas("four", "keep")
    for k in range(4):
        a = math.radians(90 * k)
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        hx, hy = ux * 270, uy * 270
        c.circle(hx, hy, 62, False)
        for s in (1, -1):
            c.circle(hx - ux * 30 + px * s * 62, hy - uy * 30 + py * s * 62, 44, False)
        c.line([(ux * 150, uy * 150), (ux * 215, uy * 215)], 24, False)
        d = math.radians(45 + 90 * k)
        c.circle(330 * math.cos(d), 330 * math.sin(d), 48, False)
        c.circle(500 * math.cos(d) * 1.414, 500 * math.sin(d) * 1.414, 150, False)
    c.poly([(0, -75), (75, 0), (0, 75), (-75, 0)], False)
    c.save("ruyi", {"name": "如意云纹", "fold": "four", "paper": "indigo", "difficulty": 3, "price": 150,
                    "desc": "四折剪，四个如意云头朝向四方"})


def dolls():
    c = Canvas("accordion", "cut")
    for k in range(6):
        cx = -400 + 160 * k
        c.circle(cx, -98, 33, True)
        c.rect(cx - 10, -70, cx + 10, -58, True)
        c.poly([(cx - 24, -62), (cx + 24, -62), (cx + 62, 92), (cx - 62, 92)], True)
        c.rect(cx - 80, -52, cx + 80, -32, True)
        c.rect(cx - 32, 88, cx - 14, 160, True)
        c.rect(cx + 14, 88, cx + 32, 160, True)
        c.circle(cx, 25, 13, False)
    c.save("dolls", {"name": "拉手小人", "fold": "accordion", "paper": "red", "difficulty": 2, "price": 0,
                     "desc": "连续拉花：一排手拉手的小人"})


if __name__ == "__main__":
    for fn in (butterfly, rabbit, goldfish, xi, fu, plum, snowflake, eight_flower, ruyi, dolls):
        fn()
