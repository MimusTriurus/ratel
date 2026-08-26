# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A 1:1 port of meatfighter.com's Java/Slick2D remake of Konami's *Jackal* (NES) to
Godot 4 / GDScript. LGPL v3, © meatfighter.com — keep the licence and attribution
with any redistribution.

**The Java original is the specification.** It lives beside this repo in
`../java_src/jackal/` (126 `.java` files, not tracked here). Every GDScript file
names the `jackal.*` class it came from in its header comment, so `grep` the
header to find the counterpart. When changing behaviour, read the Java source
first: divergence from it is a bug, not a style choice, and "cleaner" Godot-native
rewrites are the wrong direction.

## Commands

There is no test suite, linter, or build script. Godot is not on `PATH` in this
environment; substitute the actual editor path.

```bash
godot --path . src/main.tscn
```

```bash
godot --path . --headless --check-only --script src/core/main.gd
```

A fresh clone has no `.godot/`, so `class_name` globals are unresolved and any
`--script` run fails with "Identifier not declared in the current scope". Run
`godot --path . --headless --import` once first.

The closest thing to a test is the map conversion check, which loads every stage
through `MapIO` and compares it against the original binary readers (see Data):

```bash
godot --path . --headless --script tools/verify_json_maps.gd
```

Export uses the single `Windows Desktop` preset in `export_presets.cfg`:

```bash
godot --path . --headless --export-release "Windows Desktop" build/jackal.exe
```

`include_filter="*.dat,*.xml,*.json"` in that preset is load-bearing — Godot does
not import any of those extensions as resources, so without it an exported build
ships with no maps or sprite indices and dies on the loading screen. `*.json` is
there for the stage maps; verify a build really carries them with
`--export-pack` and a grep for `stage-0.json` in the `.pck`.

## Architecture

The original is a fixed-logic-rate game drawn with immediate-mode OpenGL, and is
reproduced as such. There is exactly one node: `Main` (`Node2D`) in
`src/main.tscn`. Everything else is a plain `RefCounted` — no `Area2D`, no
physics server, no scene tree, no signals except `AudioStreamPlayer.finished`.

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

### Mode state machine

`Modes` (`src/core/modes.gd`) lists the 14 modes; `Main.request_mode(int)`
constructs one and `set_mode` calls `init(main)` then `update()`. Modes are
duck-typed, not an interface: `init/update/render`, plus optional `input_event`
(only `InputMode` needs raw events, for key remapping), `fade_completed`
(`IFadeListener`) and `pan_complete`. `src/modes/` holds title/map/cutscene/menu
modes; `GameMode` in `src/game/` is the gameplay mode.

Startup is `Main._ready` → `LOADING`. `LoadingMode.update()` calls
`Main.load_next()` once per tick, which is a giant `match load_index` that loads
one asset group per tick and returns progress — this is why loading is a mode and
not a `_ready` block. `CutsceneSequence` shuffles the between-stage cutscenes.

### Entities

`GameElement` → `HitElement` → `Enemy` (`src/game/`), held in
`GameMode.elements[8]` — eight draw layers, with the player drawn between layers
3 and 4. `GameMode.add()` also files enemies into the parallel `enemies` /
`solids` / `mines` lists.

Two invariants that are easy to break:

- **`super()` first.** GDScript does not call a parent `_init` implicitly, so
  every element constructor starts with `super()`. `GameElement._init` runs
  `init()` and registers the element with the current `GameMode` **before** the
  subclass body assigns `x`/`y` — as in Java. So `init()` must not read `x`/`y`.
- **Reversed loops.** Update and draw walk `elements` backwards
  (`for j in range(list.size() - 1, -1, -1)`) and layers 7→0 on update. Enemy
  behaviour depends on this order; preserve it.

Collision is the original's hand-written AABB tests (`HitElement.overlap` and the
`hit_*` / `is_solid_*` / `is_mine_*` box families), not Godot collision.

### Rendering

`Main` owns the whole draw path. `Spr` stands in for Slick's `Image` — including
its per-image `alpha`, which the stage 2 water cross-fade mutates directly.
`Atlas` parses the `.xml` sprite sheets with `XMLParser`, returning `null` for an
unknown name (`load_extra_large_image` relies on that); it still serves the tile
sheets, the large cutscene images and the font, while the object sprites go
through `SpriteBank` (see Sprite atlases below). `_push`/`pop_graphics`/
`translate_graphics`/`rotate_graphics`/`scale_graphics` emulate the
`glPushMatrix`/`glTranslatef`/`glRotatef` stack; the `draw_*` family mirrors
Slick's overloads one for one.

Slick's `Graphics.setWorldClip()` has no Godot equivalent, so `set_clip` +
`_blit_clipped` emit a clipped sprite as a textured polygon: the quad is
transformed into device space, clipped against the rectangle with
Sutherland–Hodgman, and its UVs recovered through the inverse transform. Exact
for rotated and scaled sprites, which the floor guns, super tank treads and
rolling columns need.

`GameMode.render()` is `_draw_background()` → `_draw_sprites()` → `_draw_score()`,
replaying the original's order.

### Sprite atlases

The original's nine `sprites-N.png` sheets were packing-driven — `sprites-1`
held the player, brown tanks, soldiers, mines and lasers only because they fit
together — so every loader had to know which sheet its sprite lived in, and
`load_sprites` threaded `pack1`..`pack9` through 400 lines. They are now one
atlas per object in `assets/images/sprites/`: `brown-tank.png` holds exactly
the three brown-tank frames. 140 atlases, 264 sprites, and the total canvas
area went *down* (1.96 Mpx against 2.36 Mpx), because the sheets no longer pad
to 512x512.

`SpriteBank` (`src/core/sprite_bank.gd`) resolves a name against all of them
through the generated `sprites/index.xml`, loading each texture on first use,
so no loader names an atlas and the physical grouping can be changed again
without touching GDScript. It returns `null` for an unknown name, like
`Atlas.get_sprite`. Sprite names still carry their `.png` suffix
(`"brown-tank-%d.png"`), so call sites read exactly as before.

`tools/` owns the migration: `sprite_repack.py` regrouped the sheets (pixels
copied verbatim, 1 px transparent gutter), `sprite_verify.py` compared all 264
regions against the originals pixel for pixel and checked for overlaps, and
`sprite_index.py` regenerates `assets/images/SPRITES.md` — the name → atlas →
size table, which is the thing to grep when looking for a sprite. Verify needs
the pre-migration sheets, so run it after
`git checkout <ref-before-migration> -- assets/images/sprites-*`.

Two things to keep in mind: `index.xml` is what ships (the export preset's
`include_filter` covers `*.xml`, so no change was needed there), and new PNGs
need one editor open — or `--headless --import` — before they resolve.

### Data

Stage maps are `assets/maps/stage-N.json`, read by `MapIO` (`src/core/map_io.gd`)
into a `Stage`. One file holds everything authored about a stage:

- `types` — the collision grid, one character per tile (`#` solid, `.` empty,
  `S` shield, `~` water, `%` swamp, `>` conveyor), one string per map row, with
  the legend repeated in every file. `MapIO` appends the row of water past the
  bottom of the map that the original loader added, and `map_height` counts it,
  so a stage is 359 rows on disk and 360 in memory (391/392 for stage 5).
- `tiles` — the tile grid, one line per map row. Indices ≥ 225 come from the
  shared `tiles-6` sheet and are drawn over everything else; see the background
  loop in `GameMode._draw_background`.
- `groups` — the cells rewritten when a destructible thing is destroyed, each
  `[x, y, new tile, new type]`. **Order is significant**: `groups_map` stores the
  group index per cell and `BossHeadquarters` hardcodes `groups[0]`.
- `triggers` — spawn triggers by `Triggers` name, for both difficulties.

`Triggers` (61 constants) indexes `GameMode.process_trigger`, which spawns the
element for each map trigger, and is also what the JSON names resolve through
(`MapIO.trigger_constants`, via `get_script_constant_map`). Footprints live in
`trigger-sizes.json`; `MapIO.load_trigger_sizes` applies the same four-row
early fire to boss triggers that `Main.load_sizes` used to.

Two binary formats are left, both generated rather than authored, still read
with `FileAccess` in big-endian mode (`Main._open`/`_s16`/`_s32`) because they
are `java.io.DataInputStream` dumps: `assets/images/*.dat` (cutscene tile
tables) and `maps/dirs-N.dat`, the precomputed flow field — a 3-bit direction
for every (from-cell, to-cell) pair on a 128 px grid, packed 21 to a `long`,
which is how tanks path in O(1) via `GameMode.suggest_direction*` and
`_lookup_direction`. Text would be several MB a stage, and nobody edits them by
hand.

`Stage` holds the pristine per-stage maps; `GameMode` copies `tile_map` /
`types_map` because gameplay mutates them.

`tools/map_json.py` did the conversion from the original `.dat` maps and can
still check it: `verify` re-encodes each JSON into the binary layout and
compares byte for byte, and `tools/verify_json_maps.gd` loads every stage both
ways and diffs the `Stage` objects. Both need the deleted `.dat` maps back
first, as `sprite_verify.py` needs the pre-migration sheets:

```bash
git checkout <ref-before-the-json-migration> -- assets/maps
```

The flow field is *not* regenerated by any of this. It is derived from the
collision grid, so editing `types` invalidates it, and there is no generator
yet — the original Java one is not in this repo. Reverse engineering it got as
far as: 8-connected shortest path over the 128 px cells, a cell passable when
all sixteen of its tiles are drivable, which reproduces 94% of the shipped
directions as optimal steps (a plain BFS and a 14/10-weighted Dijkstra score
the same, so the residue is tie-breaking or a passability nuance). Good enough
to regenerate a working field, not good enough to reproduce the files.

### Audio and input

`Song` chains intro → optional intro2 → looping track through
`AudioStreamPlayer.finished`. `Sfx` keeps a small voice pool per effect and
reproduces the original's 125 ms retrigger throttle (`Main.MINIMUM_SOUND_TIME`).
Song changes are deferred: `request_song` sets `requested_song`, and `_process`
swaps it.

`HumanInput.snap()` samples level-triggered state once per logic tick; edge
triggers derive from the previous snap, which is what makes
`clear_key_pressed_record()` work. `ButtonMapping` persists to
`user://buttons.cfg`.

### Two frames: SCREEN_* vs DISPLAY_*

`DISPLAY_WIDTH`/`DISPLAY_HEIGHT` (1024x960) are no longer the viewport. They are
the original frame, kept as the layout box for fixed-size artwork;
`SCREEN_WIDTH`/`SCREEN_HEIGHT` (2048x1152, exact 16:9 at 4x) are the actual
viewport. 2048 is the full width of every map, so `max_camera_x` is 0 and there
is no horizontal scrolling. When touching anything that reads either, decide
which one the code means:

- "the edge of the visible frame" -- `is_outside_of_frame`, camera margins,
  enemies turning at the edge, boss spawn spread -> `SCREEN_WIDTH`.
- "where on the title screen / menu / cutscene does this go" -> `DISPLAY_WIDTH`.
  `JeepYeahPlane` lives in `src/game` but is a cutscene actor, so it is the one
  file there still on `DISPLAY_WIDTH`.

`Main._draw` centres every non-`GameMode` mode by `PILLAR_X` and wraps it in
`set_outer_clip`. The clip is not optional: `IntroMode` slides its story crawl
in from outside the frame and relied on the old viewport to hide it.

Clipping therefore has two independent rects intersected into `_clip_rect`: the
inner one is Slick's `setWorldClip` (`set_clip`/`clear_clip`), the outer one the
pillar box. They are kept separate deliberately -- `set_clip` is a replace and
`clear_clip` an off, and call sites like `boss_garage_manager` set twice and
clear once, so a push/pop stack would leak, and a single shared rect would let a
mode's `clear_clip` drop the pillar box for the rest of the frame. `_blit` skips
the polygon path for sprites wholly inside the clip, which matters now that
every sprite on a menu screen is clipped.

`GameMode.TILES_ACROSS`/`TILES_DOWN` are derived from the viewport; the
background loop draws one more of each, and one column fewer at the right edge
of the map where `row[TILES_ACROSS + x_tile]` would index `map_width` itself.
`max_camera_y`, `REMOVE_BOUND`, `CAMERA_MARGIN_NORTH`, the player's bottom clamp
in `Player.update` and the score HUD's y are all derived from the frame rather
than hardcoded to 960 now.

The project starts fullscreen (`display/window/size/mode=3`). Note that
`project.godot` comments use `;`, not `#` -- a `#` comment silently stops the
keys after it from being applied.

`_update_cursor_visibility` owns the mouse mode and compares against the live
`Input.mouse_mode` rather than a cached flag, because `full_screen_toggle_check`
used to set the mode itself and left that cache stale, stranding the cursor
hidden on the menus.

Because the frame is as wide as the map, `max_camera_x` is 0, and **every write
to `camera_x` must clamp to it**. Two places got this wrong when the frame
widened and crashed the background loop: `_create_player`, which the `PLAYER`
trigger runs at the start of every stage, and the ending pan, which drove
`camera_x` towards a hardcoded 512. `_create_player` also reused
`CAMERA_MARGIN_NORTH` as a horizontal offset, so growing that margin for the
taller frame moved the spawn sideways -- it has its own
`PLAYER_SPAWN_CAMERA_OFFSET` now. The background loop clamps its column and row
counts as a backstop rather than special-casing the exact map edge.

`CAMERA_BOUND` is a deliberate departure: the original's 224 is a full frame
here, so the jeep can back up about a screen and a half instead of two thirds
of one. The ratchet in `_camera_track_player` is unchanged, and the boss pan
still pins `max_camera_y` to 0, so an arena cannot be driven out of. Note that
`REMOVE_BOUND` is measured from `max_camera_y`, so a longer leash also keeps
elements alive further below the frame.

Boss managers are the exception to that, and worth checking when the frame
changes: most of their coordinates are absolute positions on the 2048-wide map
(garages, statues, ship guns, headquarters lights) and must stay that way, but a
few are screen coordinates in disguise. The boss pan leaves `camera_y` at 0, so
`BossBlueTanksManager` wrote its off-screen spawn as a literal 1012, which was
960 + 52; with a 1152-tall frame that put a tank 140 px inside the view. It is
derived from `SCREEN_HEIGHT` now. The reinforcement tanks in the ship, statue
and headquarters fights were already written as `SCREEN_HEIGHT + 48`.

Spawning is otherwise frame-independent and does not need adjusting when the
viewport changes: `load_trigger_map` sets a trigger's row to `tile_y + height - 1`, so it
fires when the bottom of the enemy's footprint is one tile above the top edge,
and a whole row fires at once regardless of x. This was measured, not assumed --
see `README.md`.

### Controls: WASD + mouse aim

The one deliberate gameplay departure from the Java original. Movement defaults
to WASD (arrows always work as a second set), the cursor sets the weapon angle,
LMB fires the machine gun and RMB throws the grenade/missile.

`ButtonMapping.mouse_aim` gates the aiming half and is switched from Options →
Controls (`ControlsMode`, `Modes.CONTROLS` — a mode with no counterpart in the
original, modelled on `DifficultyMode`). Off, `HumanInput._snap_mouse` reports
no cursor motion and no mouse buttons, so `Player` falls back to the original
code path; the WASD/arrow movement is not gated and always applies.

`README.md` has the rationale; the three constraints to keep in mind when
touching this:

- **`create_unit_vector(int)` silently lies.** It is a `match` over multiples of
  45 with no default, so an off-grid angle leaves `unit_vector` at its previous
  value. Continuous angles must go through `create_unit_vector_deg(float)`,
  which routes multiples of 45 back to the exact table so keyboard aiming stays
  bit-identical.
- **Mouse buttons stay out of `is_fire()` / `is_shoot()`.** Those are read by
  `Menu`, `IntroMode`, `SunsetMode`, `HardEndingMode` and `KonamiCode`; a click
  must not navigate a menu. `Player` reads `is_gun()` / `is_grenade()`, which OR
  the mouse in.
- **`InputMode` binds whatever it is given.** It is a faithful port, so every
  prompt accepts any key — which used to include `Escape`, leaving no way out
  of the screen but to bind six controls. It now snapshots the mapping on entry
  (`ButtonMapping.duplicate_mapping`), treats `Escape` as cancel, and shows the
  binding each prompt would replace. Options → Defaults calls
  `reset_to_defaults()` for when a mapping is already unusable.
- **Direction keys shadow the fallback gun keys.** `GUN_FALLBACK` is the
  original's `Z / Y / W / K`, and `W` is now "up", so `snap()` skips any
  fallback key a direction or the grenade claims.

Aim is resolved once per logic tick in `Player.update` (cursor position plus the
camera offset), so a shot uses the angle the cursor had on its tick. The jeep
body still faces its movement direction — the original's gun never pointed
where the sprite did, so nothing is lost and no new art is needed.

The reticle is `Main.draw_crosshair`, four `draw_rect` bars over a grown black
pass (there is no crosshair in the sprite sheets), one original-screen pixel
thick and about two thirds of the jeep's width. It is called last in
`GameMode.render()`, after `_draw_sprites()` has popped the camera translation,
so it sits at the cursor rather than in the world. `Main._update_cursor_visibility`
hides the system cursor to match, but only while a `GameMode` is playing and
unpaused — menus and pauses get the pointer back, and `MOUSE_MODE_HIDDEN` never
confines it.

Both are gated on `input.is_aiming()`, which stays false through the Chinook
intro drop only incidentally — the real gate there is `GameMode.playing`, which
`Chinook` holds false until the jeep lands.

## Conventions

- Renames forced by GDScript, all documented in the source: `Main.rotate` →
  `rotate_point` (`Node2D.rotate` exists); `GameElement.remove()` → `do_remove()`
  (a method and property cannot share a name); `IMode` and friends are duck-typed
  rather than interfaces.
- `*.uid` files are committed on purpose — Godot 4.4+ uses them as each script's
  stable identity, and excluding them breaks references on clone.
- `.gitattributes` forces LF everywhere, including the working tree on Windows.
- `.godot/` is ignored; it is regenerated on open.

## Known deviations from the original

Intentional, do not "fix":

- `SunsetMode._draw_helicopter`'s rotor disc grows instead of fading in. The Java
  original passes its fade value into `drawRotated`'s `scale` parameter rather
  than its `alpha` one; the bug is reproduced.
