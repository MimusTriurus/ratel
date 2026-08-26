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


static func load_stage(index: int, stage: Stage, trigger_sizes: Array) -> void:
	var doc := _read_json(MAPS + "stage-%d.json" % index)
	if doc.is_empty():
		return

	var width := int(doc["width"])
	var height := int(doc["height"])
	stage.map_width = width

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
		_build_trigger_map(doc["triggers"]["normal"], stage.map_height,
			trigger_sizes, index),
		_build_trigger_map(doc["triggers"]["hard"], stage.map_height,
			trigger_sizes, index),
	]


# A trigger fires when the bottom row of its footprint is one tile above the top
# edge of the frame, so it is filed under tile_y + height - 1 rather than its own
# row, and a whole row fires at once regardless of x.
static func _build_trigger_map(triggers: Array, map_height: int,
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
