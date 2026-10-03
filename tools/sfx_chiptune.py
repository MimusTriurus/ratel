#!/usr/bin/env python3
"""Turn the 3D preview's modern effects into sounds the NES could have made.

What the classic sound mode plays: with --install, every
assets/sfx3d/modern/<name>_<k>.ogg rendered on the APU (below) goes to
assets/sfx3d/classic/<name>_<k>.ogg, which then holds exactly modern's files,
the original's own (assets/sfx3d/original/) where modern's is still a copy
of it. A sound that loops (LOOPS) is rendered three times over and the middle
cut out, crossfaded over 10 ms at the seam, so that it loops without a click.

Every run also writes two renderings of each, side by side in
build/sfx3d_chip/, with index.html to hear them against the modern file and
the original's:

  apu/   analysed a frame (1/60 s) at a time, as NES games ran their sound
         effects, and played by a model of the 2A03's own channels:
           noise     the aperiodic part: its loudness as the 4-bit volume,
                     its spectrum matched against what each of the 16 noise
                     periods (and the short, metallic mode's) sounds like
           pulse     the pitched part, both channels for a chord: the nearest
                     timer value, a duty picked by how bright it is
           triangle  the low end of a blast, gated, since it has no volume
         <name>_<k>.csv beside each is the register table, frame by frame,
         to take into FamiStudio or a tracker.
  dpcm/  the file itself through the delta-modulation channel: 1 bit a
         sample, the 7-bit counter stepping 2 up or down, at one of the 16
         rates (--dpcm-rate, 15 = 33.1 kHz). A real sample stops at 4081
         bytes; that is reported, not enforced.

Files that are the original's own, byte for byte (modern started as a copy
of it), are not rendered: they are the NES already, and --install copies
them.

Both go through the APU's mixer and a Famicom's output filters (37 Hz
high-pass, 14 kHz low-pass) at 4x the output rate -- not the NES
front-loader's, whose 440 Hz high-pass takes out what the original's
recordings are made of: most of their energy is under 250 Hz -- and come out
44.1 kHz mono, as the original's files are, at the loudness -- the loudest
50 ms, RMS -- of the original's file of that name, so the mix's gains still
hold; where the original has none, at the modern file's as the modern mix
plays it, since the classic mix has 0 dB for it.

Nothing here is a port of anything: it is not in the Java original, and no
NES game's effects were made this way; they were written as these tables by
hand. This is a first draft of the tables, by ear.

Needs numpy, scipy and librosa, which the Basic Pitch venv has, and ffmpeg.
Run from the repo root:

    build/.venv_basic_pitch/Scripts/python tools/sfx_chiptune.py
    build/.venv_basic_pitch/Scripts/python tools/sfx_chiptune.py blast gun_0
    build/.venv_basic_pitch/Scripts/python tools/sfx_chiptune.py --install

then godot --path . --headless --import. A full --install also deletes
from classic/ what modern no longer has.

Names pick sounds (all of a sound's variants) or single files; none is all.
"""
import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys

import librosa
import numpy as np
from scipy import signal

MODERN = "assets/sfx3d/modern"
ORIGINAL = "assets/sfx3d/original"
CLASSIC = "assets/sfx3d/classic"
MIX = "assets/sfx3d/mix.json"
OUT = "build/sfx3d_chip"
# Level3DAudio.SOUNDS' "loop": true -- verify_level3d_audio.gd checks that
# classic's loops are looped, not that this list is right, so keep it with
# the table.
LOOPS = {"rocket_flight", "btr_idle", "btr_drive", "tank_engine", "boat_engine",
         "chinook", "rescue_rotor", "jeep_idle", "ambient_sea", "ambient_jungle"}
# Rotors, which a frame-by-frame reading takes apart: the APU's registers
# change 60 times a second, and a blade-pass rate that is no whole number of
# frames (the rescue helicopter's 24 Hz is 2.5) reads as a rhythm that
# wanders -- its regularity, the envelope's autocorrelation at the chop, fell
# from 0.76 to 0.19. The original's own rotors are a whole number of frames,
# 12 (chinook) and 4 (rescue_rotor). These are played instead as a steady
# chop of that many frames each (steady), the nearest to modern's rate:
# chinook's 12.6 Hz as 5 frames (12 Hz), rescue_rotor's 24 Hz as 3 (20 Hz).
STEADY = {"chinook": 5, "rescue_rotor": 3}
# How a blade's chop falls over its frames, from the loud end of the noise's
# volume to the quiet end: a thump, then the swish dying away.
CHOP = {3: [1.0, 0.55, 0.25], 5: [1.0, 0.7, 0.45, 0.25, 0.1]}

RATE = 44100
OVER = 4
FAST = RATE * OVER
CPU = 1789773.0
FRAME = 60.0
HOP = int(round(RATE / FRAME))  # 735

NOISE_PERIODS = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
DPCM_RATES = [428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54]
DPCM_MAX_BYTES = 4081
DUTY = [
    [0, 1, 0, 0, 0, 0, 0, 0],  # 12.5 %
    [0, 1, 1, 0, 0, 0, 0, 0],  # 25 %
    [0, 1, 1, 1, 1, 0, 0, 0],  # 50 %
]
REGISTERS = ["pulse_vol", "pulse_duty", "pulse_timer",
             "pulse2_vol", "pulse2_duty", "pulse2_timer",
             "tri_on", "tri_timer", "noise_vol", "noise_mode", "noise_period"]
TRIANGLE = np.array(list(range(15, -1, -1)) + list(range(16)), dtype=np.float64)

# The noise is matched on these bands, above where the triangle takes over.
MEL_BANDS = 48
MEL_FMIN = 180.0
# Below this the percussive part's energy goes to the triangle (the source
# is high-passed at 90 Hz first, as the APU's output is).
LOW_SPLIT = 180.0
# The range of the noise match, dB under the frame's loudest band.
WEIGHT_DB = 40.0
# A short-mode match must beat the long mode's by this (mean squared log
# difference) to be taken: it is a ringing tone, wrong more than right.
SHORT_PENALTY = 0.35
# The envelope's curve before the 4-bit volume: under 1 keeps the tails,
# which a linear map rounds down to nothing.
ENV_GAMMA = 0.7


# ----------------------------------------------------------------------------
# The APU

def _lfsr(short):
    """One period of the noise channel's output bit, 1 where it sounds."""
    tap = 6 if short else 1
    reg = 1
    out = []
    while True:
        out.append(1 - (reg & 1))
        bit = (reg ^ (reg >> tap)) & 1
        reg = (reg >> 1) | (bit << 14)
        if reg == 1:
            break
    return np.array(out, dtype=np.float64)


LFSR = {False: _lfsr(False), True: _lfsr(True)}


def _per_sample(frames, n):
    """A per-frame array held across each frame's samples at FAST."""
    idx = np.minimum((np.arange(n) * FRAME / FAST).astype(np.int64), len(frames) - 1)
    return np.asarray(frames)[idx]


def render_apu(table, n):
    """The three channels of `table` (per-frame registers) at FAST, n samples."""
    t = len(table["noise_vol"])
    # Pulses: a phase accumulator each, the 8-step sequence, the volume.
    pulse = np.zeros(n)
    for ch in ("pulse", "pulse2"):
        vol = np.array(table[ch + "_vol"])
        p_freq = np.where(vol > 0, CPU / (16.0 * (np.array(table[ch + "_timer"]) + 1)), 0.0)
        phase = np.cumsum(_per_sample(p_freq, n) / FAST)
        step = (phase * 8).astype(np.int64) % 8
        duty = _per_sample(table[ch + "_duty"], n)
        pulse += np.array(DUTY)[duty, step] * _per_sample(vol, n)
    # Triangle: holds its step while it is off, as the hardware does.
    tri_freq = np.where(np.array(table["tri_on"]) > 0,
                        CPU / (32.0 * (np.array(table["tri_timer"]) + 1)), 0.0)
    tphase = np.cumsum(_per_sample(tri_freq, n) / FAST)
    tri = TRIANGLE[(tphase * 32).astype(np.int64) % 32]
    # Noise: the LFSR clocked every period CPU cycles, averaged over the
    # sample so a fast period does not alias.
    noise = np.zeros(n)
    pos = {False: 0.0, True: 0.0}
    per_frame = FAST / FRAME
    for f in range(t):
        a = int(round(f * per_frame))
        b = min(n, int(round((f + 1) * per_frame)))
        if a >= b:
            continue
        short = bool(table["noise_mode"][f])
        period = NOISE_PERIODS[table["noise_period"][f]]
        clocks = CPU / period / FAST
        k = np.arange(b - a)
        start = pos[short] + k * clocks
        end = start + clocks
        seq = LFSR[short]
        if clocks >= 1.0:
            # Several clocks a sample: the mean of the bits it spans.
            cum = np.concatenate([[0.0], np.cumsum(np.tile(seq, 2))])
            L = len(seq)
            s0 = start % L
            s1 = s0 + clocks
            i0 = s0.astype(np.int64)
            i1 = np.minimum(s1.astype(np.int64), 2 * L - 1)
            mean = (cum[i1] - cum[i0]) / np.maximum(i1 - i0, 1)
        else:
            mean = seq[(start.astype(np.int64)) % len(seq)]
        noise[a:b] = mean * table["noise_vol"][f]
        pos[short] = (pos[short] + (b - a) * clocks) % len(seq)
    return pulse, tri, noise


def mix(pulse=None, tri=None, noise=None, dmc=None, n=0):
    """The APU's nonlinear mixer, then its output filters, down to RATE."""
    z = np.zeros(n)
    pulse = z if pulse is None else pulse
    tri = z if tri is None else tri
    noise = z if noise is None else noise
    dmc = z if dmc is None else dmc
    with np.errstate(divide="ignore"):
        p = np.where(pulse > 0, 95.88 / (8128.0 / np.maximum(pulse, 1e-9) + 100.0), 0.0)
        tnd_in = tri / 8227.0 + noise / 12241.0 + dmc / 22638.0
        tnd = np.where(tnd_in > 0, 159.79 / (1.0 / np.maximum(tnd_in, 1e-12) + 100.0), 0.0)
    out = p + tnd
    # A Famicom's output: against the original's enemy_hit, gun and chinook,
    # band by band, the rendering is 1.7-2 dB off, the NES's 4-5.
    for kind, freq in (("highpass", 37.0), ("lowpass", 14000.0)):
        b, a = signal.butter(1, freq, kind, fs=FAST)
        out = signal.lfilter(b, a, out)
    return signal.resample_poly(out, 1, OVER)


# ----------------------------------------------------------------------------
# The analysis

def _mel(fs):
    return librosa.filters.mel(sr=fs, n_fft=2048, n_mels=MEL_BANDS, fmin=MEL_FMIN, fmax=16000.0)


MEL = _mel(RATE)


def _shape(power):
    """Log mel bands with the level taken out: what a spectrum sounds like."""
    m = np.log(MEL @ power + 1e-10)
    return m - m.mean(axis=0, keepdims=True)


def noise_shapes():
    """What each (mode, period) of the noise channel sounds like through mix()."""
    shapes = []
    keys = []
    n = FAST // 2
    for short in (False, True):
        for i in range(16):
            table = {"noise_vol": [15] * 30, "noise_mode": [int(short)] * 30,
                     "noise_period": [i] * 30}
            table.update({k: [0] * 30 for k in REGISTERS if k not in table})
            _, _, noise = render_apu(table, n)
            y = mix(noise=noise, n=n)
            spec = np.abs(librosa.stft(y, n_fft=2048, hop_length=512)) ** 2
            shapes.append(_shape(spec.mean(axis=1, keepdims=True))[:, 0])
            keys.append((short, i))
    return np.array(shapes), keys


# The pulses' range: below it a blast's rumble scores as a tone, and the
# triangle has that end anyway.
PITCH_LOW = 180.0
PITCH_GRID = PITCH_LOW * 2.0 ** (np.arange(int(np.log2(4200.0 / PITCH_LOW) * 48)) / 48.0)
# How far a tone's harmonics must stand over the valleys between them, dB.
# Measured, median a frame: the jingles 7 to 31, soldier_death_gun 21;
# blasts, guns, rotors and launches -0.2 to 3, hit_armor's ring 6.
CONTRAST_DB = 8.0


def pitches(col, freqs):
    """Up to two fundamentals in a harmonic magnitude spectrum, loudest first,
    each with its strength against the first's (1 for the first).

    The score is the sum of the first six harmonics, falling off; a candidate
    only counts where its own fundamental is a quarter of the frame's
    loudest bin, which is what keeps it off the subharmonics a plain
    harmonic sum prefers (and pYIN found, at 98 Hz, under upgrade's
    arpeggio). It must also stand out of the frame, eight times its median,
    and its harmonics out of the valleys between them (CONTRAST_DB), which
    is what tells a tone from the hump of a noise.
    """
    col = np.where(freqs >= PITCH_LOW * 0.8, col, 0.0)
    top = col.max()
    if top <= 0:
        return []
    m = lambda f: np.interp(f, freqs, col, right=0.0)
    at = m(PITCH_GRID)
    floor = np.median(col[(freqs > 50.0) & (freqs < 8000.0)])
    score = sum(0.75 ** k * m(PITCH_GRID * (k + 1)) for k in range(6))
    score[(at < 0.25 * top) | (at < 8.0 * floor)] = 0.0
    if score.max() <= 0:
        return []
    i = int(np.argmax(score))
    out = [(PITCH_GRID[i], 1.0)]
    f1 = PITCH_GRID[i]
    # A second voice, not a harmonic of the first and a semitone clear of it.
    ratio = PITCH_GRID / f1
    near = np.abs(np.log2(PITCH_GRID / f1)) < 1.0 / 12.0
    harmonic = (np.abs(ratio - np.round(ratio)) < 0.03 * ratio) & (np.round(ratio) >= 1)
    rest = np.where(near | harmonic, 0.0, score)
    j = int(np.argmax(rest))
    if rest[j] >= 0.45 * score[i]:
        out.append((PITCH_GRID[j], float(at[j] / max(at[i], 1e-12))))
    # The first voice's harmonics against the valleys between them.
    f0 = out[0][0]
    ks = np.arange(1, 9)
    ks = ks[ks * f0 < 8000.0]
    peaks = (m(ks * f0) ** 2).sum()
    valleys = ((m((ks - 0.5) * f0) ** 2 + m((ks + 0.5) * f0) ** 2) / 2).sum()
    if 10 * np.log10(peaks / max(valleys, 1e-15)) < CONTRAST_DB:
        return []
    return out


def analyse(y, shapes, keys):
    """Per-frame registers for `y` at RATE."""
    frames = int(np.ceil(len(y) / HOP))
    stft = librosa.stft(y, n_fft=2048, hop_length=HOP)
    mag = np.abs(stft)
    harm, perc = librosa.decompose.hpss(mag, margin=1.5)
    hp, pp = harm ** 2, perc ** 2
    freqs = librosa.fft_frequencies(sr=RATE, n_fft=2048)
    cols = min(frames, mag.shape[1])
    rms = np.sqrt((mag[:, :cols] ** 2).sum(axis=0))
    env = (rms / max(rms.max(), 1e-12)) ** ENV_GAMMA
    e_h = hp[:, :cols].sum(axis=0)
    e_p = pp[:, :cols].sum(axis=0)
    h_frac = e_h / np.maximum(e_h + e_p, 1e-12)
    low = freqs < LOW_SPLIT
    low_frac = pp[low, :cols].sum(axis=0) / np.maximum(e_p, 1e-12)

    # The noise period, matched on the percussive part's shape.
    src = _shape(pp[:, :cols] + 1e-12)
    # Weighted by how loud each band is: a band 40 dB under the frame's
    # loudest counts for nothing, or the silence above a dark blast pulls
    # the match towards the brightest periods, which have the steepest top.
    weight = np.maximum(src - src.max(axis=0, keepdims=True) + WEIGHT_DB / 8.69, 0.0)
    weight /= np.maximum(weight.sum(axis=0, keepdims=True), 1e-12)
    dist = (((src[None, :, :] - shapes[:, :, None]) ** 2) * weight[None, :, :]).sum(axis=1)
    for j, (short, _) in enumerate(keys):
        if short:
            dist[j] += SHORT_PENALTY
    best = np.argmin(dist, axis=0)
    best = signal.medfilt(best.astype(np.float64), 3).astype(np.int64)

    table = {k: [0] * frames for k in REGISTERS}
    for f in range(cols):
        voices = pitches(harm[:, f], freqs) if h_frac[f] > 0.35 else []
        for ch, (f0, strength) in zip(("pulse", "pulse2"), voices):
            timer = int(round(CPU / (16.0 * f0) - 1))
            if not 8 <= timer <= 2047:
                continue
            table[ch + "_timer"][f] = timer
            table[ch + "_vol"][f] = int(round(15 * env[f] * np.sqrt(h_frac[f] * strength)))
            # Brightness against the pitch: a dull tone is a square.
            col = hp[:, f]
            centroid = (freqs * col).sum() / max(col.sum(), 1e-12)
            ratio = centroid / f0
            table[ch + "_duty"][f] = 2 if ratio < 2.5 else 1 if ratio < 5.0 else 0
        tonal = table["pulse_vol"][f] > 0
        # Under a tone the noise has only what the tone leaves, squared, so
        # a clean jingle does not hiss.
        share = (1.0 - h_frac[f]) ** 2 if tonal else 1.0
        vol = int(round(15 * env[f] * np.sqrt(share)))
        short, period = keys[best[f]]
        table["noise_vol"][f] = vol
        table["noise_mode"][f] = int(short)
        table["noise_period"][f] = period
        # The triangle for a blast's body: gated on the low end's share.
        if low_frac[f] > 0.3 and env[f] > 0.15:
            band = pp[low, f]
            peak = freqs[low][int(np.argmax(band))]
            peak = max(peak, 28.0)
            timer = int(round(CPU / (32.0 * peak) - 1))
            table["tri_on"][f] = 1
            table["tri_timer"][f] = min(max(timer, 2), 2047)
    return table


# ----------------------------------------------------------------------------
# DPCM

def render_dpcm(y, rate_index):
    """`y` through the delta-modulation channel: its counter's levels at FAST."""
    rate = CPU / DPCM_RATES[rate_index]
    x = librosa.resample(y, orig_sr=RATE, target_sr=rate)
    # Scaled to the loud part rather than the one loudest sample, which a
    # blast's first transient would let take the whole range.
    peak = max(np.percentile(np.abs(x), 99.5), 1e-12)
    target = 64.0 + np.clip(x / peak, -1.0, 1.0) * 56.0
    level = 64
    levels = np.empty(len(target), dtype=np.float64)
    for i, t in enumerate(target):
        if t > level:
            if level <= 125:
                level += 2
        elif level >= 2:
            level -= 2
        levels[i] = level
    n = int(round(len(y) * OVER))
    idx = np.minimum((np.arange(n) * rate / FAST).astype(np.int64), len(levels) - 1)
    return levels[idx], int(np.ceil(len(levels) / 8)), n


# ----------------------------------------------------------------------------
# Output

def loudest_rms(y, window=0.05):
    w = max(1, int(RATE * window))
    if len(y) < w:
        return float(np.sqrt(np.mean(y ** 2)))
    c = np.cumsum(np.concatenate([[0.0], y ** 2]))
    return float(np.sqrt((c[w:] - c[:-w]).max() / w))


def level_to(y, target):
    r = loudest_rms(y)
    if r <= 0:
        return y, 0.0
    y = y * (target / r)
    peak = np.abs(y).max()
    if peak <= 0.99:
        return y, 0.0
    return y * (0.99 / peak), float(20 * np.log10(peak / 0.99))


def write_csv(path, table):
    cols = REGISTERS
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("frame," + ",".join(cols) + "\n")
        for i in range(len(table["noise_vol"])):
            f.write("%d,%s\n" % (i, ",".join(str(table[c][i]) for c in cols)))


def same_as_original(file):
    path = os.path.join(ORIGINAL, file)
    if not os.path.exists(path):
        return False
    with open(path, "rb") as a, open(os.path.join(MODERN, file), "rb") as b:
        return a.read() == b.read()


def sources(picks):
    files = sorted(f for f in os.listdir(MODERN)
                   if f.endswith(".ogg") and not f.startswith("_"))
    if not picks:
        return files
    out = []
    for f in files:
        stem = f[:-4]
        base = re.sub(r"_\d+$", "", stem)
        if stem in picks or base in picks:
            out.append(f)
    return out


def write_ogg(path, y):
    """Through ffmpeg: libsndfile's Vorbis writer dies on a long file."""
    ff = shutil.which("ffmpeg")
    if ff is None:
        sys.path.insert(0, os.path.dirname(__file__))
        from sfx_tails import find_ffmpeg
        ff = find_ffmpeg(None)
    subprocess.run([ff, "-hide_banner", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1",
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "6", path],
                   input=np.ascontiguousarray(y, np.float32).tobytes(), check=True)


def steady(table, period, frames=60):
    """`table` as an even chop of `period` frames, `frames` long (a whole
    number of chops, so it loops on itself): the noise's volume falling over
    each chop from its loud end to its quiet end as the source has them (the
    90th and 10th percentiles), on the period it uses most, a step deeper for
    the thump; a tone the source holds most of the time (a pulse or the
    triangle on in half its frames), held at its median, and none otherwise,
    since a rotor's wandering partials read as a melody."""
    vol = np.array(table["noise_vol"], dtype=np.float64)
    loud, quiet = np.percentile(vol[vol > 0], 90), np.percentile(vol[vol > 0], 10)
    periods = np.array(table["noise_period"])[vol > 0]
    period_mode = int(np.bincount(periods).argmax())
    out = {k: [0] * frames for k in REGISTERS}
    for f in range(frames):
        k = f % period
        out["noise_vol"][f] = int(round(quiet + (loud - quiet) * CHOP[period][k]))
        out["noise_period"][f] = min(period_mode + (1 if k == 0 else 0), 15)
    for ch in ("pulse", "pulse2"):
        v = np.array(table[ch + "_vol"])
        on = v > 0
        if on.mean() >= 0.5:
            timer = int(np.median(np.array(table[ch + "_timer"])[on]))
            level = int(round(np.median(v[on])))
            duty = int(np.bincount(np.array(table[ch + "_duty"])[on]).argmax())
            for f in range(frames):
                out[ch + "_vol"][f], out[ch + "_timer"][f], out[ch + "_duty"][f] = level, timer, duty
    on = np.array(table["tri_on"]) > 0
    if on.mean() >= 0.5:
        timer = int(np.median(np.array(table["tri_timer"])[on]))
        for f in range(frames):
            out["tri_on"][f], out["tri_timer"][f] = 1, timer
    return out


def seamless(table, frames):
    """A loop of `table`'s `frames`: the table three times over, rendered, and
    the middle cut out, its first 10 ms faded in over what followed it, so
    that its end runs into its start as it ran into the third. The noise is
    no worse for the jump; the pulses' and the triangle's phases would click."""
    tripled = {k: list(v) * 3 for k, v in table.items()}
    n = int(round(frames / FRAME * RATE))
    big = 3 * n * OVER
    pulse, tri, noise = render_apu(tripled, big)
    y = mix(pulse, tri, noise, n=big)
    out = y[n:2 * n].copy()
    f = int(0.01 * RATE)
    ramp = np.linspace(0.0, 1.0, f)
    out[:f] = out[:f] * ramp + y[2 * n:2 * n + f] * (1.0 - ramp)
    return out


def modern_db(base):
    try:
        with open(MIX, encoding="utf-8") as f:
            return float(json.load(f)["modern"]["sounds"].get(base, 0.0))
    except (OSError, ValueError, KeyError):
        return 0.0


def write_index(rows):
    def audio(path):
        if path is None or not os.path.exists(path):
            return "<td class=none>—</td>"
        rel = os.path.relpath(path, OUT).replace(os.sep, "/")
        return '<td><audio controls preload=none src="%s"></audio></td>' % html.escape(rel)

    body = []
    for stem, notes in rows:
        base = re.sub(r"_\d+$", "", stem)
        classic = os.path.join(ORIGINAL, base + "_0.ogg") if stem.endswith("_0") else None
        body.append("<tr><th>%s<div class=note>%s</div></th>%s%s%s%s</tr>" % (
            html.escape(stem), html.escape(notes),
            audio(classic), audio(os.path.join(MODERN, stem + ".ogg")),
            audio(os.path.join(OUT, "apu", stem + ".ogg")),
            audio(os.path.join(OUT, "dpcm", stem + ".ogg"))))
    page = """<!doctype html>
<meta charset=utf-8>
<title>SFX chiptune</title>
<style>
:root { color-scheme: light dark; --bg: #fff; --fg: #1a1a1a; --mute: #777; --line: #ddd; }
@media (prefers-color-scheme: dark) { :root { --bg: #18181a; --fg: #e8e8e8; --mute: #999; --line: #333; } }
body { background: var(--bg); color: var(--fg); font: 14px/1.4 system-ui, sans-serif; margin: 16px; }
table { border-collapse: collapse; }
th, td { border-bottom: 1px solid var(--line); padding: 6px 10px; text-align: left; vertical-align: middle; }
thead th { position: sticky; top: 0; background: var(--bg); }
audio { height: 32px; width: 230px; }
.note { color: var(--mute); font-weight: normal; font-size: 12px; }
.none { color: var(--mute); text-align: center; }
</style>
<h1>SFX chiptune</h1>
<p>original — the original NES sound; modern — the source; apu — resynthesised on the 2A03's channels, what --install puts in classic/; dpcm — the source through the DPCM channel.</p>
<table>
<thead><tr><th>sound</th><th>original</th><th>modern</th><th>apu</th><th>dpcm</th></tr></thead>
<tbody>
%s
</tbody>
</table>
""" % "\n".join(body)
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write(page)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--dpcm-rate", type=int, default=15, choices=range(16))
    ap.add_argument("--install", action="store_true", help=f"also into {CLASSIC}/, what the classic mode plays")
    args = ap.parse_args()
    if args.install:
        os.makedirs(CLASSIC, exist_ok=True)

    os.makedirs(os.path.join(OUT, "apu"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "dpcm"), exist_ok=True)
    shapes, keys = noise_shapes()
    rows = []
    for file in sources(args.names):
        stem = file[:-4]
        base = re.sub(r"_\d+$", "", stem)
        if same_as_original(file):
            print("%-28s the original's own file: %s" % (stem, "copied" if args.install else "skipped"))
            if args.install:
                shutil.copyfile(os.path.join(ORIGINAL, file), os.path.join(CLASSIC, file))
            for kind in ("apu", "dpcm"):
                for ext in (".ogg", ".csv"):
                    old = os.path.join(OUT, kind, stem + ext)
                    if os.path.exists(old):
                        os.remove(old)
            continue
        y, _ = librosa.load(os.path.join(MODERN, file), sr=RATE, mono=True)
        # What the APU's output filter takes out anyway; left in, a DC
        # offset or a sub-bass hum reads as the triangle's low end.
        y = signal.sosfilt(signal.butter(2, 90.0, "highpass", fs=RATE, output="sos"), y)
        ref_path = os.path.join(ORIGINAL, base + "_0.ogg")
        if os.path.exists(ref_path):
            ref, _ = librosa.load(ref_path, sr=RATE, mono=True)
            target = loudest_rms(ref)
        else:
            # As loud as modern plays it: the classic mix has 0 dB for it.
            target = loudest_rms(y) * 10 ** (modern_db(base) / 20)
        n = len(y) * OVER

        table = analyse(y, shapes, keys)
        if base in STEADY:
            table = steady(table, STEADY[base])
            n = len(table["noise_vol"]) * int(round(RATE / FRAME)) * OVER
        pulse, tri, noise = render_apu(table, n)
        apu, clip_a = level_to(mix(pulse, tri, noise, n=n)[:len(y)], target)
        write_ogg(os.path.join(OUT, "apu", stem + ".ogg"), apu)
        write_csv(os.path.join(OUT, "apu", stem + ".csv"), table)
        if args.install:
            if base in LOOPS:
                # Levelled as the one-shot rendering was, so a loop and its
                # listening copy are as loud as each other.
                loop = seamless(table, len(table["noise_vol"]))
                loop, _ = level_to(loop, target)
                write_ogg(os.path.join(CLASSIC, file), loop)
            else:
                write_ogg(os.path.join(CLASSIC, file), apu)

        dmc, size, n2 = render_dpcm(y, args.dpcm_rate)
        dpcm, clip_d = level_to(mix(dmc=dmc, n=n2)[:len(y)], target)
        write_ogg(os.path.join(OUT, "dpcm", stem + ".ogg"), dpcm)

        tonal = sum(1 for v in table["pulse_vol"] if v > 0)
        chord = sum(1 for v in table["pulse2_vol"] if v > 0)
        tri_on = sum(table["tri_on"])
        notes = "%.2f s, %d frames: pulse %d + %d, triangle %d; DPCM %d bytes%s%s%s" % (
            len(y) / RATE, len(table["noise_vol"]), tonal, chord, tri_on, size,
            " (over %d)" % DPCM_MAX_BYTES if size > DPCM_MAX_BYTES else "",
            "; apu %.1f dB under classic's level" % clip_a if clip_a > 0.05 else "",
            "; dpcm %.1f dB under" % clip_d if clip_d > 0.05 else "")
        print("%-28s %s" % (stem, notes))
        rows.append((stem, notes))
    if args.install and not args.names:
        # classic/ holds modern's files and nothing else.
        keep = set(sources([]))
        for f in os.listdir(CLASSIC):
            if f.endswith(".ogg") and f not in keep:
                os.remove(os.path.join(CLASSIC, f))
                if os.path.exists(os.path.join(CLASSIC, f + ".import")):
                    os.remove(os.path.join(CLASSIC, f + ".import"))
                print("%-28s no longer in modern: removed from classic" % f[:-4])
    if not args.names:
        write_index(rows)
    else:
        # A partial run keeps the page of everything already rendered.
        done = sorted(f[:-4] for f in os.listdir(os.path.join(OUT, "apu")) if f.endswith(".ogg"))
        old = dict(rows)
        write_index([(s, old.get(s, "")) for s in done])


if __name__ == "__main__":
    sys.exit(main())
