#!/usr/bin/env python3
"""Turbo Thruster "metal" sound effects (fully synthesized, no samples).

Reuses the guitar/drum voices of synth_metal.py. Writes 16-bit 44.1 kHz mono
WAVs to assets/sfx_metal/, peak-normalised to -1 dBFS (the very frequent shot
and hit sit lower). Positive sounds use distorted power chords + rising
sweeps kept under ~4 kHz instead of high beeps.

    VENV/bin/python tools/music/sfx_metal.py          # render + report
    VENV/bin/python tools/music/sfx_metal.py --check  # report only
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth_metal as M  # noqa: E402
from synth import SR, saw, square, sine, lp, hp, bp, fade, mtof  # noqa: E402

OUT_DIR = os.path.join(M.S.ROOT, "assets", "sfx_metal")
PEAK_DB = {"shot": -7.0, "hit": -8.0, "ui_move": -4.0}  # default -1 dBFS
CENTROID_WARN = 3000.0


def tt(n):
    return np.arange(n) / SR


def nlen(d):
    return int(d * SR)


def env_exp(n, tau, att=0.001):
    t = tt(n)
    return np.minimum(t / att, 1) * np.exp(-t / tau)


def sweep_sine(f0, f1, n, tau):
    t = tt(n)
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def chord(root, dur, rng, mute=False, tau=0.25, drive=16.0):
    x = M.gtr_hit([root, root + 7, root + 12], dur, mute, rng, 0.09, drive)
    x = M.cabinet(x) * env_exp(len(x), tau, 0.002)
    return x


def boom(dur, f0=110, f1=35, tau=0.3):
    n = nlen(dur)
    return np.tanh(1.6 * sweep_sine(f0, f1, n, 0.04) * env_exp(n, tau, 0.0005))


def noise_burst(rng, dur, cut, tau, drive=3.0):
    n = nlen(dur)
    return np.tanh(drive * lp(rng.standard_normal(n), cut, 4)) * env_exp(n, tau, 0.0005)


def pad(x, dur):
    n = nlen(dur)
    out = np.zeros(n)
    out[:min(n, len(x))] = x[:n]
    return out


def mix(dur, *parts):
    out = np.zeros(nlen(dur))
    for x, g, at in parts:
        i = nlen(at)
        seg = x[:len(out) - i]
        out[i:i + len(seg)] += g * seg
    return out


# ---------------------------------------------------------------- the sounds
def shot(rng):
    n = nlen(0.07)
    body = sweep_sine(260, 90, n, 0.015) * env_exp(n, 0.025, 0.0005)
    zap = lp(square(380 * np.exp(-tt(n) / 0.03) + 120, n), 1500) * env_exp(n, 0.012, 0.0005)
    return fade(np.tanh(1.5 * (body + 0.35 * zap)), 0.0005, 0.01)


def charge(rng):
    n = nlen(0.6)
    t = tt(n)
    k = t / t[-1]
    f = mtof(40) * 2 ** (7 * k / 12)
    x = saw(f, n) + saw(f * 1.006, n) + saw(f * 1.5, n)
    x = M.distort(0.25 * lp(x, 1800), 10.0)
    x = M.cabinet(x)
    x = M.S.lp_var(x, 400 + 2600 * k ** 1.5, 1.2)
    nz = M.S.lp_var(rng.standard_normal(n), 300 + 2500 * k ** 2, 2.0) * 0.25
    return fade((x + nz) * k ** 1.6, 0.01, 0.03)


def charge_shot(rng):
    return fade(mix(0.8, (chord(36, 0.8, rng, tau=0.3), 1.0, 0), (boom(0.8, 120, 32, 0.3), 1.1, 0),
                    (noise_burst(rng, 0.4, 2500, 0.08), 0.5, 0)), 0.0005, 0.05)


def hit(rng):
    n = nlen(0.06)
    x = M.metal_noise(rng, n, (520, 760, 1130, 1530))
    x = bp(x, 600, 2800) * env_exp(n, 0.012, 0.0003)
    x += 0.6 * sweep_sine(400, 180, n, 0.01) * env_exp(n, 0.015, 0.0003)
    return fade(np.tanh(1.5 * x), 0.0003, 0.01)


def small_dest(rng):
    return fade(mix(0.3, (noise_burst(rng, 0.3, 2200, 0.07, 5.0), 0.8, 0), (boom(0.3, 140, 45, 0.08), 1.0, 0)),
                0.0005, 0.03)


def middle_dest(rng):
    return fade(mix(0.6, (noise_burst(rng, 0.6, 1800, 0.18, 4.0), 0.8, 0), (boom(0.6, 110, 35, 0.2), 1.0, 0),
                    (chord(38, 0.3, rng, mute=True, tau=0.08), 0.5, 0),
                    (noise_burst(rng, 0.4, 1200, 0.1, 4.0), 0.4, 0.08)), 0.0005, 0.05)


def boss_dest(rng):
    rumble = lp(noise_burst(rng, 2.0, 1500, 0.7, 3.0), 900)
    parts = [(boom(2.0, 100, 28, 0.7), 1.1, 0), (noise_burst(rng, 0.8, 2500, 0.2, 5.0), 0.7, 0),
             (rumble, 0.6, 0.05), (chord(33, 2.0, rng, tau=0.9), 0.8, 0.02),
             (boom(1.2, 90, 30, 0.4), 0.7, 0.35), (noise_burst(rng, 0.6, 1600, 0.2, 4.0), 0.4, 0.35)]
    return fade(mix(2.0, *parts), 0.0005, 0.15)


def myship_dest(rng):
    n = nlen(1.2)
    t = tt(n)
    f = 40 + 180 * np.exp(-t / 0.35)
    tone = M.distort(0.3 * lp(saw(f, n) + saw(f * 1.01, n) + saw(f * 1.5, n), 1500), 9.0)
    tone = M.cabinet(tone) * env_exp(n, 0.5, 0.003)
    parts = [(M.make_kick(rng, 0.25), 1.0, 0), (boom(1.2, 120, 30, 0.35), 0.9, 0),
             (noise_burst(rng, 0.7, 2000, 0.18, 4.0), 0.6, 0), (tone, 0.8, 0.02)]
    return fade(mix(1.2, *parts), 0.0005, 0.1)


def extend(rng):
    n = nlen(0.5)
    t = tt(n)
    k = t / t[-1]
    stab = chord(40, 0.32, rng, tau=0.18, drive=12.0)
    f = mtof(52) * 2 ** (12 * k ** 1.3 / 12)
    up = lp(saw(f, n) + saw(f * 1.007, n), 2500) * 0.3
    nz = M.S.lp_var(rng.standard_normal(n), 300 + 2500 * k, 2.0) * 0.15
    swell = (up + nz) * np.sin(np.pi * np.minimum(k * 1.05, 1)) ** 0.7
    out = mix(0.5, (stab, 1.0, 0), (swell, 0.8, 0.04), (boom(0.2, 150, 60, 0.05), 0.5, 0))
    return fade(lp(out, 4000, 4), 0.0005, 0.04)


def timeup_beep(rng):
    def blip():
        m = nlen(0.22)
        tone = M.distort(0.3 * lp(square(mtof(45), m) + square(mtof(45) * 1.5, m), 1500), 6.0)
        return lp(tone, 2000) * env_exp(m, 0.08, 0.002) * 0.6 + chord(38, 0.22, rng, True, 0.07)
    b = blip()
    return fade(mix(0.6, (b, 1.0, 0), (b, 1.0, 0.28)), 0.0005, 0.03)


def ui_move(rng):
    n = nlen(0.04)
    x = sine(620, n) * env_exp(n, 0.01, 0.001) + 0.5 * sine(310, n) * env_exp(n, 0.015, 0.001)
    return fade(lp(x, 2000), 0.001, 0.008)


def ui_confirm(rng):
    return fade(lp(chord(45, 0.25, rng, tau=0.08, drive=8.0), 3500), 0.0005, 0.03)


SOUNDS = [("shot", shot), ("charge", charge), ("charge_shot", charge_shot), ("hit", hit),
          ("small_dest", small_dest), ("middle_dest", middle_dest), ("boss_dest", boss_dest),
          ("myship_dest", myship_dest), ("extend", extend), ("timeup_beep", timeup_beep),
          ("ui_move", ui_move), ("ui_confirm", ui_confirm)]


def centroid(x):
    mag = np.abs(np.fft.rfft(x))
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return float(np.sum(f * mag) / np.sum(mag))


def render():
    import soundfile as sf
    os.makedirs(OUT_DIR, exist_ok=True)
    for i, (name, fn) in enumerate(SOUNDS):
        x = fn(np.random.default_rng(900 + i))
        x = hp(x, 30)
        x = x / np.max(np.abs(x)) * 10 ** (PEAK_DB.get(name, -1.0) / 20)
        sf.write(os.path.join(OUT_DIR, name + ".wav"), x, SR, subtype="PCM_16")


def check():
    import soundfile as sf
    for name, _ in SOUNDS:
        x, sr = sf.read(os.path.join(OUT_DIR, name + ".wav"))
        c = centroid(x)
        flag = "  <-- SHRILL?" if c > CENTROID_WARN else ""
        print(f"{name:12s} {len(x) / sr * 1000:6.0f} ms  peak {20 * np.log10(np.max(np.abs(x))):5.1f} dBFS  "
              f"centroid {c:6.0f} Hz  ch {x.ndim} sr {sr}{flag}")


if __name__ == "__main__":
    if "--check" not in sys.argv:
        render()
    check()
