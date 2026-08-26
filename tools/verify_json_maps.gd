# Proves assets/maps/stage-N.json carries everything the .dat maps carried.
#
# Loads every stage twice -- once through the original binary readers, once
# through MapIO's JSON reader -- and compares the two Stage objects field by
# field.
#
#     godot --path . --headless --script tools/verify_json_maps.gd
#
# tools/map_json.py verify checks the other direction (JSON re-encoded to the
# binary layout, byte for byte). Between them the conversion is covered from
# both ends.
#
# The binary readers live here rather than in Main because the game no longer
# has any: they were lifted verbatim out of main.gd when the maps moved to
# JSON, and they are only of interest to this proof. The .dat maps went with
# them, so restore those before running -- as with tools/sprite_verify.py:
#
#     git checkout <ref-before-the-json-migration> -- assets/maps
extends SceneTree

const MAPS := "res://assets/maps/"

var failures := 0


func _init() -> void:
	var legacy_sizes := _legacy_sizes()
	var sizes := MapIO.load_trigger_sizes()
	_check("trigger sizes", _compare_nested(legacy_sizes, sizes, "sizes"))

	for index in 6:
		var from_dat := Stage.new()
		_legacy_maps(index, from_dat)
		_legacy_types(index, from_dat)
		_legacy_trigger_map(from_dat.map_height, legacy_sizes, index,
			from_dat, false)
		_legacy_trigger_map(from_dat.map_height, legacy_sizes, index,
			from_dat, true)

		var from_json := Stage.new()
		MapIO.load_stage(index, from_json, sizes)

		_check("stage %d width" % index,
			_compare_value(from_dat.map_width, from_json.map_width))
		_check("stage %d height" % index,
			_compare_value(from_dat.map_height, from_json.map_height))
		_check("stage %d tile_map" % index,
			_compare_rows(from_dat.tile_map, from_json.tile_map))
		_check("stage %d types_map" % index,
			_compare_rows(from_dat.types_map, from_json.types_map))
		_check("stage %d groups_map" % index,
			_compare_rows(from_dat.groups_map, from_json.groups_map))
		_check("stage %d groups" % index,
			_compare_nested(from_dat.groups, from_json.groups, "group"))
		_check("stage %d triggers (normal)" % index,
			_compare_nested(from_dat.trigger_map[0], from_json.trigger_map[0], "row"))
		_check("stage %d triggers (hard)" % index,
			_compare_nested(from_dat.trigger_map[1], from_json.trigger_map[1], "row"))

	if failures == 0:
		print("\nall stages match")
	else:
		print("\n%d check(s) failed" % failures)
	quit(1 if failures > 0 else 0)


# Each _compare_* returns "" when equal, or a description of the first
# difference found.

func _compare_value(a: Variant, b: Variant) -> String:
	return "" if a == b else "%s vs %s" % [a, b]


func _compare_rows(a: Array, b: Array) -> String:
	if a.size() != b.size():
		return "%d rows vs %d rows" % [a.size(), b.size()]
	for y in a.size():
		var ra: Variant = a[y]
		var rb: Variant = b[y]
		if ra.size() != rb.size():
			return "row %d: %d wide vs %d wide" % [y, ra.size(), rb.size()]
		for x in ra.size():
			if ra[x] != rb[x]:
				return "row %d column %d: %s vs %s" % [y, x, ra[x], rb[x]]
	return ""


func _compare_nested(a: Array, b: Array, label: String) -> String:
	if a.size() != b.size():
		return "%d entries vs %d entries" % [a.size(), b.size()]
	for i in a.size():
		if a[i] != b[i]:
			return "%s %d: %s vs %s" % [label, i, a[i], b[i]]
	return ""


func _check(what: String, difference: String) -> void:
	if difference == "":
		print("  ok   %s" % what)
	else:
		failures += 1
		print("  FAIL %s -- %s" % [what, difference])


# --- The pre-JSON binary readers, verbatim from main.gd ----------------------
#
# Every .dat file is a big-endian java.io.DataInputStream dump.

func _open(path: String) -> FileAccess:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return null
	f.big_endian = true
	return f


func _s16(f: FileAccess) -> int:
	var v := f.get_16()
	return v - 65536 if v >= 32768 else v


func _legacy_sizes() -> Array:
	var f := _open(MAPS + "sizes.dat")
	var count := _s16(f)
	var sizes: Array = []
	for i in count:
		var width := _s16(f)
		var height := _s16(f)
		# Boss triggers fire four rows earlier so the camera pan can start.
		if i == Triggers.BOSS_BLUE_TANKS or i == Triggers.BOSS_GARAGE \
				or i == Triggers.BOSS_HEADQUARTERS or i == Triggers.BOSS_HELICOPTER \
				or i == Triggers.BOSS_SHIP or i == Triggers.BOSS_STATUES:
			height -= 4
		sizes.append([width, height])
	f.close()
	return sizes


func _legacy_maps(index: int, stage: Stage) -> void:
	var f := _open(MAPS + "map-%d.dat" % index)
	stage.map_width = _s16(f)
	stage.map_height = _s16(f)

	stage.tile_map = []
	stage.groups_map = []
	for y in stage.map_height + 1:
		var row := PackedInt32Array()
		row.resize(stage.map_width)
		stage.tile_map.append(row)
		var grow := PackedByteArray()
		grow.resize(stage.map_width)
		stage.groups_map.append(grow)

	for y in stage.map_height:
		var row: PackedInt32Array = stage.tile_map[y]
		for x in stage.map_width:
			row[x] = _s16(f)

	var group_count := _s16(f)
	stage.groups = []
	for i in group_count:
		var group_size := _s16(f)
		var group: Array = []
		for j in group_size:
			var gx := _s16(f)
			var gy := _s16(f)
			var tile := _s16(f)
			group.append([gx, gy, tile, 0])
			stage.groups_map[gy][gx] = i
		stage.groups.append(group)
	f.close()


func _legacy_types(index: int, stage: Stage) -> void:
	var f := _open(MAPS + "types-%d.dat" % index)
	stage.map_width = _s16(f)
	stage.map_height = _s16(f)

	stage.types_map = []
	for y in stage.map_height + 1:
		var row := PackedInt32Array()
		row.resize(stage.map_width)
		stage.types_map.append(row)

	for y in stage.map_height:
		var row: PackedInt32Array = stage.types_map[y]
		for x in stage.map_width:
			row[x] = _s16(f)

	# The row past the bottom of the map is water, so anything that falls off
	# the end drowns instead of reading out of bounds.
	var last: PackedInt32Array = stage.types_map[stage.map_height]
	for x in stage.map_width:
		last[x] = GameMode.TYPE_WATER
	stage.map_height += 1

	var group_count := _s16(f)
	for i in group_count:
		var group_size := _s16(f)
		var group: Array = stage.groups[i]
		for j in group_size:
			_s16(f)  # x
			_s16(f)  # y
			group[j][3] = _s16(f)
	f.close()


func _legacy_trigger_map(height: int, enemy_sizes: Array, index: int,
		stage: Stage, hard: bool) -> void:
	var lists: Array = []
	for i in height:
		lists.append([])

	var f := _open(MAPS + "enemies%s-%d.dat" % ["-hard" if hard else "", index])
	var count := _s16(f)
	for i in count:
		var trigger_index := _s16(f)
		var tile_x := _s16(f)
		var tile_y := _s16(f)
		var trigger_y: int = tile_y + enemy_sizes[trigger_index][1] - 1
		lists[trigger_y].append([trigger_index, tile_x << 5, tile_y << 5])
	f.close()

	stage.trigger_map[1 if hard else 0] = lists
