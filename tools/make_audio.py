#!/usr/bin/env python3
"""Generate every sound in the game.

Same principle as the art: synthesised in code rather than sourced, so the
whole project stays self-contained and a sound can be re-tuned by editing a
number instead of hunting for a replacement file.

    python tools/make_audio.py

Writes 22.05kHz 16-bit mono WAVs to audio/. That rate is deliberate — it is
plenty for short blips and keeps the files tiny.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio")
RATE = 22050


# ---------------------------------------------------------------- helpers

def envelope(n, attack=0.01, decay=0.9, sustain=0.0):
    """Simple AD envelope as a list of gains, one per sample."""
    a = max(1, int(n * attack))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / float(a))
        else:
            t = (i - a) / float(max(1, n - a))
            out.append(max(sustain, (1.0 - t) ** (1.0 / max(0.05, decay))))
    return out


def tone(freq, secs, kind="sine", detune=0.0):
    n = int(RATE * secs)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq * (1.0 + detune * i / float(n))
        phase += 2.0 * math.pi * f / RATE
        if kind == "sine":
            out.append(math.sin(phase))
        elif kind == "square":
            out.append(1.0 if math.sin(phase) >= 0 else -1.0)
        elif kind == "tri":
            out.append(2.0 / math.pi * math.asin(math.sin(phase)))
        else:  # noise
            out.append(random.uniform(-1.0, 1.0))
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    return out


def apply_env(samples, **kw):
    env = envelope(len(samples), **kw)
    return [s * e for s, e in zip(samples, env)]


def save(name, samples, gain=0.5):
    peak = max(1e-6, max(abs(s) for s in samples))
    data = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s / peak * gain)) * 32767))
        for s in samples)
    path = os.path.join(OUT, name + ".wav")
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(data)
    w.close()
    print("audio/%-16s %5.2fs" % (name + ".wav", len(samples) / float(RATE)))


# ----------------------------------------------------------------- sounds

def make_bell():
    """The object the game is named after. Struck metal: a fundamental plus
    inharmonic partials, ringing for a good while."""
    secs = 1.8
    layers = []
    for mult, gain, dec in ((1.0, 1.0, 0.55), (2.76, 0.55, 0.45),
                            (5.40, 0.30, 0.35), (8.93, 0.16, 0.3)):
        t = tone(660 * mult, secs)
        layers.append([s * gain for s in apply_env(t, attack=0.002, decay=dec)])
    save("bell", mix(*layers), 0.8)


def make_step():
    """A soft scuff. Short noise burst, low-passed by averaging."""
    n = int(RATE * 0.07)
    raw = [random.uniform(-1, 1) for _ in range(n)]
    smooth = []
    acc = 0.0
    for v in raw:
        acc = acc * 0.72 + v * 0.28
        smooth.append(acc)
    save("step", apply_env(smooth, attack=0.02, decay=0.3), 0.28)


def make_stuck():
    """A student getting stuck: a small falling two-tone, questioning."""
    a = apply_env(tone(520, 0.10, "tri"), attack=0.01, decay=0.5)
    b = apply_env(tone(392, 0.16, "tri"), attack=0.01, decay=0.4)
    save("stuck", a + b, 0.42)


def make_help():
    """Unsticking someone: the reward moment. Rising, bright, brief."""
    a = apply_env(tone(523, 0.08, "sine"), attack=0.005, decay=0.5)
    b = apply_env(tone(784, 0.14, "sine"), attack=0.005, decay=0.45)
    shimmer = apply_env(tone(1568, 0.14, "sine"), attack=0.005, decay=0.3)
    return save("help", a + [x + y * 0.3 for x, y in zip(b, shimmer)], 0.5)


def make_paper():
    """Picking up a sheet: a rustle."""
    n = int(RATE * 0.16)
    out = []
    acc = 0.0
    for i in range(n):
        v = random.uniform(-1, 1)
        acc = acc * 0.5 + v * 0.5
        # a couple of crinkle bursts rather than flat noise
        burst = 1.0 if (i % 1900) < 700 else 0.35
        out.append(acc * burst)
    save("paper", apply_env(out, attack=0.05, decay=0.4), 0.3)


def make_coins():
    """Payday. Several small high chinks, slightly detuned."""
    out = []
    for i, f in enumerate((1046, 1318, 1568)):
        t = apply_env(tone(f, 0.13, "tri", detune=0.02), attack=0.003, decay=0.4)
        pad = [0.0] * int(RATE * 0.045 * i)
        out = mix(out + [0.0] * len(t), pad + t) if out else pad + t
    save("coins", out, 0.45)


def make_blip():
    """Moving the selection in a menu. Must be very short and very dull —
    it is the sound you will hear most often in the whole game."""
    save("blip", apply_env(tone(880, 0.045, "square"), attack=0.002, decay=0.6), 0.16)


def make_confirm():
    a = apply_env(tone(659, 0.06, "square"), attack=0.002, decay=0.5)
    b = apply_env(tone(988, 0.10, "square"), attack=0.002, decay=0.5)
    save("confirm", a + b, 0.24)


def make_deny():
    save("deny", apply_env(tone(180, 0.14, "square"), attack=0.003, decay=0.5), 0.25)


def make_grade():
    """The end-of-day sting. A small major chord, warm."""
    layers = [apply_env(tone(f, 0.85, "tri"), attack=0.01, decay=0.5)
              for f in (392, 494, 587, 784)]
    save("grade", mix(*layers), 0.5)


def make_start():
    """Starting a lesson: settle-down, attention-please."""
    a = apply_env(tone(440, 0.12, "tri"), attack=0.01, decay=0.5)
    b = apply_env(tone(587, 0.20, "tri"), attack=0.01, decay=0.4)
    save("start", a + b, 0.45)


if __name__ == "__main__":
    random.seed(7)          # same sounds every run
    os.makedirs(OUT, exist_ok=True)
    make_bell()
    make_step()
    make_stuck()
    make_help()
    make_paper()
    make_coins()
    make_blip()
    make_confirm()
    make_deny()
    make_grade()
    make_start()
    print("done")
