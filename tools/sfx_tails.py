#!/usr/bin/env python3
"""Shorter tails for the 3D preview's modern effects.

The generator puts an echo and a rumble after the hit however dry it is asked
for (SFX_PROMPTS_3D.md asks for "almost no reverb"), and a gun that fires 14
times a second turns it into a wash. Past each sound's own hit, at t0, this
adds an exponential decay over the sound's own -- DECAY_DB down by t1, where
the sound now ends, with a 20 ms fade to nothing -- so the tail keeps its
shape and is only shorter. Nothing before t0 is touched.

It reads each sound as it was generated, out of git (TAILS' ref, ORIGINAL
by default), never the file in assets/, so it can be run again and gives the
same sound; and it writes assets/sfx3d/modern/<name>.ogg. Run from the repo
root, then import (godot --path . --headless --import):

    py tools/sfx_tails.py                       # every sound in TAILS
    py tools/sfx_tails.py gun_0 blast_0         # those
    py tools/sfx_tails.py --listen              # also build/sfx_tails/listen.ogg, each before and after
    py tools/sfx_tails.py blast_0 --try 0.8 1.8 # build/sfx_tails/blast_0_try.ogg only, assets untouched

A sound replaced by a new file: commit the file as generated, put its line in
TAILS with that commit as its ref, find t0 and t1 with --try, run it.

ffmpeg reads and writes the Ogg Vorbis (q6); it is found on PATH, at the
winget install, or by --ffmpeg. A run re-encodes, so the bytes change even
where the sound does not.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys

import numpy as np

MODERN = "assets/sfx3d/modern"
OUT = "build/sfx_tails"
# The last commit with every sound below as the generator made it.
ORIGINAL = "eaf02d9"
DECAY_DB = 36.0
FADE = 0.02
# name: (t0 where its own hit ends, t1 where it now ends[, git ref of the original])
# Set by ear on gun_0 and blast_0, the rest where their hits end. Not
# building_* (the collapse runs to 1.4 s and stops), blast_water (the splash
# is two seconds of itself) or rocket_launch (the rocket going away).
TAILS = {
    "gun_0": (0.10, 0.32),
    "grenade_launch_0": (0.25, 0.65),
    "blast_0": (0.55, 1.40),
    "blast_missile_0": (0.55, 1.40),
    "blast_small_0": (0.45, 1.20),
    "player_explodes_0": (1.00, 2.00),
    "enemy_hit_0": (0.45, 1.10),
    "enemy_hit_1": (0.45, 1.10),
    "enemy_hit_2": (0.45, 1.10),
}


def find_ffmpeg(given):
    if given:
        return given
    on_path = shutil.which("ffmpeg")
    if on_path:
        return on_path
    pattern = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe")
    found = sorted(glob.glob(pattern))
    if found:
        return found[-1]
    sys.exit("sfx_tails: no ffmpeg; give it with --ffmpeg")


def original(name, ref):
    path = f"{MODERN}/{name}.ogg"
    got = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True)
    if got.returncode != 0:
        sys.exit(f"sfx_tails: no {path} at {ref}: {got.stderr.decode().strip()}")
    return got.stdout


def decode(ff, data):
    """(samples x channels float32, rate) of an Ogg file's bytes."""
    probe = subprocess.run([ff, "-hide_banner", "-i", "pipe:0"], input=data, capture_output=True).stderr.decode()
    line = next(l for l in probe.splitlines() if "Audio:" in l)
    rate = int(line.split(" Hz")[0].split()[-1])
    channels = 1 if "mono" in line else 2
    raw = subprocess.run([ff, "-v", "error", "-i", "pipe:0", "-f", "f32le", "-ac", str(channels), "-ar", str(rate), "-"],
                         input=data, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, channels).copy(), rate


def encode(ff, path, x, rate):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.dirname(path) == OUT:
        # Godot would import the listening files as assets otherwise.
        open(f"{OUT}/.gdignore", "a").close()
    subprocess.run([ff, "-hide_banner", "-v", "error", "-y", "-f", "f32le", "-ar", str(rate), "-ac", str(x.shape[1]),
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "6", path],
                   input=np.ascontiguousarray(x, np.float32).tobytes(), check=True)


def shorten(x, rate, t0, t1):
    t = np.arange(len(x)) / rate
    gain = np.where(t < t0, 1.0, 10 ** (-DECAY_DB / 20 * (t - t0) / (t1 - t0)))
    y = (x * gain[:, None])[:int(t1 * rate)].copy()
    n = int(FADE * rate)
    y[-n:] *= np.linspace(1, 0, n)[:, None]
    return y


def stereo(x, rate):
    """For listen.ogg: at 44.1 kHz in two channels, whatever the file was."""
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    if rate != 44100:
        idx = np.arange(int(len(x) * 44100 / rate)) * rate / 44100
        x = np.stack([np.interp(idx, np.arange(len(x)), x[:, c]) for c in range(2)], axis=1).astype(np.float32)
    return x


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("names", nargs="*", help="sounds in TAILS; none is all of them")
    ap.add_argument("--ffmpeg")
    ap.add_argument("--listen", action="store_true", help=f"also {OUT}/listen.ogg, each before and after")
    ap.add_argument("--try", dest="trial", nargs=2, type=float, metavar=("T0", "T1"),
                    help=f"one sound at T0, T1 into {OUT}/<name>_try.ogg, assets untouched")
    args = ap.parse_args()
    ff = find_ffmpeg(args.ffmpeg)
    names = args.names or list(TAILS)
    for name in names:
        if name not in TAILS and not args.trial:
            sys.exit(f"sfx_tails: {name} is not in TAILS")
    if args.trial:
        if len(names) != 1:
            sys.exit("sfx_tails: --try takes one sound")
        name = names[0]
        ref = TAILS.get(name, (0, 0, ORIGINAL))[2:] or (ORIGINAL,)
        x, rate = decode(ff, original(name, ref[0]))
        y = shorten(x, rate, *args.trial)
        gap = np.zeros((int(0.6 * 44100), 2), np.float32)
        encode(ff, f"{OUT}/{name}_try.ogg", np.concatenate([stereo(x, rate), gap, stereo(y, rate)]), 44100)
        print(f"{name}: {len(x) / rate:.2f} -> {len(y) / rate:.2f} s, before and after in {OUT}/{name}_try.ogg")
        return
    listen = []
    for name in names:
        t0, t1, *ref = TAILS[name]
        x, rate = decode(ff, original(name, ref[0] if ref else ORIGINAL))
        y = shorten(x, rate, t0, t1)
        encode(ff, f"{MODERN}/{name}.ogg", y, rate)
        print(f"{name}: {len(x) / rate:.2f} -> {len(y) / rate:.2f} s, from {t0:.2f} s")
        if args.listen:
            gap = np.zeros((int(0.6 * 44100), 2), np.float32)
            listen += [stereo(x, rate), gap, stereo(y, rate), gap]
    if listen:
        encode(ff, f"{OUT}/listen.ogg", np.concatenate(listen), 44100)
        print(f"before and after: {OUT}/listen.ogg")


if __name__ == "__main__":
    main()
