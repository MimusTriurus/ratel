# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
It keeps the rules; the detail behind them is in the files under **Further
reading** at the end — read the one for the area you are about to touch.

## What this is

A port of meatfighter.com's Java/Slick2D remake of Konami's *Jackal* (NES) to
Godot 4 / GDScript. LGPL v3, © meatfighter.com — keep the licence and attribution
with any redistribution.

**The Java original is the reference, not a contract.** It lives beside this repo
in `../java_src/jackal/` (126 `.java` files, not tracked here). Every GDScript
file names the `jackal.*` class it came from in its header comment, so `grep` the
header to find the counterpart. Read it before changing behaviour: it is the only
explanation of why anything works the way it does, and most of the odd-looking
code here is odd because the original was.

Matching it is no longer binding, though. Deliberate departures are allowed and
several already exist (listed at the end). What is not allowed is departing by
accident: know what the original did, say in the source why this differs, and do
not reach for a "cleaner" Godot-native rewrite of something that already works.

## Commands

There is no test suite, linter, or build script. Godot is not on `PATH` in this
environment; substitute the actual editor path.

```bash
godot --path . src/game2d/main.tscn
```

The project's main scene is the 3D preview (`src/game3d/level3d_preview.tscn`),
so a bare run, F5 and an export open that; the 2D game is run by naming
`src/game2d/main.tscn`, as above.

```bash
godot --path . --headless --check-only --script src/game2d/core/main.gd
```

A fresh clone has no `.godot/`, so `class_name` globals are unresolved and any
`--script` run fails with "Identifier not declared in the current scope". Run
`godot --path . --headless --import` once first. New PNGs also need an import
before they resolve.

`tools/README.md` lists every script in `tools/`, what it is for and how it is
run. The closest thing to a test suite:

- Maps: `tools/verify_json_maps.gd`, `verify_json_roundtrip.gd` (then
  `git diff --exit-code assets/maps` must be clean), `verify_map_edit.gd`
  (leaves `stage-0.json` modified on purpose; `git checkout -- assets/maps`
  after), `verify_flow_field.gd`, and `verify_backdrop.gd` (needs a window).
  See `docs/maps.md`.
- Behaviour: `tools/play_trace.gd` — a seeded, scripted run of every stage
  writing every tick's state; run on two revisions and `cmp` the output.
  Anything that should not change gameplay must leave it identical.
- 3D: `verify_level3d.gd`, `verify_level_editor.gd`, `verify_level3d_audio.gd`.

```bash
godot --path . --headless --script tools/play_trace.gd -- build/play_trace/a.txt ghost
```

Export uses the single `Windows Desktop` preset in `export_presets.cfg`:

```bash
godot --path . --headless --export-release "Windows Desktop" build/jackal.exe
```

`include_filter="*.dat,*.xml,*.json"` in that preset is load-bearing — Godot does
not import any of those extensions as resources, so without it an exported build
ships with no maps or sprite indices and dies on the loading screen. Verify a
build really carries them with `--export-pack` and a grep for `stage-0.json` in
the `.pck`.

`build/` is scratch output, kept out of the export by `exclude_filter`. Its
subfolders carry a local `.gdignore` so that Godot does not import them — all
but `build/level3d/`, whose `.glb` the level editor builds and the preview
`load()`s, which needs it imported. A tool writing a new folder there should
add one. `docs/` is under `.gdignore` too: screenshots and renders go there.

## Architecture (2D game)

The original is a fixed-logic-rate game drawn with immediate-mode OpenGL, and is
reproduced as such. There is exactly one node: `Main` (`Node2D`) in
`src/game2d/main.tscn`. Everything else is a plain `RefCounted` — no `Area2D`, no
physics server, no scene tree, no signals except `AudioStreamPlayer.finished`.
Collision is the original's hand-written AABB tests (`HitElement.overlap` and the
`hit_*` / `is_solid_*` / `is_mine_*` families), not Godot collision.

### Timing — the 100 Hz / 60 fps split

`project.godot` sets `physics_ticks_per_second = 100` and `run/max_fps = 60`, and
that pairing is deliberate:

- `Main._physics_process` → one logic tick (`input.snap()`, `mode.update()`),
  matching the original's 100 Hz accumulator.
- `Main._process` → per-frame work only: the fade ramp, song chaining,
  `queue_redraw()`. Several counters (fade, song, jeep rumble, invincibility
  flash, mine and star animation) advance from `render()` in the original, so
  they must stay on the 60 fps side.
- `Main._draw` → the whole frame, in one pass.

Moving work between `_physics_process` and `_process` changes game speed.

### Modes and entities

`Modes` (`src/game2d/core/modes.gd`) lists the modes; `Main.request_mode(int)` builds
one. Modes are duck-typed (`init/update/render`, optional `input_event`,
`fade_completed`, `pan_complete`). `GameMode` (`src/game2d/game/`) is gameplay;
requesting any mode destroys it and the run with it.

`GameElement` → `HitElement` → `Enemy`, held in `GameMode.elements[8]` (eight
draw layers, the player between 3 and 4). Two invariants that are easy to break:

- **`super()` first.** GDScript does not call a parent `_init` implicitly, so
  every element constructor starts with `super()`. `GameElement._init` runs
  `init()` and registers the element **before** the subclass body assigns
  `x`/`y` — as in Java. So `init()` must not read `x`/`y`.
- **Reversed loops.** Update and draw walk `elements` backwards and layers 7→0
  on update. Enemy behaviour depends on this order; preserve it.

Nothing picks a jeep by index (there can be two): an element reads `player`,
which returns the nearest jeep and is re-picked on every read, so not from
`init()`; shots at the jeeps go through `attack_players` / `attack_players_rect`;
points and pickups go to `GameMode.acting_player`.

### Two frames: SCREEN_* vs DISPLAY_*

`SCREEN_WIDTH`/`SCREEN_HEIGHT` (2048x1152) are the viewport;
`DISPLAY_WIDTH`/`DISPLAY_HEIGHT` (1024x960) are the original frame, kept as the
layout box for fixed-size artwork. Decide which one the code means: "the edge
of the visible frame" → `SCREEN_*`; "where on the title / menu / cutscene does
this go" → `DISPLAY_*`.

2048 is the full width of every map, so `max_camera_x` is 0 and **every write to
`camera_x` must clamp to it** — two places that did not crashed the background
loop. Boss managers mix absolute map coordinates (keep them) with a few screen
coordinates in disguise (derive those from `SCREEN_HEIGHT`).

### Controls

- **`create_unit_vector(int)` silently lies** for an off-grid angle (a `match`
  with no default). Continuous angles go through `create_unit_vector_deg(float)`.
- **Mouse buttons stay out of `is_fire()` / `is_shoot()`**, which the menus read;
  `Player` reads `is_gun()` / `is_grenade()`, which OR the mouse in.

### Data

Stage maps are `assets/maps/stage-N.json`, read and written by `MapIO`.

- `groups` order is significant: `groups_map` stores the group index per cell
  and `BossHeadquarters` hardcodes `groups[0]`.
- `MapIO.serialize` must agree with `tools/map_json.py` byte for byte, so saving
  an unedited stage leaves no diff and one tile touches one line.
- `tile_map` is only visual; collisions and the flow field read `types_map`.
  Rebuild `dirs-N.dat` (`tools/dirs_build.gd`) only after editing the collision
  grid.

### Audio

Three buses — `Master`, with `Music` and `Sfx` feeding it (`AudioSettings`).
`set_music_paused` is the pause; `set_music_on` is the preference — never undo a
pause with `set_music_on(true)`.

## 3D preview and level files

`src/game3d/level3d_preview.tscn` plays `assets/level3d/stage-N.json`; nothing
in the 2D game reads that. `resources/3d/jackal_stage1.glb` is *built* from the
level file by `tools/blender/build_level.py`, so the base blend's `export_all()`
must not be run — it would write the hand-built level back over it
(`export_destructibles()` alone is safe). Blender here is the Store build: run
`%LOCALAPPDATA%\Microsoft\WindowsApps\blender-launcher.exe`, not `blender.exe`,
and read `--report`, because its console output is not seen.

## Conventions

- Renames forced by GDScript, all documented in the source: `Main.rotate` →
  `rotate_point` (`Node2D.rotate` exists); `GameElement.remove()` → `do_remove()`
  (a method and property cannot share a name); `IMode` and friends are duck-typed
  rather than interfaces.
- `*.uid` files are committed on purpose — Godot 4.4+ uses them as each script's
  stable identity, and excluding them breaks references on clone.
- `.gitattributes` forces LF everywhere, including the working tree on Windows.
- `.godot/` is ignored; it is regenerated on open.
- `project.godot` comments use `;`, not `#` — a `#` comment silently stops the
  keys after it from being applied.
- 3D models are cel-shaded, and a model without it is not finished: see
  `docs/cel-shading.md`. The water is deliberately left soft.

## Known deviations from the original

Deliberate. Not bugs, and not to be "fixed" back without saying why (the reasons
are in `docs/game-2d.md`):

- Controls: WASD movement, O and P for the weapons, and mouse aim, gated on
  `ButtonMapping.mouse_aim`.
- Two players, from the title screen's "2 players", and in the 3D preview.
- No loading screen: `Main.load_all` runs from `_ready`.
- Sound options on three buses, under Options → Sound and in the in-game menu.
- An Escape menu inside a stage: resume, options, quit to title, quit game.
- `CAMERA_BOUND` is a full frame rather than the original's 224.
- At most `Player.MAX_BULLETS` (3) machine-gun rounds in flight.
- Turbo, on by default (`ButtonMapping.turbo`): a held gun fires every
  `Player.TURBO_DELAY` (7) ticks rather than every `GUN_ARMED_DELAY` (45).
- `FlowField.build` produces shortest paths, which the shipped `dirs-N.dat` do
  not always contain.

And one bug kept on purpose: `SunsetMode._draw_helicopter`'s rotor disc grows
instead of fading in, because the Java original passes its fade value into
`drawRotated`'s `scale` parameter rather than its `alpha` one.

## Further reading

- `docs/game-2d.md` — modes, entities, rendering and clipping, sprite atlases,
  the two frames, controls, two players, audio and input, the in-game menu.
- `docs/maps.md` — the map checks and map editor, the stage JSON, binary
  formats, the flow field, image backdrops.
- `docs/level3d.md` — the 3D level file, its ground, the Blender builder, the
  level editor.
- `docs/preview3d.md` — the 3D preview's title, settings, light presets, splash
  and dust, its co-op. Options: `docs/preview3d-options.md`.
- `docs/audio3d.md` — the 3D preview's effects and music, the three sound
  modes, the adaptive boss music, the mix, debugging silence.
- `docs/shop-plan.md` — the planned shop between rounds: points as currency,
  bought lives, upgrades, the device key; its steps and their Definition of
  Done: `docs/shop-implementation.md`.
- `docs/level-editor-plan.md`, `docs/level3d-pipeline.md`,
  `docs/cel-shading.md`, `docs/soldier-pipeline.md`, `docs/boat-pipeline.md`.
- `README.md` — rationale for the controls and how spawning was measured.
