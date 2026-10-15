# 剪纸坊
# gen_zodiac.py - 生肖样稿生成
import math
import sys

import gen_builtin_templates as G
from gen_builtin_templates import Canvas, mirror_x

G.SCALE = 1.6

RING_OUT = 485
RING_IN = 445


RING_MID = (RING_OUT + RING_IN) / 2


def frame(c):
    c.circle(0, 0, RING_OUT, True)
    c.circle(0, 0, RING_IN, False)
    n = 72
    for k in range(n):
        a = 2 * math.pi * k / n
        b1 = a - math.pi / n * 0.85
        b2 = a + math.pi / n * 0.85
        base = RING_IN + 8
        c.poly([(base * math.cos(b1), base * math.sin(b1)),
                (base * math.cos(b2), base * math.sin(b2)),
                ((RING_IN - 16) * math.cos(a), (RING_IN - 16) * math.sin(a))], True)


def on_ring(x, y):
    r = math.hypot(x, y)
    return (x / r * RING_MID, y / r * RING_MID)


def _spline(pts, n=16):
    out = []
    p = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    out.append(pts[-1])
    return out


def stroke(c, pts, w0, w1, keep=True):
    q = _spline(pts)
    n = len(q)
    left, right = [], []
    for i in range(n):
        a = q[max(0, i - 1)]
        b = q[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / l, dx / l
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        left.append((q[i][0] + nx * w, q[i][1] + ny * w))
        right.append((q[i][0] - nx * w, q[i][1] - ny * w))
    c.poly(left + right[::-1], keep)
    c.circle(q[0][0], q[0][1], w0 / 2, keep)
    c.circle(q[-1][0], q[-1][1], max(w1, 1) / 2, keep)


def saw(c, x0, y0, x1, y1, n, depth, keep):
    dx, dy = (x1 - x0) / n, (y1 - y0) / n
    l = math.hypot(dx, dy)
    nx, ny = -dy / l * depth, dx / l * depth
    for i in range(n):
        ax, ay = x0 + dx * i, y0 + dy * i
        bx, by = ax + dx, ay + dy
        c.poly([(ax, ay), (bx, by), ((ax + bx) / 2 + nx, (ay + by) / 2 + ny)], keep)


def plum5(c, cx, cy, r, keep):
    for k in range(5):
        a = math.radians(-90 + 72 * k)
        c.circle(cx + r * math.cos(a), cy + r * math.sin(a), r * 0.62, keep)
    c.circle(cx, cy, r * 0.55, keep)


def rat():
    c = Canvas("half", "cut")
    frame(c)
    mirror_x(lambda s: c.circle(s * 255, -255, 150, True))
    c.circle(0, -20, 225, True)
    c.ellipse(0, 175, 120, 170, 0, True)
    for s in (1, -1):
        stroke(c, [(s * 70, 225), (s * 250, 185), on_ring(s * 455, 160)], 16, 10)
        stroke(c, [(s * 70, 255), (s * 250, 270), on_ring(s * 440, 310)], 16, 10)
    mirror_x(lambda s: c.crescent(s * 272, -272, math.degrees(math.atan2(272, -s * 272)), 92, False))
    c.drop(78, -35, -30, 30, 34, False)
    c.drop(-78, -35, 180 + 30, 30, 34, False)
    plum5(c, 0, -150, 30, False)
    mirror_x(lambda s: c.crescent(s * 140, 60, -90, 34, False))
    c.circle(0, 315, 30, False)
    c.save("zodiac_rat", {"name": "子鼠", "fold": "half", "paper": "red", "difficulty": 3, "price": 120,
                          "desc": "十二生肖 · 鼠：大圆耳朵，胡须连到圆框上"})


def tiger():
    c = Canvas("half", "cut")
    frame(c)
    mirror_x(lambda s: c.circle(s * 262, -282, 105, True))
    c.ellipse(0, 10, 300, 270, 0, True)
    mirror_x(lambda s: c.ellipse(s * 185, 150, 150, 120, s * 20, True))
    for s in (1, -1):
        stroke(c, [(s * 240, 140), (s * 350, 125), on_ring(s * 455, 120)], 16, 10)
        stroke(c, [(s * 250, 195), (s * 350, 215), on_ring(s * 445, 245)], 16, 10)
    mirror_x(lambda s: c.circle(s * 268, -288, 58, False))
    c.rect(-80, -200, 80, -178, False)
    c.rect(-62, -140, 62, -120, False)
    c.rect(-80, -82, 80, -60, False)
    c.rect(-11, -195, 11, -66, False)
    for s in (1, -1):
        saw(c, s * 290, -60, s * 210, -10, 3, 34 * s, False)
        saw(c, s * 300, 40, s * 225, 75, 3, 30 * s, False)
    for s in (1, -1):
        c.ellipse(s * 110, -10, 62, 34, s * -12, False)
        c.circle(s * 110, -10, 17, True)
    c.poly([(-46, 70), (46, 70), (0, 118)], False)
    mirror_x(lambda s: c.crescent(s * 36, 158, -90, 38, False))
    plum5(c, 0, 225, 24, False)
    c.save("zodiac_tiger", {"name": "寅虎", "fold": "half", "paper": "red", "difficulty": 4, "price": 180,
                            "desc": "十二生肖 · 虎：额头一个“王”，两腮锯齿条纹"})


def dragon():
    c = Canvas("half", "cut")
    frame(c)
    for s in (1, -1):
        stroke(c, [(s * 80, -170), (s * 120, -260), (s * 175, -330), on_ring(s * 230, -390)], 44, 22)
        stroke(c, [(s * 118, -255), (s * 200, -262), (s * 262, -300)], 26, 8)
        stroke(c, [(s * 160, -315), (s * 205, -360), (s * 210, -398)], 22, 6)
        for k in range(5):
            a = math.radians(-35 - 22 * k) if s > 0 else math.radians(180 + 35 + 22 * k)
            cx, cy = 230 * math.cos(a), -20 + 230 * math.sin(a)
            c.drop(cx, cy, math.degrees(a) - 20 * s, 40, 80, True)
    c.ellipse(0, -25, 210, 200, 0, True)
    c.ellipse(0, 170, 180, 115, 0, True)
    mirror_x(lambda s: c.circle(s * 70, 120, 62, True))
    for s in (1, -1):
        stroke(c, [(s * 150, 165), (s * 250, 120), (s * 320, 170), (s * 380, 120), on_ring(s * 440, 60)], 22, 10)
        stroke(c, [(s * 130, 235), (s * 210, 300), (s * 300, 300), (s * 340, 360), on_ring(s * 330, 420)], 18, 9)
    c.poly([(-70, 270), (70, 270), (40, 400), (0, RING_MID), (-40, 400)], True)
    saw(c, -55, 300, 55, 300, 4, -26, False)
    for s in (1, -1):
        c.drop(s * 80, -100, -90 + 60 * s, 26, 75, False)
        c.circle(s * 92, -35, 42, False)
        c.circle(s * 92, -35, 17, True)
    c.circle(0, -150, 28, False)
    c.circle(0, -150, 11, True)
    for s in (1, -1):
        c.crescent(s * 70, 120, -90, 30, False)
    c.ellipse(0, 222, 125, 40, 0, False)
    saw(c, -84, 181, 84, 181, 6, 30, True)
    saw(c, 84, 263, -84, 263, 6, 24, True)
    for s in (1, -1):
        for (x, y) in [(160, -5), (178, 45), (140, 45)]:
            c.crescent(s * x, y, 90, 17, False)
    c.save("zodiac_dragon", {"name": "辰龙", "fold": "half", "paper": "red", "difficulty": 5, "price": 260,
                             "desc": "十二生肖 · 龙：鹿角、火焰鬃毛、S 形长须，角和须连到圆框上"})


ALL = {"rat": rat, "tiger": tiger, "dragon": dragon}

if __name__ == "__main__":
    names = sys.argv[1:] or list(ALL)
    for n in names:
        ALL[n]()
