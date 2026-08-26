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
	_check("types edit is reported as stale pathing", editor._dirs_stale)

	# The sentinel water row past the bottom of the map is not authored.
	editor.tool = editor.TOOL_TILES
	editor._begin_stroke()
	editor.brush = 1
	editor._paint_at(Vector2i(5, stage.map_height - 1))
	_check("the water row refuses paint", editor._stroke.is_empty())
	editor._commit_stroke()

	# Triggers: place, drag, delete, undo. The document is the source of truth and
	# stage.trigger_map is rebuilt from it, so both are checked.
	var before_count: int = editor._triggers().size()
	var footprint: Vector2i = editor._footprint(Triggers.BROWN_TANK)
	var grab := Vector2i(footprint.x / 2, footprint.y / 2)
	var drop := Vector2i(30, 200)

	editor.tool = editor.TOOL_TRIGGERS
	editor.current_trigger = Triggers.BROWN_TANK
	editor.hover_tile = drop
	editor._grab_trigger(false)
	editor._release_trigger()
	_check("placing added one trigger", editor._triggers().size() == before_count + 1)

	var placed: Dictionary = editor._triggers().back()
	_check("placed trigger is centred on the cursor",
		int(placed["x"]) == drop.x - grab.x and int(placed["y"]) == drop.y - grab.y)
	_check("placed trigger reached the trigger map",
		_row_holds(stage, drop.y - grab.y + editor.trigger_sizes[Triggers.BROWN_TANK][1] - 1,
			Triggers.BROWN_TANK))

	var moved_to := Vector2i(34, 210)
	editor.selected_trigger = editor._triggers().size() - 1
	editor._drag_before = editor._triggers().duplicate(true)
	editor._drag_grab = grab
	editor._drag_trigger_to(moved_to)
	editor._release_trigger()
	var moved: Dictionary = editor._triggers().back()
	_check("dragging moved it", int(moved["x"]) == moved_to.x - grab.x
		and int(moved["y"]) == moved_to.y - grab.y)

	editor._undo()
	_check("undo put it back",
		int(editor._triggers().back()["x"]) == drop.x - grab.x)
	editor._redo()
	_check("redo moved it again",
		int(editor._triggers().back()["x"]) == moved_to.x - grab.x)

	# A boss trigger a few rows from the top fires before row zero, and MapIO
	# would drop it on load, so placing it has to fail.
	editor.current_trigger = Triggers.BOSS_SHIP
	editor.hover_tile = Vector2i(30, 1)
	var count_before_bad: int = editor._triggers().size()
	editor._grab_trigger(false)
	editor._release_trigger()
	_check("a trigger that cannot fire is refused",
		editor._triggers().size() == count_before_bad)

	editor.selected_trigger = editor._triggers().size() - 1
	editor._delete_trigger()
	_check("delete removed it", editor._triggers().size() == before_count)
	_check("delete cleared the selection", editor.selected_trigger == -1)

	# Put one back so the save has a trigger change in it.
	editor.current_trigger = Triggers.BROWN_TANK
	editor.hover_tile = drop
	editor._grab_trigger(false)
	editor._release_trigger()

	# Groups: membership, the after state, and the check that reads the same cell
	# the game reads.
	var group_count: int = stage.groups.size()
	editor.tool = editor.TOOL_GROUPS
	var first_cell: Array = stage.groups[0][0]
	editor.hover_tile = Vector2i(first_cell[0], first_cell[1])
	editor._click_group(false)
	_check("clicking a group cell selects that group", editor.selected_group == 0)

	var cells_before: int = stage.groups[0].size()
	var fresh := Vector2i(int(first_cell[0]) + 8, int(first_cell[1]))
	editor.hover_tile = fresh
	editor._click_group(false)
	_check("a bare cell joins the selected group",
		stage.groups[0].size() == cells_before + 1)
	_check("groups_map followed the new cell",
		stage.groups_map[fresh.y][fresh.x] == 0 and editor._group_of(fresh) == 0)

	# The after state is painted with the ordinary brushes, retargeted.
	editor.after_preview = true
	editor.tool = editor.TOOL_TILES
	editor.current_tile = 77
	editor.brush = 1
	editor._begin_stroke()
	editor._paint_at(fresh)
	editor._commit_stroke()
	var painted: Array = stage.groups[0][editor._selected_cells[fresh]]
	_check("the brush wrote the group's after tile", painted[2] == 77)
	_check("the map itself was left alone",
		stage.tile_map[fresh.y][fresh.x] != 77)

	editor._undo()
	_check("undo restored the group",
		stage.groups[0][editor._selected_cells[fresh]][2] != 77)
	editor._redo()
	editor.after_preview = false

	editor.tool = editor.TOOL_GROUPS
	editor.hover_tile = fresh
	editor._click_group(true)
	_check("shift-click removes the cell", stage.groups[0].size() == cells_before)
	_check("groups_map forgot it", editor._group_of(fresh) < 0)

	editor._new_group()
	_check("new group appended", stage.groups.size() == group_count + 1)
	_check("new group is selected", editor.selected_group == group_count)
	editor._delete_group()
	_check("delete removed it", stage.groups.size() == group_count)

	editor._select_group(0)
	editor._delete_group()
	_check("group 0 is refused", stage.groups.size() == group_count)

	# editor is typed as Control here, so the return type has to be spelled out.
	var problems: Array = editor._check_stage()
	_check("the check finds nothing wrong with a stage as shipped",
		problems.is_empty())

	# Break the binding the way an edit would, and see it caught.
	var probe_before := _copy_group(stage.groups[0])
	stage.groups[0].clear()
	editor._rebuild_groups_map()
	editor._select_group(0)
	_check("an object whose group lost its cell is reported",
		editor._check_stage().size() > 0)
	stage.groups[0] = probe_before
	editor._rebuild_groups_map()

	# Leave one group edit in place so the save has to carry it.
	editor._select_group(0)
	editor.hover_tile = fresh
	editor._click_group(false)
	stage.groups[0][editor._selected_cells[fresh]][2] = 77
	stage.groups[0][editor._selected_cells[fresh]][3] = MapIO.TYPE_WATER

	editor._save()
	_check("save cleared the dirty flags", not editor._is_dirty())
	# Saving the stage does not fix the flow field: that is a separate file, a
	# separate action, and a much heavier one.
	_check("save left the pathing marked stale", editor._dirs_stale)

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
	_check("triggers came through the save", triggers == 71)
	_check("the placed trigger came back",
		_row_holds(reloaded, drop.y - grab.y + editor.trigger_sizes[Triggers.BROWN_TANK][1] - 1,
			Triggers.BROWN_TANK))

	var reloaded_cell: Array = []
	for entry in reloaded.groups[0]:
		if entry[0] == fresh.x and entry[1] == fresh.y:
			reloaded_cell = entry
	_check("the group cell came back", not reloaded_cell.is_empty())
	_check("with the after state it was given",
		not reloaded_cell.is_empty() and reloaded_cell[2] == 77
		and reloaded_cell[3] == MapIO.TYPE_WATER)
	_check("groups_map was rebuilt from the file",
		reloaded.groups_map[fresh.y][fresh.x] == 0)

	editor.free()

	if failures == 0:
		print("\nall checks passed -- now look at: git diff --stat assets/maps")
	else:
		print("\n%d check(s) failed" % failures)
	quit(1 if failures > 0 else 0)


func _copy_group(group: Array) -> Array:
	var out: Array = []
	for entry in group:
		out.append([entry[0], entry[1], entry[2], entry[3]])
	return out


func _row_holds(stage: Stage, row: int, trigger_index: int) -> bool:
	if row < 0 or row >= stage.trigger_map[0].size():
		return false
	for trigger in stage.trigger_map[0][row]:
		if trigger[0] == trigger_index:
			return true
	return false


func _check(what: String, condition: bool) -> void:
	if condition:
		print("  ok   %s" % what)
	else:
		failures += 1
		print("  FAIL %s" % what)
