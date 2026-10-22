#!/usr/bin/env python3
"""Turbo Thruster soundtrack generator (fully synthesized, no samples).

Every sound (kicks, hats, claps, basses, acid lines, arps, supersaws, risers,
impacts, reverb) is generated from oscillators and noise in this file, so the
output carries no third-party licensing. Random choices use fixed seeds, so a
re-run produces the same audio.

Regenerate:
    python3 -m venv /tmp/musicvenv && /tmp/musicvenv/bin/pip install numpy scipy soundfile
    /tmp/musicvenv/bin/python tools/music/synth.py             # all tracks
    /tmp/musicvenv/bin/python tools/music/synth.py sector_b    # one track
    /tmp/musicvenv/bin/python tools/music/synth.py --check     # QA report only

Encoding uses soundfile's bundled libsndfile/libvorbis (quality ~q5); ffmpeg
(FFMPEG env var, else /opt/homebrew/bin/ffmpeg or PATH) is used for loudness
measurement and QA. Output goes to assets/music/*.ogg (44.1 kHz stereo Vorbis).

Seamless loops: each track is an exact number of bars long. A few seconds of
tail (reverb, delay, ringing notes) are rendered past the loop end and added
back onto the head; the sidechain curve is periodic. Loudness is set with a
static gain + memoryless soft clipper (measured with ffmpeg ebur128), so the
loop point stays sample-continuous (-14 LUFS integrated, true peak < -1 dBTP).
"""
import json
import os
import re
import shutil
import subprocess
import sys

import numpy as np
from scipy import signal

SR = 44100
TAIL_S = 5.0
TARGET_LUFS = -14.0
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "music")
FFMPEG = os.environ.get("FFMPEG") or (
    "/opt/homebrew/bin/ffmpeg" if os.path.exists("/opt/homebrew/bin/ffmpeg") else shutil.which("ffmpeg"))

# name, bpm, bars, key (bass midi), chord progression (root offset, quality), style, seed
TRACKS = [
    ("menu", 112, 64, 45, [(0, "m"), (8, "M"), (3, "M"), (10, "M")], "menu", 11),
    ("sector_a", 132, 96, 41, [(0, "m"), (8, "M"), (5, "m"), (7, "m")], "pump", 21),
    ("sector_b", 138, 96, 43, [(0, "m"), (0, "m"), (8, "M"), (10, "M")], "acid", 31),
    ("sector_c", 145, 112, 38, [(0, "m"), (1, "M"), (0, "m"), (10, "M")], "hard", 41),
    ("sector_d", 150, 112, 42, [(0, "m"), (8, "M"), (3, "M"), (10, "M")], "hardstyle", 51),
    ("sector_e", 158, 128, 40, [(0, "m"), (10, "M"), (8, "M"), (7, "M")], "frantic", 61),
    ("boss", 165, 64, 36, [(0, "m"), (1, "M")], "boss", 71),
]

STYLES = {
    "menu": dict(kick="clean", bass="octave", acid=None, arp="saw", lead="saw", stabs=None, ride=False, sc=0.45),
    "pump": dict(kick="punch", bass="offbeat", acid=None, arp="square", lead="pluck", stabs="chord", ride=False, sc=0.8),
    "acid": dict(kick="punch", bass="offbeat", acid="all", arp=None, lead=None, stabs=None, ride=True, sc=0.8),
    "hard": dict(kick="dist", bass="rolling", acid=None, arp=None, lead=None, stabs="dark", ride=True, sc=0.85),
    "hardstyle": dict(kick="hard", bass="reverse", acid=None, arp=None, lead="super", stabs="super", ride=False, sc=0.9),
    "frantic": dict(kick="dist", bass="rolling", acid="late", arp="square", lead="super", stabs="super", ride=True, sc=0.85),
    "boss": dict(kick="dist", bass="rolling", acid=None, arp=None, lead="alarm", stabs="super", ride=True, sc=0.85),
}
STAB_STEPS = {"chord": (2, 6, 10, 14), "dark": (3, 6, 11, 14), "hardstyle": (3, 6, 10, 14),
              "frantic": (2, 6, 10, 13), "boss": (0, 3, 6, 10, 12)}


# ----------------------------------------------------------------- DSP basics
def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def _blep(ph, dt):
    y = np.zeros_like(ph)
    m = ph < dt
    x = ph[m] / dt[m]
    y[m] = x + x - x * x - 1.0
    m = ph > 1.0 - dt
    x = (ph[m] - 1.0) / dt[m]
    y[m] = x * x + x + x + 1.0
    return y


def _phase(freq, n, ph0):
    dt = np.array(np.broadcast_to(np.asarray(freq, float) / SR, (n,)))
    return (ph0 + np.cumsum(dt) - dt) % 1.0, dt


def saw(freq, n, ph0=0.0):
    ph, dt = _phase(freq, n, ph0)
    return 2.0 * ph - 1.0 - _blep(ph, dt)


def square(freq, n, ph0=0.0, pw=0.5):
    ph, dt = _phase(freq, n, ph0)
    return np.where(ph < pw, 1.0, -1.0) + _blep(ph, dt) - _blep((ph - pw) % 1.0, dt)


def sine(freq, n, ph0=0.0):
    ph, _ = _phase(freq, n, ph0)
    return np.sin(2 * np.pi * ph)


def _sos(kind, fc, order=2):
    return signal.butter(order, fc, kind, fs=SR, output="sos")


def lp(x, fc, order=2):
    return signal.sosfilt(_sos("low", fc, order), x, axis=-1)


def hp(x, fc, order=2):
    return signal.sosfilt(_sos("high", fc, order), x, axis=-1)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", (lo, hi), order), x, axis=-1)


def lp_var(x, cutoff, q=0.707, block=32):
    """Resonant biquad lowpass whose cutoff follows `cutoff` (updated per block)."""
    n = len(x)
    idx = np.arange(0, n, block)
    w = 2 * np.pi * np.clip(cutoff[idx], 20.0, 0.45 * SR) / SR
    cs, al = np.cos(w), np.sin(w) / (2 * q)
    a0 = 1 + al
    b0, b1 = (1 - cs) / 2 / a0, (1 - cs) / a0
    a1, a2 = -2 * cs / a0, (1 - al) / a0
    y = np.empty(n)
    zi = np.zeros(2)
    for i, s in enumerate(idx):
        y[s:s + block], zi = signal.lfilter((b0[i], b1[i], b0[i]), (1.0, a1[i], a2[i]), x[s:s + block], zi=zi)
    return y


def fade(x, a=0.002, r=0.006):
    x = np.array(x, float)
    na, nr = min(len(x), int(a * SR)), min(len(x), int(r * SR))
    if na:
        x[..., :na] *= np.linspace(0, 1, na)
    if nr:
        x[..., -nr:] *= np.linspace(1, 0, nr)
    return x


def adsr(n, a, d, s, r):
    t = np.arange(n) / SR
    env = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    nr = min(n, int(r * SR))
    env[n - nr:] *= np.linspace(1, 0, nr) ** 2
    return env


def pan2(x, p):
    a = (p + 1) * np.pi / 4
    return np.vstack([x * np.cos(a), x * np.sin(a)]) * np.sqrt(2)


def supersaw(f, n, rng, voices=7, spread=0.28, width=1.0):
    out = np.zeros((2, n))
    for i in range(voices):
        x = i / (voices - 1) * 2 - 1
        out += pan2(saw(f * 2 ** (spread * x / 12), n, rng.random()), x * width)
    return out / np.sqrt(voices)


# ------------------------------------------------------------- drum one-shots
def make_kick(style, beat):
    f0, f1, tau, dec, drive, click = {
        "clean": (220, 47, 0.040, 0.30, 1.6, 0.15), "punch": (300, 50, 0.032, 0.32, 2.6, 0.25),
        "dist": (360, 52, 0.028, 0.40, 6.0, 0.30), "hard": (430, 54, 0.022, 0.25, 9.0, 0.35)}[style]
    n = int(min(0.6, 0.95 * beat) * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    amp = 1 / (1 + (t / dec) ** 4) if style == "hard" else np.exp(-t / dec)
    rng = np.random.default_rng(7)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * amp + hp(rng.standard_normal(n), 1500) * np.exp(-t / 0.004) * click
    x = np.tanh(drive * x) / np.tanh(drive)
    if drive > 3:
        x = lp(x, 7000)
    return fade(x, 0.0005, 0.01)


def make_hat(rng, dec):
    n = int(dec * 6 * SR)
    x = hp(rng.standard_normal(n), 7000, 4) * np.exp(-np.arange(n) / SR / dec)
    return fade(x / np.max(np.abs(x)), 0.0005, 0.004)


def make_ride(rng):
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    x = sum(square(f, n, rng.random()) for f in (3010, 4170, 5530, 6880, 8250))
    x = hp(x + 2 * rng.standard_normal(n), 5000) * np.exp(-t / 0.35)
    return fade(x / np.max(np.abs(x)), 0.0005, 0.01)


def make_clap(rng):
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    env = sum(np.where(t >= o, np.exp(-(t - o) / 0.004), 0) for o in (0, 0.009, 0.018))
    env = env + 0.8 * np.where(t >= 0.027, np.exp(-(t - 0.027) / 0.11), 0)
    x = bp(rng.standard_normal(n), 900, 3200) * env
    return fade(x / np.max(np.abs(x)), 0.0005, 0.01)


def make_snare(rng):
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    x = 0.6 * sine(190 * (1 + 0.5 * np.exp(-t / 0.01)), n) * np.exp(-t / 0.06)
    x = x + bp(rng.standard_normal(n), 1500, 9000) * np.exp(-t / 0.13)
    return fade(x / np.max(np.abs(x)), 0.0005, 0.01)


def make_crash(rng, dur=2.5):
    n = int(dur * SR)
    env = np.exp(-np.arange(n) / SR / 0.9)
    x = hp(rng.standard_normal((2, n)), 4000) * env
    return fade(x / np.max(np.abs(x)), 0.001, 0.05)


def make_impact(rng):
    n = int(3 * SR)
    t = np.arange(n) / SR
    boom = sine(30 + 70 * np.exp(-t / 0.07), n) * np.exp(-t / 0.9)
    nz = lp(rng.standard_normal((2, n)), 2500) * np.exp(-t / 0.5) * 0.35
    return fade(np.tanh(1.5 * (boom + nz)), 0.0005, 0.05)


def make_riser(rng, dur, midi):
    n = int(dur * SR)
    t = np.arange(n) / SR
    k = t / dur
    cut = 200 * 60 ** k
    nz = np.vstack([lp_var(rng.standard_normal(n), cut, 2.5) for _ in range(2)])
    tone = lp(saw(mtof(midi) * 4 ** k, n) + saw(mtof(midi) * 1.007 * 4 ** k, n), 3500) * 0.25
    return fade((nz + tone) * k ** 2, 0.01, 0.006)


def make_revbass(midi, beat):
    n = int(0.76 * beat * SR)
    t = np.arange(n) / SR
    f = mtof(midi)
    x = np.tanh(4 * (sine(f, n) + 0.5 * saw(f, n)))
    x = lp(x, 1600) * (t / t[-1]) ** 1.6
    return fade(x / np.max(np.abs(x)), 0.001, 0.006)


# ------------------------------------------------------------ mono synth voice
class Note:
    __slots__ = ("t", "dur", "midi", "vel", "cut", "env", "slide", "decay")

    def __init__(self, t, dur, midi, vel=1.0, cut=1000.0, env=2.0, slide=False, decay=None):
        self.t, self.dur, self.midi, self.vel = t, dur, midi, vel
        self.cut, self.env, self.slide, self.decay = cut, env, slide, decay


def _voice_curves(notes, lo, m, decay, glide, amp_decay):
    freq, amp, cut = np.zeros(m), np.zeros(m), np.full(m, 60.0)
    prev = None
    for i, nt in enumerate(notes):
        s = int(round(nt.t * SR)) - lo
        e = min(m, s + max(1, int(nt.dur * SR)))
        n = e - s
        if n <= 0:
            continue
        f = mtof(nt.midi)
        t = np.arange(n) / SR
        legato = nt.slide and prev is not None
        fr = np.full(n, f)
        if legato:
            g = min(n, int(glide * SR))
            fr[:g] = prev * (f / prev) ** (np.arange(g) / g)
        freq[s:e] = fr
        a = np.ones(n) if legato else np.minimum(1.0, t / 0.002)
        if amp_decay:
            a = a * np.exp(-t / amp_decay)
        if not (i + 1 < len(notes) and notes[i + 1].slide):
            r = min(n, int(0.008 * SR))
            a[n - r:] *= np.linspace(1, 0, r)
        amp[s:e] = a * nt.vel
        cut[s:e] = nt.cut * (1 + nt.env * np.exp(-(t + (0.25 if legato else 0)) / (nt.decay or decay)))
        prev = f
    held = np.where(freq > 0, np.arange(m), 0)
    np.maximum.accumulate(held, out=held)
    freq = freq[held]
    freq[freq == 0] = mtof(notes[0].midi)
    return freq, amp, cut


def mono_voice(notes, wave="saw", q=0.8, decay=0.12, drive=1.0, glide=0.05, sub=0.0,
               amp_decay=None, vib=None, detune=0.0, limit=None):
    """Monophonic subtractive voice: osc -> resonant LP (env) -> drive -> VCA."""
    notes = sorted(notes, key=lambda n: n.t)
    lo = int(round(notes[0].t * SR))
    hi = int(round((notes[-1].t + notes[-1].dur) * SR)) + int(0.05 * SR)
    if limit:
        hi = min(hi, limit)
    m = hi - lo
    freq, amp, cut = _voice_curves(notes, lo, m, decay, glide, amp_decay)
    if vib:
        freq = freq * 2 ** (vib[1] * np.sin(2 * np.pi * vib[0] * np.arange(m) / SR) / 12)
    osc = {"saw": saw, "square": square}[wave]
    x = osc(freq, m)
    if detune:
        x = 0.5 * (osc(freq * 2 ** (detune / 1200), m, 0.3) + osc(freq * 2 ** (-detune / 1200), m, 0.7))
    if sub:
        x = x + sub * sine(freq, m)
    y = lp_var(x, cut, q)
    if drive > 1:
        y = np.tanh(drive * y) / np.tanh(drive)
    return y * amp, lo


# ------------------------------------------------------------------ the song
class Song:
    def __init__(self, name, bpm, bars, key, prog, style, seed):
        self.name, self.bpm, self.bars, self.key, self.prog = name, bpm, bars, key, prog
        self.style, self.prof, self.seed = style, STYLES[style], seed
        self.beat = 60.0 / bpm
        self.L = int(round(bars * 4 * self.beat * SR))
        self.N = self.L + int(TAIL_S * SR)
        self.dry, self.duck, self.rev, self.dly = (np.zeros((2, self.N), np.float32) for _ in range(4))
        self.kicks = []
        self.rng = np.random.default_rng(seed)
        self.secs = self._sections()

    def _sections(self):
        if self.style == "menu":
            return [("intro", 0, 8), ("verse", 8, 16), ("drop", 24, 16), ("break", 40, 8), ("drop2", 48, 16)]
        if self.style == "boss":
            return [("intro", 0, 8), ("drop", 8, 24), ("break", 32, 8), ("drop2", 40, 24)]
        d1 = ((self.bars - 32) // 2) // 8 * 8
        return [("intro", 0, 8), ("build", 8, 8), ("drop", 16, d1), ("break", 16 + d1, 16),
                ("drop2", 32 + d1, self.bars - 32 - d1)]

    def bar_info(self, b):
        for name, start, n in self.secs:
            if start <= b < start + n:
                root, qual = self.prog[(b // 2) % len(self.prog)]
                r = root % 12
                return dict(name=name, i=b - start, n=n, root=r - 12 if r > 5 else r, qual=qual,
                            drop=name in ("drop", "drop2"))
        raise ValueError(b)

    def t(self, bar, beat=0.0):
        return (bar * 4 + beat) * self.beat

    def add(self, sig, t, bus="duck", pan=0.0, gain=1.0, rev=0.0, dly=0.0, at_sample=None):
        s = int(round(t * SR)) if at_sample is None else at_sample
        sig = pan2(sig, pan) if np.ndim(sig) == 1 else sig
        n = min(sig.shape[1], self.N - s)
        if n <= 0:
            return
        seg = sig[:, :n] * gain
        (self.dry if bus == "dry" else self.duck)[:, s:s + n] += seg
        if rev:
            self.rev[:, s:s + n] += seg * rev
        if dly:
            self.dly[:, s:s + n] += seg * dly

    def add_voice(self, notes, gain, pan=0.0, rev=0.0, dly=0.0, **kw):
        if notes:
            y, lo = mono_voice(notes, limit=self.N, **kw)
            self.add(y, 0, pan=pan, gain=gain, rev=rev, dly=dly, at_sample=lo)

    def kick(self, sig, bar, beat, gain):
        s = int(round(self.t(bar, beat) * SR))
        self.kicks.append(s)
        self.add(sig, 0, bus="dry", gain=gain, at_sample=s)

    def sidechain(self):
        depth = self.prof["sc"]
        ramp, rec = int(0.004 * SR), int(0.62 * self.beat * SR)
        k = np.arange(rec) / rec
        shape = np.concatenate([np.linspace(1, 1 - depth, ramp), 1 - depth * (1 - (3 * k ** 2 - 2 * k ** 3))])
        g = np.ones(self.N, np.float32)
        for kk in self.kicks + [k0 + self.L for k0 in self.kicks if k0 + self.L < self.N]:
            s, seg = kk - ramp, shape
            if s < 0:
                seg, s = seg[-s:], 0
            e = min(self.N, s + len(seg))
            g[s:e] = np.minimum(g[s:e], seg[:e - s])
        return g


def triad(q):
    return (0, 3, 7) if q == "m" else (0, 4, 7)


def chord_tones(base, q, octaves=2):
    return [base + 12 * o + x for o in range(octaves) for x in triad(q)]


def make_motif(rng):
    """2-bar melody: (start 8th, length in 8ths, chord-tone index)."""
    steps, pos, idx = [], 0, 2
    while pos < 16:
        dur = min(int(rng.choice([1, 1, 2, 2, 3] if pos % 4 else [1, 2, 2])), 16 - pos)
        if pos == 0 or rng.random() < 0.78:
            idx = int(np.clip(idx + rng.choice([-2, -1, -1, 0, 1, 1, 2]), 0, 5))
            steps.append((pos, dur, idx))
        pos += dur
    return steps


def make_acid(rng):
    """2-bar 303 pattern: list of dicts with 16th step, offset, accent, slide."""
    offs = [0, 0, 0, 12, 0, 3, 7, 10, -2, 5, 12]
    pat, on = [], set()
    for s in range(32):
        if s % 8 == 0 or rng.random() < 0.7:
            slide = s - 1 in on and rng.random() < 0.25
            pat.append(dict(s=s, off=int(rng.choice(offs)), acc=rng.random() < 0.3, slide=slide))
            on.add(s)
    return pat


# ------------------------------------------------------------- arrangement
class Kit:
    def __init__(self, song):
        r = np.random.default_rng(song.seed + 1000)
        self.kick = make_kick(song.prof["kick"], song.beat)
        self.kick_f = [lp(self.kick, 220, 4), lp(self.kick, 700, 4)]
        self.hat, self.ohat = make_hat(r, 0.022), make_hat(r, 0.15)
        self.ride, self.clap, self.snare = make_ride(r), make_clap(r), make_snare(r)
        self.crash, self.impact = make_crash(r), make_impact(r)
        self.rng = r
        self.rev_cache = {}


def sweep(info, lo_hi, kind="up"):
    """Cutoff automation helper: exponential rise across the section."""
    lo, hi = lo_hi
    return lo * (hi / lo) ** (info["i"] / max(1, info["n"] - 1))


def drums_bar(song, kit, b, info):
    P, name, i, n = song.prof, info["name"], info["i"], info["n"]
    menu = song.style == "menu"
    kick_on = name in ("build", "drop", "drop2", "verse") or (name == "intro" and not menu)
    kg = 0.8 if P["kick"] == "hard" else 0.95
    for beat in range(4):
        if kick_on and not (name == "build" and i == n - 1 and beat >= 2):
            ks = kit.kick_f[0 if i < 4 else 1] if name == "intro" else kit.kick
            song.kick(ks, b, beat, kg * (0.6 if name == "intro" else 1.0))
    hats = name in ("build", "drop", "drop2", "verse") or (name == "intro" and i >= 4)
    if hats:
        step = 0.5 if menu else 0.25
        for k in range(int(4 / step)):
            v = (0.55, 0.8, 1.0, 0.8)[k % 4] if not menu else (0.6, 1.0)[k % 2]
            song.add(kit.hat, song.t(b, k * step), bus="dry", pan=0.25 * (-1) ** k, gain=0.13 * v)
    if info["drop"] or (name == "build" and i >= 4) or (menu and name == "verse" and i >= 8):
        for beat in range(4):
            song.add(kit.ohat, song.t(b, beat + 0.5), bus="dry", pan=-0.15, gain=0.12)
    if P["ride"] and (name == "drop2" or (info["drop"] and song.style in ("frantic", "boss"))):
        for beat in range(4):
            song.add(kit.ride, song.t(b, beat), bus="dry", pan=0.35, gain=0.06)
    clap = kit.snare if menu else kit.clap
    if info["drop"] or name == "verse" or (name == "build" and i >= 4):
        for beat in (1, 3):
            song.add(clap, song.t(b, beat), bus="dry", gain=0.38, rev=0.25 if menu else 0.12)
        if info["drop"] and i % 8 == 7:
            for k, pos in enumerate((3.25, 3.5, 3.75)):
                song.add(clap, song.t(b, pos), bus="dry", gain=0.2 + 0.07 * k, rev=0.1)
    roll_zone = (name in ("build", "break") and i >= n - 2) or (song.style == "boss" and name == "intro" and i >= n - 2)
    if roll_zone and not (menu and name == "build"):
        first = i == n - 2
        steps = 8 if first else 16
        for k in range(steps):
            prog = ((0 if first else 1) + k / steps) / 2
            song.add(clap, song.t(b, k * 4 / steps), bus="dry", gain=0.1 + 0.3 * prog, rev=0.15)


def bass_bar(song, kit, b, info, notes):
    P, name, i = song.prof, info["name"], info["i"]
    if name not in ("build", "drop", "drop2", "verse"):
        return
    note = song.key + info["root"]
    base = {"rolling": 900, "offbeat": 750, "octave": 1100, "reverse": 800}[P["bass"]]
    cut = sweep(info, (220, base)) if name == "build" else base * (1.3 if name == "drop2" else 1.0)
    bt = song.beat
    if P["bass"] == "reverse" and info["drop"]:
        rb = kit.rev_cache.setdefault(note, make_revbass(note, bt))
        for beat in range(4):
            song.add(rb, song.t(b, beat + 0.22), bus="dry", gain=0.55)
        return
    if P["bass"] in ("offbeat", "reverse"):
        for beat in range(4):
            notes.append(Note(song.t(b, beat + 0.5), 0.42 * bt, note, 1.0, cut, 1.5))
            if name == "drop2" and song.style == "pump":
                notes.append(Note(song.t(b, beat + 0.75), 0.2 * bt, note + 12, 0.6, cut, 1.5))
    elif P["bass"] == "rolling":
        for beat in range(4):
            for s in (1, 2, 3):
                up = 12 if (name == "drop2" and s == 3 and beat % 2) else 0
                notes.append(Note(song.t(b, beat + s / 4), 0.21 * bt, note + up, (0.8, 0.9, 1.0)[s - 1], cut, 2.0))
    else:  # octave (synthwave)
        for k in range(8):
            notes.append(Note(song.t(b, k / 2), 0.45 * bt, note + 12 * (k % 2), 0.9, cut, 1.2))


def acid_cut(info, frac):
    name, x = info["name"], info["i"] + frac
    lfo = 0.5 - 0.5 * np.cos(2 * np.pi * (x % 8) / 8)
    if name == "intro":
        return 160 * 1.25 ** x
    if name == "build":
        return 450 * 3 ** (x / info["n"])
    if name == "break":
        return 250 * 12 ** (x / info["n"])
    return (1000 if name == "drop2" else 700) * (1 + 1.8 * lfo)


def acid_bar(song, b, info, notes, pats):
    mode = song.prof["acid"]
    if not mode or (mode == "late" and info["name"] not in ("break", "drop2")):
        return
    pat = pats[(info["i"] // 8) % 2]
    half = (b % 2) * 16
    step = song.beat / 4
    on = {p["s"] for p in pat}
    for p in pat:
        if not half <= p["s"] < half + 16:
            continue
        s = p["s"] - half
        legato_next = (p["s"] + 1) in on and any(q["s"] == p["s"] + 1 and q["slide"] for q in pat)
        notes.append(Note(song.t(b, s / 4), step * (1.0 if legato_next else 0.55), song.key + 12 + info["root"] + p["off"],
                          1.0 if p["acc"] else 0.7, acid_cut(info, s / 16), 6.0 if p["acc"] else 3.0,
                          p["slide"] and s > 0, 0.07 if p["acc"] else 0.15))


ARP_IDX = (0, 2, 1, 3, 2, 4, 3, 5, 4, 3, 2, 1, 3, 2, 1, 0)


def arp_bar(song, b, info, notes):
    P, name = song.prof, info["name"]
    if not P["arp"]:
        return
    active = {"saw": ("intro", "verse", "drop", "break", "drop2"), "square": ("drop", "break", "drop2", "build")}[P["arp"]]
    if song.style == "frantic":
        active = ("build", "drop", "drop2")
    if name not in active:
        return
    tones = chord_tones(song.key + 24 + info["root"], info["qual"])
    cut = {"intro": sweep(info, (300, 1500)), "build": sweep(info, (600, 2000)), "verse": 1300,
           "drop": 1800, "break": sweep(info, (700, 2500)), "drop2": 2600}[name]
    div = 8 if (song.style == "frantic" and name == "drop2") else 4
    for k in range(4 * div):
        notes.append(Note(song.t(b, k / div), 0.85 * song.beat / div, tones[ARP_IDX[k % 16]], 0.9, cut, 3.0))


def lead_notes(song, b, info, motifs):
    m = motifs[(info["i"] // 8) % 2]
    half = (b % 2) * 8
    tones = chord_tones(song.key + 24 + info["root"], info["qual"])
    out = []
    for pos, dur, idx in m:
        if half <= pos < half + 8:
            out.append((song.t(b, (pos - half) / 2), dur * song.beat / 2, tones[idx]))
    return out


def lead_bar(song, kit, b, info, motifs, mono):
    P, name, i = song.prof, info["name"], info["i"]
    kind = P["lead"]
    if not kind:
        return
    phrase_odd = (i // 8) % 2 == 1
    if kind == "alarm":
        if name != "break":
            for k in range(8):
                nt = song.key + 36 + (k % 2)
                mono.append(Note(song.t(b, k / 2), 0.48 * song.beat, nt, 1.0 if name != "intro" else 0.6,
                                 2400 if name != "intro" else sweep(info, (500, 2400)), 1.0))
        return
    on = {"saw": name in ("drop", "break", "drop2"), "pluck": name == "drop2" or (name == "drop" and phrase_odd),
          "super": name in ("break", "drop2") or (name == "drop" and phrase_odd)}[kind]
    if not on:
        return
    for t, dur, midi in lead_notes(song, b, info, motifs):
        if kind == "super":
            n = int((dur + 0.15) * SR)
            x = supersaw(mtof(midi), n, kit.rng) + 0.5 * supersaw(mtof(midi - 12), n, kit.rng, 5)
            x = lp(x, 1800 if name == "break" else 5500) * adsr(n, 0.005, 0.3, 0.7, 0.15)
            song.add(x, t, gain=0.075, rev=0.35, dly=0.15)
        else:
            cut = 2200 if kind == "saw" else 1600
            mono.append(Note(t, dur * 0.95, midi + (0 if kind == "saw" else 12), 1.0, cut, 1.0 if kind == "saw" else 4.0))


def stab_bar(song, kit, b, info):
    P, name, i = song.prof, info["name"], info["i"]
    kind = P["stabs"]
    if not kind or not info["drop"]:
        return
    if kind == "chord" and name != "drop2":
        return
    if kind == "super" and name == "drop" and (i // 8) % 2 == 1 and song.style != "boss":
        return
    steps = STAB_STEPS["chord" if kind == "chord" else "dark" if kind == "dark" else song.style]
    base = song.key + 24 + info["root"]
    chord = [base + x for x in triad(info["qual"])] + [base + 12]
    dur = song.beat * (0.35 if kind == "dark" else 0.2)
    n = int((dur + 0.1) * SR)
    cut = {"chord": 2600, "dark": 1100, "super": 4500}[kind]
    for s in steps:
        x = sum(supersaw(mtof(m), n, kit.rng, 5 if kind != "super" else 7) for m in chord) / 2.5
        x = lp(x, cut) * adsr(n, 0.002, dur * 0.5, 0.4, 0.08)
        song.add(x, song.t(b, s / 4), gain=0.09, rev=0.2, dly=0.25 if kind != "super" else 0.1)


def pad_bar(song, kit, b, info):
    name, style = info["name"], song.style
    if b % 2:
        return
    full = name == "break" or style == "menu"
    if not (name in ("intro", "break") or (info["drop"] and style in ("menu", "pump", "hardstyle", "frantic"))
            or (style == "menu" and name == "verse")):
        return
    base = song.key + 24 + info["root"]
    chord = [base + x for x in triad(info["qual"])] + [base + 12]
    n = int((8 * song.beat + 1.0) * SR)
    cut = {"intro": 700, "break": 2600, "verse": 1600}.get(name, 1800)
    x = sum(supersaw(mtof(m), n, kit.rng, 5, 0.18) for m in chord) / 3
    x = lp(x, cut) * adsr(n, 0.4, 2.0, 0.8, 1.0)
    song.add(x, song.t(b), gain=(0.18 if name == "break" else 0.09) if full else 0.05, rev=0.4)


def fx_bar(song, kit, b, info):
    name, i, n = info["name"], info["i"], info["n"]
    riser = None
    if name == "build" and i == 0:
        riser = 8
    elif name == "break" and i == n - min(8, n):
        riser = min(8, n)
    elif song.style == "boss" and name == "intro" and i == 4:
        riser = 4
    elif song.style == "menu" and name == "verse" and i == n - 4:
        riser = 4
    if riser:
        song.add(make_riser(kit.rng, riser * 4 * song.beat, song.key + 12), song.t(b), bus="dry", gain=0.16, rev=0.2)
    if i == 0 and (info["drop"] or name == "break" or b == 0):
        big = info["drop"]
        song.add(kit.impact, song.t(b), bus="dry", gain=0.45 if big else 0.3, rev=0.3)
        song.add(kit.crash, song.t(b), bus="dry", gain=0.16 if big else 0.1, rev=0.2)
    elif info["drop"] and i % 8 == 0:
        song.add(kit.crash, song.t(b), bus="dry", gain=0.09, rev=0.15)


def compose(song):
    kit = Kit(song)
    rng = song.rng
    motifs = [make_motif(rng), make_motif(rng)]
    pats = [make_acid(rng), make_acid(rng)]
    bass, acid, arp, lead = [], [], [], []
    for b in range(song.bars):
        info = song.bar_info(b)
        drums_bar(song, kit, b, info)
        bass_bar(song, kit, b, info, bass)
        acid_bar(song, b, info, acid, pats)
        arp_bar(song, b, info, arp)
        lead_bar(song, kit, b, info, motifs, lead)
        stab_bar(song, kit, b, info)
        pad_bar(song, kit, b, info)
        fx_bar(song, kit, b, info)
    hard = song.style in ("hard", "frantic", "boss")
    song.add_voice(bass, 0.42, wave="saw", q=1.1, decay=0.08, drive=2.5 if hard else 1.4, sub=0.8)
    song.add_voice(acid, 0.2, pan=0.1, wave="saw" if song.style == "acid" else "square", q=9.0, decay=0.15,
                   drive=3.0, glide=0.06, rev=0.1, dly=0.2)
    song.add_voice(arp, 0.11, pan=-0.2, wave=song.prof["arp"] or "saw", q=2.5, decay=0.08, rev=0.2, dly=0.3)
    style_lead = {"saw": dict(wave="saw", detune=9, decay=0.3, vib=(5.0, 0.1), glide=0.05),
                  "pluck": dict(wave="square", decay=0.1, amp_decay=0.2),
                  "alarm": dict(wave="square", decay=0.2, drive=2.0, vib=(7.0, 0.6))}.get(song.prof["lead"])
    if style_lead:
        song.add_voice(lead, 0.15, wave=style_lead.pop("wave"), q=1.5, rev=0.3, dly=0.25, **style_lead)
        if song.prof["lead"] == "alarm":
            hi = [Note(n.t, n.dur, n.midi + 12, n.vel * 0.6, n.cut * 1.5, 1.0) for n in lead
                  if song.bar_info(int(n.t / (4 * song.beat)))["name"] == "drop2"]
            song.add_voice(hi, 0.09, pan=0.3, wave="saw", q=1.2, detune=12, vib=(7.0, 0.6), rev=0.3)


# ----------------------------------------------------------------- mixdown
def make_ir(seed, rt=2.2, pre=0.018):
    r = np.random.default_rng(seed)
    n = int(rt * SR)
    t = np.arange(n) / SR
    ir = lp(r.standard_normal((2, n)) * np.exp(-6.9 * t / rt), 6500)
    ir[:, :int(pre * SR)] = 0
    return ir / np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True))


def pingpong(x, d, fb=0.42, taps=7):
    mono = lp(hp((x[0] + x[1]) * 0.5, 300), 5000)
    out = np.zeros_like(x)
    for k in range(1, taps + 1):
        sh = k * d
        if sh >= x.shape[1]:
            break
        out[(k - 1) % 2, sh:] += mono[:-sh] * fb ** (k - 1)
    return out


def mixdown(song):
    ir = make_ir(song.seed + 5)
    wet = np.vstack([signal.oaconvolve(song.rev[c], ir[c])[:song.N] for c in range(2)])
    dly = pingpong(song.dly.astype(float), int(round(0.75 * song.beat * SR)))
    mix = song.dry + (song.duck + 0.6 * wet + 0.5 * dly) * song.sidechain()
    mix = hp(mix, 25)
    out = mix[:, :song.L].copy()
    out[:, :song.N - song.L] += mix[:, song.L:]  # wrap tail onto head -> seamless loop
    return out


def soft_clip(x, ceil, knee=0.6):
    a = knee * ceil
    mag = np.abs(x)
    over = a + (ceil - a) * np.tanh((mag - a) / (ceil - a))
    return np.where(mag > a, np.sign(x) * over, x)


# ------------------------------------------------------------------ ffmpeg I/O
def _ff(args, data=None):
    p = subprocess.run([FFMPEG, "-hide_banner", "-nostats", *args], input=data, capture_output=True)
    if p.returncode:
        raise RuntimeError(p.stderr.decode(errors="replace")[-2000:])
    return p


def _raw(x):
    return np.ascontiguousarray(x.T, dtype="<f4").tobytes()


def ebur128(args, data=None):
    err = _ff([*args, "-af", "ebur128=peak=true", "-f", "null", "-"], data).stderr.decode()
    lufs = float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1])
    tp = float(re.findall(r"Peak:\s+(-?[\d.inf]+) dBFS", err)[-1])
    return lufs, tp


def measure(x):
    return ebur128(["-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-"], _raw(x))


def master(x, ceil_db):
    x = x / np.max(np.abs(x)) * 0.5
    ceil, g = 10 ** (ceil_db / 20), 1.0
    for _ in range(6):
        y = soft_clip(x * g, ceil)
        lufs, tp = measure(y)
        if abs(TARGET_LUFS - lufs) < 0.1:
            break
        g *= 10 ** ((TARGET_LUFS - lufs) / 20)
    return y, lufs, tp


def encode(y, path):
    """Vorbis ~q5 via libsndfile (this ffmpeg build lacks libvorbis; its native encoder is poor)."""
    import soundfile as sf
    data = np.ascontiguousarray(y.T, dtype=np.float32)
    with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=0.5) as f:
        for k in range(0, len(data), 8192):  # chunked: big single writes crash libsndfile's vorbis path
            f.write(data[k:k + 8192])


def render(spec):
    song = Song(*spec)
    compose(song)
    x = mixdown(song)
    path = os.path.join(OUT_DIR, song.name + ".ogg")
    ceil_db = -2.0
    for _ in range(4):
        y, lufs, tp = master(x, ceil_db)
        encode(y, path)
        _, otp = ebur128(["-i", path])
        if otp <= -1.1:
            break
        ceil_db -= 0.5
    print(f"{song.name}: {song.L / SR:.2f}s pre-enc {lufs:.2f} LUFS tp {tp:.2f} | ogg tp {otp:.2f} (ceil {ceil_db})")


# ------------------------------------------------------------------ QA check
def decode(path):
    raw = _ff(["-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"]).stdout
    return np.frombuffer(raw, "<f4").reshape(-1, 2).T


def check():
    total = 0
    for name, bpm, bars, *_ in TRACKS:
        path = os.path.join(OUT_DIR, name + ".ogg")
        x = decode(path)
        size = os.path.getsize(path)
        total += size
        lufs, tp = ebur128(["-i", path])
        err = _ff(["-i", path, "-af", "loudnorm=I=-14:TP=-1:print_format=json", "-f", "null", "-"]).stderr.decode()
        ln = json.loads(err[err.rindex("{"):err.rindex("}") + 1])
        expect = int(round(bars * 4 * 60 / bpm * SR))
        d = np.abs(np.diff(x, axis=1))
        seam = np.max(np.abs(x[:, 0] - x[:, -1]))
        w = int(0.05 * SR)
        rms = lambda s: 20 * np.log10(np.sqrt(np.mean(s ** 2)) + 1e-12)
        print(f"{name:9s} {bpm}bpm {bars}bars {x.shape[1] / SR:7.2f}s (samples {x.shape[1]} vs {expect}) "
              f"{size / 1e6:.2f}MB | ebur128 I {lufs:.1f} LUFS TP {tp:.1f} dBTP | loudnorm I {ln['input_i']} "
              f"TP {ln['input_tp']} | seam jump {seam:.4f} (p99 step {np.percentile(d, 99):.4f}, max step "
              f"{d.max():.4f}) | rms head/tail 50ms {rms(x[:, :w]):.1f}/{rms(x[:, -w:]):.1f} dB")
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
