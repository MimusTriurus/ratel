#!/usr/bin/env python3
"""8-bit sounds for the classic mode's gaps, written as an NES game wrote them.

Fourteen of the 3D preview's sounds have nothing in assets/sfx3d/classic/: the
original had no sound for them (SFX_PROMPTS_3D.md). Thirteen have no modern
file either, so there is nothing for sfx_chiptune.py to analyse; these are
written out of their descriptions instead, the way NES effects were -- a
table of the APU's registers, a row a frame (1/60 s) -- and played through
sfx_chiptune's model of the 2A03: the two pulses, the triangle, the noise,
the mixer and the output filters.

All fourteen, into build/sfx_nes/, each beside the classic sound it is
modelled on in listen.ogg, at its loudness, to hear whether it belongs with
the original's; a loop is cut seamless and heard round and round. With
--install each also goes to assets/sfx3d/chip/<name>_0.ogg, which is what
the classic mode plays for it while the Sound tab's 8-bit switch is on
(Level3DAudio.set_chip); then import:

    build/.venv_basic_pitch/Scripts/python tools/sfx_nes.py
    build/.venv_basic_pitch/Scripts/python tools/sfx_nes.py tank_engine
    build/.venv_basic_pitch/Scripts/python tools/sfx_nes.py --install

Each file is at the loudness of the classic one it is modelled on, so the
mix's classic gain for it starts at 0 dB.
"""
import argparse
import os
import subprocess
import sys

import numpy as np
import soundfile
from scipy import signal

sys.path.insert(0, os.path.dirname(__file__))
from sfx_chiptune import CPU, FAST, FRAME, OVER, RATE, level_to, loudest_rms, render_apu  # noqa: E402
from sfx_tails import find_ffmpeg  # noqa: E402

CLASSIC = "assets/sfx3d/classic"
CHIP = "build/sfx3d_chip/apu"
OUT = "build/sfx_nes"
CHIP_DIR = "assets/sfx3d/chip"


def mix(pulse, tri, noise, n):
    """sfx_chiptune.mix's nonlinear mixer, through a Famicom's output (37 Hz
    high-pass, 14 kHz low-pass) rather than the NES front-loader's, whose
    440 Hz high-pass takes out what the original's recordings are made of:
    most of their energy is under 250 Hz. Measured against enemy_hit, gun and
    chinook, band by band, this is 1.7-2 dB off them, the NES's output 4-5;
    a lower low-pass only takes them further off.
    """
    p = np.where(pulse > 0, 95.88 / (8128.0 / np.maximum(pulse, 1e-9) + 100.0), 0.0)
    tnd_in = tri / 8227.0 + noise / 12241.0
    tnd = np.where(tnd_in > 0, 159.79 / (1.0 / np.maximum(tnd_in, 1e-12) + 100.0), 0.0)
    out = p + tnd
    for kind, freq in (("highpass", 37.0), ("lowpass", 14000.0)):
        b, a = signal.butter(1, freq, kind, fs=FAST)
        out = signal.lfilter(b, a, out)
    return signal.resample_poly(out, 1, OVER)


class Table:
    """The APU's registers, a row a frame, as sfx_chiptune.render_apu takes them."""

    def __init__(self, frames):
        self.n = frames
        self.r = {k: [0] * frames for k in ("pulse_vol", "pulse_duty", "pulse_timer",
                                            "pulse2_vol", "pulse2_duty", "pulse2_timer",
                                            "tri_on", "tri_timer", "noise_vol", "noise_mode", "noise_period")}

    def pulse(self, f, hz, vol, duty=2, ch="pulse"):
        """duty 0 12.5 %, 1 25 %, 2 50 %; a timer under 8 silences the channel, as on the NES."""
        if 0 <= f < self.n:
            self.r[ch + "_timer"][f] = int(np.clip(round(CPU / (16 * hz) - 1), 8, 2047))
            self.r[ch + "_vol"][f] = int(np.clip(round(vol), 0, 15))
            self.r[ch + "_duty"][f] = duty

    def tri(self, f, hz):
        """No volume: on or off, the hardware's only choice."""
        if 0 <= f < self.n:
            self.r["tri_timer"][f] = int(np.clip(round(CPU / (32 * hz) - 1), 2, 2047))
            self.r["tri_on"][f] = 1

    def noise(self, f, period, vol, short=False):
        """period 0 (hiss) to 15 (rumble); short is the metallic 93-step mode."""
        if 0 <= f < self.n:
            self.r["noise_period"][f] = int(np.clip(period, 0, 15))
            self.r["noise_vol"][f] = int(np.clip(round(vol), 0, 15))
            self.r["noise_mode"][f] = int(short)

    def render(self):
        n = int(self.n / FRAME * FAST)
        pulse, tri, noise = render_apu(self.r, n)
        return mix(pulse, tri, noise, n)


# ----------------------------------------------------------------------------
# The recipes. Each is modelled on the original's sound nearest to it, as
# sfx_chiptune.analyse reads that one's registers off the classic file: its
# length, its channels, its noise periods and how its volume moves -- the
# original's are almost all noise, the volume jumping frame to frame, low
# periods (d, e) for a thud and the short mode for metal, a frame or two of
# triangle under a hit, and its jingles 3-4 frame notes on the pulses with
# octave leaps. The strings are a frame to a hex digit, as that analysis
# prints them. Each returns (the sound, the classic file it is modelled on --
# heard beside it in listen.ogg and levelled to it -- dB under that, the loop
# in seconds or 0).

def seq(text):
    return [int(c, 16) for c in text]


def noise_run(t, start, vols, periods, short=""):
    for k, (v, p) in enumerate(zip(seq(vols), seq(periods))):
        t.noise(start + k, p, v, short=k < len(short) and short[k] == "s")


def hit_ground():
    """Bullet into soft dirt, quiet. enemy_hit's thud (0.2 s: noise c f f f b
    on periods d-e, a triangle under it), smaller and shorter: 8 frames, the
    low periods for the thud and two frames of period 7-8 for the grit."""
    t = Table(9)
    noise_run(t, 0, "9b975321", "ddee7878")
    t.tri(0, 151)
    t.tri(1, 129)
    return t.render(), "enemy_hit_0", 5.0, 0


def enemy_cannon():
    """A small cannon from a bunker or a light tank, lighter than artillery.
    The player's gun (0.32 s, noise e d f d e c f d on periods d-e, a run of
    triangle) made heavier: the same length, lower periods all through, two
    frames of the short mode at the start for the metal, as blast_small has
    four, and the triangle a frame lower."""
    t = Table(20)
    noise_run(t, 0, "ffedcdbca98765433211", "88ddeeeeffeffeffffff", short="ss")
    for f, hz in enumerate((108, 65, 43)):
        t.tri(f, hz)
    return t.render(), "gun_0", 0.0, 0


def tank_engine():
    """A tank driving, a loop. chinook's (1.0 s, 60 frames: noise on periods
    d-f, its volume chopping, a low pulse and the triangle at 86 Hz in and
    out) slower and steadier: the noise chugs on periods e-f four frames a
    beat; every twelfth frame two frames of the short mode, a track's clank;
    a 50 % pulse at 110 Hz low under it for the engine's note. 60 frames,
    as chinook's."""
    loop = 60
    t = Table(loop * 3)
    chug = seq("c847")
    for f in range(t.n):
        k = f % loop
        if k % 12 in (0, 1):
            t.noise(f, 6, 7 - 2 * (k % 12), short=True)
        else:
            t.noise(f, 14 + (k // 4) % 2, chug[k % 4])
        t.pulse(f, 110, 3 + (k % 4 == 0), duty=2)
        if k % 12 == 0:
            t.tri(f, 86)
    return t.render(), "chinook_0", 3.0, loop / FRAME


def warning():
    """The boss warning: two tones, three times. upgrade's (0.6 s: 3-4 frame
    notes on the pulses, an octave apart and gated, 294 / 589 Hz) and pause's
    loudest jingle as its level: three bursts of a high and a low note, four
    frames each, the second pulse an octave under, a frame of silence after
    each note and four after each pair. 42 frames, 0.7 s."""
    t = Table(42)
    f = 0
    for rep in range(3):
        for hz in (589, 441):
            for k, v in enumerate(seq("fdcb")):
                t.pulse(f + k, hz, v, duty=1)
                t.pulse(f + k, hz / 2, v - 4, duty=2, ch="pulse2")
            f += 5
        f += 4
    return t.render(), "upgrade_0", 0.0, 0


def hit_water():
    """Bullet into water, quiet: a sharp plip and a little splash. As short
    as hit_ground, with rescue_pickup's high splashy noise (periods 3-5) in
    place of the thud, and the plip a 12.5 % pulse leaping up over two
    frames, as the original's blips do."""
    t = Table(9)
    t.pulse(0, 900, 9, duty=0)
    t.pulse(1, 1500, 6, duty=0)
    noise_run(t, 1, "8754321", "3344555")
    return t.render(), "enemy_hit_0", 6.0, 0


def hit_hard():
    """Bullet on concrete or stone, quiet: a hard crack, a chip of debris, a
    faint ricochet. hit_armor's metal (the short mode on periods 3-5, a
    pulse ringing at 3.2 kHz) in its brittle, short version: three frames
    of high long-mode noise for the crack, one of the short mode for the
    chip, and the ricochet a thin pulse falling 2.5 to 1.4 kHz. 0.2 s."""
    t = Table(12)
    noise_run(t, 0, "ca8521", "223444", short="...s")
    for k, (hz, v) in enumerate(zip(np.geomspace(2500, 1400, 7), seq("5544321"))):
        t.pulse(3 + k, hz, v, duty=0)
    return t.render(), "hit_armor_0", 4.0, 0


def hit_armor_blast():
    """A warhead against thick armour, over the weapon's own blast: a deep
    metal slam and a short grinding crunch, no explosion. hit_armor's 27
    frames (0.45 s) and its make -- the short mode, a pulse ringing -- an
    octave down: the short mode on periods 8-a for the slam and the crunch,
    two pulses ringing at 1.6 and 2.3 kHz, which no harmonic series has,
    so it reads as a plate and not a note, and two frames of triangle."""
    t = Table(27)
    noise_run(t, 0, "fecba98776655443322221111", "8899aaaa9a9a9a9aaaabbbbbb", short="s" * 12)
    for k, v in enumerate(seq("cba98776655444333222221111")):
        t.pulse(1 + k, 1600, v, duty=1)
        t.pulse(1 + k, 2290, v - 3, duty=0, ch="pulse2")
    t.tri(0, 65)
    t.tri(1, 43)
    return t.render(), "hit_armor_0", 0.0, 0


def enemy_mg():
    """An enemy rifle or light machine gun: thinner and lighter than the
    player's gun, a dry crack. gun's shape (noise jumping e d f d e c f d)
    two thirds as long and higher, periods 7-a in place of d-e, and no
    triangle: 12 frames, 0.2 s."""
    t = Table(12)
    noise_run(t, 0, "dfcda8654321", "778899aaaaaa")
    return t.render(), "gun_0", 3.0, 0


def btr_idle():
    """The BTR standing, a loop: a low steady chug and a light rattle.
    chinook's 60 frames and its chop, slowed to a diesel's idle: the noise on
    periods e-f in beats of five frames, every tenth frame a frame of the
    short mode for the rattle, a 50 % pulse at 82 Hz low under it."""
    loop = 60
    t = Table(loop * 3)
    chug = seq("a6453")
    for f in range(t.n):
        k = f % loop
        if k % 10 == 7:
            t.noise(f, 7, 3, short=True)
        else:
            t.noise(f, 15 - (k % 5 == 0), chug[k % 5])
        t.pulse(f, 82, 3, duty=2)
    return t.render(), "chinook_0", 8.0, loop / FRAME


def btr_drive():
    """The BTR driving, over btr_idle: the same engine under load. Its chug
    twice as fast, on periods d-e, the pulse a step up to 98 Hz at 25 %
    and louder, and the tyres a steady low noise between the beats."""
    loop = 60
    t = Table(loop * 3)
    chug = seq("c7a6")
    for f in range(t.n):
        k = f % loop
        t.noise(f, 13 + (k % 4 >= 2), chug[k % 4])
        t.pulse(f, 98, 5 - (k % 2), duty=1)
    return t.render(), "chinook_0", 5.0, loop / FRAME


def boat_engine():
    """A patrol boat, a loop: a buzzing outboard and water churning. The buzz
    a 12.5 % pulse at 147 Hz, its volume flickering every frame, which is how
    the original's rotors buzz; the churn high noise (periods 4-6) swelling
    and falling twice across chinook's 60 frames."""
    loop = 60
    t = Table(loop * 3)
    for f in range(t.n):
        k = f % loop
        t.pulse(f, 147, 6 if k % 2 else 4, duty=0)
        swell = 0.5 - 0.5 * np.cos(2 * np.pi * k / 30)
        t.noise(f, 4 + (k % 3), 2 + 4 * swell)
    return t.render(), "chinook_0", 5.0, loop / FRAME


def ambient_sea():
    """The sea, under everything: soft waves on a beach. No original to model
    it on, so it is the plainest the NES has: the noise alone on periods 9-b,
    rising and falling, a wave of 3.5 s and one of 4.5, an 8 s loop."""
    loop = 480
    t = Table(loop * 3)
    for f in range(t.n):
        k = f % loop
        wave, length = (k, 210) if k < 210 else (k - 210, 270)
        x = wave / length
        rise = np.sin(np.pi * min(x / 0.6, 1.0) / 2) if x < 0.6 else np.cos(np.pi * (x - 0.6) / 0.8)
        t.noise(f, 11 - int(2 * rise), 1 + 4 * max(rise, 0.0))
    return t.render(), "chinook_0", 14.0, loop / FRAME


def ambient_jungle():
    """The jungle, under everything: insects, birds far off, leaves. The
    insects a 12.5 % pulse at 3.5 kHz at the lowest volume, on every other
    frame, which buzzes; a bird now and then, two quick notes leaping up on
    the second pulse as the original's jingles do, quietly; the leaves the
    noise on period 3, barely there. An 8 s loop."""
    loop = 480
    t = Table(loop * 3)
    birds = {40: (1760, 2350), 190: (1980, 2640), 300: (1760, 2350), 410: (2090, 2790)}
    for f in range(t.n):
        k = f % loop
        if k % 2:
            t.pulse(f, 3520, 1, duty=0)
        t.noise(f, 3, 1 if (k // 20) % 3 else 2)
        for at, (a, b) in birds.items():
            if 0 <= k - at < 8:
                t.pulse(f, a if k - at < 4 else b, 3 - (k - at) % 4 // 2, duty=0, ch="pulse2")
    return t.render(), "chinook_0", 16.0, loop / FRAME


RECIPES = {"hit_ground": hit_ground, "hit_water": hit_water, "hit_hard": hit_hard, "hit_armor_blast": hit_armor_blast,
           "enemy_mg": enemy_mg, "enemy_cannon": enemy_cannon,
           "btr_idle": btr_idle, "btr_drive": btr_drive, "tank_engine": tank_engine, "boat_engine": boat_engine,
           "warning": warning, "ambient_sea": ambient_sea, "ambient_jungle": ambient_jungle}
# Sounds with a modern file: sfx_chiptune.py's registers for it (its .csv),
# played through this mix, with the classic file heard beside it, and
# whether it loops.
ANALYSED = {"rocket_flight": ("rocket_flight_0", "rocket_launch_0", 4.0, True)}


def from_csv(path, times=1):
    """The table `times` over, for a loop to be cut out of the middle of."""
    with open(path, encoding="utf-8") as f:
        cols = f.readline().strip().split(",")[1:]
        rows = [[int(v) for v in line.strip().split(",")[1:]] for line in f if line.strip()]
    rows = rows * times
    t = Table(len(rows))
    t.r = {c: [r[i] for r in rows] for i, c in enumerate(cols)}
    return t.render(), len(rows) // times / FRAME


def seamless(y, loop):
    """One loop out of a render of three or more: the second, its first 10 ms
    faded in over what followed it, so that its end runs into its start as it
    ran into the third. The noise is no worse for the jump; the pulses' and
    the triangle's phases are what would click."""
    n = int(round(loop * RATE))
    f = int(0.01 * RATE)
    out = y[n:2 * n].copy()
    ramp = np.linspace(0.0, 1.0, f)
    out[:f] = out[:f] * ramp + y[2 * n:2 * n + f] * (1.0 - ramp)
    return out


def load(path):
    y, rate = soundfile.read(path, dtype="float64", always_2d=True)
    y = y.mean(axis=1)
    if rate != RATE:
        y = signal.resample_poly(y, RATE, rate)
    return y


def write(path, y):
    """Through ffmpeg: libsndfile's Vorbis writer dies on a file of any length."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.dirname(path) == OUT:
        open(f"{OUT}/.gdignore", "a").close()
    subprocess.run([find_ffmpeg(None), "-hide_banner", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1",
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "6", path],
                   input=np.ascontiguousarray(y, np.float32).tobytes(), check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("names", nargs="*", help="recipes; none is all of them")
    ap.add_argument("--install", action="store_true", help=f"also into {CHIP_DIR}/<name>_0.ogg")
    args = ap.parse_args()
    names = args.names or list(RECIPES) + list(ANALYSED)
    gap = np.zeros(int(0.7 * RATE))
    listen = []
    for name in names:
        if name in RECIPES:
            y, near, under, loop = RECIPES[name]()
        elif name in ANALYSED:
            chip, near, under, loops = ANALYSED[name]
            y, loop = from_csv(f"{CHIP}/{chip}.csv", 3 if loops else 1)
            loop = loop if loops else 0
        else:
            sys.exit(f"sfx_nes: no recipe for {name}")
        ref = load(f"{CLASSIC}/{near}.ogg")
        if loop:
            y = seamless(y, loop)
        y, cut = level_to(y, loudest_rms(ref) * 10 ** (-under / 20))
        write(f"{OUT}/{name}.ogg", y)
        if args.install:
            write(f"{CHIP_DIR}/{name}_0.ogg", y)
        print(f"{name}: {len(y) / RATE:.2f} s{f', loops every {loop:.2f} s' if loop else ''}; "
              f"at {near}'s loudness{f' -{under:g} dB' if under else ''}{f', peak held {cut:.1f} dB down' if cut else ''}")
        # a loop heard round and round, 8 s or three times, whichever is longer
        heard = np.tile(y, max(3, int(np.ceil(8.0 * RATE / len(y))))) if loop else y
        listen += [ref, gap, heard, gap, gap]
    write(f"{OUT}/listen.ogg", np.concatenate(listen))
    print(f"each beside its classic neighbour: {OUT}/listen.ogg")


if __name__ == "__main__":
    main()
