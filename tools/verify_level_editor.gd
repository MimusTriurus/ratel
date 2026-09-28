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
# - A save writes the level file and both rasters, and reading them back and
#   tracing again gives the same file; the saved level passes Level3DIO.check.
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
		# A level with nobody on it yet: the one thing check has to say.
		var problems := Array(Level3DIO.check(doc, Level3DIO.read_catalog())).filter(
				func(p): return not p.contains("PLAYER/CHINOOK"))
		_expect(problems.is_empty(), "Level3DIO.check finds nothing but the missing player: %s" % [problems])

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

	if shots:
		DirAccess.make_dir_recursive_absolute(shot_dir)
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
