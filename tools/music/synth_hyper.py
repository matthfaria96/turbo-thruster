#!/usr/bin/env python3
"""Turbo Thruster "Hyperdrive" soundtrack generator (fully synthesized, no samples).

Hard trance, euphoric hardstyle, happy hardcore, rawstyle, gabber, uptempo and
frenchcore, all generated in code: 9-voice panned unison supersaws + octave
layers, PWM hoover with glides, reese / rolling / reverse basses, hardstyle
kicks (transient + distorted tail tuned to the bass root), overdriven gabber
kicks, formant vocal chops (vowels only), piano-like plucks, noise risers,
impacts and 1/16-1/32 snare rolls. Plate reverb + ping-pong sends, sidechain
on everything but the drums. Reuses synth.py helpers (does not modify it).

    VENV/bin/python tools/music/synth_hyper.py            # all tracks + check
    VENV/bin/python tools/music/synth_hyper.py sector_c   # one track
    VENV/bin/python tools/music/synth_hyper.py --check    # QA only

Output: assets/music_hyper/*.ogg (Vorbis ~q6, 44.1 kHz stereo, -12 LUFS,
true peak < -1 dBTP). Each loop is a whole number of bars; the rendered tail is
wrapped onto the head, the sidechain curve and filter automation are periodic,
and loudness uses one static gain + memoryless soft clip, so the seam is clean.
"""
import os
import sys

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth as S  # noqa: E402
from synth import SR, saw, square, sine, lp, hp, bp, fade, pan2, mtof, adsr  # noqa: E402

TAIL_S = 5.0
TARGET_LUFS = -12.0
VORBIS_LEVEL = 0.4  # libsndfile compression level 0.4 -> Vorbis quality 0.6 (~q6)
OUT_DIR = os.path.join(S.ROOT, "assets", "music_hyper")
OPEN_HZ = 20000.0

# Hooks: 4 phrases of 2 bars (call, response, call, resolving response).
# Token "off.len": semitone offset from the lead tonic, length in 16ths; "r" rest; "~" glide in.
HOOKS = {
    "menu": ("12.3 15.3 19.2 17.3 15.3 12.2 15.3 12.3 10.2 12.3 7.3 r.2",
             "12.3 15.3 20.2 19.3 17.3 15.2 17.3 15.3 12.2 15.4 r.4",
             "12.3 15.3 19.2 17.3 15.3 12.2 15.3 12.3 10.2 12.3 15.3 r.2",
             "14.3 15.3 19.2 22.3 19.3 17.2 19.6 17.2 15.4 14.4"),
    "sector_a": ("7.2 7.2 10.2 12.4 10.2 7.2 5.2 7.2 7.2 10.2 15.4 14.2 12.4",
                 "15.2 15.2 14.2 12.4 10.2 12.2 15.2 20.6 19.2 15.4 12.4",
                 "12.2 12.2 15.2 17.4 15.2 12.2 10.2 12.2 12.2 15.2 20.4 19.2 17.4",
                 "18.2 19.2 21.2 22.4 21.2 19.2 18.2 19.6 21.2 18.8"),
    "sector_b": ("0.2 4.2 7.2 4.1 7.1 9.2 7.2 4.2 0.2 2.2 4.2 2.2 0.2 -3.4 -5.4",
                 "7.2 11.2 14.2 11.1 14.1 16.2 14.2 11.2 7.2 9.2 11.2 9.2 7.2 4.4 2.4",
                 "4.2 9.2 12.2 9.1 12.1 14.2 12.2 9.2 4.2 7.2 9.2 7.2 4.2 2.4 0.4",
                 "5.2 9.2 12.2 9.1 12.1 14.2 12.2 9.2 5.2 14.2 12.2 9.2 7.2 9.4 7.4"),
    "sector_c": ("0.4 ~3.2 ~0.2 7.4 ~5.2 3.2 0.4 ~3.2 ~0.2 -2.4 ~0.4",
                 "-4.4 ~0.2 ~3.2 7.4 ~8.2 7.2 3.4 ~0.2 3.2 7.8",
                 "0.4 ~3.2 ~0.2 7.4 ~10.2 12.2 12.4 ~10.2 7.2 3.4 ~5.4",
                 "-2.4 ~2.2 ~5.2 10.4 ~7.2 5.2 2.4 ~5.2 ~7.2 -2.8"),
    "sector_d": ("0.1 r.1 0.1 r.1 3.2 0.2 7.2 5.2 3.2 2.2 0.1 r.1 0.1 r.1 3.2 0.2 -2.4 -5.4",
                 "0.1 r.1 0.1 r.1 3.2 0.2 8.2 7.2 5.2 3.2 0.1 r.1 0.1 r.1 3.2 5.2 3.4 0.4",
                 "2.1 r.1 2.1 r.1 5.2 2.2 10.2 7.2 5.2 3.2 2.1 r.1 2.1 r.1 5.2 2.2 -2.4 2.4",
                 "7.1 r.1 7.1 r.1 11.2 7.2 14.2 12.2 11.2 7.2 11.1 r.1 11.1 r.1 14.2 11.2 7.4 11.4"),
    "sector_e": ("7.2 7.1 7.1 12.2 7.2 10.2 7.2 3.2 2.2 3.2 3.1 3.1 7.2 3.2 5.2 3.2 0.4",
                 "8.2 8.1 8.1 12.2 8.2 10.2 8.2 5.2 3.2 5.2 5.1 5.1 8.2 5.2 7.2 8.2 12.4",
                 "12.2 12.1 12.1 15.2 12.2 15.2 20.2 19.2 15.2 12.2 12.1 12.1 15.2 12.2 10.2 8.2 3.4",
                 "11.2 11.1 11.1 14.2 11.2 14.2 19.2 14.2 11.2 7.2 7.1 7.1 11.2 7.2 11.2 12.2 7.4"),
    "boss": ("~12.2 ~15.2 ~12.2 ~15.2 ~12.2 ~15.2 ~17.2 ~15.2 ~12.2 ~15.2 ~12.2 ~15.2 ~19.4 ~17.4",
             "~12.2 ~15.2 ~12.2 ~15.2 ~12.2 ~15.2 ~20.2 ~19.2 ~17.2 ~15.2 ~12.2 ~10.2 ~12.8",
             "~12.2 ~17.2 ~12.2 ~17.2 ~12.2 ~17.2 ~20.2 ~17.2 ~12.2 ~17.2 ~12.2 ~17.2 ~24.4 ~20.4",
             "~13.2 ~16.2 ~13.2 ~16.2 ~13.2 ~16.2 ~19.2 ~16.2 ~13.4 ~16.4 ~19.4 ~13.4"),
}

# Plans: I intro, U build, D drop, K breakdown, D2 second drop, O outro.
P96 = (("I", 8), ("U", 8), ("D", 24), ("K", 16), ("U", 8), ("D2", 24), ("O", 8))
TRACKS = [
    dict(name="menu", bpm=128, key=41, prog=((0, "m"), (8, "M"), (3, "M"), (10, "M")), seed=101,
         plan=(("I", 8), ("U", 4), ("D", 16), ("K", 12), ("U", 4), ("D2", 16), ("O", 4)),
         kick="trance", bass="rolling", lead="saw", mod=0),
    dict(name="sector_a", bpm=150, key=43, prog=((0, "m"), (8, "M"), (5, "m"), (7, "M")), seed=202,
         plan=(("I", 8), ("U", 8), ("D", 16), ("K", 16), ("U", 8), ("D2", 24), ("O", 8)),
         kick="hardstyle", bass="reverse", lead="saw", mod=0),
    dict(name="sector_b", bpm=165, key=38, prog=((0, "M"), (7, "M"), (9, "m"), (5, "M")), seed=303,
         plan=P96, kick="happy", bass="offbeat", lead="saw", mod=0, piano=True),
    dict(name="sector_c", bpm=160, key=40, prog=((0, "m"), (8, "M"), (0, "m"), (10, "M")), seed=404,
         plan=P96, kick="raw", bass="none", lead="hoover", mod=0),
    dict(name="sector_d", bpm=175, key=45, prog=((0, "m"), (8, "M"), (10, "M"), (7, "M")), seed=505,
         plan=(("I", 8), ("U", 8), ("D", 24), ("K", 16), ("U", 8), ("D2", 32), ("O", 8)),
         kick="gabber", bass="reese", lead="saw", mod=2),
    dict(name="sector_e", bpm=190, key=37, prog=((0, "m"), (5, "m"), (8, "M"), (7, "M")), seed=606,
         plan=(("I", 8), ("U", 8), ("D", 24), ("K", 16), ("U", 8), ("D2", 32), ("O", 16)),
         kick="uptempo", bass="offdist", lead="saw", mod=1),
    dict(name="boss", bpm=200, key=38, prog=((0, "m"), (8, "M"), (5, "m"), (7, "M")), seed=707,
         plan=(("I", 4), ("U", 4), ("D", 16), ("K", 8), ("U", 4), ("D2", 24), ("O", 4)),
         kick="french", bass="none", lead="alarm", mod=2),
]

# stem: (active RMS dB, bus, automation curve, reverb send, delay send, hp Hz, lp Hz)
STEMS = {
    "kick": (-14.5, "dry", "r", 0.0, 0.0, None, None),
    "bass": (-20.0, "duck", "r", 0.0, 0.0, None, 2500),
    "clap": (-24.0, "dry", None, 0.22, 0.0, 180, 11000),
    "hats": (-30.0, "duck", "r", 0.05, 0.0, 2500, 11500),
    "roll": (-27.0, "dry", None, 0.18, 0.0, 160, 7500),
    "lead": (-19.0, "duck", "m", 0.32, 0.20, 280, 10500),
    "chords": (-25.5, "duck", "m", 0.30, 0.0, 220, 5500),
    "pad": (-24.0, "duck", None, 0.55, 0.0, 160, 6000),
    "pluck": (-24.5, "duck", "m", 0.30, 0.32, 200, 8500),
    "chops": (-25.0, "duck", None, 0.30, 0.25, 220, 7000),
    "sub": (-26.0, "duck", None, 0.0, 0.0, None, 250),
    "fx": (-28.0, "duck", None, 0.20, 0.0, 120, 9000),
    "impact": (-23.0, "dry", None, 0.25, 0.0, 28, 9000),
    "crash": (-29.0, "duck", None, 0.15, 0.0, 400, 12000),
}


# --------------------------------------------------------------- oscillators
def spread_offsets(v):
    x = np.linspace(-1, 1, v)
    return np.sign(x) * np.abs(x) ** 1.4


def ssaw(freq, n, rng, voices=9, cents=30.0, width=0.9):
    """Unison supersaw: detuned saws with random phases, each voice panned across the field."""
    out = np.zeros((2, n))
    for x in spread_offsets(voices):
        g = 1.0 if abs(x) < 1e-9 else 0.8
        out += pan2(g * saw(freq * 2 ** (cents * x / 1200), n, rng.random()), width * x)
    return out / np.sqrt(voices)


def hoover(freq, n, rng):
    """Detuned PWM squares + octave-down saws, lightly driven (classic hoover)."""
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    for i, x in enumerate(spread_offsets(5)):
        pw = 0.5 + 0.36 * np.sin(2 * np.pi * (0.8 + 0.15 * i) * t + rng.random() * 6.28)
        out += pan2(square(freq * 2 ** (24 * x / 1200), n, rng.random(), pw), 0.85 * x)
    out = out / np.sqrt(5) + 0.9 * ssaw(freq * 0.5, n, rng, 5, 28, 0.6)
    return np.tanh(1.3 * out)


def stereo(x, p=0.0):
    return pan2(x, p) if np.ndim(x) == 1 else x


def repitch(x, semis):
    r = 2 ** (semis / 12)
    idx = np.arange(0, len(x) - 1, r)
    return np.interp(idx, np.arange(len(x)), x)


def peq(x, f0, db, q=1.0):
    a_, w = 10 ** (db / 40), 2 * np.pi * f0 / SR
    al, c = np.sin(w) / (2 * q), np.cos(w)
    b = np.array([1 + al * a_, -2 * c, 1 - al * a_])
    a = np.array([1 + al / a_, -2 * c, 1 - al / a_])
    return signal.lfilter(b / a[0], a / a[0], x, axis=-1)


# ---------------------------------------------------------------- kicks
KICKS = {  # length (beats), punch f0, tau, tail drive, punch gain, screech, gabber-style
    "trance": (0.62, 260, 0.030, 1.8, 1.0, False, False),
    "hardstyle": (0.50, 750, 0.010, 7.0, 0.9, False, False),
    "happy": (0.58, 600, 0.012, 5.0, 0.9, False, False),
    "raw": (0.94, 800, 0.009, 14.0, 0.8, True, False),
    "gabber": (0.86, 330, 0.024, 22.0, 0.7, False, True),
    "uptempo": (0.92, 700, 0.010, 16.0, 0.8, True, False),
    "french": (0.92, 650, 0.011, 18.0, 0.8, False, False),
}


def make_kick(kind, tail_midi, beat, seed=7):
    ln, f0, tau, drive, pg, screech, gab = KICKS[kind]
    n = int(ln * beat * SR)
    t = np.arange(n) / SR
    ft = 50.0 if kind == "trance" else mtof(tail_midi)
    f = ft + (f0 - ft) * np.exp(-t / tau) + 0.5 * ft * np.exp(-t / 0.018)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR)
    rng = np.random.default_rng(seed)
    click = bp(rng.standard_normal(n), 1800, 7500) * np.exp(-t / 0.0025)
    punch = np.tanh(2.2 * (body * np.exp(-t / 0.05) + 0.45 * click))
    life = np.clip(1 - t / t[-1], 0, 1)
    if gab:  # overdriven 909: long sine decay crushed into a square-ish "doof"
        amp = 1 / (1 + (t / (0.55 * ln * beat)) ** 3)
        tail = np.tanh(drive * body * amp) * life ** 0.4
        tail = lp(peq(tail, 900, 4.0, 0.8), 5200, 4)
        x = 0.55 * punch * np.exp(-t / 0.02) + tail
    else:
        tail = np.tanh(drive * body * life ** 0.5 * (1 - np.exp(-t / 0.008))) * life ** 0.35
        tail = peq(tail, 3 * ft, 3.0, 1.2)
        if screech:
            cut = 500 + 2600 * np.exp(-t / 0.09) + 900 * np.exp(-((t - 0.5 * t[-1]) / 0.05) ** 2)
            tail = 0.7 * tail + 0.5 * S.lp_var(tail, cut, 4.0)
        tail = lp(tail, 5500 if drive > 4 else 2500, 4)
        mixk = np.minimum(t / 0.025, 1)
        x = pg * punch * (1 - 0.7 * mixk) + (0.15 if kind == "trance" else 0.75) * tail * mixk
    x = lp(hp(x, 30), 11000, 2)
    return fade(x / np.max(np.abs(x)), 0.0004, 0.008)


# ---------------------------------------------------------------- voices
def pluck(midi, dur, rng):
    """Piano-like pluck: slightly inharmonic additive partials, two detuned strings, hammer."""
    f = mtof(midi)
    n = int((min(dur, 0.7) + 0.45) * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for det, g in ((1.0, 1.0), (1.0016, 0.6)):
        for k in range(1, 10):
            fk = f * det * k * np.sqrt(1 + 0.0004 * k * k)
            if fk > 8000:
                break
            x += g * np.sin(2 * np.pi * fk * t + rng.random() * 6.28) * np.exp(-t * (2.2 + 1.9 * k)) / k ** 1.15
    x += 0.15 * bp(rng.standard_normal(n), 700, 3000) * np.exp(-t / 0.004)
    x *= np.minimum(t / 0.0015, 1) * np.where(t > dur, np.exp(-(t - dur) / 0.09), 1.0)
    return fade(x, 0.0005, 0.02)


def bass_note(kind, midi, dur, rng):
    n = max(int(dur * SR), 64)
    t = np.arange(n) / SR
    f = mtof(midi)
    if kind == "reese":
        x = saw(f * 2 ** (0.14 / 12), n, rng.random()) + saw(f * 2 ** (-0.14 / 12), n, rng.random())
        x = np.tanh(1.8 * lp(x + 0.5 * saw(f * 2, n), 700)) + 0.9 * sine(f, n)
        env = adsr(n, 0.004, 0.2, 0.8, 0.02)
    elif kind == "reverse":
        x = np.tanh(4 * (sine(f, n) + 0.6 * saw(f, n))) * 0.7 + 0.6 * sine(f, n)
        x = lp(x, 1800)
        env = (t / t[-1]) ** 1.6
    elif kind == "offdist":
        x = np.tanh(5 * lp(saw(f, n) + saw(f * 1.006, n), 1400)) * 0.6 + 0.7 * sine(f, n)
        env = adsr(n, 0.002, 0.08, 0.5, 0.015)
    else:  # rolling / offbeat: saw + pulse through a plucky filter, sine sub
        x = saw(f, n) + 0.6 * square(f * 1.003, n, 0.2, 0.4)
        x = S.lp_var(x, 300 + 1600 * np.exp(-t / 0.05), 1.3, 64)
        x = np.tanh(1.6 * x) * 0.7 + 0.8 * sine(f, n)
        env = adsr(n, 0.002, 0.12, 0.6, 0.012)
    return fade(x * env, 0.001, 0.008)


FORMANTS = {"e": ((400, 70, 1.0), (2000, 110, 0.35), (2550, 130, 0.2)),
            "i": ((290, 60, 1.0), (2250, 110, 0.3), (2950, 130, 0.15)),
            "a": ((800, 80, 1.0), (1150, 90, 0.5), (2900, 130, 0.18)),
            "o": ((450, 70, 1.0), (800, 80, 0.5), (2830, 120, 0.08)),
            "u": ((325, 60, 1.0), (700, 70, 0.3), (2530, 120, 0.05))}


def formant(x, v):
    out = np.zeros_like(x)
    for f, bw, g in FORMANTS[v]:
        b, a = signal.iirpeak(f, f / bw, fs=SR)
        out += g * signal.lfilter(b, a, x)
    return out


def chop(midi, dur, v0, v1, rng, breath=0.0):
    """Synthetic vocal chop: saw/pulse source through gliding vowel formants (no words)."""
    n = int((dur + 0.08) * SR)
    t = np.arange(n) / SR
    f = mtof(midi) * (1 + 0.01 * np.sin(2 * np.pi * 5.5 * t)) * 2 ** (-1.2 * np.exp(-t / 0.03) / 12)
    src = saw(f, n, rng.random()) + 0.6 * square(f * 1.004, n, rng.random(), 0.35)
    c = np.clip(t / max(dur, 0.05) * 1.5 - 0.25, 0, 1)
    c = c * c * (3 - 2 * c)
    y = (1 - c) * formant(src, v0) + c * formant(src, v1)
    if breath:
        y += breath * formant(rng.standard_normal(n), v0) * np.exp(-t / 0.035)
    return fade(np.tanh(1.5 * y) * adsr(n, 0.008, 0.12, 0.75, 0.07), 0.001, 0.02)


def uplifter(rng, dur, midi=48):
    n = int(dur * SR)
    t = np.arange(n) / SR
    k = t / dur
    cut = 400 * 20 ** k
    nz = np.vstack([S.lp_var(rng.standard_normal(n), cut, 1.6, 64) for _ in range(2)])
    tone = lp(ssaw(mtof(midi) * 4 ** k, n, rng, 5, 45, 0.8), 5000) * 0.35
    return fade(hp(nz + tone, 180) * k ** 2.2, 0.01, 0.01)


def downlifter(rng, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    cut = 7000 * (250 / 7000) ** (t / dur)
    nz = np.vstack([S.lp_var(rng.standard_normal(n), cut, 1.2, 64) for _ in range(2)])
    return fade(nz * np.exp(-t / (dur * 0.35)), 0.002, 0.05)


# ---------------------------------------------------------------- song state
def parse_hook(phrases):
    notes = []
    for k, txt in enumerate(phrases):
        pos = 0
        for tok in txt.split():
            slide = tok.startswith("~")
            p, ln = tok.lstrip("~").rsplit(".", 1)
            if p != "r":
                notes.append((32 * k + pos, int(ln), int(p), slide))
            pos += int(ln)
        assert pos == 32, (txt, pos)
    return notes


class Song:
    def __init__(self, spec):
        self.__dict__.update(spec)
        self.piano = spec.get("piano", False)
        self.beat = 60.0 / self.bpm
        self.step = self.beat / 4
        self.bars = sum(nb for _, nb in self.plan)
        self.L = int(round(self.bars * 4 * self.beat * SR))
        self.N = self.L + int(TAIL_S * SR)
        self.rng = np.random.default_rng(self.seed)
        self.stems = {}
        self.triggers = []
        self.curve = {"r": np.full(self.N, OPEN_HZ), "m": np.full(self.N, OPEN_HZ)}
        self.hook = parse_hook(HOOKS[self.name])
        self.lead_base = 60 + self.key % 12
        self.kick_lo = 36 if self.kick == "french" else 31
        self.kicks = {}
        r = np.random.default_rng(self.seed + 1)
        self.clap, self.snare = S.make_clap(r), S.make_snare(r)
        self.hat, self.ohat, self.ride = S.make_hat(r, 0.02), S.make_hat(r, 0.11), S.make_ride(r)
        self.crash, self.impact = S.make_crash(r), S.make_impact(r)
        self.snares = {}
        self.secs, b = [], 0
        for kind, nb in self.plan:
            self.secs.append((kind, b, nb))
            b += nb
        self.sec_of = [s for s in self.secs for _ in range(s[2])]

    def pos(self, bar, step=0.0):
        return int(round((bar * 16 + step) * self.step * SR))

    def add(self, stem, x, at, gain=1.0, pan=0.0):
        buf = self.stems.setdefault(stem, np.zeros((2, self.N)))
        x = stereo(x, pan)
        at = max(at, 0)
        m = min(x.shape[1], self.N - at)
        if m > 0:
            buf[:, at:at + m] += gain * x[:, :m]

    def chord(self, b):
        """-> (bass root midi, chord pitch classes, tr) for bar b."""
        kind, start, nb = self.sec_of[b % self.bars]
        i = b - start
        off, q = self.prog[(i // 2) % 4]
        tr = self.mod if kind == "D2" and i >= (nb // 2) // 8 * 8 else 0
        w = off - 12 if off > 6 else off
        third = 3 if q == "m" else 4
        return self.key + w + tr, (0, third, 7), tr

    def kick_hit(self, b, step, depth=0.85, gain=1.0, max_steps=None):
        root, _, _ = self.chord(b)
        tail = self.kick_lo + (root - self.kick_lo) % 12
        if tail not in self.kicks:
            self.kicks[tail] = make_kick(self.kick, tail, self.beat, self.seed)
        x = self.kicks[tail]
        if max_steps:
            x = fade(x[:int(max_steps * self.step * SR)], 0, 0.006)
        at = self.pos(b, step)
        self.add("kick", x, at, gain)
        self.triggers.append((at, depth))

    def ramp(self, which, bar0, nbars, f0, f1, shape=1.0):
        s, e = self.pos(bar0), self.pos(bar0 + nbars)
        k = np.linspace(0, 1, e - s) ** shape
        self.curve[which][s:e] = f0 * (f1 / f0) ** k

    def snare_at(self, semis):
        key = round(semis * 2) / 2
        if key not in self.snares:
            self.snares[key] = repitch(0.6 * self.snare + 0.5 * self.clap, key)
        return self.snares[key]


# ---------------------------------------------------------------- parts
def render_line(song, b0, nbars, notes, kind, gain, stem="lead", octave=0, glide=0.04, layers=1.0):
    """Monophonic lead over `nbars`: one continuous oscillator bank driven by freq/amp curves."""
    if not notes:
        return
    span = song.pos(b0 + nbars) - song.pos(b0)
    n = span + int(0.25 * SR)
    f, amp = np.zeros(n), np.zeros(n)
    prev_end, prev_f = -1, None
    for st, ln, midi, slide in notes:
        s = song.pos(b0, st) - song.pos(b0)
        e = min(n, song.pos(b0, st + ln) - song.pos(b0))
        if e <= s:
            continue
        fr = np.full(e - s, mtof(midi + octave))
        tt = np.arange(e - s) / SR
        legato = slide and prev_f is not None and s <= prev_end + 8
        if legato:
            g = min(e - s, int(glide * SR))
            fr[:g] = prev_f * (fr[0] / prev_f) ** (np.arange(g) / g)
            env = np.ones(e - s)
        else:
            if kind == "hoover":
                fr *= 2 ** (-5 * np.exp(-tt / 0.05) / 12)
            env = np.minimum(tt / 0.003, 1) * (0.8 + 0.2 * np.exp(-tt / 0.12))
        r = min(e - s, int(0.018 * SR))
        env[-r:] *= np.linspace(1, 0.15 if kind != "saw" else 0, r)
        f[s:e], amp[s:e] = fr, env
        prev_end, prev_f = e, fr[-1]
    held = np.where(f > 0, np.arange(n), 0)
    np.maximum.accumulate(held, out=held)
    f = f[held]
    f[f == 0] = mtof(notes[0][2] + octave)
    amp = lp(amp, 120)  # de-click gate edges
    rng = song.rng
    if kind == "hoover":
        x = hoover(f, n, rng)
    else:
        x = ssaw(f, n, rng, 9, 26 if kind == "alarm" else 32)
        x += 0.5 * layers * ssaw(2 * f, n, rng, 7, 20, 1.0)
        if kind == "alarm":
            x += 0.35 * pan2(square(f, n, 0.0, 0.3), 0)
    song.add(stem, x * amp, song.pos(b0), gain)


def hook_notes(song, b0, nbars, shift=0):
    out = []
    for i in range(0, nbars, 8):
        for st, ln, off, sl in song.hook:
            if st // 16 + i >= nbars:
                continue
            _, _, tr = song.chord(b0 + i + st // 16)
            out.append((16 * i + st, ln, song.lead_base + off + tr + shift, sl))
    return out


def harmony(song, b0, notes):
    """Diatonic harmony: highest chord tone at least a minor third under each melody note."""
    out = []
    for st, ln, midi, sl in notes:
        root, tones, _ = song.chord(b0 + st // 16)
        pcs = {(root + x) % 12 for x in tones}
        h = midi - 3
        while h % 12 not in pcs:
            h -= 1
        out.append((st, ln, h, sl))
    return out


def chord_midis(song, b, octave=12, four=True):
    root, tones, _ = song.chord(b)
    ms = [root + octave + x for x in tones]
    return ms + [ms[0] + 12] if four else ms


def chords_hold(song, b, nbars, stem, gain, voices=7, cents=24, att=0.005, rel=0.15, cut=None):
    n = song.pos(b + nbars) - song.pos(b) + int(rel * SR)
    x = np.zeros((2, n))
    for m in chord_midis(song, b):
        x += ssaw(mtof(m), n, song.rng, voices, cents, 0.8)
    x *= adsr(n, att, 0.6, 0.8, rel)
    if cut:
        x = lp(x, cut, 2)
    song.add(stem, x, song.pos(b), gain)


ARP = (0, 1, 2, 3, 2, 1, 2, 3, 0, 2, 1, 3, 2, 3, 1, 2)


def arp_bar(song, b, gain, sub=1, octave=24):
    ms = chord_midis(song, b, octave)
    for i in range(0, 16, sub):
        x = pluck(ms[ARP[i]], song.step * sub * 0.9, song.rng)
        song.add("pluck", x, song.pos(b, i), gain * (1.0 if i % 4 == 0 else 0.75), pan=0.35 * np.sin(i))


def pluck_hook(song, b0, nbars, gain, shift=-12):
    for st, ln, midi, _ in hook_notes(song, b0, nbars, shift):
        song.add("pluck", pluck(midi, ln * song.step, song.rng), song.pos(b0, st), gain)
        song.add("pluck", pluck(midi + 12, ln * song.step, song.rng), song.pos(b0, st), gain * 0.35, pan=0.3)


def bass_bar(song, b, gain=1.0):
    root, _, _ = song.chord(b)
    st, k = song.step, song.bass
    if k == "rolling":
        for i in range(16):
            if i % 4:
                m = root + (12 if i % 4 == 3 and i % 8 == 7 else 0)
                song.add("bass", bass_note("rolling", m, st * 0.92, song.rng), song.pos(b, i), gain)
    elif k == "reverse":
        for i in (1, 5, 9, 13):
            song.add("bass", bass_note("reverse", root, st * 2.85, song.rng), song.pos(b, i + 0.1), gain)
    elif k == "offbeat":
        for j, i in enumerate((2, 6, 10, 14)):
            m = root + (12 if j % 2 else 0)
            song.add("bass", bass_note("offbeat", m, st * 1.7, song.rng), song.pos(b, i), gain)
    elif k in ("reese", "offdist"):
        for i in (2, 6, 10, 14):
            song.add("bass", bass_note(k, root, st * 1.8, song.rng), song.pos(b, i), gain)


def kick_bar(song, b, roll=False, depth=0.85, gain=1.0):
    steps = (0, 4, 8, 12)
    if roll and song.kick in ("gabber", "french", "uptempo"):
        steps = (0, 4, 8, 10, 12, 13, 14, 15) if song.kick == "gabber" else (0, 4, 8, 12, 14, 15)
    for j, s in enumerate(steps):
        nxt = steps[j + 1] - s if j + 1 < len(steps) else 16 - s
        song.kick_hit(b, s, depth, gain * (0.9 if s % 4 else 1.0), max_steps=nxt if nxt < 4 else None)


def hats_bar(song, b, level=1.0, ride=False):
    for i in range(16):
        if i % 4 == 2:
            song.add("hats", song.ohat, song.pos(b, i), 0.9 * level, pan=0.15)
        elif i % 2 == 1:
            song.add("hats", song.hat, song.pos(b, i), 0.45 * level, pan=-0.25)
        if ride and i % 2 == 0:
            song.add("hats", song.ride, song.pos(b, i), 0.35 * level, pan=0.4)


def clap_bar(song, b, fill=False):
    for i in (4, 12):
        song.add("clap", song.clap, song.pos(b, i), 1.0, pan=0.05)
    if song.kick in ("french", "uptempo", "gabber"):
        song.add("clap", song.snare, song.pos(b, 12), 0.6)
    if fill:
        for i in (13, 14, 15):
            song.add("roll", song.snare_at(i - 13), song.pos(b, i), 0.5 + 0.15 * (i - 13))


def hit_fx(song, b, crash=True, impact=True, down=True):
    at = song.pos(b)
    if crash:
        song.add("crash", song.crash, at)
    if impact:
        song.add("impact", song.impact, at)
    if down:
        song.add("fx", downlifter(song.rng, 2 * 4 * song.beat), at, 0.8)


def hey(song, b, step, midi=None, gain=1.0):
    m = midi or song.lead_base + 7
    song.add("chops", chop(m, song.step * 3, "e", "i", song.rng, 0.4), song.pos(b, step), gain, pan=-0.1)


def ohoh(song, b, step):
    m = song.lead_base
    for j, (dm, ln) in enumerate(((0, 3), (3, 5))):
        song.add("chops", chop(m + dm, song.step * ln, "o", "u", song.rng), song.pos(b, step + 4 * j), 0.9, pan=0.1)


# ---------------------------------------------------------------- sections
def sec_intro(song, b0, nb):
    song.ramp("r", b0, nb, 180, OPEN_HZ, 1.6)
    song.ramp("m", b0, nb, 450, 2400)
    for i in range(nb):
        kick_bar(song, b0 + i, depth=0.55)
        if i >= nb // 2:
            hats_bar(song, b0 + i, 0.5 + 0.5 * i / nb)
            arp_bar(song, b0 + i, 0.5, 2 if song.bpm > 170 else 1)
    chords_hold(song, b0 + nb // 2, nb // 2, "pad", 0.35, cut=1800, att=1.5)


def sec_build(song, b0, nb):
    song.ramp("m", b0, nb, 380, OPEN_HZ, 1.3)
    song.add("fx", uplifter(song.rng, nb * 4 * song.beat, song.lead_base - 12), song.pos(b0), 1.0)
    for i in range(nb):
        k = i / nb
        b = b0 + i
        if k < 0.5:
            kick_bar(song, b, depth=0.7, gain=0.85)
        sub = 4 if k < 0.25 else 2 if k < 0.5 else 1 if k < 0.875 else 0.5
        s = 0.0
        while s < 16 and not (i == nb - 1 and s >= 14):
            semi = 9 * (i * 16 + s) / (nb * 16)
            song.add("roll", song.snare_at(semi), song.pos(b, s), 0.3 + 0.7 * (i * 16 + s) / (nb * 16))
            s += sub
    render_line(song, b0, nb, hook_notes(song, b0, nb), song.lead, 0.8)
    pb = max(1, nb // 4)  # pitch-up chord into the drop
    n = song.pos(b0 + nb) - song.pos(b0 + nb - pb) - int(0.5 * song.beat * SR)
    kk = np.linspace(0, 1, n) ** 2
    x = sum(ssaw(mtof(m) * 2 ** kk, n, song.rng, 7, 30) for m in chord_midis(song, b0 + nb - 1, 12, False))
    song.add("chords", fade(x * (0.3 + 0.7 * kk), 0.05, 0.02), song.pos(b0 + nb - pb), 0.9)
    song.add("crash", song.crash[:, ::-1][:, -int(2 * song.beat * SR):], song.pos(b0 + nb - 1, 8) - int(0.5 * song.beat * SR), 0.7)
    hey(song, b0 + nb - 1, 12, gain=1.1)


def sec_drop(song, b0, nb, two=False):
    hit_fx(song, b0)
    for i in range(nb):
        b = b0 + i
        last8 = i % 8 == 7
        kick_bar(song, b, roll=last8 or (two and i % 4 == 3))
        bass_bar(song, b)
        clap_bar(song, b, fill=last8 and i != nb - 1)
        hats_bar(song, b, 1.0, ride=two)
        if i % 2 == 0:
            chords_hold(song, b, 2, "chords", 0.8)
        arp_bar(song, b, 0.35, 2 if song.bpm > 170 else 1, 24)
        if i % 8 == 0 and i:
            song.add("crash", song.crash, song.pos(b), 0.8)
        if i % 8 == 3:
            hey(song, b, 14)
        if i % 8 == 7 and two:
            ohoh(song, b, 4)
    notes = hook_notes(song, b0, nb)
    render_line(song, b0, nb, notes, song.lead, 1.0, glide=0.09 if song.lead == "hoover" else 0.035,
                layers=1.4 if two else 1.0)
    if two:
        render_line(song, b0, nb, harmony(song, b0, notes), "saw" if song.lead == "alarm" else song.lead,
                    0.5, layers=0.5)
        render_line(song, b0, nb, notes, "saw", 0.4, octave=-12, layers=0.0)
    if song.piano:
        pluck_hook(song, b0, nb, 0.9, 0)


def sec_break(song, b0, nb):
    hit_fx(song, b0, impact=True, down=True)
    for i in range(0, nb, 2):
        chords_hold(song, b0 + i, 2, "pad", 1.0, voices=7, cents=18, att=0.5, rel=1.2, cut=2600)
        song.add("sub", lp(sine(mtof(song.chord(b0 + i)[0]), song.pos(b0 + i + 2) - song.pos(b0 + i)), 200)
                 * adsr(song.pos(b0 + i + 2) - song.pos(b0 + i), 0.3, 1, 0.8, 0.3), song.pos(b0 + i), 0.5)
    half = nb // 2
    for i in range(nb):
        arp_bar(song, b0 + i, 0.8 if i < half else 0.45, 2 if song.bpm > 170 else 1)
        if i >= half:  # ghost pump keeps the groove alive under the tease
            for s in (0, 4, 8, 12):
                song.triggers.append((song.pos(b0 + i, s), 0.3))
    pluck_hook(song, b0 + half, half, 1.0)
    render_line(song, b0 + nb - min(4, half), min(4, half),
                hook_notes(song, b0 + nb - min(4, half), min(4, half)), song.lead, 0.35)
    for i in (3, 7, 11):
        if i < nb:
            ohoh(song, b0 + i, 8)
    song.add("crash", song.crash[:, ::-1], song.pos(b0 + nb) - song.crash.shape[1], 0.5)


def sec_outro(song, b0, nb):
    song.ramp("r", b0, nb, OPEN_HZ, 180, 0.7)
    song.ramp("m", b0, nb, 2400, 450)
    hit_fx(song, b0, impact=False)
    for i in range(nb):
        b = b0 + i
        kick_bar(song, b, depth=0.6)
        if i < nb - 1:
            hats_bar(song, b, 1.0 - 0.6 * i / nb)
        if i < nb // 2:
            bass_bar(song, b, 0.8)
        arp_bar(song, b, 0.5, 2 if song.bpm > 170 else 1)
    rc = song.crash[:, ::-1][:, -int(4 * song.beat * SR):]
    song.add("crash", rc, song.pos(b0 + nb) - rc.shape[1], 0.5)


def compose(song):
    for kind, b0, nb in song.secs:
        if kind == "I":
            sec_intro(song, b0, nb)
        elif kind == "U":
            sec_build(song, b0, nb)
        elif kind in ("D", "D2"):
            sec_drop(song, b0, nb, kind == "D2")
        elif kind == "K":
            sec_break(song, b0, nb)
        else:
            sec_outro(song, b0, nb)
    for c in song.curve.values():  # periodic automation for the wrapped tail
        c[song.L:] = c[:song.N - song.L]


# ---------------------------------------------------------------- mixing
def rms_db(x):
    v = x[np.abs(x) > 1e-4]
    return 20 * np.log10(np.sqrt(np.mean(v ** 2)) + 1e-12) if v.size else -120.0


def auto_filter(x, curve, margin):
    y = x.copy()
    act = np.concatenate([[0], (curve < 18000).astype(int), [0]])
    edges = np.flatnonzero(np.diff(act))
    for s, e in zip(edges[::2], edges[1::2]):
        s0, e0 = max(0, s - margin), min(len(curve), e + margin)
        for c in range(2):
            y[c, s0:e0] = S.lp_var(x[c, s0:e0], curve[s0:e0], 0.707, 64)
    return y


def sidechain(song):
    ramp, rec = int(0.003 * SR), int(0.6 * song.beat * SR)
    k = np.arange(rec) / rec
    base = 1 - (3 * k ** 2 - 2 * k ** 3)
    g = np.ones(song.N)
    trig = song.triggers + [(s + song.L, d) for s, d in song.triggers if s + song.L < song.N] \
        + [(s - song.L, d) for s, d in song.triggers if s > song.L - rec]
    for s0, d in trig:
        seg = np.concatenate([np.linspace(1, 1 - d, ramp), 1 - d * base])
        s = s0 - ramp
        if s < 0:
            seg, s = seg[-s:], 0
        e = min(song.N, s + len(seg))
        if e > s:
            g[s:e] = np.minimum(g[s:e], seg[:e - s])
    return g


def mixdown(song):
    dry, duck = np.zeros((2, song.N)), np.zeros((2, song.N))
    rev, dly = np.zeros((2, song.N)), np.zeros((2, song.N))
    margin = int(0.25 * SR)
    for name, x in song.stems.items():
        db, bus, auto, rs, ds, hpf, lpf = STEMS[name]
        if hpf:
            x = hp(x, hpf, 2)
        if lpf:
            x = lp(x, lpf, 2)
        if auto:
            x = auto_filter(x, song.curve[auto], margin)
        x = x * 10 ** ((db - rms_db(x)) / 20)
        (dry if bus == "dry" else duck)[:] += x
        rev += rs * x
        dly += ds * x
    ir = S.make_ir(song.seed + 5, rt=1.7, pre=0.012)
    rev = hp(rev, 280)
    wet = np.vstack([signal.oaconvolve(rev[c], ir[c])[:song.N] for c in range(2)])
    echo = S.pingpong(dly, int(round(0.75 * song.beat * SR)), 0.38, 8)
    g = sidechain(song)
    mix = dry + (duck + 0.6 * wet + 0.55 * echo) * g
    mix = hp(mix, 25)
    out = mix[:, :song.L].copy()
    out[:, :song.N - song.L] += mix[:, song.L:]
    return out


def master(x, ceil_db):
    x = x / np.max(np.abs(x)) * 0.5
    ceil, gain = 10 ** (ceil_db / 20), 1.0
    for _ in range(8):
        y = S.soft_clip(x * gain, ceil)
        lufs, tp = S.measure(y)
        if abs(TARGET_LUFS - lufs) < 0.08:
            break
        gain *= 10 ** ((TARGET_LUFS - lufs) / 20)
    return y, lufs, tp


def encode(y, path):
    import soundfile as sf
    data = np.ascontiguousarray(y.T, dtype=np.float32)
    with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=VORBIS_LEVEL) as f:
        for k in range(0, len(data), 8192):  # chunked: big single writes crash libsndfile's vorbis path
            f.write(data[k:k + 8192])


def render(spec):
    song = Song(spec)
    compose(song)
    x = mixdown(song)
    path = os.path.join(OUT_DIR, song.name + ".ogg")
    ceil_db, otp, lufs, tp = -1.6, 0.0, 0.0, 0.0
    for _ in range(6):
        y, lufs, tp = master(x, ceil_db)
        encode(y, path)
        _, otp = S.ebur128(["-i", path])
        if otp <= -1.1:
            break
        ceil_db -= 0.4
    print(f"{song.name}: {song.L / SR:.2f}s {lufs:.2f} LUFS tp {tp:.2f} | ogg tp {otp:.2f} (ceil {ceil_db:.1f})")


def check():
    total = 0
    print(f"{'track':9s} {'bpm':>4s} {'bars':>4s} {'sec':>7s} {'MB':>5s} {'LUFS':>6s} {'dBTP':>5s} "
          f"{'seam':>7s} {'p99':>7s} {'max':>7s} {'clip%':>6s}")
    for spec in TRACKS:
        name, bpm = spec["name"], spec["bpm"]
        bars = sum(nb for _, nb in spec["plan"])
        path = os.path.join(OUT_DIR, name + ".ogg")
        if not os.path.exists(path):
            continue
        x = S.decode(path)
        size = os.path.getsize(path)
        total += size
        lufs, tp = S.ebur128(["-i", path])
        expect = int(round(bars * 4 * 60 / bpm * SR))
        assert x.shape[1] == expect, (name, x.shape[1], expect)
        d = np.abs(np.diff(x, axis=1))
        seam = np.max(np.abs(x[:, 0] - x[:, -1]))
        hot = 100 * np.mean(np.abs(x) > 0.8)
        print(f"{name:9s} {bpm:4d} {bars:4d} {x.shape[1] / SR:7.2f} {size / 1e6:5.2f} {lufs:6.1f} {tp:5.1f} "
              f"{seam:7.4f} {np.percentile(d, 99):7.4f} {d.max():7.4f} {hot:6.2f}")
    print(f"total {total / 1e6:.2f} MB")


def main(argv):
    if "--check" in argv:
        return check()
    os.makedirs(OUT_DIR, exist_ok=True)
    wanted = [a for a in argv if not a.startswith("-")]
    for spec in TRACKS:
        if not wanted or spec["name"] in wanted:
            render(spec)
    check()


if __name__ == "__main__":
    main(sys.argv[1:])
