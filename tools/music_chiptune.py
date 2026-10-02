#!/usr/bin/env python3
"""The modern music as a Famicom game with a VRC6 could have played it.

What the classic sound mode plays (assets/music3d/classic/): the same notes
as modern's songs -- the MIDI the remix and the boss theme are rendered from,
in build/music3d_pogonya/ and build/music3d_boss/ -- arranged for eight
voices and played on a model of the chips, not modern's audio converted:

  2A03  pulse 1 and 2 (four duties, 4-bit volume), the triangle (no volume:
        on or off), the noise (16 periods, a long and a short, metallic,
        mode) and the DPCM channel, which plays the drums' samples
  VRC6  two more pulses (eight duties) and a sawtooth -- Konami's expansion,
        as in Akumajou Densetsu, the Japanese Castlevania III

ARRANGEMENT says which MIDI track goes to which voice, and how: a track's
highest or lowest note at each frame, a chord's notes split over two voices,
or played as a one-frame arpeggio, as NES drivers did. Everything moves on
the frame (1/60 s), as an NES driver's tables do: at 180 BPM a sixteenth is
5 frames and a bar 80, at 150 BPM 6 and 96 -- 58800 and 70560 samples, the
modern cuts' bars exactly, so each part is cut on the same bars as modern's
(CUTS) and a loop out of the middle of three runs into itself.

Mono, 44.1 kHz, through a Famicom's output (37 Hz high-pass, 14 kHz
low-pass), each song at the loudness of modern's loop (its integrated LUFS),
the parts of a song at one gain and through one limiter at -1 dBFS -- on the
whole render, before it is cut, so that a loop still runs into itself: the
chips' output is all transients, the DPCM kick's above all, and its peaks
held it 7 dB under modern's otherwise. The boss's is the linear one: its intro,
the loop with every layer in it, the victory and the accent.

    build/.venv_basic_pitch/Scripts/python tools/music_chiptune.py            # build/music_chiptune/
    build/.venv_basic_pitch/Scripts/python tools/music_chiptune.py --install  # and assets/music3d/classic/

then godot --path . --headless --import. The MIDI is in build/, which is not
in git (the remix's is under copyright); README.md in each folder says how it
is made.
"""
import argparse
import os
import re
import struct
import subprocess
import sys

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(__file__))
from sfx_chiptune import CPU, DPCM_RATES, LFSR, NOISE_PERIODS, render_dpcm  # noqa: E402
from sfx_tails import find_ffmpeg  # noqa: E402

RATE = 44100
OVER = 4
FAST = RATE * OVER
FRAME = 60
HOP = RATE // FRAME          # 735
OUT = "build/music_chiptune"
INSTALL = "assets/music3d/classic"
MODERN = "assets/music3d/modern"
POGONYA = "build/music3d_pogonya"
BOSS = "build/music3d_boss"

# ----------------------------------------------------------------------------
# The arrangement: voice -> (role, tracks, level). Tracks by their MIDI name;
# the first one sounding wins, for a voice two tracks share. Roles:
#   lead   the highest note, held, a little vibrato on a long one, its bends
#   echo   the lead again an eighth late and quieter, the NES's way to a
#          second guitar
#   root, fifth
#          a power chord's lowest note and the next above it
#   chug   palm-muted: each note dies away fast
#   arp    every note of a chord in turn, a frame each
#   bass   the lowest note, gated (the triangle has no volume)
# Levels are of 15 (the pulses) or of the saw's 42.

STAGE = {
    "pulse1": ("lead", ["Lead"], 13),
    "pulse2": ("echo", ["Lead"], 5),
    "vrc1": ("root chug", ["Rhythm L"], 10),
    "vrc2": ("fifth chug", ["Rhythm L"], 8),
    "saw": ("arp", ["Strings"], 26),
    "triangle": ("bass", ["Bass"], 15),
}
BOSS_ARRANGEMENT = {
    "pulse1": ("lead", ["lead"], 13),
    "pulse2": ("lead", ["lead2", "synth"], 7),
    "vrc1": ("root chug", ["rg1"], 10),
    "vrc2": ("fifth chug", ["rg1"], 8),
    "saw": ("arp", ["strings"], 26),
    "triangle": ("bass", ["bass"], 15),
}
# Duties: the 2A03's 0-3 (12.5, 25, 50, 75 %), the VRC6's 0-7 ((d+1)/16).
DUTY = {"pulse1": 1, "pulse2": 0, "vrc1": 7, "vrc2": 5}

# The drums, General MIDI's note -> what the noise does: (period, short mode,
# volume over its frames). The kick and the big drums are DPCM samples.
NOISE_DRUMS = {
    38: (6, False, [15, 13, 11, 9, 7, 5, 4, 3, 2, 1]),         # snare
    40: (6, False, [15, 13, 11, 9, 7, 5, 4, 3, 2, 1]),
    42: (1, False, [7, 4, 2]),                                 # closed hat
    44: (1, False, [6, 3, 1]),
    46: (1, False, [7, 6, 5, 4, 3, 3, 2, 2, 1, 1]),            # open hat
    51: (3, True, [6, 5, 4, 3, 3, 2, 2, 1]),                   # ride
    49: (3, False, [13] + list(range(12, 0, -1)) * 1 + [1] * 20),  # crash
    57: (3, False, [13] + list(range(12, 0, -1)) * 1 + [1] * 20),
    52: (4, True, [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 1, 1]),  # china
    41: (11, False, [13, 11, 9, 7, 5, 3, 2, 1]),               # toms, low to high
    43: (10, False, [13, 11, 9, 7, 5, 3, 2, 1]),
    45: (9, False, [13, 11, 9, 7, 5, 3, 2, 1]),
    47: (9, False, [13, 11, 9, 7, 5, 3, 2, 1]),
    48: (8, False, [13, 11, 9, 7, 5, 3, 2, 1]),
    50: (7, False, [13, 11, 9, 7, 5, 3, 2, 1]),
}
DPCM_DRUMS = {35: "kick", 36: "kick"}
# Tracks that are drums of their own: all their notes a sample.
DPCM_TRACKS = {"timp": "timpani", "taiko": "taiko"}

# What is cut out of which render, in bars: (MIDI, first bar, last bar,
# fade-out seconds at the end, extra seconds after the last bar).
CUTS = {
    "start.ogg": (f"{POGONYA}/part_start_hold.mid", 0, 4, 0.01, 0.0),
    "stage0_intro.ogg": (f"{POGONYA}/part_intro.mid", 0, 6, 0.0, 0.0),
    "stage0_repeat.ogg": (f"{POGONYA}/part_loop3.mid", 25, 50, 0.0, 0.0),
    "boss_intro.ogg": (f"{BOSS}/clip_intro.mid", 0, 4, 0.0, 0.0),
    "boss_full.ogg": (f"{BOSS}/stem_all.mid", 16, 32, 0.0, 0.0),
    "boss_victory.ogg": (f"{BOSS}/clip_victory.mid", 0, 2, 1.2, 2.5),
    "boss_breach.ogg": (f"{BOSS}/clip_accent.mid", 0, 0.25, 0.8, 2.2),
}
SONGS = {"stage": (["start.ogg", "stage0_intro.ogg", "stage0_repeat.ogg"], "stage0_repeat.ogg", STAGE),
         "boss": (["boss_intro.ogg", "boss_full.ogg", "boss_victory.ogg", "boss_breach.ogg"], "boss_full.ogg",
                  BOSS_ARRANGEMENT)}
# The accent plays over the music: as the modern one, 9 dB under the rest.
UNDER_DB = {"boss_breach.ogg": 9.0}
LIMITER = "alimiter=limit=0.891:attack=5:release=50:level=disabled:latency=1"


# ----------------------------------------------------------------------------
# MIDI

def _vlq(d, i):
    v = 0
    while True:
        b = d[i]
        i += 1
        v = (v << 7) | (b & 0x7F)
        if not b & 0x80:
            return v, i


def read_midi(path):
    """(beats a minute, {track name: (notes [(start, end, pitch, velocity)] in
    beats, bends [(beat, semitones)])})."""
    d = open(path, "rb").read()
    _, ntr, div = struct.unpack(">HHH", d[8:14])
    i = 8 + struct.unpack(">I", d[4:8])[0]
    bpm = 120.0
    tracks = {}
    for _ in range(ntr):
        ln = struct.unpack(">I", d[i + 4:i + 8])[0]
        j, end = i + 8, i + 8 + ln
        i = end
        tick, run, name, on, notes, bends = 0, None, None, {}, [], []
        while j < end:
            dt, j = _vlq(d, j)
            tick += dt
            b = d[j]
            if b == 0xFF:
                kind = d[j + 1]
                n, j = _vlq(d, j + 2)
                data = d[j:j + n]
                j += n
                if kind == 0x03 and name is None:
                    name = data.decode("latin1")
                elif kind == 0x51:
                    bpm = 60e6 / int.from_bytes(data, "big")
                continue
            if b in (0xF0, 0xF7):
                n, j = _vlq(d, j + 1)
                j += n
                continue
            if b & 0x80:
                run = b
                j += 1
            hi = run & 0xF0
            n = 1 if hi in (0xC0, 0xD0) else 2
            args = d[j:j + n]
            j += n
            beat = tick / div
            if hi == 0x90 and args[1] > 0:
                on[args[0]] = (beat, args[1])
            elif hi in (0x80, 0x90):
                if args[0] in on:
                    s, v = on.pop(args[0])
                    notes.append((s, beat, args[0], v))
            elif hi == 0xE0:
                bends.append((beat, ((args[1] << 7 | args[0]) - 8192) / 8192 * 2.0))
        if name is not None and (notes or bends):
            tracks[name] = (sorted(notes), bends)
    return bpm, tracks


# ----------------------------------------------------------------------------
# The arrangement onto frames

def _frames(beats, bpm):
    return int(round(beats * 60.0 / bpm * FRAME))


def sounding(notes, bpm, frames):
    """frame -> the notes sounding: [(pitch, velocity, frames since its start)]."""
    out = [[] for _ in range(frames)]
    for s, e, p, v in notes:
        a, b = _frames(s, bpm), max(_frames(e, bpm), _frames(s, bpm) + 1)
        for f in range(a, min(b, frames)):
            out[f].append((p, v, f - a))
    return out


def bend_curve(bends, bpm, frames):
    curve = np.zeros(frames)
    for beat, semis in sorted(bends):
        curve[_frames(beat, bpm):] = semis
    return curve


def voice(role, tracks, level, bpm, frames):
    """(pitch in semitones or nan, volume 0-1 of `level`) a frame, for one voice."""
    pitch = np.full(frames, np.nan)
    vol = np.zeros(frames)
    kinds = role.split()
    per_track = []
    for name in tracks:
        if name in TRACKS:
            notes, bends = TRACKS[name]
            per_track.append((sounding(notes, bpm, frames), bend_curve(bends, bpm, frames)))
    delay = int(round(FRAME * 60.0 / bpm / 2)) if "echo" in kinds else 0
    for f in range(frames):
        src = f - delay
        if src < 0:
            continue
        for notes, bend in per_track:
            now = notes[src]
            if not now:
                continue
            ps = sorted(now)
            if "root" in kinds:
                p, v, age = ps[0]
            elif "fifth" in kinds:
                if len(ps) < 2:
                    break
                p, v, age = ps[1]
            elif "bass" in kinds:
                p, v, age = ps[0]
            elif "arp" in kinds:
                p, v, age = ps[f % len(ps)]
                age = min(n[2] for n in ps)
            else:
                p, v, age = ps[-1]
            g = v / 127.0
            if "chug" in kinds:
                g *= max(0.82 ** age, 0.3)
            elif "lead" in kinds or "echo" in kinds:
                g *= 1.0 if age < 2 else max(0.8, 1.0 - 0.015 * age)
                if age > 18:
                    p = p + 0.18 * np.sin(2 * np.pi * 5.5 * (age - 18) / FRAME)
            elif "arp" in kinds:
                g *= 0.9
            if "echo" in kinds:
                g *= 1.0
            pitch[f] = p + bend[src]
            vol[f] = g
            break
    return pitch, vol * level


def drums(notes, bpm, frames):
    """The noise channel's (period, short, volume) a frame, and the DPCM's hits
    [(frame, sample)]. A hit takes the noise if it starts at least as loud as
    what is still dying away there, as a driver's priority would."""
    period = np.zeros(frames, dtype=np.int64)
    short = np.zeros(frames, dtype=bool)
    vol = np.zeros(frames)
    hits = []
    for s, _, p, v in sorted(notes):
        f = _frames(s, bpm)
        if f >= frames:
            continue
        if p in DPCM_DRUMS:
            hits.append((f, DPCM_DRUMS[p]))
            continue
        if p not in NOISE_DRUMS:
            continue
        per, sh, env = NOISE_DRUMS[p]
        env = [e * v / 127.0 for e in env]
        if vol[f] > env[0]:
            continue
        for k, e in enumerate(env):
            if f + k >= frames:
                break
            period[f + k], short[f + k], vol[f + k] = per, sh, e
    return period, short, vol, hits


# ----------------------------------------------------------------------------
# The chips

def _dpcm_samples():
    """The drums' samples as the DPCM channel plays them: its counter's levels
    at FAST, through sfx_chiptune.render_dpcm (1 bit a sample, 33.1 kHz)."""
    t = np.arange(int(0.35 * RATE)) / RATE

    def drum(f0, f1, length, noise=0.0):
        f = f1 + (f0 - f1) * np.exp(-t / (length / 4))
        y = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t / length)
        y += noise * np.random.default_rng(1).standard_normal(len(t)) * np.exp(-t / (length / 6))
        return render_dpcm(y.astype(np.float64), 15)[0]

    return {"kick": drum(160, 48, 0.07), "timpani": drum(110, 72, 0.18), "taiko": drum(90, 55, 0.14, 0.3)}


def _timer(hz, divider, lo, hi):
    return np.clip(np.round(CPU / (divider * hz) - 1), lo, hi)


def render(arrangement, path):
    """The song in `path` on the chips, mono at RATE."""
    global TRACKS
    bpm, TRACKS = read_midi(path)
    end = max(max(n[1] for n in notes) for notes, _ in TRACKS.values() if notes)
    frames = _frames(end, bpm) + 3 * FRAME
    v = {name: voice(*spec, bpm, frames) for name, spec in arrangement.items()}
    drum_notes = TRACKS.get("Drums", TRACKS.get("drums", ([], [])))[0]
    n_period, n_short, n_vol, hits = drums(drum_notes, bpm, frames)
    for track, sample in DPCM_TRACKS.items():
        for s, _, _, _ in TRACKS.get(track, ([], []))[0]:
            hits.append((_frames(s, bpm), sample))
    hits.sort()
    samples = _dpcm_samples()

    per_frame = FAST // FRAME
    total = frames * per_frame
    dmc = np.zeros(total)
    level = 64.0
    for k, (f, name) in enumerate(hits):
        a = f * per_frame
        seg = np.clip(samples[name] - samples[name][0] + level, 0, 127)
        b = min(total, a + len(seg), hits[k + 1][0] * per_frame if k + 1 < len(hits) else total)
        dmc[a:b] = seg[:b - a]
        level = dmc[b - 1]
        nxt = hits[k + 1][0] * per_frame if k + 1 < len(hits) else total
        dmc[b:nxt] = level

    hz = {name: 440.0 * 2.0 ** ((np.nan_to_num(p, nan=69.0) - 69.0) / 12.0) for name, (p, _) in v.items()}
    on = {name: ~np.isnan(p) for name, (p, _) in v.items()}
    freq = {}
    for name in ("pulse1", "pulse2"):
        freq[name] = np.where(on[name], CPU / (16.0 * (_timer(hz[name], 16, 8, 2047) + 1)), 0.0)
    for name in ("vrc1", "vrc2"):
        freq[name] = np.where(on[name], CPU / (16.0 * (_timer(hz[name], 16, 8, 4095) + 1)), 0.0)
    freq["saw"] = np.where(on["saw"], CPU / (14.0 * (_timer(hz["saw"], 14, 8, 4095) + 1)), 0.0)
    freq["triangle"] = np.where(on["triangle"], CPU / (32.0 * (_timer(hz["triangle"], 32, 2, 2047) + 1)), 0.0)
    vol = {name: np.round(np.clip(vv, 0, 42 if name == "saw" else 15)) for name, (_, vv) in v.items()}

    duty_2a03 = np.array([[0, 1, 0, 0, 0, 0, 0, 0], [0, 1, 1, 0, 0, 0, 0, 0],
                          [0, 1, 1, 1, 1, 0, 0, 0], [1, 0, 0, 1, 1, 1, 1, 1]], dtype=np.float64)
    tri_seq = np.array(list(range(15, -1, -1)) + list(range(16)), dtype=np.float64)
    phase = {name: 0.0 for name in freq}
    noise_pos = {False: 0.0, True: 0.0}
    fir = signal.firwin(97, 19000.0, fs=FAST)
    tail = np.zeros(len(fir) - 1)
    hp = signal.butter(1, 37.0, "highpass", fs=FAST)
    lp = signal.butter(1, 14000.0, "lowpass", fs=FAST)
    zi_hp = np.zeros(1)
    zi_lp = np.zeros(1)
    out = []
    chunk = 4 * FRAME
    for c0 in range(0, frames, chunk):
        c1 = min(frames, c0 + chunk)
        n = (c1 - c0) * per_frame
        idx = np.repeat(np.arange(c0, c1), per_frame)

        def wave(name):
            ph = phase[name] + np.cumsum(freq[name][idx] / FAST)
            phase[name] = ph[-1] % 1.0
            return ph % 1.0

        pulse = np.zeros(n)
        for name in ("pulse1", "pulse2"):
            step = (wave(name) * 8).astype(np.int64) % 8
            pulse += duty_2a03[DUTY[name], step] * vol[name][idx]
        vrc = np.zeros(n)
        for name in ("vrc1", "vrc2"):
            step = (wave(name) * 16).astype(np.int64) % 16
            vrc += (step <= DUTY[name]) * vol[name][idx]
        saw = ((wave("saw") * 7).astype(np.int64) * vol["saw"][idx]).astype(np.int64) >> 3
        tri = tri_seq[(wave("triangle") * 32).astype(np.int64) % 32]
        noise = np.zeros(n)
        for f in range(c0, c1):
            a = (f - c0) * per_frame
            sh = bool(n_short[f])
            clocks = CPU / NOISE_PERIODS[n_period[f]] / FAST
            seq = LFSR[sh]
            pos = noise_pos[sh] + np.arange(per_frame) * clocks
            if clocks >= 1.0:
                cum = np.concatenate([[0.0], np.cumsum(np.tile(seq, 2))])
                s0 = pos % len(seq)
                i0 = s0.astype(np.int64)
                i1 = np.minimum((s0 + clocks).astype(np.int64), 2 * len(seq) - 1)
                bits = (cum[i1] - cum[i0]) / np.maximum(i1 - i0, 1)
            else:
                bits = seq[pos.astype(np.int64) % len(seq)]
            noise[a:a + per_frame] = bits * round(n_vol[f])
            noise_pos[sh] = (noise_pos[sh] + per_frame * clocks) % len(seq)
        d = dmc[c0 * per_frame:c1 * per_frame]
        with np.errstate(divide="ignore"):
            p_out = np.where(pulse > 0, 95.88 / (8128.0 / np.maximum(pulse, 1e-9) + 100.0), 0.0)
            tnd_in = tri / 8227.0 + noise / 12241.0 + d / 22638.0
            tnd = np.where(tnd_in > 0, 159.79 / (1.0 / np.maximum(tnd_in, 1e-12) + 100.0), 0.0)
        # The VRC6 summed in at about a 2A03 pulse's level for each of its own,
        # the saw's 0-31 as a pulse's 0-15.
        y = p_out + tnd + 0.00996 * (vrc + saw * 15.0 / 31.0)
        y, zi_hp = signal.lfilter(*hp, y, zi=zi_hp)
        y, zi_lp = signal.lfilter(*lp, y, zi=zi_lp)
        full = np.concatenate([tail, y])
        tail = full[-(len(fir) - 1):]
        filtered = np.convolve(full, fir, mode="valid")
        out.append(filtered[::OVER])
    y = np.concatenate(out)
    # the FIR's delay, half its length at FAST
    delay = (len(fir) - 1) // 2 // OVER
    return np.concatenate([y[delay:], np.zeros(delay)]), bpm


# ----------------------------------------------------------------------------
# Cuts, levels, files

def lufs(y):
    e = subprocess.run([find_ffmpeg(None), "-hide_banner", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
                        "-af", "ebur128", "-f", "null", "-"],
                       input=np.ascontiguousarray(y, np.float32).tobytes(), capture_output=True).stderr.decode()
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", e)[-1])


def load(path):
    raw = subprocess.run([find_ffmpeg(None), "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def limit(y):
    raw = subprocess.run([find_ffmpeg(None), "-hide_banner", "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "1",
                          "-i", "-", "-af", LIMITER, "-f", "f32le", "-"],
                         input=np.ascontiguousarray(y, np.float32).tobytes(), capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def cut(y, bpm, file):
    _, first, last, fade, extra = CUTS[file]
    bar = int(round(4 * 60.0 / bpm * RATE))
    x = y[int(round(first * bar)):int(round(last * bar + extra * RATE))].copy()
    if fade > 0:
        n = int(fade * RATE)
        x[-n:] *= np.linspace(1.0, 0.0, n) ** 2
    return x


def write(path, y):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.dirname(path) == OUT:
        open(f"{OUT}/.gdignore", "a").close()
    subprocess.run([find_ffmpeg(None), "-hide_banner", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1",
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "6", path],
                   input=np.ascontiguousarray(y, np.float32).tobytes(), check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("songs", nargs="*", help=f"of {list(SONGS)}; none is both")
    ap.add_argument("--install", action="store_true", help=f"also into {INSTALL}/")
    args = ap.parse_args()
    for song in args.songs or list(SONGS):
        files, loop, arrangement = SONGS[song]
        renders = {}
        for file in files:
            mid = CUTS[file][0]
            if mid not in renders:
                renders[mid] = render(arrangement, mid)
        loop_mid = CUTS[loop][0]
        target = lufs(load(f"{MODERN}/{loop}"))
        gain = target - lufs(cut(*renders[loop_mid], loop))
        # Twice: the limiter takes some of the gain back.
        for _ in range(2):
            limited = {mid: (limit(y * 10 ** (gain / 20)), bpm) for mid, (y, bpm) in renders.items()}
            gain += target - lufs(cut(*limited[loop_mid], loop))
        for file in files:
            x = cut(*limited[CUTS[file][0]], file) * 10 ** (-UNDER_DB.get(file, 0.0) / 20)
            write(f"{OUT}/{file}", x)
            if args.install:
                write(f"{INSTALL}/{file}", x)
            print(f"{file:20} {len(x) / RATE:6.2f} s  {lufs(x):6.1f} LUFS  peak {20 * np.log10(np.abs(x).max()):5.1f} dBFS")
        print(f"{song}: {gain:+.1f} dB and the limiter, its loop at {target:.1f} LUFS as modern's")


TRACKS = {}

if __name__ == "__main__":
    main()
