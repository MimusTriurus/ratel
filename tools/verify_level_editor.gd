# Drives the level editor (src/tools/level_editor.tscn) without anyone at it:
# a new level, a stroke of every brush, undo and redo, a save, and the file
# read back.
#
#     godot --path . --headless --script tools/verify_level_editor.gd
#
# With a window instead of --headless it also writes what it drew, top down
# and tilted, to build/level_editor/ (-- --shots <dir> to put them elsewhere).
# -- --build also builds the level through the menu's Build, Blender and the
# import, into build/level3d/_verify_build.glb.
#
# - Undo puts back exactly what a stroke painted over, and redo exactly what
#   it painted.
# - The brushes do what they say: land is land, the sea cuts a shore round
#   itself, the forest keeps to land, raise lifts the middle of the brush and
#   not its rim.
# - Entities and objects: one put down lands where it is snapped to and is
#   picked, a drag moves it, undo takes it away and redo brings it back; a
#   gun comes with its bunker, which moves and goes with it; an object turns,
#   scales and is deleted, and undo puts it back.
# - Walls and bridges: a drag draws one, laid out as stage 1's are, and
#   dragging it moves it whole; delete and undo; a wall makes its tiles solid
#   and a bridge its deck empty in a grid from the ground. A gate comes with
#   its Gate and a destruction group of the middle of its footprint, which
#   moves with it.
# - The nav grid: on a new level painting keeps a tile over the ground's and
#   Auto gives it back; on stage 1 it paints the grid itself, and undo puts
#   the row back.
# - A save writes the level file and both rasters, and reading them back and
#   tracing again gives the same file; the saved level passes Level3DIO.check
#   -- a new level comes with the Chinook it needs.
extends SceneTree

const DIR := "res://build/level_editor/"
const T := Level3DGround.Tool

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var editor: Node3D = (load("res://src/tools/level_editor.tscn") as PackedScene).instantiate()
	root.add_child(editor)
	await process_frame
	var shots := DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	var shot_dir := args[args.find("--shots") + 1] if args.has("--shots") else DIR
	DirAccess.make_dir_recursive_absolute(DIR)

	editor._new_level("verify", 120, 1)
	var ground: Level3DGround = editor.ground
	var origin := Level3DMap.ORIGIN
	print("new level: %d x %d cells, bounds %s" % [ground.grid.w, ground.grid.h, ground.bounds()])
	_expect(ground.bits_at(Vector2(origin.x - 6.0, origin.y + 20.0)) & Level3DGround.WATER != 0,
			"the sea lies west of the map")
	_expect(ground.bits_at(Vector2(origin.x + 10.0, origin.y + 20.0)) == Level3DGround.LAND,
			"the map is land")

	# A bay cut into the land, and its shore.
	var before := ground.ground.duplicate()
	var bay := Vector2(origin.x + 8.0, origin.y + 30.0)
	_stroke(editor, T.SEA, [bay, bay + Vector2(4.0, 0.0)], 2.0)
	_expect(ground.bits_at(bay) == Level3DGround.WATER, "the sea brush makes sea")
	_expect(ground.bits_at(bay + Vector2(0.0, 2.0 + 0.4)) == 0,
			"a shore of slope round the sea it painted")
	_expect(ground.bits_at(bay + Vector2(0.0, 2.0 + editor.shore + 0.3)) == Level3DGround.LAND,
			"land past the shore")
	var after := ground.ground.duplicate()
	editor._undo_step(editor._undo, editor._redo)
	_expect(ground.ground == before, "undo puts back what the stroke painted over")
	editor._undo_step(editor._redo, editor._undo)
	_expect(ground.ground == after, "redo puts back what it painted")

	# A river, an island of land in the bay, forest, a hill.
	var river_from := Vector2(origin.x + 20.0, origin.y + 5.0)
	_stroke(editor, T.RIVER, [river_from, river_from + Vector2(-6.0, 15.0), bay + Vector2(4.0, 0.0)], 1.2)
	_expect(ground.bits_at(river_from + Vector2(-3.0, 7.5)) & Level3DGround.RIVER != 0, "the river brush makes river")
	_stroke(editor, T.LAND, [bay + Vector2(1.5, 0.0)], 0.7)
	_expect(ground.bits_at(bay + Vector2(1.5, 0.0)) == Level3DGround.LAND, "the land brush makes land in water")
	var wood := Vector2(origin.x + 6.0, origin.y + 45.0)
	_stroke(editor, T.FOREST, [wood, wood + Vector2(8.0, 3.0)], 3.0)
	_expect(ground.bits_at(wood) == Level3DGround.LAND | Level3DGround.FOREST, "the forest brush plants land")
	_stroke(editor, T.FOREST, [bay], 1.0)
	_expect(ground.bits_at(bay) & Level3DGround.FOREST == 0, "no forest on the water")
	var hill := Vector2(origin.x + 22.0, origin.y + 40.0)
	editor.strength = 0.3
	for k in 8:
		_stroke(editor, T.RAISE, [hill], 3.0)
	var top := ground.rise_at(hill)
	var rim := ground.rise_at(hill + Vector2(2.9, 0.0))
	print("hill: %.2f m at the middle, %.3f at the rim" % [top, rim])
	_expect(top > 2.0 and rim < 0.05, "raise lifts the middle and not the rim")
	_stroke(editor, T.SMOOTH, [hill], 3.0)
	_expect(ground.rise_at(hill) < top, "smooth takes the top down")
	editor.view.refresh(Rect2i(0, 0, ground.grid.w, ground.grid.h))
	_expect(absf(editor.view.height_at(hill) - ground.rise_at(hill)) < 0.3,
			"the picture stands the hill where the rise is")

	# Entities.
	var M = editor.Mode
	editor._set_mode(M.ENTITIES)
	_expect(editor.doc["entities"].size() == 1 and editor.doc["entities"][0]["type"] == "CHINOOK",
			"a new level has its Chinook")
	editor._entity_list.select(editor._entity_types.find("SOLDIER_WALKER"))
	var spot := Vector2(origin.x + 12.03, origin.y + 50.02)
	editor._press(spot)
	editor._release()
	var walker: Dictionary = editor.doc["entities"][-1]
	var snapped: Vector2 = editor.items.snap_entity("SOLDIER_WALKER", spot)
	_expect(walker["type"] == "SOLDIER_WALKER" and Vector2(walker["pos"][0], walker["pos"][1]) == snapped
			and editor.items.selected() == walker["id"], "a click puts an entity down, snapped, and picks it")
	var tile_m: float = editor.items.tile_m()
	editor._press(Vector2(walker["pos"][0], walker["pos"][1]))
	editor._move(Vector2(walker["pos"][0], walker["pos"][1]) + Vector2(tile_m * 3.0, -tile_m * 2.0))
	editor._release()
	var moved: Dictionary = editor.items.find_entity(walker["id"])
	var by := Vector2(float(moved["pos"][0]) - snapped.x, float(moved["pos"][1]) - snapped.y) / tile_m
	print("  dragged by %.4f, %.4f tiles" % [by.x, by.y])
	_expect(by.distance_to(Vector2(3.0, -2.0)) < 0.01, "a drag moves it by whole tiles")
	var count: int = editor.doc["entities"].size()
	editor._undo_step(editor._undo, editor._redo)
	_expect(Vector2(editor.items.find_entity(walker["id"])["pos"][0], editor.items.find_entity(walker["id"])["pos"][1]) == snapped,
			"undo moves it back")
	editor._undo_step(editor._undo, editor._redo)
	_expect(editor.doc["entities"].size() == count - 1, "undo again takes it away")
	editor._redo_step()
	editor._redo_step()
	_expect(editor.doc["entities"].size() == count and not editor.items.find_entity(walker["id"]).is_empty(),
			"redo brings both back")
	editor._press(spot + Vector2(10.0, 0.0))
	editor._release()
	var picked: String = editor.items.selected()
	editor._delete_selected()
	_expect(editor.items.find_entity(picked).is_empty(), "Delete removes the picked one")

	# A gun comes with its bunker, which goes where it goes and with it.
	editor._entity_list.select(editor._entity_types.find("GRAY_GUN"))
	var gun_at := Vector2(origin.x + 20.0, origin.y + 55.0)
	var objects_before: int = editor.doc["objects"].size()
	editor._press(gun_at)
	editor._release()
	var gun: Dictionary = editor.doc["entities"][-1]
	var bunkers: Array = editor._belonging_to(gun["id"])
	_expect(bunkers.size() == 1 and bunkers[0]["asset"] == "Bunker"
			and is_equal_approx(float(bunkers[0]["pos"][0]), float(gun["pos"][0])), "a gun is put down on a bunker of its own")
	editor._press(Vector2(gun["pos"][0], gun["pos"][1]))
	editor._move(Vector2(gun["pos"][0], gun["pos"][1]) + Vector2(tile_m * 4.0, 0.0))
	editor._release()
	gun = editor.items.find_entity(gun["id"])
	bunkers = editor._belonging_to(gun["id"])
	_expect(absf(float(bunkers[0]["pos"][0]) - float(gun["pos"][0])) < 0.002, "the bunker moves with its gun")
	editor.items.select(gun["id"])
	editor._delete_selected()
	_expect(editor.doc["objects"].size() == objects_before and editor.items.find_entity(gun["id"]).is_empty(),
			"deleting the gun takes its bunker too")
	editor._undo_step(editor._undo, editor._redo)
	_expect(editor._belonging_to(gun["id"]).size() == 1 and not editor.items.find_entity(gun["id"]).is_empty(),
			"and undo brings both back")
	count = editor.doc["entities"].size()

	# Objects.
	editor._set_mode(M.OBJECTS)
	editor._asset_list.select(editor._assets.find("Palm_1"))
	var palm_at := Vector2(origin.x + 4.0, origin.y + 20.0)
	editor._press(palm_at)
	editor._release()
	var palm: Dictionary = editor.doc["objects"][-1]
	_expect(palm["asset"] == "Palm_1" and is_equal_approx(float(palm["pos"][0]), palm_at.x), "a click puts an object down")
	_expect(editor.items._templates.get("Palm_1") != null, "it is drawn as the stage's glb draws it")
	editor._turn_selected(15.0)
	editor._scale_selected(1.1)
	palm = editor.items.find_object(palm["id"])
	_expect(is_equal_approx(float(palm["yaw"]), 15.0) and is_equal_approx(float(palm["scale"]), 1.1),
			"R turns it and ] scales it")
	var objects: int = editor.doc["objects"].size()
	editor._delete_selected()
	editor._undo_step(editor._undo, editor._redo)
	_expect(editor.doc["objects"].size() == objects and not editor.items.find_object(palm["id"]).is_empty(),
			"undo brings a deleted object back")

	# Walls, a bridge, a gate.
	var B = editor.Build
	editor.build = B.WALL
	var w0 := Vector2(origin.x + 2.0, origin.y + 8.0)
	editor._press(w0)
	editor._move(w0 + Vector2(8.0, 0.3))
	editor._release()
	var wall: Dictionary = editor.doc["walls"][-1]
	_expect(wall["style"] == "wall" and is_equal_approx(Level3DStructures.length_of(wall), 8.0)
			and float(wall["from"][1]) == float(wall["to"][1]), "a drag draws a wall, held to the level")
	_expect(int(wall["merlons"]["count"]) == 8, "with 8 merlons on 8 m, as stage 1 lays them (%d)" % int(wall["merlons"]["count"]))
	editor.build = B.SIDE
	editor._press(w0)
	editor._move(w0 + Vector2(0.0, 6.0))
	editor._release()
	_expect(editor.doc["walls"][-1]["style"] == "side" and not editor.doc["walls"][-1].has("merlons"), "a side wall, no merlons")
	editor.build = B.PLACE
	var middle := w0 + Vector2(4.0, 0.0)
	var from_x := float(wall["from"][0])
	editor._press(middle)
	editor._move(middle + Vector2(1.0, 0.0))
	editor._release()
	wall = editor.items.find_structure(wall["id"])
	_expect(absf(float(wall["from"][0]) - from_x - 1.0) < 0.001 and is_equal_approx(Level3DStructures.length_of(wall), 8.0),
			"a picked wall is dragged whole")
	editor.build = B.BRIDGE
	var b0 := Vector2(origin.x + 14.5, origin.y + 11.0)
	editor._press(b0)
	editor._move(b0 + Vector2(5.0, 1.0))
	editor._release()
	var bridge: Dictionary = editor.doc["bridges"][-1]
	_expect(bridge["piers"].size() >= 1 and int(bridge["plates"]["count"]) == 5, "a bridge, its piers and plates laid (%s, %d)"
			% [bridge["piers"], int(bridge["plates"]["count"])])
	editor.build = B.PLACE
	var nav: Array = editor._nav_rows()
	var wall_tile: Vector2i = editor.items.tile_at(middle + Vector2(1.0, 0.0))
	var river_tile: Vector2i = editor.items.tile_at(Vector2(origin.x + 17.6, origin.y + 11.0))
	_expect(nav[wall_tile.y][wall_tile.x] == "#", "the wall's tiles are solid")
	_expect(nav[river_tile.y][river_tile.x] == ".", "the bridge's deck is empty over the river")
	editor.items.select(bridge["id"])
	editor._delete_selected()
	_expect(editor.doc["bridges"].is_empty(), "Delete removes the bridge")
	editor._undo_step(editor._undo, editor._redo)
	_expect(editor.doc["bridges"].size() == 1, "and undo brings it back")
	editor._set_mode(M.ENTITIES)
	editor._entity_list.select(editor._entity_types.find("GATE"))
	var gate_at := Vector2(origin.x + 6.0, origin.y + 16.0)
	editor._press(gate_at)
	editor._release()
	var gate: Dictionary = editor.doc["entities"][-1]
	var gate_objects: Array = editor._belonging_to(gate["id"])
	var group: Array = editor.doc["groups"].filter(func(g): return int(g["index"]) == int(gate.get("group", -1)))
	_expect(gate_objects.size() == 1 and gate_objects[0]["asset"] == "Gate", "a gate comes with its Gate")
	_expect(group.size() == 1 and group[0]["cells"].size() == 16, "and a group of the 16 cells it opens")
	var first_cell: Array = group[0]["cells"][0]
	editor._press(Vector2(gate["pos"][0], gate["pos"][1]))
	editor._move(Vector2(gate["pos"][0], gate["pos"][1]) + Vector2(tile_m * 3.0, 0.0))
	editor._release()
	group = editor.doc["groups"].filter(func(g): return int(g["index"]) == int(gate["group"]))
	_expect(int(group[0]["cells"][0][0]) == int(first_cell[0]) + 3, "which moves with it")
	var gate_tile: Vector2i = editor.items.entity_tile(editor.items.find_entity(gate["id"]))
	_expect(editor._nav_rows()[gate_tile.y + 1][gate_tile.x + 2] == "#", "the gate is solid until it is blown")
	editor._set_mode(M.OBJECTS)

	# The nav grid, over the ground.
	editor._set_mode(M.NAV)
	var land_tile: Vector2i = editor.items.tile_at(palm_at + Vector2(2.0, 3.0))
	var land_p := palm_at + Vector2(2.0, 3.0)
	_expect(editor._nav_rows()[land_tile.y][land_tile.x] == ".", "land is empty in the ground's grid")
	editor._set_nav_type(MapIO.TYPE_SOLID)
	editor.nav_brush = 1
	editor._press(land_p)
	editor._release()
	_expect(editor.doc["nav_paint"][land_tile.y][land_tile.x] == "#" and editor._nav_rows()[land_tile.y][land_tile.x] == "#",
			"painting keeps a tile over the ground's")
	editor._set_nav_type(editor.NAV_AUTO)
	editor._press(land_p)
	editor._release()
	_expect(editor._nav_rows()[land_tile.y][land_tile.x] == ".", "Auto gives it back to the ground")
	editor._set_nav_type(MapIO.TYPE_SWAMP)
	editor._press(land_p)
	editor._release()
	editor._set_mode(M.GROUND)

	var file := DIR + "verify.json"
	await editor._save_to(file)
	var doc := Level3DIO.read_path(file)
	_expect(not doc.is_empty(), "the level file reads back")
	if not doc.is_empty():
		print("saved: %d land, %d water, %d forest polygons" % [doc["terrain"]["land"].size(),
				doc["water"].size(), doc["forest"].size()])
		var kinds := {}
		for polygon in doc["water"]:
			kinds[polygon["kind"]] = true
		_expect(kinds.has("sea") and kinds.has("river"), "sea and river both traced")
		_expect(doc["forest"].size() >= 1, "the forest traced")
		var back := Level3DGround.load_for(doc, DIR)
		_expect(back != null and back.ground == ground.ground, "the ground raster reads back as painted")
		var steps_ok := back != null
		if back:
			for k in back.rise.size():
				if absf(back.rise[k] - ground.rise[k]) > Level3DGround.RISE_STEP * 0.5 + 1e-4:
					steps_ok = false
					break
		_expect(steps_ok, "the rise reads back to within half a step")
		if back:
			var traced := doc.duplicate(true)
			back.trace(traced)
			_expect(Level3DIO.serialize(traced) == Level3DIO.serialize(doc), "traced again, the same file")
		_expect(doc["nav"][land_tile.y][land_tile.x] == "%", "the saved grid has the tile painted over the ground's")
		_expect(doc["entities"].size() == count + 1 and doc["objects"].size() == objects + 1, "the entities and objects saved")
		_expect(doc["walls"].size() == 2 and doc["bridges"].size() == 1, "the walls and the bridge saved")
		var problems := Level3DIO.check(doc, Level3DIO.read_catalog())
		_expect(problems.is_empty(), "Level3DIO.check finds nothing: %s" % [problems])

	# -- --build: Level -> Build, Blender and the import, as the menu runs them.
	if args.has("--build"):
		editor.path = "res://assets/level3d/_verify_build.json"
		await editor._save_to(editor.path)
		var started := Time.get_ticks_msec()
		editor._build()
		while not editor._job.is_empty() and Time.get_ticks_msec() - started < 300000:
			await process_frame
		print("  built in %.1f s: %s" % [(Time.get_ticks_msec() - started) / 1000.0, editor._footer.text])
		_expect(ResourceLoader.exists(editor._built_glb()), "the build made %s, imported" % editor._built_glb())
		for f in ["_verify_build.json", "rasters/_verify_build-ground.png", "rasters/_verify_build-height.png"]:
			DirAccess.remove_absolute("res://assets/level3d/" + f)

	# Stage 1's own grid, painted and undone, not saved.
	editor._open(Level3DIO.path(0))
	editor._set_mode(M.NAV)
	var stage_p := Vector2(0.0, -60.0)
	var stage_tile: Vector2i = editor.items.tile_at(stage_p)
	var row_before: String = editor.doc["nav"][stage_tile.y]
	editor._set_nav_type(MapIO.TYPE_SHIELD)
	editor._press(stage_p)
	editor._release()
	_expect(editor.doc["nav"][stage_tile.y][stage_tile.x] == "S" and not editor.doc.has("nav_paint"),
			"on stage 1 the brush paints the grid itself")
	editor._undo_step(editor._undo, editor._redo)
	_expect(editor.doc["nav"][stage_tile.y] == row_before, "and undo puts the row back")
	_expect(editor.doc["entities"].size() == 120 and editor.doc["objects"].size() == 727
			and editor.doc["walls"].size() == 10 and editor.doc["bridges"].size() == 1,
			"stage 1 opens with its 120 entities, 727 objects, 10 walls and its bridge")
	editor.dirty = false

	if shots:
		DirAccess.make_dir_recursive_absolute(shot_dir)
		editor._set_mode(M.ENTITIES)
		editor.items.select("gray_gun_13")
		editor._focus = Vector2(-5.0, -20.0)
		editor._distance = 18.0
		editor._pitch = 60.0
		editor._yaw = 0.0
		editor._place_camera()
		await _shot(shot_dir.path_join("editor_stage_items.png"))
		editor._set_mode(M.NAV)
		await _shot(shot_dir.path_join("editor_stage_nav.png"))
		editor._open(DIR + "verify.json")
		editor._frame_level()
		await _shot(shot_dir.path_join("editor_top.png"))
		editor._focus = bay + Vector2(4.0, 6.0)
		editor._distance = 30.0
		editor._pitch = 50.0
		editor._yaw = 20.0
		editor._place_camera()
		await _shot(shot_dir.path_join("editor_tilt.png"))

	print("\n%s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)


func _stroke(editor: Node, tool: Level3DGround.Tool, points: Array, radius: float) -> void:
	editor.tool = tool
	editor.radius = radius
	editor._begin_stroke(points[0])
	for p in points.slice(1):
		editor._stroke_to(p)
	editor._end_stroke()


func _shot(file: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(file)
	print("  %s %s" % [file, "written" if error == OK else "FAILED"])


func _expect(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		failures += 1
		print("  FAIL  " + what)
