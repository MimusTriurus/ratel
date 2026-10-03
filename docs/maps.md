# Stage maps, the flow field and image backdrops

Moved out of `CLAUDE.md`. How a stage is stored, checked and edited.

## Checks and the map editor

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

## Data

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

## Image backdrops

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

