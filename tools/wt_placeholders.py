#!/usr/bin/env python3
"""Fills assets/sfx_wt/ with placeholder sounds for the 3D preview.

The source is War Thunder's FMOD Studio project for modders, a separate
checkout. Its content is licensed for War Thunder mods only (see its
Readme.md and Gaijin's contribution agreement), so what this copies is for
listening to on this machine and nothing else:

  * assets/sfx_wt/ is in .gitignore and in the export preset's exclude_filter;
  * this script drops a .gdignore into it, so Godot never imports it and it
    cannot be packed by accident;
  * the preview reads the files straight off the disk (Level3DAudio), and
    without them falls back to the original's effects, or to silence.

This file -- the list of which War Thunder asset stands in for which of our
sounds -- is ours, and is what is committed.

    python tools/wt_placeholders.py D:/Projects/Other/fmod_studio_warthunder_for_modders

The project's .wav files are Ogg Vorbis under the wrong extension (its
Readme says so, and every one starts with OggS); they are copied as
<name>_<k>.ogg, k from 0, which is what Level3DAudio looks for. The folder
is emptied first, so taking a file out of PLACEHOLDERS takes it out of the
game. The sound names are Level3DAudio.SOUNDS'; a loop there uses only
the first file of its list, and an empty list keeps the original's effect.
The gains in SOUNDS were set from these files' measured loudness: a file
swapped for another wants its "db" measured again.
"""

import shutil
import sys
from pathlib import Path

PLACEHOLDERS = {
    # The player's weapons.
    "gun": [f"tanks/weapon/mg/oneshot/besa/besa_close-00{i}.wav" for i in range(1, 7)],
    "grenade_launch": [f"ath/grenade_launcher/grenade_launcher_0{i}.wav" for i in range(1, 4)],
    "rocket_launch": [f"weapons/rockets_missiles/missile_start_light-00{i}.wav" for i in range(1, 4)],
    # Where rounds land.
    "hit_ground": [f"fx/bullets/bullet_dirt_{i:02d}.wav" for i in range(1, 12)],
    "hit_water": [f"fx/bullets_water/bullet_hit_water_{i:02d}.wav" for i in range(1, 12)],
    "hit_hard": [f"tanks/impacts/tank_rico_0{i}.wav" for i in range(1, 5)],
    "hit_armor": [f"tanks/impacts/hit_mg/bullet_hit-{i:03d}.wav" for i in range(1, 11)],
    # The enemies' guns.
    # A machine gun for the soldiers, and not the BTR's own BESA, so that the
    # two are told apart: a DT, the close shot, the full one with its tail.
    "enemy_mg": [f"tanks/weapon/mg/oneshot/dt/dt_close-00{i}.wav" for i in range(1, 9)],
    "enemy_cannon": [f"tanks/weapon/cannons/cannon_37mm_sh37/cannon_37mm_sh37_shot_{i}.wav"
                     for i in range(1, 5)],
    # Blasts.
    "blast_small": [f"tanks/explosions/ground/tanks_explosion_ground_{i}.wav" for i in range(1, 6)],
    "blast_missile": [f"tanks/explosions/ground/tanks_explosion_ground_{i}.wav" for i in range(1, 6)],
    "blast_water": [f"tanks/explosions/water/tanks_explosion_water_{i}.wav" for i in range(1, 6)],
    "blast": [f"tanks/explosions/metal/tanks_explosion_metal_{i}.wav" for i in range(1, 6)],
    # Under the original's explode only, which the placeholder replaces.
    "enemy_hit": [],
    "building": [f"tanks/impacts_objects/object_crashes/building/building_crash_l2_{i}.wav"
                 for i in range(1, 4)],
    "breach": [f"tanks/impacts/hit_expl/hit_expl_big-00{i}.wav" for i in range(1, 5)],
    "player_explodes": [f"explosive/wreck_explosion_0{i}.wav" for i in range(1, 4)],
    # No soldiers in War Thunder: the original's soldier_killed.ogg stays.
    "soldier_death": [],
    # Engines: a BRDM's V8 for the BTR, idling and under load; a T-34 for the
    # tanks; a light boat's.
    "btr_idle": ["tanks/engines/brdm_v8_gasoline/engine_00.wav"],
    "btr_drive": ["tanks/engines/brdm_v8_gasoline/engine_60_load.wav"],
    "tank_engine": ["tanks/engines/t34/t34_engine_33.wav"],
    "boat_engine": ["ships/engines/light01/sh_engine_l1_rpm_low_3rd.wav"],
    # Helicopters: a Mi-8's rotor for the Chinook, an OH-58D's for the Little Bird.
    "chinook": ["engines/helicopters/mi_8t/rotor_loop_exterior.wav"],
    "rescue_rotor": ["engines/helicopters/ho_58d/rotor_main_loop.wav"],
    # Prisoners and the HUD.
    "pickup": ["gui/pickup_bonus.wav"],
    "rescue_pickup": ["gui/obj_complete.wav"],
    "upgrade": ["gui/new_rang.wav"],
    "warning": ["gui/critical_event_warning.wav"],
    "pause": [],
    # Ambience.
    "ambient_sea": ["ambient/amb_sea.wav"],
    "ambient_jungle": ["ambient/amb_tropics/amb_tropics_1.wav"],
}

TARGET = Path(__file__).resolve().parent.parent / "assets" / "sfx_wt"


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    assets = Path(sys.argv[1]) / "Assets"
    if not assets.is_dir():
        print(f"No Assets folder in {sys.argv[1]}")
        return 1
    if TARGET.exists():
        shutil.rmtree(TARGET)
    TARGET.mkdir(parents=True)
    (TARGET / ".gdignore").write_text("")
    copied = missing = 0
    for name, files in PLACEHOLDERS.items():
        k = 0
        for rel in files:
            source = assets / rel
            if not source.is_file():
                print(f"  missing: {rel}")
                missing += 1
                continue
            with source.open("rb") as f:
                if f.read(4) != b"OggS":
                    print(f"  not Ogg Vorbis, skipped: {rel}")
                    missing += 1
                    continue
            shutil.copyfile(source, TARGET / f"{name}_{k}.ogg")
            k += 1
            copied += 1
        print(f"{name}: {k}")
    print(f"{copied} files in {TARGET}, {missing} missing")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
