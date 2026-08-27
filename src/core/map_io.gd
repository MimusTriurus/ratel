# Reads the stage maps in their authored form, assets/maps/stage-N.json.
#
# The originals were java.io.DataInputStream dumps inherited from the Java
# remake -- map-N.dat (tile grid), types-N.dat (collision grid) and
# enemies[-hard]-N.dat (spawn triggers) -- readable by nothing but Main's
# loader. tools/map_json.py converted them and proves the conversion lossless
# by re-encoding the JSON back into the binary layout byte for byte.
#
# dirs-N.dat stays binary and is still read by Main: it is derived data (a
# 2M-entry flow field computed from the collision grid), not something anyone
# authors, and it would be several MB of text per stage.
class_name MapIO
extends RefCounted

const MAPS := "res://assets/maps/"
const TILE := 32

# What a stage draws its terrain from. "tiles" assembles it out of tiles-N.png a
# cell at a time, as the original did; "image" blits the baked chunks under
# LEVELS instead (tools/bake_stage_image.gd writes them). A stage file with no
# background block means tiles, which is why that is 0.
const BACKGROUND_TILES := 0
const BACKGROUND_IMAGE := 1
const BACKGROUND_NAMES: Array[String] = ["tiles", "image"]

# The chunk files are a convention rather than data, as dirs-N.dat and
# tiles-N.png are: chunk k covers map rows [k * chunk_height / TILE, ...) and the
# last one is cropped to whatever is left, so only the chunk height is authored
# -- the count and the last chunk's height follow from map_height.
const LEVELS := "res://assets/images/levels/"

# Mirrors GameMode.TYPE_* and tools/map_json.py TYPE_CHARS. Spelled out rather
# than referencing GameMode so that src/core does not depend on src/game.
const TYPE_SOLID := 0
const TYPE_EMPTY := 1
const TYPE_SHIELD := 2
const TYPE_WATER := 3
const TYPE_SWAMP := 4
const TYPE_CONVEYOR := 5

const TYPE_CHARS := {
	"#": TYPE_SOLID,
	".": TYPE_EMPTY,
	"S": TYPE_SHIELD,
	"~": TYPE_WATER,
	"%": TYPE_SWAMP,
	">": TYPE_CONVEYOR,
}

# The same thing the other way round, indexed by type, for writing and for
# anything that needs to name a type to a human.
const TYPE_CHAR: Array[String] = ["#", ".", "S", "~", "%", ">"]
const TYPE_NAME: Array[String] = [
	"SOLID", "EMPTY", "SHIELD", "WATER", "SWAMP", "CONVEYOR",
]

# Boss triggers fire four rows earlier so the camera pan can start. Same list
# as Main.load_sizes.
const EARLY_BOSS_TRIGGERS: Array[int] = [
	Triggers.BOSS_BLUE_TANKS, Triggers.BOSS_GARAGE, Triggers.BOSS_HEADQUARTERS,
	Triggers.BOSS_HELICOPTER, Triggers.BOSS_SHIP, Triggers.BOSS_STATUES,
]


static func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s is not a JSON object" % path)
		return {}
	return parsed


# Trigger name -> index, straight off the Triggers constants, so the JSON never
# repeats numbers that already have a name in the source.
static func trigger_constants() -> Dictionary:
	var consts: Dictionary = (Triggers as Script).get_script_constant_map()
	if consts.size() != 61:
		push_error("Triggers has %d constants, expected 61" % consts.size())
	return consts


static func load_trigger_sizes() -> Array:
	var doc := _read_json(MAPS + "trigger-sizes.json")
	var consts := trigger_constants()
	var sizes: Array = []
	sizes.resize(consts.size())
	for name in doc:
		if not consts.has(name):
			push_error("trigger-sizes.json names unknown trigger %s" % name)
			continue
		var index: int = consts[name]
		var entry: Dictionary = doc[name]
		var height := int(entry["height"])
		if EARLY_BOSS_TRIGGERS.has(index):
			height -= 4
		sizes[index] = [int(entry["width"]), height]
	for i in sizes.size():
		if sizes[i] == null:
			push_error("trigger-sizes.json is missing an entry for trigger %d" % i)
			sizes[i] = [1, 1]
	return sizes


# How many map rows one chunk holds, and how many chunks a stage takes. Zero
# rows means the stage has no baked backdrop, and the count is 0 with it.
static func background_chunk_rows(stage: Stage) -> int:
	@warning_ignore("integer_division")
	return stage.background_chunk_height / TILE


static func background_chunk_count(stage: Stage) -> int:
	var rows := background_chunk_rows(stage)
	if rows <= 0:
		return 0
	@warning_ignore("integer_division")
	return (stage.map_height + rows - 1) / rows


static func background_chunk_path(index: int, chunk: int) -> String:
	return LEVELS + "stage-%d-%d.png" % [index, chunk]


# The parsed stage file, for a tool that needs to carry the parts a Stage does
# not keep in authored form -- the trigger list in its original order -- across
# a load and save.
static func read_document(index: int) -> Dictionary:
	return _read_json(MAPS + "stage-%d.json" % index)


static func save_stage(index: int, stage: Stage, source: Dictionary) -> Error:
	var path := MAPS + "stage-%d.json" % index
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		var error := FileAccess.get_open_error()
		push_error("Cannot write %s (error %d)" % [path, error])
		return error
	f.store_string(serialize(index, stage, source))
	f.close()
	return OK


# Reproduces the layout tools/map_json.py writes, so that saving a stage nobody
# edited leaves no diff behind. One map row is one line, which is the whole
# point of the format.
#
# The grids come from the Stage, everything else from the document it was loaded
# from: triggers keep the order they were authored in, which the Stage cannot
# preserve because it files them by the row they fire on.
static func serialize(index: int, stage: Stage, source: Dictionary) -> String:
	var width := stage.map_width
	var height := stage.map_height - 1  # the sentinel water row is not authored

	var out := PackedStringArray()
	out.append("{")
	out.append('  "stage": %d,' % index)
	out.append('  "width": %d,' % width)
	out.append('  "height": %d,' % height)

	# Written only for a stage that carries a backdrop, in either mode: a stage
	# that has never been baked has to round-trip byte for byte.
	if stage.background_mode != BACKGROUND_TILES or source.has("background"):
		out.append('  "background": {"mode": "%s", "chunk_height": %d},'
			% [BACKGROUND_NAMES[stage.background_mode],
				stage.background_chunk_height])

	var legend := PackedStringArray()
	for t in TYPE_NAME.size():
		legend.append('"%s": "%s"' % [TYPE_CHAR[t], TYPE_NAME[t]])
	out.append('  "type_legend": {%s},' % ", ".join(legend))

	var rows := PackedStringArray()
	for y in height:
		var row: PackedInt32Array = stage.types_map[y]
		var chars := ""
		for x in width:
			chars += TYPE_CHAR[row[x]]
		rows.append('    "%s"' % chars)
	out.append('  "types": [')
	out.append(",\n".join(rows))
	out.append("  ],")

	rows = PackedStringArray()
	for y in height:
		var row: PackedInt32Array = stage.tile_map[y]
		var numbers := PackedStringArray()
		for x in width:
			numbers.append(str(row[x]))
		rows.append("    [%s]" % ",".join(numbers))
	out.append('  "tiles": [')
	out.append(",\n".join(rows))
	out.append("  ],")

	rows = PackedStringArray()
	for i in stage.groups.size():
		var cells := PackedStringArray()
		for cell in stage.groups[i]:
			cells.append('[%d, %d, %d, "%s"]'
				% [cell[0], cell[1], cell[2], TYPE_CHAR[cell[3]]])
		rows.append('    {"index": %d, "cells": [%s]}' % [i, ", ".join(cells)])
	out.append('  "groups": [')
	out.append(",\n".join(rows))
	out.append("  ],")

	out.append('  "triggers": {')
	var difficulties := ["normal", "hard"]
	for d in 2:
		out.append('    "%s": [' % difficulties[d])
		var entries := PackedStringArray()
		for t in source["triggers"][difficulties[d]]:
			var trigger: Dictionary = t
			entries.append('      {"type": "%s", "x": %d, "y": %d}'
				% [trigger["type"], int(trigger["x"]), int(trigger["y"])])
		out.append(",\n".join(entries))
		out.append("    ]" if d == 1 else "    ],")
	out.append("  }")
	out.append("}")

	return "\n".join(out) + "\n"


static func load_stage(index: int, stage: Stage, trigger_sizes: Array) -> void:
	var doc := _read_json(MAPS + "stage-%d.json" % index)
	if doc.is_empty():
		return

	var width := int(doc["width"])
	var height := int(doc["height"])
	stage.map_width = width

	stage.background_mode = BACKGROUND_TILES
	stage.background_chunk_height = 0
	if doc.has("background"):
		_load_background(index, stage, doc["background"])

	# Both grids get one row past the bottom of the map, as in the original: the
	# extra types row is water, so anything that drives off the end drowns
	# instead of reading out of bounds. map_height counts it.
	var tile_rows: Array = doc["tiles"]
	var type_rows: Array = doc["types"]
	if tile_rows.size() != height or type_rows.size() != height:
		push_error("stage-%d.json: grid is not %d rows" % [index, height])
		return

	stage.tile_map = []
	stage.types_map = []
	stage.groups_map = []
	for y in height + 1:
		var tiles := PackedInt32Array()
		tiles.resize(width)
		var types := PackedInt32Array()
		types.resize(width)
		var group_row := PackedByteArray()
		group_row.resize(width)

		if y < height:
			var src: Array = tile_rows[y]
			var chars: String = type_rows[y]
			if src.size() != width or chars.length() != width:
				push_error("stage-%d.json: row %d is not %d wide" % [index, y, width])
				return
			for x in width:
				tiles[x] = int(src[x])
				types[x] = TYPE_CHARS.get(chars[x], TYPE_EMPTY)
		else:
			for x in width:
				types[x] = TYPE_WATER

		stage.tile_map.append(tiles)
		stage.types_map.append(types)
		stage.groups_map.append(group_row)

	stage.map_height = height + 1

	# A group is the set of cells rewritten when the thing standing on them is
	# destroyed; groups_map is the reverse index the elements look themselves up
	# in. Order matters -- BossHeadquarters hardcodes groups[0].
	stage.groups = []
	var group_docs: Array = doc["groups"]
	for i in group_docs.size():
		var group_doc: Dictionary = group_docs[i]
		if int(group_doc["index"]) != i:
			push_error("stage-%d.json: group %d is labelled %d"
				% [index, i, int(group_doc["index"])])
		var group: Array = []
		for cell in group_doc["cells"]:
			var gx := int(cell[0])
			var gy := int(cell[1])
			group.append([gx, gy, int(cell[2]), TYPE_CHARS.get(cell[3], TYPE_EMPTY)])
			stage.groups_map[gy][gx] = i
		stage.groups.append(group)

	stage.trigger_map = [
		build_trigger_map(doc["triggers"]["normal"], stage.map_height,
			trigger_sizes, index),
		build_trigger_map(doc["triggers"]["hard"], stage.map_height,
			trigger_sizes, index),
	]


# The backdrop block is optional and the game has to draw something either way,
# so anything wrong with it falls back to tiles instead of refusing the stage.
static func _load_background(index: int, stage: Stage, doc: Variant) -> void:
	if typeof(doc) != TYPE_DICTIONARY:
		push_error("stage-%d.json: background is not an object" % index)
		return
	var block: Dictionary = doc

	var chunk_height := int(block.get("chunk_height", 0))
	if chunk_height <= 0 or chunk_height % TILE != 0:
		push_error("stage-%d.json: background chunk_height %d is not a positive multiple of %d"
			% [index, chunk_height, TILE])
		return

	var name := str(block.get("mode", BACKGROUND_NAMES[BACKGROUND_TILES]))
	var mode := BACKGROUND_NAMES.find(name)
	if mode < 0:
		push_error("stage-%d.json: unknown background mode %s" % [index, name])
		return

	stage.background_mode = mode
	stage.background_chunk_height = chunk_height


# A trigger fires when the bottom row of its footprint is one tile above the top
# edge of the frame, so it is filed under tile_y + height - 1 rather than its own
# row, and a whole row fires at once regardless of x.
static func build_trigger_map(triggers: Array, map_height: int,
		trigger_sizes: Array, stage_index: int) -> Array:
	var consts := trigger_constants()
	var lists: Array = []
	for i in map_height:
		lists.append([])

	for t in triggers:
		var entry: Dictionary = t
		var name: String = entry["type"]
		if not consts.has(name):
			push_error("stage-%d.json: unknown trigger %s" % [stage_index, name])
			continue
		var trigger_index: int = consts[name]
		var tile_x := int(entry["x"])
		var tile_y := int(entry["y"])
		var row: int = tile_y + trigger_sizes[trigger_index][1] - 1
		if row < 0 or row >= map_height:
			push_error("stage-%d.json: %s at (%d, %d) fires on row %d, outside 0..%d"
				% [stage_index, name, tile_x, tile_y, row, map_height - 1])
			continue
		lists[row].append([trigger_index, tile_x << 5, tile_y << 5])

	return lists
