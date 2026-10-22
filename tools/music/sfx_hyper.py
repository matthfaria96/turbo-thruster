#!/usr/bin/env python3
"""Turbo Thruster "Hyperdrive" sound effects (fully synthesized, no samples).

Club-style hits built from the voices of synth_hyper.py: supersaw stabs,
hardstyle / gabber kicks, white-noise risers and downlifters, impacts,
piano-like plucks and a synthetic formant "hey!" chop. Every sound is kept
dark enough (spectral centroid under ~3 kHz) to stay hyped without being
shrill. Writes 16-bit 44.1 kHz mono WAVs to assets/sfx_hyper/, peak-normalised
to -1 dBFS; the very frequent shot / hit / ui_move sit lower.

    VENV/bin/python tools/music/sfx_hyper.py          # render + report
    VENV/bin/python tools/music/sfx_hyper.py --check  # report only
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth_hyper as H  # noqa: E402
from synth import SR, saw, square, sine, lp, hp, bp, fade, mtof  # noqa: E402

OUT_DIR = os.path.join(H.S.ROOT, "assets", "sfx_hyper")
PEAK_DB = {"shot": -9.0, "hit": -10.0, "ui_move": -7.0}  # default -1 dBFS
CENTROID_WARN = 3000.0


def tt(n):
    return np.arange(n) / SR


def nlen(d):
    return int(d * SR)


def env_exp(n, tau, att=0.001):
    t = tt(n)
    return np.minimum(t / att, 1) * np.exp(-t / tau)


def mono(x):
    return x.mean(0) if np.ndim(x) == 2 else x


def mix(dur, *parts):
    out = np.zeros(nlen(dur))
    for x, g, at in parts:
        i = nlen(at)
        seg = mono(x)[:len(out) - i]
        out[i:i + len(seg)] += g * seg
    return out


def stab(midis, dur, rng, cut0=3200, cut1=700, tau=0.12, voices=9):
    """Supersaw chord stab whose low-pass closes from cut0 to cut1 (mono sum)."""
    n = nlen(dur)
    t = tt(n)
    x = sum(mono(H.ssaw(mtof(m), n, rng, voices, 30)) for m in midis)
    x = H.S.lp_var(x, cut1 + (cut0 - cut1) * np.exp(-t / tau), 1.1, 32)
    return x * env_exp(n, dur * 0.45, 0.002)


def boom(dur, f0=120, f1=38, tau=0.3):
    n = nlen(dur)
    t = tt(n)
    f = f1 + (f0 - f1) * np.exp(-t / 0.04)
    return np.tanh(1.6 * np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, tau, 0.0005))


def crunch(rng, dur, cut, tau, drive=4.0):
    n = nlen(dur)
    x = np.tanh(drive * lp(rng.standard_normal(n), cut, 4)) * env_exp(n, tau, 0.0005)
    return np.round(x * 24) / 24  # light bit-crush for grit (filtered below)


def kick(kind, midi, beat):
    return H.make_kick(kind, midi, beat)


# ---------------------------------------------------------------- the sounds
def shot(rng):
    n = nlen(0.07)
    t = tt(n)
    f = mtof(69) * 2 ** (-12 * (1 - np.exp(-t / 0.02)) / 12)
    zap = H.S.lp_var(saw(f, n) + 0.6 * square(f * 1.01, n, 0.3), 400 + 2000 * np.exp(-t / 0.012), 1.4, 32)
    body = sine(260 * np.exp(-t / 0.03) + 110, n)
    return fade((0.6 * zap + 0.8 * body) * env_exp(n, 0.022, 0.0008), 0.0005, 0.012)


def charge(rng):
    n = nlen(0.6)
    t = tt(n)
    k = t / t[-1]
    f = mtof(45) * 2 ** (12 * k ** 1.4 / 12)
    x = mono(H.ssaw(f, n, rng, 9, 35)) + 0.5 * mono(H.ssaw(f * 2, n, rng, 5, 25))
    x = H.S.lp_var(x, 350 + 2300 * k ** 1.5, 1.6, 32)
    nz = H.S.lp_var(rng.standard_normal(n), 300 + 2600 * k ** 2, 1.5, 32) * 0.3
    gate = 0.65 + 0.35 * np.cos(2 * np.pi * np.cumsum(6 + 22 * k) / SR)  # accelerating 'roll' pump
    return fade((x + nz) * gate * k ** 1.5, 0.01, 0.025)


def charge_shot(rng):
    st = stab([45, 52, 57, 60], 0.8, rng, 3400, 600, 0.15)
    parts = [(st, 0.9, 0), (kick("hardstyle", 33, 0.75), 1.0, 0),
             (crunch(rng, 0.35, 2200, 0.07), 0.35, 0), (boom(0.8, 110, 36, 0.25), 0.6, 0)]
    return fade(lp(mix(0.8, *parts), 5000, 2), 0.0005, 0.06)


def hit(rng):
    n = nlen(0.06)
    t = tt(n)
    tick = sine(780 * (1 + 0.3 * np.exp(-t / 0.004)), n) * env_exp(n, 0.012, 0.0004)
    nz = bp(rng.standard_normal(n), 500, 2400) * env_exp(n, 0.006, 0.0003) * 0.5
    return fade(lp(tick + nz + 0.4 * sine(330, n) * env_exp(n, 0.015), 3000), 0.0003, 0.01)


def small_dest(rng):
    parts = [(crunch(rng, 0.3, 2000, 0.07, 5.0), 0.7, 0), (kick("gabber", 36, 0.3), 0.9, 0),
             (stab([50, 57], 0.22, rng, 2500, 400, 0.04, 5), 0.4, 0.005)]
    return fade(lp(mix(0.3, *parts), 3500, 2), 0.0005, 0.03)


def middle_dest(rng):
    n = nlen(0.45)
    t = tt(n)
    fall = mono(H.ssaw(mtof(52) * 2 ** (-12 * t / t[-1] / 12), n, rng, 7, 35))
    fall = lp(fall, 1800) * env_exp(n, 0.15, 0.002)
    parts = [(kick("gabber", 33, 0.5), 1.0, 0), (crunch(rng, 0.6, 1800, 0.16, 4.0), 0.6, 0),
             (boom(0.6, 110, 35, 0.2), 0.7, 0), (fall, 0.45, 0.01), (crunch(rng, 0.4, 1200, 0.1), 0.35, 0.09)]
    return fade(lp(mix(0.6, *parts), 4000, 2), 0.0005, 0.05)


def boss_dest(rng):
    imp = mono(H.S.make_impact(rng))
    down = mono(H.downlifter(rng, 2.0))
    down = lp(down, 3000)
    chord = stab([33, 45, 48, 52, 57], 2.0, rng, 2600, 500, 0.5)
    parts = [(imp, 1.0, 0), (kick("raw", 33, 0.8), 0.9, 0), (boom(2.0, 100, 28, 0.7), 0.8, 0),
             (crunch(rng, 0.8, 2200, 0.22, 5.0), 0.5, 0), (down, 0.7, 0.05), (chord, 0.6, 0.02),
             (kick("raw", 33, 0.8), 0.6, 0.38), (crunch(rng, 0.6, 1500, 0.18), 0.3, 0.38)]
    return fade(lp(mix(2.0, *parts), 4500, 2), 0.0005, 0.2)


def myship_dest(rng):
    n = nlen(1.2)
    t = tt(n)
    f = mtof(57) * 2 ** (-24 * (1 - np.exp(-t / 0.45)) / 12)
    fall = mono(H.ssaw(f, n, rng, 9, 40)) + 0.6 * mono(H.ssaw(f * 1.5, n, rng, 5, 30))
    fall = H.S.lp_var(fall, 300 + 2200 * np.exp(-t / 0.3), 1.3, 32) * env_exp(n, 0.45, 0.003)
    parts = [(kick("hardstyle", 36, 0.7), 1.0, 0), (mono(H.S.make_impact(rng)), 0.7, 0),
             (crunch(rng, 0.7, 2000, 0.18), 0.45, 0), (fall, 0.8, 0.02)]
    return fade(lp(mix(1.2, *parts), 4500, 2), 0.0005, 0.1)


def extend(rng):
    n = nlen(0.5)
    t = tt(n)
    k = t / t[-1]
    st = stab([57, 61, 64, 69], 0.42, rng, 3000, 1100, 0.2)
    sweep = mono(H.ssaw(mtof(57) * 2 ** (12 * k ** 1.2 / 12), n, rng, 5, 30))
    sweep = lp(sweep, 2600) * np.sin(np.pi * np.minimum(k * 1.1, 1)) ** 0.8
    hey = H.chop(64, 0.22, "e", "i", rng, 0.4)
    out = mix(0.5, (st, 1.0, 0), (sweep, 0.35, 0.02), (hey, 0.55, 0.05), (boom(0.18, 140, 70, 0.05), 0.4, 0))
    return fade(lp(out, 4500, 2), 0.0005, 0.05)


def timeup_beep(rng):
    def pulse(dur):
        m = nlen(dur)
        t = tt(m)
        x = square(mtof(45), m, 0, 0.35) + 0.8 * saw(mtof(45) * 1.005, m) + 0.6 * square(mtof(57), m, 0.2)
        x = lp(np.tanh(1.5 * lp(x, 1400)), 1600)
        pump = np.minimum(t / 0.012, 1) * (1 - 0.55 * np.clip(t / dur, 0, 1) ** 2)
        return x * pump
    k = kick("happy", 33, 0.4)
    return fade(mix(0.6, (pulse(0.24), 0.8, 0), (k, 0.6, 0), (pulse(0.24), 0.8, 0.3), (k, 0.6, 0.3)), 0.0005, 0.03)


def ui_move(rng):
    n = nlen(0.04)
    x = sine(660, n) * env_exp(n, 0.008, 0.001) + 0.6 * sine(330, n) * env_exp(n, 0.012, 0.001)
    return fade(lp(x, 1800), 0.001, 0.008)


def ui_confirm(rng):
    out = mix(0.25, *[(H.pluck(m, 0.12, rng)[:nlen(0.25)], 1.0 if m < 64 else 0.7, 0.012 * i)
                      for i, m in enumerate((57, 61, 64, 69))])
    return fade(lp(out, 4000, 2), 0.0005, 0.03)


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
        x = hp(fn(np.random.default_rng(1900 + i)), 30)
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
