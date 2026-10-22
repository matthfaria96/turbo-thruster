#!/usr/bin/env python3
"""Turbo Thruster "metal" soundtrack generator (fully synthesized, no samples).

Industrial / modern-DOOM-style metal: down-tuned distorted power-chord guitars
(detuned saw/square voices -> pre-filter -> asymmetric two-stage clipping ->
cabinet EQ, double-tracked L/R), distorted synth bass, double-kick drums,
snare with room, crash/china/ride from summed square partials, sub drops,
screaming leads and a siren synth. Every sound is generated here; reuses the
DSP/encoding helpers of synth.py (which it does not modify).

    VENV/bin/python tools/music/synth_metal.py            # all tracks + check
    VENV/bin/python tools/music/synth_metal.py sector_c   # one track
    VENV/bin/python tools/music/synth_metal.py --check    # QA only

Output: assets/music_metal/*.ogg (Vorbis ~q5, 44.1 kHz stereo, -14 LUFS,
true peak < -1 dBTP). Loops are a whole number of bars; the rendered tail is
wrapped onto the head and loudness uses a static gain + memoryless soft clip.
"""
import os
import sys

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth as S  # noqa: E402
from synth import SR, saw, square, sine, lp, hp, bp, fade, pan2, mtof  # noqa: E402

TAIL_S = 4.0
OUT_DIR = os.path.join(S.ROOT, "assets", "music_metal")

# Section plans (type, bars). Types: I intro, A main riff, B breakdown, C heavy+lead.
PLAN_48 = [("I", 8), ("A", 16), ("B", 8), ("C", 8), ("A", 8)]
PLAN_80 = [("I", 8), ("A", 16), ("B", 16), ("C", 16), ("A", 16), ("C", 8)]
PLAN_96 = [("I", 8), ("A", 16), ("B", 16), ("C", 16), ("A", 16), ("C", 16), ("A", 8)]
PLAN_112 = [("I", 8), ("A", 16), ("B", 16), ("C", 16), ("A", 16), ("B", 8), ("C", 24), ("A", 8)]
PLAN_BOSS = [("I", 4), ("A", 12), ("B", 8), ("C", 16), ("A", 8)]

# name, bpm, key (low string midi), plan, style, seed
TRACKS = [
    ("menu", 100, 33, PLAN_48, "groove", 101),
    ("sector_a", 140, 36, PLAN_80, "punk", 202),
    ("sector_b", 150, 38, PLAN_80, "gallop", 303),
    ("sector_c", 160, 35, PLAN_96, "industrial", 404),
    ("sector_d", 170, 36, PLAN_96, "blast", 505),
    ("sector_e", 180, 37, PLAN_112, "relentless", 606),
    ("boss", 150, 33, PLAN_BOSS, "doom", 707),
]

# Riff legend (16 steps/bar): x = palm-muted low-root chug, lowercase o/h/m/t/v = open
# ringing power chord at progression root +0/+1/+3/+6/+7, uppercase = muted chord,
# '-' = ring on, '.' = silence.
RIFFS = {
    "groove": dict(A="o--.x.xxo--.x.x.", B="o-------x..x..x.", C="x.xxo-x.xxm-x.t-"),
    "punk": dict(A="O-O-O-O-O-O-o---", B="o-----x.x.o-----", C="xxxxO-xxxxM-xxT-"),
    "gallop": dict(A="x.xxx.xxx.xxm-v-", B="o--x..x.o--x.x..", C="xxxxxxxxo-xxm-xx"),
    "industrial": dict(A="x..xx..x.x.xo-..", B="x..x..x...x.x...", C="xxx.xxx.o-o-t-.."),
    "blast": dict(A="xxxxxxxxxxxxo---", B="o-------h-------", C="xxxxm-xxxxt-xxxx"),
    "relentless": dict(A="xxxxO-xxxxM-xxxx", B="o--.x.xo--.x.x..", C="xxxxxxxxh-xxt-xx"),
    "doom": dict(A="o-------x.x.m---", B="x..x..x.x..x..x.", C="o---h---o---t---"),
}
PROGS = {
    "groove": dict(I=[0, 0, 5, 3], A=[0, 0, 3, 5], B=[0, 1, 0, 6], C=[0, 3, 5, 1]),
    "punk": dict(I=[0, 5, 3, 7], A=[0, 5, 3, 7], B=[0, 3, 0, 5], C=[0, 0, 5, 3]),
    "gallop": dict(I=[0, 3, 5, 1], A=[0, 0, 3, 1], B=[0, 5, 0, 6], C=[0, 3, 1, 0]),
    "industrial": dict(I=[0, 1, 0, 6], A=[0, 0, 1, 0], B=[0, 0, 0, 0], C=[0, 3, 1, 6]),
    "blast": dict(I=[0, 3, 1, 5], A=[0, 1, 3, 1], B=[0, 3, 5, 6], C=[0, 0, 3, 1]),
    "relentless": dict(I=[0, 5, 3, 1], A=[0, 3, 0, 5], B=[0, 1, 0, 3], C=[0, 5, 3, 1]),
    "doom": dict(I=[0, 1, 0, 6], A=[0, 1, 0, 6], B=[0, 0, 0, 0], C=[0, 1, 3, 1]),
}
# Drum patterns for the A section: kick, snare, cymbal (h hat, o open hat, r ride, n china, c crash).
DRUMS_A = {
    "groove": ("x..x..x...x.x...", "....x.......x...", "r.r.r.r.r.r.r.r."),
    "punk": ("x..x.x..x..x.x..", "....x.......x...", "o.o.o.o.o.o.o.o."),
    "gallop": ("x.xxx.xxx.xxx.xx", "....x.......x...", "h.h.h.h.h.h.h.h."),
    "industrial": ("x...x...x...x..x", "....x.......x...", "h.hhh.hhh.hhh.hh"),
    "blast": ("xxxxxxxxxxxxxxxx", "....x.......x...", "r.r.r.r.r.r.r.r."),
    "relentless": ("xxxxxxxxxxxxxxxx", "....x.......x...", "r.r.r.r.r.r.r.r."),
    "doom": ("x.....x.xx......", "........x.......", "n...n...n...n..."),
}
OPEN = {"o": 0, "h": 1, "m": 3, "t": 6, "v": 7}
SCALE = (0, 1, 3, 5, 7, 8, 10)  # phrygian-ish minor for leads


# ----------------------------------------------------------------- tone shaping
def peq(x, f0, db, q=1.0):
    a_ = 10 ** (db / 40)
    w = 2 * np.pi * f0 / SR
    al, c = np.sin(w) / (2 * q), np.cos(w)
    b = np.array([1 + al * a_, -2 * c, 1 - al * a_])
    a = np.array([1 + al / a_, -2 * c, 1 - al / a_])
    return signal.lfilter(b / a[0], a / a[0], x, axis=-1)


def cabinet(x):
    x = hp(x, 80, 2)
    x = peq(x, 120, 3.0, 0.9)
    x = peq(x, 400, -6.0, 1.3)
    x = peq(x, 2500, 3.0, 1.0)
    return lp(x, 5500, 4)


def distort(x, drive, bias=0.3):
    y = (np.tanh(drive * x + bias) - np.tanh(bias)) / (1 - np.tanh(bias))
    return np.clip(1.6 * y, -0.85, 0.95)  # asymmetric second stage


def gtr_hit(midis, dur, mute, rng, detune=0.08, drive=18.0):
    n = max(int(dur * SR), 64)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for m in midis:
        f = mtof(m)
        for c in (-detune, detune):
            x += saw(f * 2 ** ((c + rng.uniform(-0.02, 0.02)) / 12), n, rng.random())
        x += 0.5 * square(f * 2 ** (rng.uniform(-0.04, 0.04) / 12), n, rng.random())
    x = lp(hp(x, 90), 750 if mute else 2600)
    pre = np.minimum(t / 0.002, 1) * (np.exp(-t / 0.05) if mute else np.exp(-t / 3.0))
    y = distort(0.22 * x * pre, drive)
    gate = np.exp(-t / 0.085) if mute else np.ones(n)
    return fade(y * gate, 0.001, 0.008 if mute else 0.03)


def bass_hit(midi, dur, mute):
    n = max(int(dur * SR), 64)
    t = np.arange(n) / SR
    m = midi if midi <= 36 else midi - 12
    f = mtof(m)
    x = saw(f, n) + 0.4 * saw(f * 1.004, n)
    x = np.tanh(3.0 * lp(x, 900)) * 0.6 + 0.7 * sine(f if f < 45 else f / 2, n)
    env = np.exp(-t / 0.09) if mute else np.exp(-t / 2.0)
    return fade(lp(x, 1400) * env, 0.002, 0.01)


def lead_note(midi, dur, rng, kind="scream"):
    n = max(int(dur * SR), 64)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.25, 1)
    if kind == "siren":
        semis = 5 * (0.5 - 0.5 * np.cos(2 * np.pi * t / max(dur, 0.1)))
        f = mtof(midi) * 2 ** (semis / 12)
        x = square(f, n, rng.random()) + 0.7 * saw(f * 1.006, n, rng.random())
    else:
        f = mtof(midi) * vib
        x = saw(f, n, rng.random()) + saw(f * 1.005, n, rng.random()) + 0.4 * square(f * 0.5, n)
    y = distort(0.3 * lp(x, 3000), 7.0, 0.15)
    y = lp(hp(y, 250), 4200, 4)
    env = np.minimum(t / 0.01, 1) * (0.8 + 0.2 * np.exp(-t / 0.2))
    return fade(y * env, 0.003, 0.05)


def synth_stab(midis, dur, rng):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = sum(saw(mtof(m) * 2 ** (d / 1200), n, rng.random()) for m in midis for d in (-12, 12))
    y = lp(distort(0.15 * x, 4.0, 0.1), 3500) * np.exp(-t / (dur * 0.35))
    return fade(y, 0.002, 0.03)


# ------------------------------------------------------------------ drum kit
def make_kick(rng, dec):
    n = int(max(dec * 3, 0.12) * SR)
    t = np.arange(n) / SR
    f = 46 + 150 * np.exp(-t / 0.028)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / dec)
    click = hp(rng.standard_normal(n), 2500) * np.exp(-t / 0.0025) * 0.4
    beater = bp(rng.standard_normal(n), 1500, 4500) * np.exp(-t / 0.008) * 0.25
    x = np.tanh(1.8 * (body + click + beater))
    return fade(x / np.max(np.abs(x)), 0.0003, 0.01)


def make_snare(rng):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    tone = 0.7 * sine(185 * (1 + 0.4 * np.exp(-t / 0.008)), n) * np.exp(-t / 0.07)
    tone += 0.3 * sine(330, n) * np.exp(-t / 0.04)
    nz = bp(rng.standard_normal(n), 900, 7500) * np.exp(-t / 0.12)
    x = np.tanh(1.5 * (tone + nz))
    return fade(x / np.max(np.abs(x)), 0.0003, 0.01)


def metal_noise(rng, n, freqs):
    return sum(square(f * rng.uniform(0.99, 1.01), n, rng.random()) for f in freqs)


def make_cym(rng, kind):
    dur, dec, lo, hi, freqs = {
        "c": (2.2, 0.8, 4000, 12000, (431, 587, 739, 1023, 1307, 1663)),
        "n": (1.2, 0.35, 2500, 9000, (331, 467, 601, 853, 1117, 1471)),
        "r": (1.0, 0.3, 5000, 11000, (2210, 3170, 4530, 5880)),
        "h": (0.12, 0.03, 7000, 13000, (2910, 4330, 5470, 7010)),
        "o": (0.4, 0.12, 6000, 12000, (2910, 4330, 5470, 7010)),
    }[kind]
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = metal_noise(rng, n, freqs) + 1.5 * rng.standard_normal(n)
    if kind == "n":
        x = np.tanh(2.5 * x)
    x = bp(x, lo, hi, 2) * np.exp(-t / dec) * np.minimum(t / 0.001, 1)
    return fade(x / np.max(np.abs(x)), 0.0005, 0.02)


def make_tom(f0):
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    x = sine(f0 * (1 + 0.5 * np.exp(-t / 0.02)), n) * np.exp(-t / 0.15)
    return fade(np.tanh(1.5 * x), 0.0005, 0.01)


def make_clang(rng):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    x = metal_noise(rng, n, (211, 347, 523, 761, 1093))
    x = np.tanh(3 * bp(x, 400, 3500)) * np.exp(-t / 0.12)
    return fade(x / np.max(np.abs(x)), 0.0005, 0.01)


def make_subdrop(dur=1.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = sine(30 + 40 * np.exp(-t / 0.25), n) * np.exp(-t / (dur * 0.4))
    return fade(np.tanh(1.3 * x), 0.002, 0.05)


# ---------------------------------------------------------------------- song
class Song:
    def __init__(self, name, bpm, key, plan, style, seed):
        self.name, self.bpm, self.key, self.plan, self.style, self.seed = name, bpm, key, plan, style, seed
        self.bars = sum(b for _, b in plan)
        self.step = 60.0 / bpm / 4
        self.L = int(round(self.bars * 4 * 60 / bpm * SR))
        self.N = self.L + int(TAIL_S * SR)
        self.rng = np.random.default_rng(seed)
        names = ("gl", "gr", "bass", "kick", "snare", "cym", "fx", "lead", "synth")
        self.bus = {k: np.zeros(self.N) for k in names}
        self.cym_st = np.zeros((2, self.N))
        self.room = np.zeros(self.N)
        self.hall = np.zeros(self.N)
        r = self.rng
        kdec = min(0.22, self.step * 2.2)
        self.kicks = [make_kick(np.random.default_rng(seed + i), kdec) for i in range(3)]
        self.snares = [make_snare(np.random.default_rng(seed + 10 + i)) for i in range(3)]
        self.cyms = {k: make_cym(np.random.default_rng(seed + 20 + i), k) for i, k in enumerate("cnrho")}
        self.toms = [make_tom(f) for f in (150, 110, 82)]
        self.clang = make_clang(r)
        self.sub = make_subdrop()

    def pos(self, bar, step):
        return int(round((bar * 16 + step) * self.step * SR))

    def add(self, buf, x, at):
        at = max(at, 0)
        if at >= self.N:
            return
        x = x[..., :self.N - at]
        buf[..., at:at + x.shape[-1]] += x


def parse_riff(pat):
    """-> list of (step, length_steps, char)."""
    ev = []
    for i, ch in enumerate(pat):
        if ch in "-.":
            continue
        j = i + 1
        while j < 16 and pat[j] == "-":
            j += 1
        ev.append((i, j - i, ch))
    return ev


def riff_for(song, kind, bar_in_sec, sec_bars):
    if kind == "I":
        last = bar_in_sec == sec_bars - 1
        return "o-------x.x.xxxx" if last else "o---------------"
    pat = RIFFS[song.style][kind]
    if kind == "A" and bar_in_sec % 4 == 3:  # turnaround variation
        pat = pat[:12] + "xxxx"
    return pat


def guitar_bar(song, bar, pat, prog_root):
    for step, ln, ch in parse_riff(pat):
        low = ch == "x"
        mute = low or ch.isupper()
        root = song.key if low else song.key + prog_root + OPEN.get(ch.lower(), 0)
        notes = [root, root + 7] if low else [root, root + 7, root + 12]
        dur = min(song.step * 0.95, 0.17) if mute else ln * song.step * 0.98
        at = song.pos(bar, step)
        for side, det, off in (("gl", 0.07, 0.0), ("gr", 0.11, 0.004)):
            jit = off + song.rng.uniform(-0.002, 0.002)
            song.add(song.bus[side], gtr_hit(notes, dur, mute, song.rng, det), at + int(jit * SR))
        song.add(song.bus["bass"], bass_hit(root, dur, mute), at)


def hit(song, kind, at, vel=1.0):
    r = song.rng
    if kind == "k":
        song.add(song.bus["kick"], song.kicks[r.integers(3)] * vel * r.uniform(0.9, 1.0), at)
    elif kind == "s":
        x = song.snares[r.integers(3)] * vel * r.uniform(0.92, 1.0)
        song.add(song.bus["snare"], x, at)
        song.add(song.room, x, at)
    elif kind in "t":
        song.add(song.bus["snare"], song.toms[r.integers(3)] * vel * 0.9, at)
    elif kind == "g":
        song.add(song.bus["fx"], song.clang * vel, at)
    else:
        pan = {"c": -0.4, "n": 0.45, "r": 0.3, "h": -0.25, "o": -0.25}[kind]
        g = {"c": 0.9, "n": 0.75, "r": 0.45, "h": 0.35, "o": 0.5}[kind] * vel
        song.add(song.cym_st, pan2(song.cyms[kind] * g, pan), at)
        song.add(song.hall, song.cyms[kind] * g * 0.2, at)


def drum_pats(song, kind, riff):
    st = song.style
    if kind == "I":
        return "x...............", "................", "c..............."
    if kind == "B":
        k = "".join("x" if ch not in "-." else "." for ch in riff)
        return k, "........x.......", "n...n...n...n..."
    if kind == "C":
        if st == "blast":
            return "x.x.x.x.x.x.x.x.", ".x.x.x.x.x.x.x.x", "c...c...c...c..."
        if st == "doom":
            return "xxxxxxxx........", "........x.......", "c...c...c...c..."
        return "xxxxxxxxxxxxxxxx", "....x.......x...", "c...c...c...c..."
    return DRUMS_A[st]


def drums_bar(song, bar, kind, bis, sec_bars, riff):
    k, s, c = drum_pats(song, kind, riff)
    last = bis == sec_bars - 1
    if kind == "I" and bis >= sec_bars - 2:
        k, s, c = "x.......x.......", "....s.......s...", "h.h.h.h.h.h.h.h."
    for i in range(16):
        at = song.pos(bar, i)
        fill = last and i >= 12
        if fill:
            hit(song, "s" if i % 2 == 0 or kind == "I" else "t", at, 0.6 + 0.1 * (i - 12))
            continue
        if k[i] == "x":
            hit(song, "k", at, 1.0 if i % 4 == 0 else 0.85)
        if s[i] in "xs":
            hit(song, "s", at, 1.0 if s[i] == "x" else 0.8)
        if c[i] != ".":
            hit(song, "c" if (i == 0 and bis % 4 == 0) else c[i], at, 1.0 if i % 4 == 0 else 0.8)
    if bis == 0:
        hit(song, "c", song.pos(bar, 0))
    if song.style == "industrial" and kind in "AC":
        for i in (6, 13):
            hit(song, "g", song.pos(bar, i), 0.7)


def make_phrase(song, bars=2):
    r = song.rng
    out, t = [], 0
    base = song.key + 24
    deg = 0
    while t < bars * 16:
        ln = int(r.choice([2, 2, 4, 4, 6, 8]))
        deg = int(np.clip(deg + r.choice([-2, -1, 1, 1, 2, 3]), -2, 9))
        midi = base + 12 * (deg // 7) + SCALE[deg % 7]
        out.append((t, min(ln, bars * 16 - t), midi))
        t += ln
    return out


def lead_section(song, bar0, nbars, kind):
    phrase = make_phrase(song)
    for b in range(0, nbars, 2):
        for st, ln, midi in phrase:
            if b % 8 == 6 and st >= 16:
                midi += 2 if (midi - song.key) % 12 in (1, 3) else 0
            at = song.pos(bar0 + b, st)
            x = lead_note(midi, ln * song.step, song.rng)
            song.add(song.bus["lead"], x, at)
            song.add(song.hall, x * 0.35, at)


def siren_section(song, bar0, nbars):
    for b in range(0, nbars, 2):
        at = song.pos(bar0 + b, 0)
        x = lead_note(song.key + 31, 32 * song.step, song.rng, "siren")
        song.add(song.bus["lead"], x, at)
        song.add(song.hall, x * 0.4, at)


def compose(song):
    bar = 0
    progs = PROGS[song.style]
    for kind, nb in song.plan:
        song.add(song.bus["fx"], song.sub, song.pos(bar, 0)) if kind in "IBC" else None
        for bis in range(nb):
            pr = progs[kind][bis % 4]
            riff = riff_for(song, kind, bis, nb)
            guitar_bar(song, bar + bis, riff, pr)
            drums_bar(song, bar + bis, kind, bis, nb, riff)
            if kind == "C" and song.style in ("industrial", "relentless", "blast") and bis % 2 == 0:
                r = song.key + 24 + pr
                song.add(song.bus["synth"], synth_stab([r, r + 7, r + 12], 4 * song.step, song.rng),
                         song.pos(bar + bis, 0))
        if kind == "C":
            if song.style == "doom":
                siren_section(song, bar, nb)
            else:
                lead_section(song, bar, nb, kind)
        if song.style == "doom" and kind == "A":
            siren_section(song, bar + nb // 2, nb // 2)
        bar += nb


# -------------------------------------------------------------------- mixing
def rms_db(x, active=False):
    v = x[np.abs(x) > 1e-4] if active else x
    return 20 * np.log10(np.sqrt(np.mean(v ** 2)) + 1e-12) if v.size else -120.0


def level(x, target_db, active=False):
    return x * 10 ** ((target_db - rms_db(x, active)) / 20)


def mixdown(song):
    b = song.bus
    gl, gr = level(cabinet(b["gl"]), -19), level(cabinet(b["gr"]), -19)
    mix = pan2(gl, -0.8) + pan2(gr, 0.8)
    mix += pan2(level(lp(b["bass"], 2500), -21), 0)
    mix += pan2(level(b["kick"], -19), 0)
    snare = level(b["snare"], -24)
    room_ir = S.make_ir(song.seed + 1, rt=0.55, pre=0.006)
    sg = snare.copy()
    room_src = level(song.room, -24)
    mix += pan2(sg, 0)
    mix += 0.35 * np.vstack([signal.oaconvolve(room_src, room_ir[c])[:song.N] for c in range(2)])
    cym = song.cym_st * 10 ** ((-29 - rms_db(song.cym_st.mean(0))) / 20)
    mix += cym
    if np.any(b["fx"]):
        mix += pan2(level(b["fx"], -27), 0)
    if np.any(b["lead"]):
        mix += pan2(level(b["lead"], -20, True), 0.1)
    if np.any(b["synth"]):
        mix += pan2(level(b["synth"], -24, True), -0.1)
    hall_ir = S.make_ir(song.seed + 2, rt=1.8)
    hall = level(song.hall, -30) if np.any(song.hall) else song.hall
    mix += 0.5 * np.vstack([signal.oaconvolve(hall, hall_ir[c])[:song.N] for c in range(2)])
    mix = hp(mix, 28)
    out = mix[:, :song.L].copy()
    out[:, :song.N - song.L] += mix[:, song.L:]  # wrap tail -> seamless loop
    return out


def render(spec):
    song = Song(*spec)
    compose(song)
    x = mixdown(song)
    path = os.path.join(OUT_DIR, song.name + ".ogg")
    ceil_db, otp, lufs, tp = -2.0, 0.0, 0.0, 0.0
    for _ in range(5):
        y, lufs, tp = S.master(x, ceil_db)
        S.encode(y, path)
        _, otp = S.ebur128(["-i", path])
        if otp <= -1.1:
            break
        ceil_db -= 0.5
    print(f"{song.name}: {song.L / SR:.2f}s {lufs:.2f} LUFS tp {tp:.2f} | ogg tp {otp:.2f} (ceil {ceil_db})")


def check():
    total = 0
    for name, bpm, _, plan, *_ in TRACKS:
        bars = sum(b for _, b in plan)
        path = os.path.join(OUT_DIR, name + ".ogg")
        if not os.path.exists(path):
            continue
        x = S.decode(path)
        size = os.path.getsize(path)
        total += size
        lufs, tp = S.ebur128(["-i", path])
        expect = int(round(bars * 4 * 60 / bpm * SR))
        d = np.abs(np.diff(x, axis=1))
        seam = np.max(np.abs(x[:, 0] - x[:, -1]))
        print(f"{name:9s} {bpm}bpm {bars}bars {x.shape[1] / SR:7.2f}s (samples {x.shape[1]} vs {expect}) "
              f"{size / 1e6:.2f}MB | I {lufs:.1f} LUFS TP {tp:.1f} dBTP | seam jump {seam:.4f} "
              f"(p99 step {np.percentile(d, 99):.4f}, max {d.max():.4f})")
    print(f"total {total / 1e6:.2f} MB")


def main(argv):
    if "--check" in argv:
        return check()
    os.makedirs(OUT_DIR, exist_ok=True)
    wanted = [a for a in argv if not a.startswith("-")]
    for spec in TRACKS:
        if not wanted or spec[0] in wanted:
            render(spec)
    check()


if __name__ == "__main__":
    main(sys.argv[1:])
