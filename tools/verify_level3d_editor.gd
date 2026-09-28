# Drives the level editor's nodes (Level3DEditRoot and the entities and objects
# under it) without the editor, and checks what they would save. Nothing is
# written but the level file, saved once untouched, which must come out as it
# was; every other check reads Level3DEditRoot.to_doc.
#
#     godot --path . --headless --script tools/verify_level3d_editor.gd
#
# - Loaded and saved untouched, the nodes give back the file byte for byte:
#   git diff --exit-code assets/level3d stays clean.
# - A painted stroke changes those cells of those rows and nothing else.
# - An entity dragged off the grid lands on the tile its footprint covers,
#   and the trigger it gives is that tile.
# - A duplicate is given a fresh id, and keeps its place in the order.
# - An object tilted and stretched comes back turned and scaled evenly.
# - The ids a save settles on are unique, and Level3DIO.check finds nothing.
extends SceneTree

var failures := 0


# On the first frame: until the tree runs, nothing added to it is ready and the
# nodes, which build themselves on entering it, have nothing to build from.
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var level := Level3DEditRoot.new()
	level.stage = 0
	root.add_child(level)
	var file := FileAccess.get_file_as_string(Level3DIO.path(0))

	_expect("untouched, the nodes give back the file",
			Level3DIO.serialize(level.to_doc()) == file)
	level.save()
	_expect("and saving them writes it again unchanged",
			FileAccess.get_file_as_string(Level3DIO.path(0)) == file)
	var before := level.to_doc()

	# A stroke: a 3x3 of SHIELD round (20, 100).
	var cells: Array = []
	var types: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			cells.append(Vector2i(20 + dx, 100 + dy))
			types.append(MapIO.TYPE_SHIELD)
	level.set_cells(cells, types)
	var painted := level.to_doc()
	var changed := []
	for y in (before["nav"] as Array).size():
		if painted["nav"][y] != before["nav"][y]:
			changed.append(y)
	_expect("a 3x3 stroke changes rows 99-101 only", changed == [99, 100, 101])
	_expect("and only columns 19-21 of them",
			(painted["nav"][100] as String).substr(19, 3) == "SSS"
			and (painted["nav"][100] as String).left(19) == (before["nav"][100] as String).left(19)
			and (painted["nav"][100] as String).substr(22) == (before["nav"][100] as String).substr(22))

	# Dragging a gun half a tile and a bit off: it snaps to the nearest tile.
	var gun := level.entities.get_node("gray_gun_0") as Level3DEditEntity
	var tile := gun.tile()
	gun.position += Vector3(level.tile_m() * 1.3, 0.2, -level.tile_m() * 0.4)
	var moved := level.to_doc()
	await process_frame
	var sizes := Level3DIO.footprints()
	var got: Dictionary = Level3DIO.triggers_of(moved, "normal", sizes)[0]
	var snapped := Level3DIO.entity_pos(level.grid(), gun.footprint(), tile + Vector2i(1, 0))
	_expect("a dragged gun snaps to the next tile over, in the file and on screen",
			Vector2i(got["x"], got["y"]) == tile + Vector2i(1, 0)
			and gun.position.is_equal_approx(Vector3(snapped.x, 0.0, snapped.y)))

	# A duplicate, as Ctrl+D would make it, right after the original.
	var copy := gun.duplicate() as Level3DEditEntity
	level.entities.add_child(copy)
	level.entities.move_child(copy, gun.get_index() + 1)
	var with_copy := level.to_doc()
	var ids := {}
	var unique := true
	for e in with_copy["entities"]:
		unique = unique and not ids.has(e["id"])
		ids[e["id"]] = true
	_expect("a duplicate gets its own id", unique
			and with_copy["entities"][1]["type"] == "GRAY_GUN"
			and with_copy["entities"][1]["id"] != "gray_gun_0")
	_expect("and draws one box and one label, not the original's as well",
			copy.get_child_count(true) == 2)

	# An object tilted and stretched by the gizmo.
	var palm := level.objects.get_child(20) as Level3DEditObject
	palm.rotation_degrees = Vector3(10, 30, 5)
	palm.scale = Vector3(1.2, 2.0, 0.7)
	await process_frame
	var object: Dictionary = level.to_doc()["objects"][20]
	_expect("a tilted palm comes back turned only, and scaled evenly",
			absf(float(object["yaw"]) - 30.0) < 0.01 and absf(float(object["scale"]) - 1.2) < 0.001
			and is_zero_approx(palm.rotation.x) and is_zero_approx(palm.rotation.z))

	# One point of a shore moved: one line of the file.
	var land := level.ground.get_node("land_0") as Level3DEditShape
	var outer := land.get_node("outer") as Path3D
	var before_text := Level3DIO.serialize(level.to_doc())
	var point := outer.curve.get_point_position(100)
	outer.curve.set_point_position(100, point + Vector3(0.25, 0.4, -0.1))
	var after_text := Level3DIO.serialize(level.to_doc())
	var a := before_text.split("\n")
	var b := after_text.split("\n")
	var lines := 0
	for k in mini(a.size(), b.size()):
		if a[k] != b[k]:
			lines += 1
	_expect("a shore point moved changes one line of the file (%d)" % lines,
			a.size() == b.size() and lines == 1)
	_expect("and stays flat on the ground",
			is_equal_approx(outer.curve.get_point_position(100).y, Level3DEditShape.LIFT))

	# The ground drawn from the file.
	var started := Time.get_ticks_msec()
	level.backdrop = "file"
	var proxy := level.find_child("GroundProxy", true, false)
	var trees := 0
	if proxy:
		for multi in proxy.find_children("*", "MultiMeshInstance3D", true, false):
			trees += (multi as MultiMeshInstance3D).multimesh.instance_count
	_expect("the file's ground builds, %d trees, in %d ms"
			% [trees, Time.get_ticks_msec() - started], proxy != null and trees > 1000)

	var problems := Level3DIO.check(with_copy, level.catalog)
	_expect("Level3DIO.check finds nothing in the edited level (%d)" % problems.size(),
			problems.is_empty())
	for problem in problems:
		print("       ", problem)

	print("\n%s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	level.free()
	quit(0 if failures == 0 else 1)


func _expect(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1
