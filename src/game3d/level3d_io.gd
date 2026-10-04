# Reads and writes the 3D levels, assets/level3d/stage-N.json: what the 3D
# preview plays and what Blender builds the level from. See
# docs/level-editor-plan.md.
#
# A level file holds what is authored about a level, not its geometry: the
# gameplay grid (nav, groups, entities) in metres on the game's own grid, and
# the placed scenery. Nothing in the 2D game reads it; the stage maps under
# assets/maps were its source for stage 0, once, and are not written back.
#
# The layout is fixed, one entity or grid row to a line, so that saving a level
# nobody edited leaves no diff and moving one bunker touches one line --
# MapIO.serialize's rule, for the same reason.
class_name Level3DIO
extends RefCounted

const DIR := "res://assets/level3d/"
const FORMAT := "jackal-level3d"
const VERSION := 1
const DIFFICULTIES: Array[String] = ["normal", "hard"]


static func path(stage_index: int) -> String:
	return DIR + "stage-%d.json" % stage_index


# dirs-N.dat for the level's own grid, written by the editor's Flow field
# button. Absent until then, and Level3DMap falls back to the game's.
static func flow_field_path(stage_index: int) -> String:
	return DIR + "dirs-%d.dat" % stage_index


static func read(stage_index: int) -> Dictionary:
	return read_path(path(stage_index))


# Any level file, a stage's or one the level editor made.
static func read_path(file_path: String) -> Dictionary:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s (error %d)" % [file_path, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s is not a JSON object" % file_path)
		return {}
	var doc: Dictionary = parsed
	if doc.get("format") != FORMAT or int(doc.get("version", 0)) != VERSION:
		push_error("%s is not a %s file, version %d" % [file_path, FORMAT, VERSION])
		return {}
	return doc


static func save(doc: Dictionary) -> Error:
	return save_path(doc, path(int(doc["stage"])))


static func save_path(doc: Dictionary, file_path: String) -> Error:
	# A script error inside serialize does not stop it; it returns what it had
	# got to. So the text is read back before it replaces the file, and has to
	# hold what the document does.
	var text := serialize(doc)
	var back: Variant = JSON.parse_string(text)
	if typeof(back) != TYPE_DICTIONARY:
		push_error("Not writing %s: what serialize wrote does not parse" % file_path)
		return ERR_INVALID_DATA
	for key in doc:
		var want: Variant = doc[key]
		if not back.has(key) or (want is Array and (back[key] as Array).size() != (want as Array).size()):
			push_error("Not writing %s: %s did not come through" % [file_path, key])
			return ERR_INVALID_DATA
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		var error := FileAccess.get_open_error()
		push_error("Cannot write %s (error %d)" % [file_path, error])
		return error
	f.store_string(text)
	f.close()
	return OK


# A level with nothing on it yet, `rows` map rows long: the game's 64 tiles
# across, the grid where stage 1's is, empty nav, no entities, no objects,
# and the ground's bounds and frame laid round the map as stage 1's are --
# the sea's width to the west, a strip to the east, the forest's depth past
# the north end. Its ground is Level3DGround's to paint; `profile` is the
# shore's, which stage 1's measured one is a fair start for. "stage" is -1:
# it is not one of the game's.
static func new_level(rows: int, profile: Dictionary) -> Dictionary:
	var px := Level3DMap.PX
	var origin := Level3DMap.ORIGIN
	var length := rows * 32 * px
	var nav: Array = []
	var paint: Array = []
	for j in rows:
		nav.append(".".repeat(64))
		paint.append("-".repeat(64))
	var snap := func(v: float) -> float: return snappedf(v, 0.05)
	return {
		"format": FORMAT, "version": VERSION, "stage": -1,
		"grid": {"width": 64, "height": rows, "tile_px": 32, "m_per_px": px,
				"origin": [origin.x, origin.y]},
		"nav": nav, "nav_paint": paint, "groups": [], "entities": [], "objects": [],
		"terrain": {
			"bounds": [snap.call(origin.x - 12.0), snap.call(origin.y - 7.0),
					snap.call(origin.x + 34.2), snap.call(origin.y + length + 0.3)],
			"frame": [snap.call(origin.x - 12.0), round_mm(origin.y),
					round_mm(origin.x + 31.929), round_mm(origin.y + length + 0.37)],
			"profile": "shore", "profiles": {"shore": profile.duplicate(true)},
			"land": [],
		},
		"water": [], "forest": [],
	}


# --- The grid ---------------------------------------------------------------
#
# Level metres from map pixels and back: Level3DMap.to_level, with the
# transform read from the file rather than fixed, so that a level built for
# another map can say where that map lies.
#
#     level x = m_per_px * map x + origin.x      level z = m_per_px * map y + origin.y


static func to_level(grid: Dictionary, p: Vector2) -> Vector2:
	return _origin(grid) + p * float(grid["m_per_px"])


static func to_map(grid: Dictionary, v: Vector2) -> Vector2:
	return (v - _origin(grid)) / float(grid["m_per_px"])


static func _origin(grid: Dictionary) -> Vector2:
	var o: Array = grid["origin"]
	return Vector2(float(o[0]), float(o[1]))


# Footprints in tiles by trigger name, as trigger-sizes.json authors them --
# without the four rows MapIO.load_trigger_sizes takes off the boss triggers,
# which move when a boss fires and not where it stands.
static func footprints() -> Dictionary:
	var f := FileAccess.open(MapIO.MAPS + "trigger-sizes.json", FileAccess.READ)
	if f == null:
		push_error("Cannot open trigger-sizes.json")
		return {}
	var doc: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var out := {}
	for name in doc:
		out[name] = Vector2i(int(doc[name]["width"]), int(doc[name]["height"]))
	return out


# An entity stands where the middle of its footprint is, in metres, to the
# millimetre. The trigger's tile comes back by rounding, and a millimetre
# against a 469 mm tile makes that exact.
static func entity_pos(grid: Dictionary, size: Vector2i, tile: Vector2i) -> Vector2:
	var tile_px := float(grid["tile_px"])
	var centre := (Vector2(tile) + Vector2(size) * 0.5) * tile_px
	return to_level(grid, centre)


static func entity_tile(grid: Dictionary, size: Vector2i, pos: Vector2) -> Vector2i:
	var tile_px := float(grid["tile_px"])
	var corner := to_map(grid, pos) / tile_px - Vector2(size) * 0.5
	return Vector2i(roundi(corner.x), roundi(corner.y))


# --- Back to the game's terms -------------------------------------------------


# The trigger list of one difficulty, in the layout of a stage file's
# "triggers" block: the entities of that difficulty in the order the file lists
# them, which is the order they were authored in.
static func triggers_of(doc: Dictionary, difficulty: String, sizes: Dictionary) -> Array:
	var out: Array = []
	for e in doc["entities"]:
		var entity: Dictionary = e
		if not (entity["difficulty"] as Array).has(difficulty):
			continue
		var p: Array = entity["pos"]
		var tile := entity_tile(doc["grid"], sizes[entity["type"]], Vector2(p[0], p[1]))
		out.append({"type": entity["type"], "x": tile.x, "y": tile.y})
	return out


# Fills a Stage the way MapIO.load_stage does -- grid, the sentinel row of
# water under it, groups, groups_map and both trigger maps -- from a level file.
# The tile grid is left empty: nothing 3D draws it.
static func load_stage(doc: Dictionary, stage: Stage, trigger_sizes: Array) -> void:
	var grid: Dictionary = doc["grid"]
	var width := int(grid["width"])
	var height := int(grid["height"])
	var rows: Array = doc["nav"]
	if rows.size() != height:
		push_error("level %d: nav is %d rows, not %d" % [doc["stage"], rows.size(), height])
		return
	stage.map_width = width
	stage.tile_map = []
	stage.types_map = []
	stage.groups_map = []
	for y in height + 1:
		var types := PackedInt32Array()
		types.resize(width)
		var group_row := PackedByteArray()
		group_row.resize(width)
		if y < height:
			var chars: String = rows[y]
			if chars.length() != width:
				push_error("level %d: nav row %d is not %d wide" % [doc["stage"], y, width])
				return
			for x in width:
				types[x] = MapIO.TYPE_CHARS.get(chars[x], MapIO.TYPE_EMPTY)
		else:
			types.fill(MapIO.TYPE_WATER)
		stage.types_map.append(types)
		stage.groups_map.append(group_row)
	stage.map_height = height + 1

	# Tile 0 stands in for the tile a group would draw: Stage keeps the 2D
	# layout, [x, y, tile, type], and nothing 3D reads the tile.
	stage.groups = []
	var group_docs: Array = doc["groups"]
	for i in group_docs.size():
		var group: Array = []
		for cell in group_docs[i]["cells"]:
			var gx := int(cell[0])
			var gy := int(cell[1])
			group.append([gx, gy, 0, MapIO.TYPE_CHARS.get(cell[2], MapIO.TYPE_EMPTY)])
			stage.groups_map[gy][gx] = i
		stage.groups.append(group)

	var sizes := footprints()
	stage.trigger_map = []
	for d in DIFFICULTIES:
		stage.trigger_map.append(MapIO.build_trigger_map(triggers_of(doc, d, sizes),
				stage.map_height, trigger_sizes, int(doc["stage"])))


# --- Writing ------------------------------------------------------------------


static func serialize(doc: Dictionary) -> String:
	var grid: Dictionary = doc["grid"]
	var origin: Array = grid["origin"]
	var out := PackedStringArray()
	out.append("{")
	out.append('  "format": "%s",' % FORMAT)
	out.append('  "version": %d,' % VERSION)
	out.append('  "stage": %d,' % int(doc["stage"]))
	# Level3DMap.ORIGIN to its last authored place: it is a Vector2, single
	# precision, and more places would only write its rounding down.
	out.append('  "grid": {"width": %d, "height": %d, "tile_px": %d, "m_per_px": %s, "origin": [%s, %s]},'
			% [int(grid["width"]), int(grid["height"]), int(grid["tile_px"]),
				String.num(float(grid["m_per_px"]), 6),
				String.num(float(origin[0]), 4), String.num(float(origin[1]), 4)])

	var legend := PackedStringArray()
	for t in MapIO.TYPE_NAME.size():
		legend.append('"%s": "%s"' % [MapIO.TYPE_CHAR[t], MapIO.TYPE_NAME[t]])
	out.append('  "type_legend": {%s},' % ", ".join(legend))

	var rows := PackedStringArray()
	for row in doc["nav"]:
		rows.append('    "%s"' % row)
	_block(out, "nav", rows)
	# A level the editor made plays the grid its ground makes, with what was
	# painted over it: this, "-" where the ground's stands. "nav" is the
	# result, written for the preview, which reads no rasters.
	if doc.has("nav_paint"):
		rows = PackedStringArray()
		for row in doc["nav_paint"]:
			rows.append('    "%s"' % row)
		_block(out, "nav_paint", rows)

	rows = PackedStringArray()
	for g in doc["groups"]:
		var cells := PackedStringArray()
		for cell in g["cells"]:
			cells.append('[%d, %d, "%s"]' % [int(cell[0]), int(cell[1]), cell[2]])
		rows.append('    {"index": %d, "cells": [%s]}' % [int(g["index"]), ", ".join(cells)])
	_block(out, "groups", rows)

	rows = PackedStringArray()
	for e in doc["entities"]:
		var entity: Dictionary = e
		var difficulty := PackedStringArray()
		for d in entity["difficulty"]:
			difficulty.append('"%s"' % d)
		var line := '    {"id": "%s", "type": "%s", "pos": %s, "difficulty": [%s]' \
				% [entity["id"], entity["type"], _vec(entity["pos"]), ", ".join(difficulty)]
		if entity.has("group"):
			line += ', "group": %d' % int(entity["group"])
		rows.append(line + "}")
	_block(out, "entities", rows)

	# Scenery turns about the vertical only and scales uniformly: everything
	# stage 1 places does, and the forest, which tilts, is not placed one tree
	# at a time. "entity" ties a piece to the entity it belongs to -- a bunker
	# to its gun -- which the preview used to find by the nearest one.
	rows = PackedStringArray()
	for o in doc["objects"]:
		var object: Dictionary = o
		var line := '    {"id": "%s", "asset": "%s", "pos": %s, "yaw": %s, "scale": %s' \
				% [object["id"], object["asset"], _vec(object["pos"]),
					_num(float(object["yaw"])), _num(float(object["scale"]))]
		if object.has("entity"):
			line += ', "entity": "%s"' % object["entity"]
		rows.append(line + "}")
	var ground := ["terrain", "water", "forest"].filter(func(key): return doc.has(key))
	var built := ["walls", "bridges", "paths"].filter(func(key): return doc.has(key))
	_block(out, "objects", rows, ground.is_empty() and built.is_empty())

	# What is built rather than placed (Level3DStructures): a wall a segment
	# of a style, width and height, with its merlons' row; a bridge a segment
	# and a width, with its piers and plates.
	if doc.has("walls"):
		rows = PackedStringArray()
		for w in doc["walls"]:
			var line := '    {"id": "%s", "style": "%s", "from": %s, "to": %s, "width": %s, "height": %s' \
					% [w["id"], w["style"], _vec(w["from"]), _vec(w["to"]), _num(float(w["width"])),
						_num(float(w["height"]))]
			if w.has("merlons"):
				var m: Dictionary = w["merlons"]
				line += ', "merlons": {"side": "%s", "first": %s, "step": %s, "count": %d}' \
						% [m["side"], _num(float(m["first"])), _num(float(m["step"])), int(m["count"])]
			rows.append(line + "}")
		_block(out, "walls", rows, ground.is_empty() and not doc.has("bridges") and not doc.has("paths"))
	if doc.has("bridges"):
		rows = PackedStringArray()
		for b in doc["bridges"]:
			var plates: Dictionary = b["plates"]
			rows.append('    {"id": "%s", "from": %s, "to": %s, "width": %s, "piers": %s, "plates": {"first": %s, "step": %s, "count": %d}}'
					% [b["id"], _vec(b["from"]), _vec(b["to"]), _num(float(b["width"])), _vec(b["piers"]),
						_num(float(plates["first"])), _num(float(plates["step"])), int(plates["count"])])
		_block(out, "bridges", rows, ground.is_empty() and not doc.has("paths"))
	# A wall through points (Level3DStructures, paths): its header, its points
	# a line each -- [x, z], or a gate it goes through -- and then what it
	# makes, the runs of its centre line and its merlons, a point to a line.
	if doc.has("paths"):
		rows = PackedStringArray()
		for path in doc["paths"]:
			rows.append(_path(path))
		_block(out, "paths", rows, ground.is_empty())

	# The ground (Level3DTerrain), when the level has one: a polygon's header on
	# its first line and then one point to a line, so that moving a point of a
	# shore touches that line and adding one adds one.
	if doc.has("terrain"):
		var terrain: Dictionary = doc["terrain"]
		out.append('  "terrain": {')
		out.append('    "bounds": %s,' % _vec(terrain["bounds"]))
		if terrain.has("frame"):
			out.append('    "frame": %s,' % _vec(terrain["frame"]))
		out.append('    "profile": "%s",' % terrain["profile"])
		out.append('    "profiles": {')
		var profiles := PackedStringArray()
		for name in terrain["profiles"]:
			var profile: Dictionary = terrain["profiles"][name]
			profiles.append('      "%s": {"slope": %s,\n        "foot": %s}'
					% [name, _table(profile["slope"]), _table(profile["foot"])])
		out.append(",\n".join(profiles))
		out.append("    },")
		# The rasters the editor paints (Level3DGround), which the polygons
		# below are traced off: named, not held, and absent from a level that
		# has only its polygons.
		if terrain.has("raster"):
			var raster: Dictionary = terrain["raster"]
			out.append('    "raster": {"cell": %s, "shore": %s, "ground": "%s", "height": "%s"},'
					% [_num(float(raster["cell"])), _num(float(raster["shore"])),
						raster["ground"], raster["height"]])
		rows = PackedStringArray()
		for polygon in terrain["land"]:
			rows.append(_polygon(polygon, '"id": "%s", "height": %s, "profile": "%s"'
					% [polygon["id"], _num(float(polygon["height"])), polygon["profile"]], "    "))
		if rows.is_empty():
			out.append('    "land": []')
		else:
			out.append('    "land": [')
			out.append(",\n".join(rows))
			out.append("    ]")
		out.append("  }," if ground.size() > 1 else "  }")
	if doc.has("water"):
		rows = PackedStringArray()
		for polygon in doc["water"]:
			rows.append(_polygon(polygon, '"id": "%s", "kind": "%s", "level": %s'
					% [polygon["id"], polygon["kind"], _num(float(polygon["level"]))], "  "))
		_block(out, "water", rows, not doc.has("forest"))
	if doc.has("forest"):
		rows = PackedStringArray()
		for polygon in doc["forest"]:
			rows.append(_polygon(polygon, '"id": "%s", "spacing": %s, "jitter": %s, "pines": %s, "seed": %d'
					% [polygon["id"], _num(float(polygon["spacing"])), _num(float(polygon["jitter"])),
						_num(float(polygon["pines"])), int(polygon["seed"])], "  "))
		_block(out, "forest", rows, true)

	out.append("}")
	return "\n".join(out) + "\n"


# One polygon of the ground, indented under its list: the header, the outer
# ring a point to a line, and the holes after it the same way.
static func _polygon(polygon: Dictionary, header: String, indent: String) -> String:
	var lines := PackedStringArray()
	lines.append('%s  {%s, "outer": [' % [indent, header])
	lines.append(_points(polygon["outer"], indent + "    "))
	var holes: Array = polygon.get("holes", [])
	if holes.is_empty():
		lines.append('%s  ], "holes": []}' % indent)
	else:
		lines.append('%s  ], "holes": [' % indent)
		var rings := PackedStringArray()
		for hole in holes:
			rings.append("%s    [\n%s\n%s    ]" % [indent, _points(hole, indent + "      "), indent])
		lines.append(",\n".join(rings))
		lines.append("%s  ]}" % indent)
	return "\n".join(lines)


static func _path(path: Dictionary) -> String:
	var header := '"id": "%s", "kind": "%s", "width": %s, "height": %s, "smooth": %s, "closed": %s' \
			% [path["id"], path["kind"], _num(float(path["width"])), _num(float(path["height"])),
				"true" if path["smooth"] else "false", "true" if path["closed"] else "false"]
	if path.has("merlons"):
		header += ', "merlons": {"side": "%s", "step": %s}' % [path["merlons"]["side"], _num(float(path["merlons"]["step"]))]
	var lines := PackedStringArray()
	lines.append('    {%s, "points": [' % header)
	var elements := PackedStringArray()
	for e in path["points"]:
		elements.append('      {"gate": "%s"}' % e["gate"] if e is Dictionary else "      " + _vec(e))
	lines.append(",\n".join(elements))
	var runs: Array = path.get("runs", [])
	if runs.is_empty():
		lines.append('    ], "runs": [], "merlon_at": [')
	else:
		lines.append('    ], "runs": [')
		var parts := PackedStringArray()
		for run in runs:
			parts.append('      {"closed": %s, "points": [\n%s\n      ]}'
					% ["true" if run["closed"] else "false", _points(run["points"], "        ")])
		lines.append(",\n".join(parts))
		lines.append('    ], "merlon_at": [')
	var merlons: Array = path.get("merlon_at", [])
	if merlons.is_empty():
		lines[-1] = lines[-1].trim_suffix("[") + "[]}"
	else:
		var parts := PackedStringArray()
		for m in merlons:
			parts.append("      " + _vec(m))
		lines.append(",\n".join(parts))
		lines.append("    ]}")
	return "\n".join(lines)


static func _points(points: Array, indent: String) -> String:
	var lines := PackedStringArray()
	for p in points:
		lines.append("%s[%s, %s]" % [indent, _num(float(p[0])), _num(float(p[1]))])
	return ",\n".join(lines)


static func _table(rows: Array) -> String:
	var parts := PackedStringArray()
	for row in rows:
		parts.append(_vec(row))
	return "[%s]" % ", ".join(parts)


static func _block(out: PackedStringArray, key: String, rows: PackedStringArray,
		last := false) -> void:
	if rows.is_empty():
		out.append('  "%s": []%s' % [key, "" if last else ","])
		return
	out.append('  "%s": [' % key)
	out.append(",\n".join(rows))
	out.append("  ]" if last else "  ],")


# Millimetres for lengths, thousandths of a degree for angles, thousandths for
# scale: enough for anything placed by hand and short enough to read. Minus
# zero is written as zero, or a value that rounds to it would diff by its sign.
static func _vec(values: Array) -> String:
	var parts := PackedStringArray()
	for v in values:
		parts.append(_num(float(v)))
	return "[%s]" % ", ".join(parts)


static func _num(v: float) -> String:
	var text := "%.3f" % v
	return "0.000" if text == "-0.000" else text


static func round_mm(v: float) -> float:
	return float(_num(v))


# --- Checking -----------------------------------------------------------------


static func read_catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "catalog.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%scatalog.json is not a JSON object" % DIR)
		return {"entity_kinds": [], "entities": {}, "collisions": [], "assets": {}}
	return parsed


# What is wrong with the catalogue itself: a trigger it has no entry for, an
# entry that is not a trigger, a kind or a collision it does not list.
static func check_catalog(catalog: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var consts := MapIO.trigger_constants()
	for type in catalog["entities"]:
		if not consts.has(type):
			problems.append("catalog.json names %s, which is not a trigger" % type)
		elif not (catalog["entity_kinds"] as Array).has(catalog["entities"][type]["kind"]):
			problems.append("catalog.json: %s has unknown kind %s"
					% [type, catalog["entities"][type]["kind"]])
	for type in consts:
		if not catalog["entities"].has(type):
			problems.append("catalog.json has no entry for trigger %s" % type)
	for asset in catalog["assets"]:
		var collision: String = catalog["assets"][asset]["collision"]
		if not (catalog["collisions"] as Array).has(collision):
			problems.append("catalog.json: %s has unknown collision %s" % [asset, collision])
	return problems


# What is wrong with a level: the map editor's Check stage, in the terms of
# a level file, and the references between the file and the catalogue. Empty
# when there is nothing. The editor's Check button and tools/verify_level3d.gd
# both run this.
static func check(doc: Dictionary, catalog: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var consts := MapIO.trigger_constants()
	var sizes := footprints()
	var trigger_sizes := MapIO.load_trigger_sizes()
	var grid: Dictionary = doc["grid"]
	var width := int(grid["width"])
	var height := int(grid["height"])
	var stage := Stage.new()
	load_stage(doc, stage, trigger_sizes)

	var ids := {}
	var gates: Array = []
	var arrivals := {}
	var rows := {}
	for d in DIFFICULTIES:
		arrivals[d] = 0
		rows[d] = {}
	for e in doc["entities"]:
		var entity: Dictionary = e
		var id: String = entity["id"]
		if ids.has(id):
			problems.append("id %s is used twice" % id)
		ids[id] = entity
		var type: String = entity["type"]
		if not consts.has(type) or not sizes.has(type):
			problems.append("%s: %s is not a trigger with a footprint" % [id, type])
			continue
		if not catalog["entities"].has(type):
			problems.append("%s: %s is not in the catalogue" % [id, type])
		var difficulties: Array = entity["difficulty"]
		if difficulties.is_empty():
			problems.append("%s is on neither difficulty" % id)
		for d in difficulties:
			if not DIFFICULTIES.has(d):
				problems.append("%s: unknown difficulty %s" % [id, d])

		var index: int = consts[type]
		var p: Array = entity["pos"]
		var size: Vector2i = sizes[type]
		var tile := entity_tile(grid, size, Vector2(p[0], p[1]))
		if tile.x < 0 or tile.x + size.x > width:
			problems.append("%s at tile %s hangs off the side of the map" % [id, tile])
		# A trigger fires when the top of the frame passes the bottom of its
		# footprint (MapIO.build_trigger_map, GameMode._process_triggers).
		var row: int = tile.y + trigger_sizes[index][1] - 1
		if row < 0 or row >= height + 1:
			problems.append("%s at tile %s fires on row %d, which is not on the map"
					% [id, tile, row])
		else:
			for d in difficulties:
				if rows.has(d):
					rows[d][row] = rows[d].get(row, 0) + 1
		if index == Triggers.PLAYER or index == Triggers.CHINOOK:
			for d in difficulties:
				if arrivals.has(d):
					arrivals[d] += 1

		var probe: Variant = MapIO.GROUP_PROBES.get(index)
		if probe == null:
			if entity.has("group"):
				problems.append("%s: %s does not bind a group, but names one" % [id, type])
			continue
		var cell: Vector2i = tile + probe
		var group := int(entity.get("group", -1))
		if group < 0 or group >= stage.groups.size():
			problems.append("%s names group %d, and there are %d" % [id, group, stage.groups.size()])
		elif cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
			problems.append("%s probes %s, which is off the map" % [id, cell])
		elif stage.groups_map[cell.y][cell.x] != group:
			problems.append("%s names group %d, but the game would probe %s and find group %d"
					% [id, group, cell, stage.groups_map[cell.y][cell.x]])
		if index == Triggers.GATE:
			gates.append(entity)

	# Any number of gates, each opening its own group; not group 0 where the
	# headquarters is, which blows groups[0] by number (BossHeadquarters).
	var headquarters := (doc["entities"] as Array).any(func(e): return e["type"] == "BOSS_HEADQUARTERS")
	var opened := {}
	for gate in gates:
		var group := int(gate.get("group", -1))
		if opened.has(group):
			problems.append("%s opens group %d, which %s opens too" % [gate["id"], group, opened[group]])
		opened[group] = gate["id"]
		if group == 0 and headquarters:
			problems.append("%s opens group 0, which the headquarters blows as well" % gate["id"])

	# Every stage brings the player in exactly once, by parking the jeep
	# (PLAYER) or flying it in (CHINOOK, which stage 1 uses). A row fires all
	# at once, so a crowded one is a wall of enemies rather than a wave; the
	# busiest row in the game as shipped holds eight.
	for d in DIFFICULTIES:
		if arrivals[d] != 1:
			problems.append("%s has %d PLAYER/CHINOOK entities, it needs exactly one"
					% [d, arrivals[d]])
		for row in rows[d]:
			if rows[d][row] > 12:
				problems.append("%s row %d fires %d entities at once" % [d, row, rows[d][row]])

	for o in doc["objects"]:
		var object: Dictionary = o
		var id: String = object["id"]
		if ids.has(id):
			problems.append("id %s is used twice" % id)
		ids[id] = object
		if not catalog["assets"].has(object["asset"]):
			problems.append("%s: asset %s is not in the catalogue" % [id, object["asset"]])
		if object.has("entity"):
			var owner: Variant = ids.get(object["entity"])
			if owner == null or not (owner as Dictionary).has("type"):
				problems.append("%s belongs to %s, which is not an entity" % [id, object["entity"]])
		# A gate's frame alone is only a frame: no gate in the game, no group,
		# nothing a wall goes through. Gates are put down as GATE entities.
		elif object["asset"] == "Gate":
			problems.append("%s is a Gate frame with no GATE entity: delete it and put the gate down again" % id)
	for key in ["walls", "bridges"]:
		for st in doc.get(key, []):
			var id: String = st["id"]
			if ids.has(id):
				problems.append("id %s is used twice" % id)
			ids[id] = st
			if Level3DStructures.length_of(st) < 0.1 or float(st["width"]) <= 0.0:
				problems.append("%s: %s has no length or no width" % [key, id])
			if key == "walls" and not Level3DStructures.STYLES.has(st["style"]):
				problems.append("%s: wall style %s is not one of %s" % [id, st["style"], Level3DStructures.STYLES.keys()])
	# A path: a kind, two points or more, gates that are gates with a Gate and
	# no gate in two places, and what it makes -- its runs and merlons -- as
	# Level3DStructures.lay_path makes them now, which is what the builder
	# builds.
	var gated := {}
	for path in doc.get("paths", []):
		var id: String = path["id"]
		if ids.has(id):
			problems.append("id %s is used twice" % id)
		ids[id] = path
		if not Level3DStructures.STYLES.has(path["kind"]):
			problems.append("%s: path kind %s is not one of %s" % [id, path["kind"], Level3DStructures.STYLES.keys()])
			continue
		if (path["points"] as Array).size() < 2 or float(path["width"]) <= 0.0:
			problems.append("%s: a path wants two points or more and a width" % id)
		for gate in Level3DStructures.gates_in(path):
			var owner: Variant = ids.get(gate)
			if owner == null or owner.get("type", "") != "GATE":
				problems.append("%s goes through %s, which is not a GATE" % [id, gate])
			elif Level3DStructures.gate_frame(doc, gate).is_empty():
				problems.append("%s goes through %s, which has no Gate" % [id, gate])
			elif gated.has(gate):
				problems.append("%s and %s both go through %s" % [gated[gate], id, gate])
			gated[gate] = id
		var laid: Dictionary = path.duplicate(true)
		Level3DStructures.lay_path(laid, doc)
		if _path(laid) != _path(path):
			problems.append("%s: its runs and merlons are not what its points make now -- saved by something else than the editor?" % id)
	# An entity the catalogue gives an object -- a gun its bunker, the landing
	# port its pad -- has one of that asset belonging to it: the preview sets
	# the gun on the bunker it finds that way, and without one there is none.
	for e in doc["entities"]:
		var wanted: String = catalog["entities"].get(e["type"], {}).get("object", "")
		if wanted == "":
			continue
		var found := 0
		for o in doc["objects"]:
			if o.get("entity", "") == e["id"] and o["asset"] == wanted:
				found += 1
		if found != 1:
			problems.append("%s has %d %s objects belonging to it; it needs one" % [e["id"], found, wanted])

	if doc.get("bridges", []).size() > Level3DStructures.WATER_SHADOW_BRIDGES:
		problems.append("%d bridges: the water draws its own shadows for the first %d, the rest cast straight ones"
				% [doc["bridges"].size(), Level3DStructures.WATER_SHADOW_BRIDGES])
	problems.append_array(_check_ground(doc, ids))
	return problems


const WATER_KINDS: Array[String] = ["sea", "river"]


# The ground blocks, when there are any: rings that are rings, ids nobody else
# has, profiles that exist and run forward, water of a kind the shader knows.
static func _check_ground(doc: Dictionary, ids: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if not doc.has("terrain"):
		if doc.has("water") or doc.has("forest"):
			problems.append("the level has water or forest but no terrain")
		return problems
	var terrain: Dictionary = doc["terrain"]
	var profiles: Dictionary = terrain.get("profiles", {})
	if not profiles.has(terrain.get("profile", "")):
		problems.append("terrain's profile %s is not among its profiles" % terrain.get("profile"))
	for name in profiles:
		for table in ["slope", "foot"]:
			var rows: Array = profiles[name].get(table, [])
			if rows.size() < 2:
				problems.append("profile %s: %s has %d rows, it needs two" % [name, table, rows.size()])
			for k in range(1, rows.size()):
				if float(rows[k][0]) <= float(rows[k - 1][0]):
					problems.append("profile %s: %s does not run forward at row %d" % [name, table, k])
					break
	var polygons: Array = []
	for polygon in terrain.get("land", []):
		polygons.append(polygon)
		if not profiles.has(polygon.get("profile", "")):
			problems.append("%s: no profile %s" % [polygon["id"], polygon.get("profile")])
	for polygon in doc.get("water", []):
		polygons.append(polygon)
		if not WATER_KINDS.has(polygon.get("kind", "")):
			problems.append("%s: water of kind %s" % [polygon["id"], polygon.get("kind")])
	for polygon in doc.get("forest", []):
		polygons.append(polygon)
		if float(polygon.get("spacing", 0.0)) <= 0.0:
			problems.append("%s: spacing %s" % [polygon["id"], polygon.get("spacing")])
	for polygon in polygons:
		var id: String = polygon.get("id", "")
		if ids.has(id):
			problems.append("id %s is used twice" % id)
		ids[id] = polygon
		var rings: Array = [polygon.get("outer", [])]
		rings.append_array(polygon.get("holes", []))
		for points in rings:
			if (points as Array).size() < 3:
				problems.append("%s has a ring of %d points" % [id, (points as Array).size()])
	return problems
