# 3D level files, the Blender builder and the level editor

Moved out of `CLAUDE.md`. The format, decisions and stages are in
`level-editor-plan.md`; the Blender side in `level3d-pipeline.md`.


## The file

`assets/level3d/stage-N.json` is what the 3D preview plays and what the
Blender builder is to build from — the start of the level editor in
`docs/level-editor-plan.md`, which has the format, the decisions and the
stages. `Level3DIO` (`src/game3d/level3d_io.gd`) reads and writes it with a
fixed layout, as `MapIO` does. It holds the gameplay grid (`nav`, in the
`types` legend), the destruction groups, the triggers of both difficulties
as one ordered list of `entities` (metres, centre of the footprint, with the
group named outright rather than probed), and the placed scenery as
`objects`; `assets/level3d/catalog.json` says what every trigger type and
asset is. `Level3DMap` reads the grid from it, not from the game's
`stage-0.json`, and nothing in the 2D game reads it at all.

`tools/level_from_stage.gd` wrote stage 0's out of `assets/maps/stage-0.json`
and `jackal_stage1.glb`, and overwrites it when run again. The check holds it
to the game's map — round trip, nav, groups, both trigger lists in order, the
`Stage` it fills — and to the catalogue:

```bash
godot --path . --headless --script tools/level_from_stage.gd
```

```bash
godot --path . --headless --script tools/verify_level3d.gd
```

## The ground

The ground is in the file too: land polygons along the brow, water polygons
along the waterline, a measured slope profile between them, and forest
polygons with a scatter rule (`Level3DTerrain`, `src/game3d/world/level3d_terrain.gd`). The polygons are traced off two
rasters the file names, `assets/level3d/rasters/stage-N-ground.png` (red land,
blue water, half blue a river, green forest) and `-height.png` (the rise of
the ground, 5 cm a step), which are what the level editor paints and the
source from now on (`Level3DGround`, `src/game3d/world/level3d_ground.gd`, part 2 of
the plan); `verify_level3d.gd` checks that the two still agree, and
`tools/level_ground_rasters.gd -- N` gave stage 0 its rasters off its
polygons, once. Stage 0's was traced off the
hand-built glb, by a tool that keeps everything else in the file, as
`level_from_stage.gd` keeps the ground. The glb is built from the file now,
so run bare the tool only compares the file with it; its header says how
to trace the hand-built one, which is in git at `7d0abb6`, again:

```bash
godot --path . --headless --script tools/level_terrain_from_glb.gd
```

## The Blender builder

`tools/blender/build_level.py` builds the level in Blender from the file,
on top of `jackal_stage1_lowpoly.blend` for what the file does not describe
(the buildings that are blown up, the palette, the sun, the cameras) and for
the pieces it builds the file's walls, bridges and gate frames out of --
each a copy of the base's piece of its kind, with its bevel, contour and
materials, and a box of its own (`walls` and `bridges` in the file; the gate
an object tied to the GATE entity; stage 1's were read off the base by
`tools/blender/extract_structures.py` and `tools/level_structures_from_base.gd`)
-- into
`build/level3d/` — never over the base. Blender here is the Store build:
run it through `%LOCALAPPDATA%\Microsoft\WindowsApps\blender-launcher.exe`,
not `blender.exe` (permission denied), and read `--report`, because its
console output is not seen. Then hold the result to the file, and to the
hand-built level from above, and play it with the preview's `--level`.
`resources/3d/jackal_stage1.glb` is such a build, copied over: it is what
the preview and the editor load, so the file is the level's source and the
base's own `export_all()` must not be run -- it would write the hand-built
level back over it (`export_destructibles()` alone is safe). The preview
takes its frame from the file's `terrain.frame`, since a built ground runs
out to the file's bounds.
Under the water nothing is triangulated -- the shallows show the ground, and
whatever a triangulation fans out there shows as streaks -- so the builder
makes a wall along every shore off the profile's foot table and a flat river
bed that sinks out of sight where it ends at no shore, and stops the build if
a slope face reaches under the water, an open edge of ground lies in it, or
the slope has more specks -- tiny facets turned from their neighbours, which
the two-tone light makes dead pixels -- than the hand-built stage's 14. The
height raster lifts the land, the top of the slope, the brow's line, the
forest and the objects (a hill's steep facets are rock, `Terrain_Hill`), and
a level whose file is not stage 0 is built without stage 1's own pieces --
its collections emptied, its ocean cut to the level's length.
It also turns off Godot's vertex compression in the glb's `.import`
(`jackal_stage1.glb.import` has it off too): compressed, a vertex two
surfaces share is rounded to each surface's own bounds, and the water
shows through the hairline between a light facet and a dark one as a
row of bright pixels at close zoom:

```bash
blender-launcher -b resources/3d/jackal_stage1_lowpoly.blend --python tools/blender/build_level.py -- assets/level3d/stage-0.json --out build/level3d/jackal_stage1_gen.blend --glb build/level3d/jackal_stage1_gen.glb --report build/level3d/report.txt
```

```bash
godot --path . --headless --script tools/level_terrain_from_glb.gd -- --glb res://build/level3d/jackal_stage1_gen.glb --compare
```

```bash
blender-launcher -b build/level3d/jackal_stage1_gen.blend --python tools/blender/render_top.py -- --render build/level3d/top_gen.png 50
```

## The level editor

The level editor is a program of its own, `src/editors/level_editor.tscn`
(`level_editor.gd`; `Level3DGroundView` draws its ground, `LevelEditorItems`
what stands on it): File -> New, Open, Save, and four modes. Ground paints
land, sea, river, forest and the rise of the ground; Nav paints the grid;
Entities and Objects put down, pick, drag, turn and delete from the
catalogue -- a type picked in the list puts one down, and with none picked
a click picks, Shift+click adds, a drag over nothing draws a box, and a
drag on a picked one moves everything picked (`LevelEditorItems` keeps a
list, the last the one the panel shows); Esc empties the list first --
entities snapped to the tiles their footprint covers and a
building given the group its probe cell is in; one the catalogue gives an
object (a gun its Bunker, the landing port its Helipad) comes with it, tied
by the object's `"entity"`, which is how the preview finds another level's
guns -- stage 1's it finds by its bunkers' names. Objects also draws bridges,
a drag from end to end, and walls as paths, a click to a point -- straight
or smooth, open or closed, through gates (`"paths"` in the file, with what
they make, their runs and merlons, kept beside them as the ground's
polygons are, so that the builder builds the curve the editor drew) -- laid
out as stage 1's are (`Level3DStructures`, `src/game3d/world/level3d_structures.gd`);
a picked one has handles on its points, and a bridge's end by its handle
lays its piers out again; a gate put down by a path goes into it, a path
through a gate follows it, and a gate deleted closes the wall; a GATE entity
brings its Gate and the destruction group of its passage, as many gates as
wanted, each with a group of its own and never group 0 (the headquarters
blows `groups[0]` by number, so a level's first gate starts an empty one),
and the preview moves a `jackal_dest_Gate.glb` to each on a level that is
not stage 1. Everything is one undo a
stroke or a move. A save writes the level file, its two rasters and the
polygons traced off them. Stage 1's nav grid is the game's and is painted
as it is; a level made here plays the grid its ground makes (land empty,
forest solid, slope and water water) with what was painted over it,
`nav_paint` in the file, `-` where the ground's stands. Level -> Build runs
the Blender builder in the background into `build/level3d/<name>.glb` and
imports that; Play (F5) saves and builds first when the level is newer
than its glb, then opens the preview on it in a process of its own --
`-- --file <level> --level <glb> --editor`, the last making the Escape
menu's exit "Back to the editor" -- and waits minimised for that process to end,
however it ends, to come back. The preview is not run inside the editor's
process because it keeps state in statics (`Level3DMap.file`, the audio
buses, the tree's pause, the mouse mode). The preview moves the start and the Chinook's landing to the level's
south end and leaves out stage 1's own buildings; Check is
`Level3DIO.check`, and Rebuild flow field writes stage 1's own
`assets/level3d/dirs-0.dat`, which `Level3DMap` prefers to the game's
(another level's is built when the preview loads it). Its check drives it
without anyone at it -- with a window it also writes what it drew to
`build/level_editor/`, and `-- --build` builds through the menu too:

```bash
godot --path . src/editors/level_editor.tscn
```

```bash
godot --path . --windowed --resolution 1600x900 --script tools/verify_level_editor.gd
```

