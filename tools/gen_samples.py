# 剪纸坊
# gen_samples.py - 示例照片生成
import math
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "samples")
N = 900


def dihedral_mask(n, rot, seed, outer):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:N, 0:N].astype(float)
    cx = cy = N / 2
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy) / (N * 0.42)
    th = np.arctan2(dy, dx) - rot
    seg = math.pi / n
    t = np.mod(th, 2 * seg)
    t = np.where(t > seg, 2 * seg - t, t)
    m = outer(r, t, seg)
    for _ in range(rng.integers(4, 7)):
        rr = rng.uniform(0.18, 0.8)
        tt = rng.uniform(0.15, 0.85) * seg
        px, py = rr * math.cos(tt), rr * math.sin(tt)
        qx, qy = r * np.cos(t), r * np.sin(t)
        d = np.hypot(qx - px, qy - py)
        size = rng.uniform(0.04, 0.09)
        kind = rng.integers(0, 3)
        if kind == 0:
            hole = d < size
        elif kind == 1:
            ang = np.arctan2(qy - py, qx - px)
            hole = d < size * (0.55 + 0.45 * np.cos(ang - tt))
        else:
            d2 = np.hypot(qx - px - size * 0.5, qy - py)
            hole = (d < size) & (d2 > size * 0.8)
        m &= ~hole
    m &= ~(r < 0.06)
    return m


def flower(r, t, seg):
    return r < 0.82 + 0.16 * np.cos(t / seg * math.pi)


def snow(r, t, seg):
    arm = (t < seg * 0.28) & (r < 1.0)
    branch = (np.abs(r * np.sin(t) - 0.16) < 0.06) & (r > 0.35) & (r < 0.8)
    return arm | branch | (r < 0.42)


def plum(r, t, seg):
    return r < 0.62 + 0.38 * np.abs(np.cos(t / seg * math.pi / 2)) ** 0.6


def photo(mask, paper_rgb, bg_rgb, seed, name):
    rng = np.random.default_rng(seed)
    big = N + 300
    canvas = np.zeros((big, big, 3)) + np.array(bg_rgb, float)
    yy, xx = np.mgrid[0:big, 0:big]
    canvas *= (1.04 - 0.12 * (((xx - big * 0.4) / big) ** 2 + ((yy - big * 0.35) / big) ** 2))[..., None]
    grain = np.array(Image.fromarray((rng.normal(128, 30, (big, big))).clip(0, 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.5))) / 255.0 - 0.5
    canvas *= (1 + grain * 0.06)[..., None]
    m = Image.fromarray((mask * 255).astype('uint8'))
    sh = Image.new('L', (big, big), 0)
    sh.paste(m, (150 + 10, 150 + 14))
    sh = np.array(sh.filter(ImageFilter.GaussianBlur(9))) / 255.0
    canvas *= (1 - 0.35 * sh)[..., None]
    pm = np.zeros((big, big))
    pm[150:150 + N, 150:150 + N] = mask
    fib = np.array(Image.fromarray((rng.normal(128, 40, (big, big))).clip(0, 255).astype('uint8')).filter(ImageFilter.GaussianBlur(0.8))) / 255.0 - 0.5
    paper = np.array(paper_rgb, float) * (1 + fib * 0.12)[..., None]
    canvas = canvas * (1 - pm[..., None]) + paper * pm[..., None]
    canvas += rng.normal(0, 3, canvas.shape)
    img = Image.fromarray(canvas.clip(0, 255).astype('uint8')).resize((1000, 1000), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".jpg"), quality=88)


def connected_mask(n, rot, outer, seed0):
    from scipy import ndimage
    for seed in range(seed0, seed0 + 200):
        m = dihedral_mask(n, rot, seed, outer)
        lab, k = ndimage.label(m)
        if k == 0:
            continue
        sizes = np.bincount(lab.ravel())[1:]
        if sizes.max() / sizes.sum() > 0.995:
            print("seed", seed)
            return lab == (np.argmax(sizes) + 1)
    raise RuntimeError("no connected pattern")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    photo(connected_mask(4, 0.0, flower, 3), (196, 30, 32), (236, 228, 214), 1, "sample_flower")
    photo(connected_mask(6, -math.pi / 2, snow, 5), (214, 40, 46), (225, 214, 196), 2, "sample_snow")
    photo(connected_mask(5, -math.pi / 2, plum, 9), (180, 22, 30), (240, 236, 228), 3, "sample_plum")
    print("ok")
