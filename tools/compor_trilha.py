#!/usr/bin/env python3
"""Compositor/sintetizador da trilha sonora do Breakout Matemático 3D.

Gera músicas originais (synthwave) por síntese, sem samples e sem direitos autorais:
  jogo_1/2/3 em 4 camadas sincronizadas (base, ritmo, arp, lead), menu, quiz, vitoria, derrota.
Requer: numpy, scipy e ffmpeg (libvorbis).   Uso: python3 tools/compor_trilha.py [pasta_destino]
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
rng = np.random.default_rng(7)
_sos = {}


def mtof(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


# ------------------------------------------------------------------ osciladores / envelopes
def polyblep(t, dt):
    out = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m = t > 1.0 - dt
    x = (t[m] - 1.0) / dt[m]
    out[m] = x * x + x + x + 1.0
    return out


def osc(kind, freq, n, pw=0.5, phase0=0.0):
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    dt = freq / SR
    t = (phase0 + np.cumsum(dt)) % 1.0
    if kind == "saw":
        return 2.0 * t - 1.0 - polyblep(t, dt)
    if kind == "square":
        y = np.where(t < pw, 1.0, -1.0)
        return y + polyblep(t, dt) - polyblep((t + (1.0 - pw)) % 1.0, dt)
    if kind == "tri":
        return 2.0 * np.abs(2.0 * t - 1.0) - 1.0
    return np.sin(2.0 * np.pi * t)


def adsr(n, a, d, s, r):
    na = min(n, int(a * SR))
    nd = min(n - na, int(d * SR))
    nr = min(n, int(r * SR))
    e = np.empty(n)
    if na:
        e[:na] = np.linspace(0.0, 1.0, na, endpoint=False)
    if nd:
        e[na:na + nd] = np.linspace(1.0, s, nd, endpoint=False)
    e[na + nd:] = s
    if nr:
        e[n - nr:] *= np.linspace(1.0, 0.0, nr)
    return e


def lp(x, fc, order=2):
    key = ("lp", fc, order)
    if key not in _sos:
        _sos[key] = butter(order, min(fc, SR * 0.45), btype="low", fs=SR, output="sos")
    return sosfilt(_sos[key], x)


def hp(x, fc, order=2):
    key = ("hp", fc, order)
    if key not in _sos:
        _sos[key] = butter(order, fc, btype="high", fs=SR, output="sos")
    return sosfilt(_sos[key], x)


def bp(x, lo, hi):
    key = ("bp", lo, hi)
    if key not in _sos:
        _sos[key] = butter(2, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(_sos[key], x)


def noise(n):
    return rng.standard_normal(n)


# ------------------------------------------------------------------ instrumentos
def pluck(midi, dur, bright=3200, tau=0.13):
    n = int((dur + 0.35) * SR)
    f = mtof(midi)
    y = osc("saw", f, n) * 0.6 + osc("saw", f * 1.004, n) * 0.4
    t = np.arange(n) / SR
    e = np.exp(-t / tau) * np.minimum(1.0, t / 0.002)
    return lp(y, bright) * e


def bass_note(midi, dur):
    n = int((dur + 0.06) * SR)
    f = mtof(midi)
    y = osc("saw", f, n) * 0.7 + osc("square", f, n) * 0.3
    y = lp(y, 900) + 0.6 * osc("sin", f, n)
    return np.tanh(y * 1.4) * adsr(n, 0.004, 0.08, 0.8, 0.05)


def pad_chord(midis, dur, bright=1500):
    n = int((dur + 1.0) * SR)
    y = np.zeros(n)
    for m in midis:
        f = mtof(m)
        for det in (0.9965, 1.0, 1.0035):
            y += osc("saw", f * det, n)
    y = lp(y / (3 * len(midis)), bright)
    return y * adsr(n, 0.5, 0.3, 0.8, 0.9)


def lead_note(midi, dur, kind):
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    f = mtof(midi) * (1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) / 0.25, 0, 1))
    if kind == "saw":
        y = osc("saw", f, n) * 0.6 + osc("square", f * 1.003, n) * 0.4
        y = lp(y, 5000)
    elif kind == "square":
        y = osc("square", f, n, pw=0.35) * 0.7 + osc("saw", f * 0.997, n) * 0.3
        y = lp(y, 3500)
    else:
        y = (osc("saw", f * 0.994, n) + osc("saw", f, n) + osc("saw", f * 1.006, n)) / 3.0
        y = lp(y, 6000) + 0.25 * osc("sin", f * 0.5, n)
    return y * adsr(n, 0.012, 0.12, 0.7, 0.28)


def bell(midi, dur, ratio=3.5, index=3.0):
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    f = mtof(midi)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * np.exp(-t / 0.35)
    y = np.sin(2 * np.pi * f * t + mod)
    return y * np.exp(-t / (0.5 + dur * 0.5)) * np.minimum(1.0, t / 0.003)


def kick():
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 45.0 + 120.0 * np.exp(-t / 0.035)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.15)
    y += 0.25 * noise(n) * np.exp(-t / 0.004)
    return y


def snare():
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    y = bp(noise(n), 1500, 9000) * np.exp(-t / 0.10)
    y += 0.55 * np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.06)
    for off in (0.0, 0.011, 0.022):
        i = int(off * SR)
        y[i:] += 0.25 * hp(noise(n - i), 1200) * np.exp(-np.arange(n - i) / SR / 0.04)
    return y


def hat(open_=False):
    n = int((0.5 if open_ else 0.11) * SR)
    t = np.arange(n) / SR
    return hp(noise(n), 8000) * np.exp(-t / (0.16 if open_ else 0.03))


def crash():
    n = int(2.6 * SR)
    t = np.arange(n) / SR
    return hp(noise(n), 5000) * np.exp(-t / 0.9)


def tick(freq):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2.7 * t)) * np.exp(-t / 0.018)


# ------------------------------------------------------------------ mixagem / efeitos
def beat_sample(beat, bpm):
    return int(round(beat * 60.0 / bpm * SR))


def put(buf, start, mono, pan=0.0, gain=1.0):
    if start >= len(buf):
        return
    end = min(len(buf), start + len(mono))
    seg = mono[:end - start] * gain
    a = (pan + 1.0) * np.pi / 4.0
    buf[start:end, 0] += seg * np.cos(a)
    buf[start:end, 1] += seg * np.sin(a)


def reverb(x, seconds=1.8, wet=0.3):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = np.stack([noise(n), noise(n)], 1) * np.exp(-t * (6.9 / seconds))[:, None]
    ir = sosfilt(butter(1, 5500, fs=SR, output="sos"), ir, axis=0)
    ir /= np.linalg.norm(ir, axis=0) + 1e-9
    w = np.stack([fftconvolve(x[:, 0], ir[:, 0]), fftconvolve(x[:, 1], ir[:, 1])], 1)
    out = np.zeros_like(w)
    out[:len(x)] = x
    return out * (1.0 - wet * 0.5) + w * wet


def delay(x, time_s, fb=0.45, mix=0.35, taps=4):
    d = int(time_s * SR)
    out = x.copy()
    for k in range(1, taps + 1):
        sh = np.zeros_like(x)
        sh[k * d:] = x[:len(x) - k * d]
        if k % 2:
            sh = sh[:, ::-1]
        out += mix * (fb ** (k - 1)) * sh
    return out


def fold(x, length):
    out = x[:length].copy()
    tail = x[length:]
    m = min(len(tail), length)
    out[:m] += tail[:m]
    return out


def duck_env(n, kick_beats, bpm, depth=0.55):
    env = np.ones(n)
    seg = int(0.28 * SR)
    tt = np.arange(seg) / SR
    dip = 1.0 - depth * np.exp(-tt / 0.09)
    for b in kick_beats:
        s = beat_sample(b, bpm)
        if s >= n:
            continue
        e = min(n, s + seg)
        env[s:e] = np.minimum(env[s:e], dip[:e - s])
    return env[:, None]


def fade_out(n, seconds):
    f = np.ones(n)
    m = int(seconds * SR)
    f[-m:] = np.linspace(1.0, 0.0, m)
    return f[:, None]


def soft(x):
    a = np.abs(x)
    return np.where(a < 0.8, x, np.sign(x) * (0.8 + 0.2 * np.tanh((a - 0.8) / 0.2)))


# ------------------------------------------------------------------ composição
BASE_PROG = [  # Am - F - C - G (raiz grave, acorde)
    (45, [57, 60, 64, 67]),
    (41, [53, 57, 60, 64]),
    (48, [60, 64, 67, 71]),
    (43, [55, 59, 62, 69]),
]
M1 = [
    [(0, 2, 76), (2, 1, 74), (3, 1, 72)], [(0, 1, 69), (1, 1, 72), (2, 2, 77)],
    [(0, 1, 76), (1, 1, 79), (2, 1, 76), (3, 1, 72)], [(0, 2, 74), (2, 1, 71), (3, 1, 74)],
    [(0, 1, 81), (1, 1, 79), (2, 1, 76), (3, 1, 72)], [(0, 1, 77), (1, 1, 76), (2, 1, 72), (3, 1, 69)],
    [(0, 1, 72), (1, 1, 76), (2, 2, 79)], [(0, 2, 79), (2, 2, 74)],
]
M2 = [
    [(0, .5, 72), (.5, .5, 76), (1, 1, 79), (2, 2, 76)], [(0, .5, 72), (.5, .5, 77), (1, 1, 81), (2, 2, 77)],
    [(0, 1, 79), (1, .5, 76), (1.5, .5, 72), (2, 2, 76)], [(0, 1, 74), (1, 1, 79), (2, 1, 78), (3, 1, 74)],
    [(0, 1.5, 81), (1.5, .5, 79), (2, 2, 76)], [(0, 1.5, 77), (1.5, .5, 76), (2, 2, 72)],
    [(0, 1, 76), (1, 1, 79), (2, 1, 84), (3, 1, 79)], [(0, 2, 83), (2, 1, 79), (3, 1, 74)],
]
BASS_PAT = {
    "eighths": [(s, 12 if s in (6, 14) else 0, 2) for s in range(0, 16, 2)],
    "offbeat": [(s, 0, 2) for s in (2, 6, 10, 14)],
    "rolling": [(s, iv, 1) for s, iv in enumerate([0, 0, 12, 0, 0, 0, 12, 0, 0, 0, 12, 0, 0, 12, 0, 12])],
}
ARP_PAT = {
    "A": [0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1, 2, 3],
    "B": [0, 2, 1, 3, 4, 6, 5, 7, 0, 2, 1, 3, 4, 6, 5, 7],
    "C": [0, 4, 1, 5, 2, 6, 3, 7, 4, 0, 5, 1, 6, 2, 7, 3],
}
DRUMS = {
    "four": dict(kick={0, 4, 8, 12}, snare={4, 12}, hat={2: .8, 6: .8, 10: .8, 14: .8, 1: .22, 3: .22, 5: .22, 7: .22,
                                                       9: .22, 11: .22, 13: .22, 15: .22}),
    "break": dict(kick={0, 3, 6, 10}, snare={4, 12}, hat={0: .5, 2: .5, 4: .5, 6: .5, 8: .5, 10: .5, 12: .5, 14: .5}),
}
TRACKS = [
    dict(name="jogo_1", bpm=120, cs=0, ls=0, bass="eighths", arp="A", drums="four", mel=M1, lead="saw"),
    dict(name="jogo_2", bpm=126, cs=-5, ls=-5, bass="offbeat", arp="B", drums="break", mel=M2, lead="square"),
    dict(name="jogo_3", bpm=132, cs=5, ls=5, bass="rolling", arp="C", drums="four", mel=M2, lead="super"),
]


def wrap_bass(r):
    while r > 47:
        r -= 12
    return r


def render_game(cfg):
    bpm, bars = cfg["bpm"], 16
    beat = 60.0 / bpm
    L = int(round(bars * 4 * beat * SR))
    N = L + int(3.2 * SR)
    kick_beats = []
    drums = DRUMS[cfg["drums"]]
    base = np.zeros((N, 2))
    ritmo = np.zeros((N, 2))
    arp = np.zeros((N, 2))
    lead = np.zeros((N, 2))
    cache = {}
    k_s, s_s, h_s, oh_s, c_s = kick(), snare(), hat(False), hat(True), crash()

    for bar in range(bars):
        root, chord = BASE_PROG[bar % 4]
        root = wrap_bass(root + cfg["cs"])
        chord = [c + cfg["cs"] for c in chord]
        b0 = bar * 4
        # base: pad + baixo
        put(base, beat_sample(b0, bpm), pad_chord(chord, 4 * beat), 0.0, 0.7)
        for step, iv, ln in BASS_PAT[cfg["bass"]]:
            key = ("b", root + iv, ln)
            if key not in cache:
                cache[key] = bass_note(root + iv, ln * 0.25 * beat)
            put(base, beat_sample(b0 + step * 0.25, bpm), cache[key], 0.0, 0.8)
        # arp
        tones = chord + [c + 12 for c in chord]
        for step, idx in enumerate(ARP_PAT[cfg["arp"]]):
            key = ("a", tones[idx])
            if key not in cache:
                cache[key] = pluck(tones[idx], 0.25 * beat)
            put(arp, beat_sample(b0 + step * 0.25, bpm), cache[key], -0.35 + 0.7 * (step % 4) / 3.0, 0.6)
        # bateria
        fill = bar % 4 == 3
        for step in range(16):
            pos = b0 + step * 0.25
            sp = beat_sample(pos, bpm)
            if step in drums["kick"]:
                put(ritmo, sp, k_s, 0.0, 1.0)
                kick_beats.append(pos)
            if fill and step >= 12:
                put(ritmo, sp, s_s, 0.0, 0.45 + 0.18 * (step - 12))
            elif step in drums["snare"]:
                put(ritmo, sp, s_s, 0.0, 0.75)
            if step in drums["hat"]:
                put(ritmo, sp, h_s, 0.3 if step % 4 else -0.3, 0.3 * drums["hat"][step])
            if step == 14 and bar % 2 == 1:
                put(ritmo, sp, oh_s, 0.25, 0.28)
        if bar in (0, 8):
            put(ritmo, beat_sample(b0, bpm), c_s, 0.2, 0.35)
        # lead
        mel = cfg["mel"][bar % 8]
        for off, ln, midi in mel:
            n = midi + cfg["ls"]
            sp = beat_sample(b0 + off, bpm)
            put(lead, sp, lead_note(n, ln * beat, cfg["lead"]), 0.1, 0.65)
            if bar >= 12:
                put(lead, sp, lead_note(n + 12, ln * beat, cfg["lead"]), -0.1, 0.22)

    # efeitos
    duck = duck_env(N, kick_beats, bpm, 0.5)
    base = reverb(base * duck, 2.2, 0.22)
    arp = reverb(delay(arp * duck, beat * 0.75, 0.45, 0.4), 1.6, 0.2)
    lead = reverb(delay(lead, beat, 0.4, 0.3, 3), 2.0, 0.3)
    ritmo = reverb(ritmo, 0.8, 0.08)
    stems = {k: fold(v, L) for k, v in dict(base=base, ritmo=ritmo, arp=arp, lead=lead).items()}
    mix = sum(stems.values())
    scale = 0.78 / np.percentile(np.abs(mix), 99.8)
    return {k: soft(v * scale) for k, v in stems.items()}


def render_menu():
    bpm, bars = 80, 16
    beat = 60.0 / bpm
    L = int(round(bars * 4 * beat * SR))
    N = L + int(3.5 * SR)
    prog = [(38, [50, 57, 60, 64], [(0, 1.5, 81), (1.5, .5, 79), (2, 2, 77)]),
            (34, [58, 62, 65, 69], [(0, 1.5, 77), (1.5, .5, 74), (2, 2, 74)]),
            (41, [53, 60, 64, 69], [(0, 1.5, 81), (1.5, .5, 77), (2, 2, 72)]),
            (36, [48, 55, 60, 64, 67], [(0, 1.5, 79), (1.5, .5, 76), (2, 2, 72)])]
    pad = np.zeros((N, 2))
    arp = np.zeros((N, 2))
    bells = np.zeros((N, 2))
    low = np.zeros((N, 2))
    k = lp(kick(), 160) * 0.5
    for bar in range(bars):
        root, chord, motif = prog[bar % 4]
        b0 = bar * 4
        put(pad, beat_sample(b0, bpm), pad_chord(chord, 4 * beat, 1100), 0.0, 0.6)
        n = int((4 * beat + 0.4) * SR)
        sub = (osc("sin", mtof(root), n) + 0.4 * osc("tri", mtof(root), n)) * adsr(n, 0.15, 0.2, 0.85, 0.35)
        put(low, beat_sample(b0, bpm), sub, 0.0, 0.7)
        if bar % 2 == 0:
            put(low, beat_sample(b0, bpm), k, 0.0, 0.6)
            put(low, beat_sample(b0 + 2, bpm), k, 0.0, 0.45)
        for step in range(8):
            tone = chord[[0, 1, 2, 3, 2, 1, 2, 3][step] % len(chord)] + (12 if step % 4 == 3 else 0)
            put(arp, beat_sample(b0 + step * 0.5, bpm), pluck(tone, 0.5 * beat, 2400, 0.16),
                -0.4 + 0.8 * step / 7.0, 0.32)
        for off, ln, midi in motif:
            put(bells, beat_sample(b0 + off, bpm), bell(midi, ln * beat), 0.15, 0.16)
    arp = reverb(delay(arp, beat * 0.75, 0.5, 0.45), 2.4, 0.3)
    bells = reverb(bells, 3.0, 0.4)
    pad = reverb(pad, 3.0, 0.35)
    mix = fold(pad, L) + fold(arp, L) + fold(bells, L) + fold(low, L)
    return {"menu": soft(mix * 0.5 / np.percentile(np.abs(mix), 99.8))}


def render_quiz():
    bpm, bars = 100, 8
    beat = 60.0 / bpm
    L = int(round(bars * 4 * beat * SR))
    N = L + int(3.0 * SR)
    chords = [[57, 60, 64], [55, 59, 62], [57, 60, 64], [56, 59, 62]]
    pats = [[57, 60, 64, 60, 57, 60, 64, 67], [55, 59, 62, 59, 55, 59, 62, 65],
            [57, 60, 64, 60, 57, 60, 64, 67], [56, 59, 62, 59, 56, 59, 62, 64]]
    drone = np.zeros((N, 2))
    arp = np.zeros((N, 2))
    clock = np.zeros((N, 2))
    t_hi, t_lo = tick(1250), tick(880)
    for bar in range(bars):
        b0 = bar * 4
        ch = chords[bar // 2 % 4]
        n = int((4 * beat + 0.5) * SR)
        d = osc("saw", mtof(33 + (ch[0] - 57)), n) + 0.7 * osc("saw", mtof(40 + (ch[0] - 57)), n)
        put(drone, beat_sample(b0, bpm), lp(d, 320) * adsr(n, 0.3, 0.2, 0.9, 0.5), 0.0, 0.5)
        put(drone, beat_sample(b0, bpm), pad_chord([c for c in ch], 4 * beat, 900), 0.0, 0.25)
        for step, midi in enumerate(pats[bar // 2 % 4]):
            put(arp, beat_sample(b0 + step * 0.5, bpm), pluck(midi, 0.5 * beat, 2800, 0.1), -0.3 + 0.6 * (step % 2), 0.35)
        for b in range(4):
            put(clock, beat_sample(b0 + b, bpm), t_hi if b % 2 == 0 else t_lo, 0.0, 0.5 if b % 2 == 0 else 0.35)
    arp = reverb(delay(arp, beat * 0.75, 0.4, 0.35), 1.4, 0.2)
    drone = reverb(drone, 2.5, 0.25)
    mix = fold(drone, L) + fold(arp, L) + fold(clock, L)
    return {"quiz": soft(mix * 0.55 / np.percentile(np.abs(mix), 99.8))}


def render_vitoria():
    bpm = 120
    N = int(6.0 * SR)
    buf = np.zeros((N, 2))
    for beat_pos, ln, midi in [(0, .5, 72), (.5, .5, 76), (1, .5, 79), (1.5, .5, 84)]:
        put(buf, beat_sample(beat_pos, bpm), bell(midi, ln * 0.5), 0.0, 0.5)
        put(buf, beat_sample(beat_pos, bpm), lead_note(midi, ln * 0.5, "saw"), 0.0, 0.25)
    for midi in (72, 76, 79, 84, 88):
        put(buf, beat_sample(2, bpm), bell(midi, 2.0, 3.5, 2.0), (midi - 80) / 20.0, 0.3)
    put(buf, beat_sample(2, bpm), pad_chord([60, 64, 67, 72], 2.0, 3000), 0.0, 0.45)
    buf = reverb(buf, 2.2, 0.35)[:N]
    buf *= fade_out(N, 0.6)
    return {"vitoria": soft(buf * 0.8 / np.abs(buf).max())}


def render_derrota():
    bpm = 70
    N = int(7.0 * SR)
    buf = np.zeros((N, 2))
    for beat_pos, ln, midi in [(0, 1, 69), (1, 1, 67), (2, 1, 64), (3, 3, 57)]:
        put(buf, beat_sample(beat_pos, bpm), bell(midi, ln * 0.85, 2.7, 1.6), 0.0, 0.5)
        put(buf, beat_sample(beat_pos, bpm), pluck(midi - 12, ln * 0.85, 1800, 0.5), 0.0, 0.4)
    n = int(6.0 * SR)
    put(buf, 0, lp(osc("saw", mtof(33), n), 380) * adsr(n, 0.6, 0.3, 0.8, 2.0), 0.0, 0.5)
    put(buf, beat_sample(3, bpm), pad_chord([57, 60, 64], 3.0, 900), 0.0, 0.5)
    buf = reverb(buf, 3.0, 0.5)[:N]
    buf *= fade_out(N, 1.2)
    return {"derrota": soft(buf * 0.8 / np.abs(buf).max())}


# ------------------------------------------------------------------ saída
def write_ogg(path_ogg, audio):
    pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", path_ogg],
                       check=True)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "music")
    os.makedirs(out, exist_ok=True)
    jobs = [("menu", render_menu), ("quiz", render_quiz), ("vitoria", render_vitoria), ("derrota", render_derrota)]
    jobs += [(t["name"], (lambda c=t: render_game(c))) for t in TRACKS]
    for name, fn in jobs:
        res = fn()
        for stem, audio in res.items():
            fname = f"{name}_{stem}.ogg" if name.startswith("jogo_") else f"{stem}.ogg"
            assert np.isfinite(audio).all(), fname
            write_ogg(os.path.join(out, fname), audio)
            print(f"{fname:22s} {len(audio) / SR:6.1f}s  pico {np.abs(audio).max():.2f}  "
                  f"rms {20 * np.log10(np.sqrt((audio ** 2).mean()) + 1e-9):6.1f} dB", flush=True)


if __name__ == "__main__":
    main()
