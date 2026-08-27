# TODO — the map editor

State: `src/tools/map_editor.tscn` edits all four things a stage file holds —
the tile grid, the collision grid, the spawn triggers and the destruction
groups — and writes `assets/maps/stage-N.json` back with a diff no larger than
the edit. `FlowField` rebuilds `dirs-N.dat` from the collision grid. Four checks
run without a window: `verify_json_maps.gd`, `verify_json_roundtrip.gd`,
`verify_map_edit.gd`, `verify_flow_field.gd`. All green.

What is left, in the order it matters.

## Decisions, not work

- **`dirs-1.dat` and `dirs-4.dat` disagree with their own collision grids.**
  Followed cell by cell they arrive on 38% and 56% of walks, under every
  passability rule tried; the other four manage 86–99%. They were most likely
  generated from a different revision of those maps. Rebuilding them moves tanks
  more than rebuilding any other stage would — towards the map that is actually
  in the game. Nothing has been rebuilt so far.

- **A rebuilt field paths better than the shipped one.** It is optimal by
  construction and never produces a longer path; 19–48% of sampled walks come
  out shorter. Enemies therefore converge sooner and the stage plays slightly
  harder. The standing policy is to rebuild only the stage whose collision grid
  was edited, which keeps this to where it cannot be avoided.

## Only playing can settle these

- Play a stage after rebuilding its flow field. The tanks either behave as
  before or they do not, and no percentage decides it.

- **The export was never run to completion.** Godot 4.7.2's export templates are
  not installed on this machine, so `--export-release` fails before it starts.
  `--export-pack` proved the preset's `include_filter` carries `*.json` and that
  `stage-0.json` is in the `.pck`, but no built `.exe` has been launched.

## Next work, by value

1. **Play from here.** Launch the game at the stage and row the editor is
   looking at. Today the edit loop is closed by hand. Needs a guarded
   `OS.get_cmdline_user_args()` branch in `Main` and a button in the editor.

2. **Flood fill for the tile brush.** Freehand and rectangle only at the moment,
   which makes retiling a shoreline tedious.

3. **Copy and paste a region.** The compounds repeat across stages and are laid
   out tile by tile today.

4. **A seventh stage.** The editor edits the six that exist; a new one needs its
   own `tiles-N` atlas first, which is an art problem rather than an editor one.

## Gaps in Check stage

- `BOSS_GARAGE` and `BOSS_STATUES` bind to groups the same way everything else
  does, but their managers place the objects at absolute map coordinates rather
  than at the trigger's, so the probe table cannot cover them. They go
  unchecked.

- `ElephantMissile` reads `groups_map` wherever it lands, so a missile that hits
  a cell belonging to no group fires group 0 instead. Nothing works out whether
  that matters per stage; on stage 6 group 0 is the headquarters.

- Overlapping trigger footprints are legal and unflagged. Whether they are ever
  a mistake is not established.

## Small print

- Group 0 cannot be deleted — `BossHeadquarters` reaches for `groups[0]` by
  number. Emptying it is allowed and does the same thing for everything else.

- `tools/map_json.py verify` and `tools/verify_json_maps.gd` compare against the
  original binary maps, which were deleted in the JSON migration. Restore them
  first: `git checkout <ref before 3aa6814> -- assets/maps`.

- A fresh clone has no `.godot/`, so any `--script` run fails on unresolved
  `class_name` globals until `godot --path . --headless --import` has run once.
