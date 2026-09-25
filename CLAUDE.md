# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
several already exist — WASD and mouse aim, a longer camera leash, a flow field
that paths better than the one that shipped. What is not allowed is departing by
accident: know what the original did, say in the source why this differs, and do
not reach for a "cleaner" Godot-native rewrite of something that already works.

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

The closest thing to a test suite is the three map checks in `tools/`, none of
which need a window:

```bash
godot --path . --headless --script tools/verify_json_maps.gd
```

```bash
godot --path . --headless --script tools/verify_json_roundtrip.gd
```

```bash
godot --path . --headless --script tools/verify_map_edit.gd
```

The first loads every stage through `MapIO` and through the original binary
readers and compares the two (see Data). The second writes every stage straight
back out: `git diff --exit-code assets/maps` must stay clean, which is what
proves `MapIO.serialize` agrees with `tools/map_json.py` byte for byte; it also
checks the optional `background` block both ways round. The
third drives the editor's brushes, undo and save without a tree, and leaves
`stage-0.json` modified on purpose — `git diff --stat assets/maps` should show
one line per painted row and nothing else, then `git checkout -- assets/maps`.

A fourth check does need a window, because it compares rendered frames: it draws
every stage both ways, from the tile grid and from the baked image chunks, and
they must come out identical. See Image backdrops.

```bash
godot --path . --windowed --resolution 1280x720 --script tools/verify_backdrop.gd
```

`src/tools/map_editor.tscn` shows a stage the way the game draws it, with the
collision types, destruction groups and spawn triggers over the top — including
the row each trigger actually fires on, which is the thing about the map format
that is impossible to see in the game. It edits all four things a stage file
holds: the tile grid, the collision grid, the triggers and the destruction
groups. Check stage looks for the mistake the format invites — a destructible
object binds to its group by reading `groups_map` at one cell of its own
footprint, so a group that has drifted off that cell silently fires group 0
instead:

```bash
godot --path . src/tools/map_editor.tscn
```

It can also render one view and quit, which is how it gets checked (a real
window is required, `--headless` has no framebuffer to read back):

```bash
godot --path . --windowed --resolution 1280x720 src/tools/map_editor.tscn -- --shot out.png 3 0.6 150 "tiles,overlay,types,triggers"
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

Startup is `Main._ready` → `load_all()` → `INTRO`, the title screen. Loading
used to be a mode of its own: `LoadingMode` called `load_next()` once a tick and
drew a progress bar over an NES controller, because the original did. It is a
`_ready` block now, so the window opens on the title screen rather than on a
progress bar — about 0.6 s of work before the first frame. `load_next` is still
a giant `match load_index` loading one asset group per call, and its last step
is what requests `INTRO`, which is what ends `load_all`'s loop.
`CutsceneSequence` shuffles the between-stage cutscenes.

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
- `background` — optional, and the one part of the file that is not the
  original's data: `{"mode": "tiles" | "image", "chunk_height": 2048}`. See
  Image backdrops below. Absent means `tiles`, so a stage that has never been
  baked round-trips byte for byte without it, which
  `tools/verify_json_roundtrip.gd` checks along with the block itself.

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

`MapIO` writes as well as reads. `serialize` reproduces `map_json.py`'s layout
exactly, one map row to a line, so that saving a stage nobody edited leaves no
diff and an edit to one tile touches one line. The grids come from the `Stage`;
everything else is carried over from the document the stage was loaded from,
which is why `read_document` exists and why `save_stage` wants it — the trigger
list keeps the order it was authored in, and a `Stage` cannot preserve that
because it files triggers by the row they fire on.

`tools/map_json.py` did the conversion from the original `.dat` maps and can
still check it: `verify` re-encodes each JSON into the binary layout and
compares byte for byte, and `tools/verify_json_maps.gd` loads every stage both
ways and diffs the `Stage` objects. Both need the deleted `.dat` maps back
first, as `sprite_verify.py` needs the pre-migration sheets:

```bash
git checkout <ref-before-the-json-migration> -- assets/maps
```

`FlowField` owns `dirs-N.dat` — reading, writing and building it. Building is
**not** a faithful port: the original generator is not in this repo, so the rule
was reverse engineered from the data. It is a breadth-first search from each
target over the 128 px cells, eight-connected, neighbours visited in
direction-code order, each cell taking the direction back to whichever neighbour
reached it first; a cell is passable when the four tiles in the middle of it are
drivable. That agrees with the shipped files on 60–76% of pairs and, where it
differs, produces the shorter path — it is optimal by construction and the
shipped one is not.

Rebuild only after editing the collision grid, which invalidates the field
anyway. Editing tiles or triggers does not.

```bash
godot --path . --headless --script tools/dirs_build.gd -- 3
```

```bash
godot --path . --headless --script tools/verify_flow_field.gd
```

The check must report `valid 100%` for every stage: following a built field
always arrives. Two other numbers are worth knowing before rebuilding anything.
Following the *shipped* field arrives on 99% of walks for `dirs-0`, 98% for
`dirs-2`, 87% for `dirs-3` and 86% for `dirs-5` — but only 38% for `dirs-1` and
56% for `dirs-4`, under any passability rule tried. Those two disagree with
their own collision grids and were most likely generated from a different
revision of those maps, so rebuilding them changes tank behaviour more than the
others — towards the map that is actually in the game.

### Image backdrops

An alternative to assembling the terrain out of tiles: one image per stage,
authored as a whole rather than as a grid. It draws, and it draws exactly what
the tile path drew — `tools/verify_backdrop.gd` compares 222 rendered frames
across the six stages and finds no differing pixel. What does not exist yet is a
reason to switch: the images are baked *from* the tiles, so every stage still
says `"mode": "tiles"`, and there is nothing to gain until a stage is painted by
hand. Flipping that one word per stage file is the whole switch.

The geometry is what makes it cheap. A map is 64 tiles wide, so 2048 px, which
is exactly `SCREEN_WIDTH` — hence `max_camera_x == 0` — and a stage image is a
2048x11488 strip (2048x12512 for stage 5). That is 94 MB of RGBA8, and
`Main.load_stages` loads all six up front, so it is cut into 2048x2048 chunks:
`assets/images/levels/stage-N-K.png`, chunk `K` covering map rows
`[K * chunk_height / 32, ...)` with the last one cropped to what is left. The
names and the count are a convention rather than data — `MapIO.background_chunk_*`
derives both from `chunk_height` and `map_height`, as `dirs-N.dat` and
`tiles-N.png` are derived from a stage index. At a 1152 px frame no more than two
chunks are ever on screen.

`tools/bake_stage_image.gd` writes them, reproducing `_draw_background` cell for
cell out of the same sheets, so a stage can be compared against the tile path
frame by frame and the images double as wallpaper to paint over:

```bash
godot --path . --headless --script tools/bake_stage_image.gd -- all
```

Three things are deliberately not in the image, because they move: stage 2's
water (`tiles-2` is the one sheet with transparency, so the terrain layer comes
out with holes in exactly the shape of the water, which is what an animated layer
drawn *under* the image wants — `--water` fills them in for a look, not for
shipping), stage 5's conveyor (frame 0 is baked in; the frames are opaque, so an
animated layer over the image covers it), and destruction, which rewrites 16 to
50 cells a stage through `trigger_group`.

`tile_map` is otherwise **only** visual: collisions are `types_map`, the flow
field is built from `types_map`, triggers fire by row. That is why the switch
touches so little — the four places that read it are the whole of it:

- `GameMode._draw_background` picks between `_draw_background_tiles`, unchanged,
  and `_draw_background_image`: the water pattern, then the chunks the frame
  spans, then the patches, then the conveyor. `Main.draw_tiled` is the one new
  primitive, and the one with no Slick counterpart — the water is a repeating
  64x64 pattern rather than a tile per cell, two draws for the whole frame
  instead of a few thousand.
- `trigger_group` and `TileDebris` also call `mark_patched`, which records the
  cell in `background_patches`. `tile_map` stays the source of truth for what a
  cell looks like now; the patch set is just which cells the image is wrong
  about, and they are drawn from the tile sheet.
- `TileDebris` takes the cell's current sprite off the chunk through
  `Spr.sub_image` — `GameMode.background_sprite` answers for either backdrop, so
  the debris code does not know which it got. It falls back to the sheet for a
  patched cell and for a conveyor cell, where the image holds a frame of an
  animation.

Chunks load on demand and are kept for the run: 12 ms each, 16 ms worst, so a
chunk coming into view without the one-ahead prefetch would cost a single frame.
Nothing is evicted — a stage is 90 to 98 MB of texture, and dropping chunks
behind the camera would reload during a boss pan, which can drive the camera back
up a whole stage.

### Audio and input

`Song` chains intro → optional intro2 → looping track through
`AudioStreamPlayer.finished`. `Sfx` keeps a small voice pool per effect and
reproduces the original's 125 ms retrigger throttle (`Main.MINIMUM_SOUND_TIME`).
Song changes are deferred: `request_song` sets `requested_song`, and `_process`
swaps it.

Three buses, not one. Everything used to play on `Master`, which is why the
pause key — the only thing that ever silenced anything — muted the effects
along with the music. `AudioSettings` (`src/core/audio_settings.gd`) adds
`Music` and `Sfx`, both routed to `Master`, at `_ready` and before the first
stream loads; `Sfx` and `Song.make_player` name them. The three controls are
then three separate things: mute one bus, mute the other, set the gain on the
bus they both feed. It persists to `user://audio.cfg`.

Pause and preference are separate too. `set_music_paused` is what the pause key
and the in-game menu use; `set_music_on` is the preference. Undoing a pause
with `set_music_on(true)` — which is what the code did — turns the music back
on for someone who had switched it off.

`SoundMode` (`Modes.SOUND`, not in the original) is the screen: music, sound,
volume, done, reached from Options and returning there. It is the one menu mode
that does not leave when an entry is picked, so its labels carry the state and
`Menu`'s one-shot `selection_made` latch is released after every toggle. The
same trick drives the in-game menu's options page.

`HumanInput.snap()` samples level-triggered state once per logic tick; edge
triggers derive from the previous snap, which is what makes
`clear_key_pressed_record()` work. `ButtonMapping` persists to
`user://buttons.cfg`.

### The in-game menu

Escape opens it over the frozen stage — two pages, both inside `GameMode`
(`_open_menu`, `_render_menu`), because requesting a mode destroys the
`GameMode` and with it the run. That is what "quit to title" is for; the other
entries are resume, options and quit game. The options page toggles music,
sound, volume and mouse aim in place.

Three things worth knowing before touching it:

- It borrows `paused` rather than adding a second frozen state, so the
  crosshair, the system cursor and the pause key all behave as they do under
  the pause key.
- The music keeps playing, unlike under the pause key. The options page can
  switch the music off, and a switch you cannot hear tells you nothing.
- Escape no longer leaves fullscreen while a stage is up — `full_screen_toggle_check`
  ignores it when the mode is a `GameMode`. F12 still toggles the window, and
  every other screen keeps Escape as the way out of fullscreen.

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
- 3D models (`resources/3d/`, built by the scripts inside each `.blend`) are
  cel-shaded, and a model without it is not finished: black chamfers on sharp
  edges, an inverted-hull contour round every part, black seals round flat
  panes. How, and the line widths, are in `docs/cel-shading.md`; the
  per-kind pipelines are `docs/soldier-pipeline.md`, `docs/boat-pipeline.md`
  and `docs/level3d-pipeline.md`. Only the jeep and the BTR are done so far.

## Known deviations from the original

Deliberate. Not bugs, and not to be "fixed" back without saying why:

- Controls: WASD movement and mouse aim, gated on `ButtonMapping.mouse_aim`.
- No loading screen: `Main.load_all` runs from `_ready`, so the game opens on
  the title screen. `jackal.LoadingMode` has no counterpart here any more.
- Sound options — music, effects and a master volume, on three buses where the
  original had one — under Options → Sound and in the in-game menu.
- An Escape menu inside a stage: resume, options, quit to title, quit game. The
  original had no way out of a stage but to die or finish it.
- `CAMERA_BOUND` is a full frame rather than the original's 224, so the jeep can
  back up about a screen and a half.
- At most `Player.MAX_BULLETS` (3) machine-gun rounds in flight. The original
  fires on every press with no cap, so a turbo pad got a round per press; three
  is above what hand tapping reaches and holds turbo to about 14 a second.
- Turbo, on by default (`ButtonMapping.turbo`, Options → Controls and the
  in-game options): a held gun fires every `Player.TURBO_DELAY` (7) ticks
  rather than every `GUN_ARMED_DELAY` (45), which is exactly the cap's rate.
  Mouse aiming means holding LMB, and the original's two rounds a second read
  as a broken gun. Off gives the original trigger back.
- `FlowField.build` produces shortest paths, which the shipped `dirs-N.dat` do
  not always contain. Only stages whose collision grid is edited get rebuilt, so
  this only bites where it has to.

And one bug kept on purpose, because reproducing it is cheaper than explaining
the difference:

- `SunsetMode._draw_helicopter`'s rotor disc grows instead of fading in. The Java
  original passes its fade value into `drawRotated`'s `scale` parameter rather
  than its `alpha` one.
