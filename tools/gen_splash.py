# 剪纸坊
# gen_splash.py - 开屏动画贴图生成
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
OUT = os.path.join(ROOT, "assets", "splash")
S = 2.0
SS = 3
STAGE = 430


def px(v):
    return int(round(v * S))


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), int(round(a * 255)))


def lin_grad(w, h, deg, stops):
    a = np.radians(deg)
    d = np.array([np.sin(a), -np.cos(a)])
    L = abs(w * np.sin(a)) + abs(h * np.cos(a))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = ((xx + 0.5 - w / 2) * d[0] + (yy + 0.5 - h / 2) * d[1]) / L + 0.5
    t = np.clip(t, 0, 1)
    out = np.zeros((h, w, 4), np.float32)
    ts = [s[0] for s in stops]
    for c in range(4):
        out[..., c] = np.interp(t, ts, [s[1][c] for s in stops])
    return Image.fromarray(out.round().astype(np.uint8), "RGBA")


def rr_mask(size, box, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, r, fill=255)
    return m


def shadow_layer(size, mask, dx, dy, blur, color):
    sh = Image.new("L", size, 0)
    sh.paste(mask, (int(dx), int(dy)))
    sh = sh.filter(ImageFilter.GaussianBlur(blur / 2))
    layer = Image.new("RGBA", size, color[:3] + (0,))
    layer.putalpha(sh.point(lambda v: int(v * color[3] / 255)))
    return layer


def doors():
    icon = Image.open(os.path.join(ROOT, "assets", "icon.png")).convert("RGBA")
    w, h = px(STAGE / 2), px(STAGE)
    big = icon.resize((w * 2 * SS, h * SS), Image.LANCZOS)
    for side in ("l", "r"):
        W, H = w * SS, h * SS
        face = big.crop((0, 0, W, H)) if side == "l" else big.crop((W, 0, 2 * W, H))
        rx, ry = 0.14 * W, 0.14 * H
        m = Image.new("L", (W, H), 255)
        d = ImageDraw.Draw(m)
        for cy in (0, H):
            cx = 0 if side == "l" else W
            box = (cx - rx, cy - ry, cx + rx, cy + ry)
            corner = (0 if side == "l" else W - rx, 0 if cy == 0 else H - ry,
                      rx if side == "l" else W, ry if cy == 0 else H)
            d.rectangle(corner, fill=0)
            ex = (0, 0 if cy == 0 else H - 2 * ry, 2 * rx, 2 * ry if cy == 0 else H) if side == "l" else \
                 (W - 2 * rx, 0 if cy == 0 else H - 2 * ry, W, 2 * ry if cy == 0 else H)
            d.ellipse(ex, fill=255)
        a = np.minimum(np.array(face.split()[3]), np.array(m))
        face.putalpha(Image.fromarray(a))
        k = S * SS
        for top in (30, STAGE - 30 - 52):
            x0 = 7 if side == "l" else STAGE / 2 - 7 - 20
            box = (x0 * k, top * k, (x0 + 20) * k, (top + 52) * k)
            hm = rr_mask((W, H), box, 4 * k)
            face = Image.alpha_composite(face, shadow_layer((W, H), hm, 0, 3 * k, 8 * k, (0, 0, 0, 82)))
            g = lin_grad(W, H, 180, [(0, hexc("e6c064")), (1, hexc("a8792a"))])
            g = lin_grad(int(20 * k), int(52 * k), 180, [(0, hexc("e6c064")), (1, hexc("a8792a"))])
            gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            gl.paste(g, (int(box[0]), int(box[1])))
            gl.putalpha(Image.fromarray(np.minimum(np.array(gl.split()[3]), np.array(hm))))
            face = Image.alpha_composite(face, gl)
            hl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(hl).line((box[0] + 4 * k, box[1] + k, box[2] - 4 * k, box[1] + k), fill=(255, 255, 255, 150), width=int(k))
            face = Image.alpha_composite(face, hl)
        size = 56
        cx = (STAGE / 2 - 26 - size / 2) if side == "l" else (26 + size / 2)
        cy = STAGE * 0.58
        sc = size / 62.0
        ox, oy = (cx - size / 2) * k, (cy - size / 2) * k
        kn = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dk = ImageDraw.Draw(kn)
        def circ(x, y, r, fill=None, outline=None, width=0):
            X, Y, R = ox + x * sc * k, oy + y * sc * k, r * sc * k
            dk.ellipse((X - R, Y - R, X + R, Y + R), fill=fill, outline=outline, width=int(width * sc * k))
        circ(31, 38, 14 + 2.75, outline=hexc("c9962b"), width=5.5)
        circ(31, 18, 8 + 1, fill=hexc("e6c064"), outline=hexc("8a5d1c"), width=2)
        km = kn.split()[3]
        face = Image.alpha_composite(face, shadow_layer((W, H), km, 0, 3 * k, 5 * k, (0, 0, 0, 102)))
        face = Image.alpha_composite(face, kn)
        face.resize((w, h), Image.LANCZOS).save(os.path.join(OUT, "door_%s.png" % side))


FR = (-60, -60, 490, 530)


def frame():
    k = S * SS
    W, H = int((FR[2] - FR[0]) * k), int((FR[3] - FR[1]) * k)
    def X(v): return (v - FR[0]) * k
    def Y(v): return (v - FR[1]) * k
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sm = Image.new("L", (W, H), 0)
    x0, x1 = -0.02 * STAGE, STAGE * 1.02
    yb = STAGE + 0.04 * STAGE
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cxp, cyp = (X(x0) + X(x1)) / 2, (Y(yb - 34) + Y(yb)) / 2
    ax, ay = (X(x1) - X(x0)) / 2, 17 * k
    r = np.sqrt(((xx - cxp) / ax) ** 2 + ((yy - cyp) / ay) ** 2)
    al = np.clip(1 - r / 0.7, 0, 1) * 0.26 * 255
    sl = Image.new("RGBA", (W, H), (110, 70, 30, 0))
    sl.putalpha(Image.fromarray(al.astype(np.uint8)).filter(ImageFilter.GaussianBlur(3 * k)))
    img = Image.alpha_composite(img, sl)
    box = (X(-22), Y(-22), X(STAGE + 22), Y(STAGE + 22))
    ring = rr_mask((W, H), box, 16 * k)
    ImageDraw.Draw(ring).rectangle((X(0), Y(0), X(STAGE), Y(STAGE)), fill=0)
    bw, bh = int(box[2] - box[0]), int(box[3] - box[1])
    g = lin_grad(bw, bh, 160, [(0, hexc("a3121c")), (0.45, hexc("7d0810")), (1, hexc("42040a"))])
    gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gl.paste(g, (int(box[0]), int(box[1])))
    gl.putalpha(Image.fromarray(np.minimum(np.array(gl.split()[3]), np.array(ring))))
    img = Image.alpha_composite(img, gl)
    sb = (X(-26), Y(STAGE + 30 - 18), X(STAGE + 26), Y(STAGE + 30))
    smk = rr_mask((W, H), sb, 5 * k)
    img = Image.alpha_composite(img, shadow_layer((W, H), smk, 0, 12 * k, 22 * k, (90, 20, 20, 66)))
    g = lin_grad(int(sb[2] - sb[0]), int(sb[3] - sb[1]), 180, [(0, hexc("9c1018")), (1, hexc("42040a"))])
    gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gl.paste(g, (int(sb[0]), int(sb[1])))
    gl.putalpha(Image.fromarray(np.minimum(np.array(gl.split()[3]), np.array(smk))))
    img = Image.alpha_composite(img, gl)
    hl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(hl).line((sb[0] + 5 * k, sb[1] + k * 0.5, sb[2] - 5 * k, sb[1] + k * 0.5), fill=hexc("e6c064", 0.45), width=int(k))
    img = Image.alpha_composite(img, hl)
    img.resize((int(W / SS), int(H / SS)), Image.LANCZOS).save(os.path.join(OUT, "frame.png"))


def glow():
    W, H = 592, 528
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx, dy = xx + 0.5 - W / 2, yy + 0.5 - H / 2
    R = np.hypot(W / 2, H / 2)
    t = np.hypot(dx, dy) / R
    a = np.interp(t, [0, 0.4, 0.7], [0.98, 0.62, 0.0])
    rp = np.interp(t, [0, 0.4, 0.7], [255 * .98, 255 * .62, 0])
    gp = np.interp(t, [0, 0.4, 0.7], [241 * .98, 226 * .62, 0])
    bp = np.interp(t, [0, 0.4, 0.7], [214 * .98, 196 * .62, 0])
    inside = (dx / (W / 2)) ** 2 + (dy / (H / 2)) ** 2 <= 1
    a = a * inside
    safe = np.maximum(a, 1e-6)
    out = np.dstack([rp / safe, gp / safe, bp / safe, a * 255])
    out[..., :3] = np.where(a[..., None] > 0, out[..., :3], 255)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "glow.png"))


WHITE = [
    "M120 42C134 46 138 60 130 72C120 88 100 104 80 114C66 121 54 124 46 121C52 108 60 96 70 86C84 71 102 53 120 42Z",
    "M129 44L153 51L129 59Z",
    "M104 58C98 36 84 16 62 4C74 26 80 46 79 64C88 60 96 58 104 58Z",
    "M54 118L10 146L38 124L8 110Z",
]
BLACK = [
    "M94 52C89 38 81 26 70 18C76 30 79 42 80 54C85 52 89 51 94 52Z",
    "M86 60C82 48 76 38 68 30C72 40 75 50 76 60C79 59 82 59 86 60Z",
    "M114 58C104 72 92 86 78 98C88 88 98 76 107 64C110 61 112 59 114 58Z",
    "M32 118C26 120 20 124 15 130C22 128 28 126 34 126C34 123 33 120 32 118Z",
]


def path_pts(d):
    toks = re.findall(r"[MLCZ]|-?\d+\.?\d*", d)
    pts, i, cur, cmd = [], 0, (0, 0), None
    while i < len(toks):
        t = toks[i]
        if t in "MLCZ":
            cmd = t
            i += 1
            if t == "Z":
                continue
        if cmd in ("M", "L"):
            cur = (float(toks[i]), float(toks[i + 1]))
            pts.append(cur)
            i += 2
        elif cmd == "C":
            p1 = (float(toks[i]), float(toks[i + 1]))
            p2 = (float(toks[i + 2]), float(toks[i + 3]))
            p3 = (float(toks[i + 4]), float(toks[i + 5]))
            for s in np.linspace(0, 1, 24)[1:]:
                u = 1 - s
                pts.append((u ** 3 * cur[0] + 3 * u * u * s * p1[0] + 3 * u * s * s * p2[0] + s ** 3 * p3[0],
                            u ** 3 * cur[1] + 3 * u * u * s * p1[1] + 3 * u * s * s * p2[1] + s ** 3 * p3[1]))
            cur = p3
            i += 6
    return pts


BIRD_BOX = 166
BIRD_PAD = 40


def bird():
    k = 3.0 * SS
    full = BIRD_BOX + BIRD_PAD * 2
    W = int(full * k)
    sc = BIRD_BOX / 160.0
    oy = (BIRD_BOX - 150 * sc) / 2
    def T(p): return ((BIRD_PAD + p[0] * sc) * k, (BIRD_PAD + oy + p[1] * sc) * k)
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    for p in WHITE:
        d.polygon([T(q) for q in path_pts(p)], fill=255)
    c = T((121, 50)); r = 12 * sc * k
    d.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=255)
    for p in BLACK:
        d.polygon([T(q) for q in path_pts(p)], fill=0)
    eye = [T((122 + 4 * np.cos(a) * np.cos(np.radians(-18)) - 5 * np.sin(a) * np.sin(np.radians(-18)),
              50 + 4 * np.cos(a) * np.sin(np.radians(-18)) + 5 * np.sin(a) * np.cos(np.radians(-18))))
           for a in np.linspace(0, 2 * np.pi, 40)]
    d.polygon(eye, fill=0)
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    vx = (xx / k - BIRD_PAD) / sc
    vy = (yy / k - BIRD_PAD - oy) / sc
    ax, ay = 0.6 * 160, 150.0
    t = np.clip((vx * ax + vy * ay) / (ax * ax + ay * ay), 0, 1)
    cols = [hexc("f23341"), hexc("d1141f"), hexc("93060f")]
    rgb = np.dstack([np.interp(t, [0, 0.5, 1], [c_[i] for c_ in cols]) for i in range(3)])
    body = Image.fromarray(np.dstack([rgb, np.array(m)]).astype(np.uint8), "RGBA")
    out = Image.alpha_composite(Image.new("RGBA", (W, W), (0, 0, 0, 0)),
                                shadow_layer((W, W), m, 0, 8 * k, 14 * k, (120, 10, 16, 56)))
    out = Image.alpha_composite(out, body)
    out.resize((int(W / SS), int(W / SS)), Image.LANCZOS).save(os.path.join(OUT, "bird.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    doors()
    frame()
    glow()
    bird()
    print("ok ->", os.path.abspath(OUT))
