# Checks the 3D level files, assets/level3d/stage-N.json, against the stage
# maps they were made from and against the catalogue.
#
#     godot --path . --headless --script tools/verify_level3d.gd
#
# - The file round-trips: Level3DIO.serialize writes back exactly what was
#   read, so saving an unedited level leaves no diff.
# - The gameplay grid is the game's: the nav rows are stage-N.json's types,
#   the groups its groups, and each difficulty's triggers, picked out of the
#   entities, are its trigger list in order. A Stage filled from the level is
#   the Stage MapIO fills.
# - The grid block is Level3DMap's transform, which the preview converts by.
# - The ground polygons are the rasters' (Level3DGround): traced again off
#   the PNGs the file names, they come out exactly as the file has them, so
#   nobody has edited the one without the other.
# - Level3DIO.check finds nothing: the map editor's Check stage and the
#   references -- ids unique, every type a trigger in the catalogue, every
#   asset in the catalogue, every "entity" an entity, every group the one the
#   game would probe for.
#
# The first can only fail by a bug in Level3DIO. The second
# says how far a level has moved from the 2D stage -- which is allowed, and
# will then be reported rather than failed.
extends SceneTree

var failures := 0


func _init() -> void:
	var catalog := Level3DIO.read_catalog()
	for problem in Level3DIO.check_catalog(catalog):
		_fail(problem)
	var sizes := Level3DIO.footprints()
	for index in 6:
		if not FileAccess.file_exists(Level3DIO.path(index)):
			continue
		print("stage %d" % index)
		var doc := Level3DIO.read(index)
		if doc.is_empty():
			_fail("  cannot read %s" % Level3DIO.path(index))
			continue
		_check_round_trip(index, doc)
		_check_rasters(doc)
		if index == Level3DMap.STAGE:
			_check_preview_grid(doc)
		_check_against_map(index, doc, sizes)
		_check_references(doc, catalog)
	print("\n%s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)


func _fail(message: String) -> void:
	failures += 1
	print(message)


func _check_round_trip(index: int, doc: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(Level3DIO.path(index))
	var written := Level3DIO.serialize(doc)
	if written == text:
		print("  round trip: ok")
		return
	var a := text.split("\n")
	var b := written.split("\n")
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			_fail("  round trip: line %d differs\n    file:    %s\n    written: %s"
					% [i + 1, a[i], b[i]])
			return
	_fail("  round trip: %d lines read, %d written" % [a.size(), b.size()])


func _check_rasters(doc: Dictionary) -> void:
	if not doc.get("terrain", {}).has("raster"):
		print("  rasters: none, the polygons are the source")
		return
	var ground := Level3DGround.load_for(doc, Level3DIO.DIR)
	if ground == null:
		_fail("  rasters: cannot read %s" % doc["terrain"]["raster"])
		return
	var traced := doc.duplicate(true)
	ground.trace(traced)
	if Level3DIO.serialize(traced) == Level3DIO.serialize(doc):
		print("  rasters: %dx%d at %.2f m, trace to the file's polygons" % [ground.grid.w, ground.grid.h, ground.grid.r])
	else:
		_fail("  rasters: traced again, they are not the file's polygons -- one was edited without the other")


# The preview converts with Level3DMap's constants, not the file's grid, so the
# two must agree until it reads the grid too.
func _check_preview_grid(doc: Dictionary) -> void:
	var grid: Dictionary = doc["grid"]
	var origin := Vector2(float(grid["origin"][0]), float(grid["origin"][1]))
	if not is_equal_approx(float(grid["m_per_px"]), Level3DMap.PX) 			or not origin.is_equal_approx(Level3DMap.ORIGIN):
		_fail("  grid is not Level3DMap's: %s, %s against %s, %s"
				% [grid["m_per_px"], origin, Level3DMap.PX, Level3DMap.ORIGIN])


func _check_against_map(index: int, doc: Dictionary, sizes: Dictionary) -> void:
	var source := MapIO.read_document(index)
	if doc["nav"] != source["types"]:
		_fail("  nav differs from stage-%d.json types" % index)
	var groups: Array = source["groups"]
	var level_groups: Array = doc["groups"]
	if groups.size() != level_groups.size():
		_fail("  %d groups, stage-%d.json has %d" % [level_groups.size(), index, groups.size()])
	else:
		for i in groups.size():
			var cells: Array = []
			for cell in groups[i]["cells"]:
				cells.append([cell[0], cell[1], cell[3]])
			if cells != level_groups[i]["cells"]:
				_fail("  group %d differs from stage-%d.json" % [i, index])

	for d in Level3DIO.DIFFICULTIES:
		var expected: Array = source["triggers"][d]
		var got := Level3DIO.triggers_of(doc, d, sizes)
		var same := expected.size() == got.size()
		for i in mini(expected.size(), got.size()):
			var e: Dictionary = expected[i]
			var g: Dictionary = got[i]
			if e["type"] != g["type"] or int(e["x"]) != g["x"] or int(e["y"]) != g["y"]:
				_fail("  %s trigger %d: stage has %s, level gives %s" % [d, i, e, g])
				same = false
				break
		if same:
			print("  %s triggers: %d, in order" % [d, got.size()])
		elif expected.size() != got.size():
			_fail("  %s triggers: stage has %d, level gives %d" % [d, expected.size(), got.size()])

	var trigger_sizes := MapIO.load_trigger_sizes()
	var from_map := Stage.new()
	MapIO.load_stage(index, from_map, trigger_sizes)
	var from_level := Stage.new()
	Level3DIO.load_stage(doc, from_level, trigger_sizes)
	for field in ["map_width", "map_height", "types_map", "groups_map", "trigger_map"]:
		if from_map.get(field) != from_level.get(field):
			_fail("  Stage.%s differs" % field)
	var group_types := func(stage: Stage) -> Array:
		var out: Array = []
		for group in stage.groups:
			for g in group:
				out.append([g[0], g[1], g[3]])
		return out
	if group_types.call(from_map) != group_types.call(from_level):
		_fail("  Stage.groups differs")


func _check_references(doc: Dictionary, catalog: Dictionary) -> void:
	var problems := Level3DIO.check(doc, catalog)
	for problem in problems:
		_fail("  " + problem)
	print("  Level3DIO.check: %d entities, %d objects, %d problems"
			% [(doc["entities"] as Array).size(), (doc["objects"] as Array).size(), problems.size()])
