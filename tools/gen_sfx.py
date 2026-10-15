# 剪纸坊
# gen_sfx.py - 音效合成
import os
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def env(t, attack, decay):
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def bandpass(x, lo, hi):
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    mask = np.clip((freqs - lo) / (lo * 0.3 + 1), 0, 1) * np.clip((hi - freqs) / (hi * 0.3 + 1), 0, 1)
    return np.fft.irfft(f * mask, len(x))


def place(buf, sig, at):
    i = int(at * SR)
    n = min(len(sig), len(buf) - i)
    buf[i:i + n] += sig[:n]


def click(sec, freqs, decay, noise_amt=0.6, lo=2000, hi=9000):
    t = t_axis(sec)
    tone = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * w for f, w in freqs)
    n = bandpass(rng.normal(0, 1, len(t)), lo, hi)
    n /= np.abs(n).max() + 1e-9
    return (tone * env(t, 0.0008, decay) + noise_amt * n * env(t, 0.0005, decay * 0.35))


def save(name, x, gain=0.85):
    x = x / (np.abs(x).max() + 1e-9) * gain
    fade = int(SR * 0.004)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def snip():
    buf = np.zeros(int(SR * 0.16))
    paper = bandpass(rng.normal(0, 1, int(SR * 0.06)), 1800, 7000)
    paper *= env(t_axis(0.06), 0.012, 0.025) * 0.5 / (np.abs(paper).max() + 1e-9)
    place(buf, paper, 0.0)
    place(buf, click(0.09, [(3150, 1.0), (5230, 0.6), (7400, 0.25)], 0.028), 0.03)
    place(buf, 0.45 * click(0.07, [(3900, 1.0), (6100, 0.4)], 0.02), 0.052)
    return buf


def rustle(sec=0.45):
    t = t_axis(sec)
    n = bandpass(rng.normal(0, 1, len(t)), 700, 4500)
    mod = np.interp(t, np.linspace(0, sec, 14), rng.uniform(0.2, 1.0, 14))
    return n * mod * env(t, 0.03, sec * 0.45)


def whoosh(sec=0.5):
    t = t_axis(sec)
    n = rng.normal(0, 1, len(t))
    out = np.zeros_like(n)
    seg = 8
    for k in range(seg):
        a, b = k * len(t) // seg, (k + 1) * len(t) // seg
        lo = 300 + 1500 * k / seg
        out[a:b] = bandpass(n, lo, lo * 3)[a:b]
    shape = np.sin(np.pi * t / sec) ** 1.5
    return out * shape


def tap():
    return click(0.05, [(1900, 1.0), (3800, 0.25)], 0.008, 0.3, 1500, 6000)


def coin():
    t = t_axis(0.7)
    x = (np.sin(2 * np.pi * 2093 * t) + 0.7 * np.sin(2 * np.pi * 2637 * t + 1) +
         0.25 * np.sin(2 * np.pi * 5410 * t)) * env(t, 0.002, 0.22)
    buf = np.zeros(int(SR * 0.85))
    place(buf, x, 0)
    place(buf, 0.6 * x, 0.09)
    return buf


def gavel():
    t = t_axis(0.35)
    thump = np.sin(2 * np.pi * (110 + 60 * np.exp(-t / 0.02)) * t) * env(t, 0.001, 0.09)
    wood = click(0.12, [(900, 1.0), (1650, 0.6), (2800, 0.3)], 0.03, 0.8, 600, 4000)
    buf = np.zeros(len(t))
    place(buf, thump, 0)
    place(buf, 0.8 * wood, 0)
    return buf


def tick():
    return click(0.06, [(1250, 1.0), (2500, 0.4)], 0.012, 0.5, 900, 5000)


def carve():
    t = t_axis(0.2)
    buf = np.zeros(len(t))
    place(buf, 0.6 * np.sin(2 * np.pi * (180 + 80 * np.exp(-t / 0.015)) * t) * env(t, 0.001, 0.05), 0)
    place(buf, click(0.12, [(2600, 1.0), (4300, 0.5)], 0.025, 0.9, 1500, 8000), 0.004)
    return buf


def unfold():
    buf = np.zeros(int(SR * 0.6))
    for k in range(4):
        place(buf, (0.6 + 0.4 * k / 3) * rustle(0.18), 0.12 * k)
    return buf


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("snip", snip())
    save("rustle", rustle(), 0.6)
    save("whoosh", whoosh(), 0.6)
    save("tap", tap(), 0.5)
    save("coin", coin(), 0.7)
    save("gavel", gavel())
    save("tick", tick(), 0.6)
    save("carve", carve())
    save("unfold", unfold(), 0.6)
    print("ok ->", os.path.abspath(OUT))
