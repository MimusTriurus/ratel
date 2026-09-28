# What a 3D level builds rather than places: its walls, its bridges and its
# gate (docs/level-editor-plan.md, part 3). The file holds a wall as a
# segment, a style, a width and a height, with its merlons' row; a bridge as
# a segment and a width, with its piers and its plates; the gate as an object
# tied to the GATE entity. tools/blender/build_level.py builds them out of
# stage 1's own pieces; this is what the level editor needs of them -- the
# defaults a new one gets, the box each makes on the plan, and what they do
# to the nav grid of a level whose grid comes from its ground.
class_name Level3DStructures
extends RefCounted

const STYLES := {
	"wall": {"width": 1.9, "height": 1.3, "merlons": true},
	"side": {"width": 0.48, "height": 1.4, "merlons": false},
}
# Stage 1's merlon row: the first 0.36 m from the start, 0.96 m apart, the
# last no nearer the end than MERLON_END; MERLON_INSET from the edge.
const MERLON_FIRST := 0.36
const MERLON_STEP := 0.96
const MERLON_END := 0.26
const MERLON_INSET := 0.24
const MERLON_SIZE := Vector3(0.52, 0.3, 0.4)
# Stage 1's bridge: 2.7 m wide, piers 2.3 m apart about its middle and no
# nearer an end than PIER_END, plates 0.92 m apart.
const BRIDGE_WIDTH := 2.7
const PIER_STEP := 2.3
const PIER_END := 1.2
const PLATE_STEP := 0.92
const CURB := 0.3
const DECK_TOP := 0.2
const PIER_DEPTH := -1.24
# A gate's footprint is 6 x 4 tiles, and blowing it opens the four in the
# middle: stage 1's group 6.
const GATE_PASSAGE := Rect2i(1, 0, 4, 4)


static func length_of(s: Dictionary) -> float:
	return _v(s["from"]).distance_to(_v(s["to"]))


static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _a(v: Vector2) -> Array:
	return [Level3DIO.round_mm(v.x), Level3DIO.round_mm(v.y)]


# A wall from `a` to `b` in a style's width and height, its merlons laid out
# as stage 1's are.
static func new_wall(id: String, style: String, a: Vector2, b: Vector2) -> Dictionary:
	var s: Dictionary = STYLES[style]
	var wall := {"id": id, "style": style, "from": _a(a), "to": _a(b),
			"width": s["width"], "height": s["height"]}
	if s["merlons"]:
		wall["merlons"] = {"side": "left", "first": MERLON_FIRST, "step": MERLON_STEP, "count": 0}
		lay_merlons(wall)
	return wall


# As many merlons as its length holds, from MERLON_FIRST on.
static func lay_merlons(wall: Dictionary) -> void:
	if not wall.has("merlons"):
		return
	var m: Dictionary = wall["merlons"]
	var room := length_of(wall) - float(m["first"]) - MERLON_END
	m["count"] = floori(room / float(m["step"])) + 1 if room >= 0.0 else 0


static func new_bridge(id: String, a: Vector2, b: Vector2) -> Dictionary:
	var bridge := {"id": id, "from": _a(a), "to": _a(b), "width": BRIDGE_WIDTH, "piers": [],
			"plates": {"first": 0.0, "step": PLATE_STEP, "count": 0}}
	lay_bridge(bridge)
	return bridge


# Piers PIER_STEP apart, one at the middle if they are odd, none nearer an
# end than PIER_END; plates as many as fit, centred.
static func lay_bridge(bridge: Dictionary) -> void:
	var length := length_of(bridge)
	var middle := length * 0.5
	var piers: Array = []
	var span := middle - PIER_END
	if span >= 0.0:
		var n := floori(span / PIER_STEP)
		for k in range(-n, n + 1):
			piers.append(Level3DIO.round_mm(middle + k * PIER_STEP))
	bridge["piers"] = piers
	var plates: Dictionary = bridge["plates"]
	var count := maxi(floori((length - 0.1) / PLATE_STEP), 0)
	plates["count"] = count
	plates["first"] = Level3DIO.round_mm((length - (count - 1) * PLATE_STEP) * 0.5) if count > 0 else 0.0


# The four corners of a segment's box, `width` across.
static func corners(s: Dictionary) -> PackedVector2Array:
	var a := _v(s["from"])
	var b := _v(s["to"])
	var d := (b - a).normalized() if a != b else Vector2.RIGHT
	var left := Vector2(d.y, -d.x) * float(s["width"]) * 0.5
	return PackedVector2Array([a - left, b - left, b + left, a + left])


# The middle of each merlon of a wall, and the direction along it.
static func merlons_of(wall: Dictionary) -> Array:
	var out: Array = []
	if not wall.has("merlons"):
		return out
	var m: Dictionary = wall["merlons"]
	var a := _v(wall["from"])
	var b := _v(wall["to"])
	var d := (b - a).normalized() if a != b else Vector2.RIGHT
	# Left of from -> to, x east and z south: north for a wall running east.
	var left := Vector2(d.y, -d.x)
	var side := left if m["side"] == "left" else -left
	var off := float(wall["width"]) * 0.5 - MERLON_INSET
	for k in int(m["count"]):
		out.append(a + d * (float(m["first"]) + k * float(m["step"])) + side * off)
	return out


static func distance_to(s: Dictionary, p: Vector2) -> float:
	var q := Geometry2D.get_closest_point_to_segment(p, _v(s["from"]), _v(s["to"]))
	return maxf(p.distance_to(q) - float(s["width"]) * 0.5, 0.0)


# The cells a gate's blowing opens: GATE_PASSAGE of its footprint.
static func gate_cells(tile: Vector2i) -> Array:
	var out: Array = []
	for dy in GATE_PASSAGE.size.y:
		for dx in GATE_PASSAGE.size.x:
			out.append([tile.x + GATE_PASSAGE.position.x + dx, tile.y + GATE_PASSAGE.position.y + dy, "."])
	return out


# What the level's walls, bridges and gates make of a grid that came from
# the ground: a tile any of nine points across which is in a wall is solid,
# so is a gate's footprint, and a tile on a bridge's deck is empty -- over the
# water it crosses.
static func apply_nav(doc: Dictionary, rows: Array) -> void:
	var grid: Dictionary = doc["grid"]
	var tile := float(grid["tile_px"])
	var set_tile := func(x: int, y: int, c: String) -> void:
		if y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length():
			var row: String = rows[y]
			rows[y] = row.substr(0, x) + c + row.substr(x + 1)
	for pass_ in [["bridges", "."], ["walls", "#"]]:
		for s in doc.get(pass_[0], []):
			var box := corners(s)
			var lo := Vector2(INF, INF)
			var hi := -lo
			for c in box:
				lo = lo.min(c)
				hi = hi.max(c)
			var t0 := (Level3DIO.to_map(grid, lo) / tile).floor()
			var t1 := (Level3DIO.to_map(grid, hi) / tile).floor()
			for y in range(int(t0.y), int(t1.y) + 1):
				for x in range(int(t0.x), int(t1.x) + 1):
					var hit := false
					for sy in [0.2, 0.5, 0.8]:
						for sx in [0.2, 0.5, 0.8]:
							if Geometry2D.is_point_in_polygon(Level3DIO.to_level(grid,
									Vector2((x + sx) * tile, (y + sy) * tile)), box):
								hit = true
					if hit:
						set_tile.call(x, y, pass_[1])
	var sizes := Level3DIO.footprints()
	for e in doc["entities"]:
		if e["type"] != "GATE":
			continue
		var size: Vector2i = sizes["GATE"]
		var at := Level3DIO.entity_tile(grid, size, Vector2(float(e["pos"][0]), float(e["pos"][1])))
		for dy in size.y:
			for dx in size.x:
				set_tile.call(at.x + dx, at.y + dy, "#")
