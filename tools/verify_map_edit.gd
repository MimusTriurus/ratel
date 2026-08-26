# Drives the editor's painting, undo and save without a window.
#
#     godot --path . --headless --script tools/verify_map_edit.gd
#     git diff --stat assets/maps          # one line per painted row, no more
#     git checkout -- assets/maps          # put the stage back
#
# The editor script is a Control, but nothing on the editing path needs a tree:
# it paints into the Stage arrays, and the sidebar getters all guard on null. So
# this instantiates the script alone and calls the same methods the mouse does.
#
# It leaves stage-0.json modified on purpose -- the diff is half the point.
extends SceneTree

var failures := 0


func _init() -> void:
	var editor: Control = load("res://src/tools/map_editor.gd").new()
	editor.trigger_sizes = MapIO.load_trigger_sizes()
	editor._load_trigger_meta()
	editor._load_stage(0)

	var stage: Stage = editor.stage
	var cell := Vector2i(10, 100)
	var original_tile: int = stage.tile_map[cell.y][cell.x]
	var original_type: int = stage.types_map[cell.y][cell.x]

	# One freehand stroke with a 3x3 brush.
	editor.tool = editor.TOOL_TILES
	editor.current_tile = 42
	editor.brush = 3
	editor._begin_stroke()
	editor._paint_at(cell)
	editor._commit_stroke()

	_check("brush painted the centre", stage.tile_map[cell.y][cell.x] == 42)
	_check("brush painted the corner", stage.tile_map[cell.y - 1][cell.x - 1] == 42)
	_check("brush stopped at 3x3", stage.tile_map[cell.y - 2][cell.x] != 42
		or original_tile == 42)
	_check("stroke marked the stage dirty", editor._is_dirty())

	editor._undo()
	_check("undo restored the tile", stage.tile_map[cell.y][cell.x] == original_tile)
	editor._redo()
	_check("redo painted it again", stage.tile_map[cell.y][cell.x] == 42)

	# A rectangle of collision types, the way Shift+drag applies it.
	editor.tool = editor.TOOL_TYPES
	editor.current_type = MapIO.TYPE_SWAMP
	editor._rect_anchor = Vector2i(20, 120)
	editor.hover_tile = Vector2i(23, 122)
	editor._fill_rect()
	editor._commit_stroke()
	_check("rect filled its corner", stage.types_map[122][23] == MapIO.TYPE_SWAMP)
	_check("rect filled its far corner", stage.types_map[120][20] == MapIO.TYPE_SWAMP)
	_check("rect left the neighbour alone",
		stage.types_map[120][19] != MapIO.TYPE_SWAMP or original_type == MapIO.TYPE_SWAMP)
	_check("types edit is reported as stale pathing", editor._dirty["types"])

	# The sentinel water row past the bottom of the map is not authored.
	editor.tool = editor.TOOL_TILES
	editor._begin_stroke()
	editor.brush = 1
	editor._paint_at(Vector2i(5, stage.map_height - 1))
	_check("the water row refuses paint", editor._stroke.is_empty())
	editor._commit_stroke()

	editor._save()
	_check("save cleared the dirty flags", not editor._is_dirty())

	# Read it back through the loader the game uses.
	var reloaded := Stage.new()
	MapIO.load_stage(0, reloaded, editor.trigger_sizes)
	_check("saved tile survives a reload", reloaded.tile_map[cell.y][cell.x] == 42)
	_check("saved type survives a reload",
		reloaded.types_map[122][23] == MapIO.TYPE_SWAMP)
	_check("the rest of the map is untouched",
		reloaded.tile_map[0][0] == stage.tile_map[0][0]
		and reloaded.groups.size() == stage.groups.size())

	var triggers := 0
	for row in reloaded.trigger_map[0]:
		triggers += row.size()
	_check("triggers came through the save", triggers == 70)

	editor.free()

	if failures == 0:
		print("\nall checks passed -- now look at: git diff --stat assets/maps")
	else:
		print("\n%d check(s) failed" % failures)
	quit(1 if failures > 0 else 0)


func _check(what: String, condition: bool) -> void:
	if condition:
		print("  ok   %s" % what)
	else:
		failures += 1
		print("  FAIL %s" % what)
