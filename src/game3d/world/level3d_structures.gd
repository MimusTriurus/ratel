# What a 3D level builds rather than places: its walls, its bridges and its
# gate (docs/level-editor-plan.md, part 3). The file holds a wall as a
# segment, a style, a width and a height, with its merlons' row, or as a path
# through points (see Paths below); a bridge as
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
# Over the deck, as build_level.py's CURB: the top of what a bridge shades
# the water with.
const CURB_HEIGHT := 0.12
# As many bridges as the water draws its own shadows for (level3d_ocean.gdshader's
# bridge_ends); past them, the shadow map's straight edge.
const WATER_SHADOW_BRIDGES := 8
const PIER_DEPTH := -1.24
# Along the bridge; across, a pier is the deck less its two curbs. As
# build_level.py's PIER and CURB, which build it.
const PIER_LENGTH := 0.56
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
# so is a gate's footprint and its frame in a path's wall, and a tile on a
# bridge's deck is empty -- over the water it crosses.
static func apply_nav(doc: Dictionary, rows: Array) -> void:
	var grid: Dictionary = doc["grid"]
	for pass_ in [["bridges", "."], ["walls", "#"]]:
		for s in doc.get(pass_[0], []):
			_mark(grid, rows, corners(s), pass_[1])
	for path in doc.get("paths", []):
		for polygon in path_polygons(path, doc):
			_mark(grid, rows, polygon, "#")
	var set_tile := func(x: int, y: int, c: String) -> void:
		if y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length():
			var row: String = rows[y]
			rows[y] = row.substr(0, x) + c + row.substr(x + 1)
	var sizes := Level3DIO.footprints()
	for e in doc["entities"]:
		if e["type"] != "GATE":
			continue
		var size: Vector2i = sizes["GATE"]
		var at := Level3DIO.entity_tile(grid, size, Vector2(float(e["pos"][0]), float(e["pos"][1])))
		for dy in size.y:
			for dx in size.x:
				set_tile.call(at.x + dx, at.y + dy, "#")


# A tile any of nine points across which is in `polygon` becomes `c`.
static func _mark(grid: Dictionary, rows: Array, polygon: PackedVector2Array, c: String) -> void:
	var tile := float(grid["tile_px"])
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in polygon:
		lo = lo.min(p)
		hi = hi.max(p)
	var t0 := (Level3DIO.to_map(grid, lo) / tile).floor()
	var t1 := (Level3DIO.to_map(grid, hi) / tile).floor()
	for y in range(maxi(int(t0.y), 0), mini(int(t1.y) + 1, rows.size())):
		for x in range(maxi(int(t0.x), 0), mini(int(t1.x) + 1, (rows[y] as String).length())):
			var hit := false
			for sy in [0.2, 0.5, 0.8]:
				for sx in [0.2, 0.5, 0.8]:
					if not hit and Geometry2D.is_point_in_polygon(Level3DIO.to_level(grid,
							Vector2((x + sx) * tile, (y + sy) * tile)), polygon):
						hit = true
			if hit:
				var row: String = rows[y]
				rows[y] = row.substr(0, x) + c + row.substr(x + 1)


# --- Paths ------------------------------------------------------------------------
#
# A wall that runs on through as many points as it has, straight from one to
# the next or smooth through them, and round to its first again if it is
# closed. A point is [x, z] or a gate, {"gate": <its GATE entity's id>}: the
# wall goes through the gate's frame -- GATE_HALF_GAP either side of the Gate
# object, as stage 1's walls stop 2.3 m from its gate's middle -- square to it,
# and is open between. So a gate moved takes the wall with it, and a wall is
# drawn round a gate by going through it.
#
# What a path makes is kept in the file with it, as the ground's polygons are
# kept with the rasters they are traced off: "runs", the centre line cut at the
# gates, a point to PATH_STEP or less along a curve, and "merlon_at", where
# each merlon stands and which way it faces ([x, z, yaw]). The builder builds
# from those, so that it and the editor cannot disagree on a curve;
# Level3DIO.check holds them to what lay_path makes of the path now.

const PATH_STEP := 0.4
const GATE_HALF_GAP := 2.3
# How far a joint's corner may reach out, in half widths, at a sharp turn.
const MITER_LIMIT := 2.0
# How near a path a gate put down has to be to go into it.
const GATE_REACH := 1.2
# How far from the gate's axis a wall may run and still go through it. A
# gate's footprint is the game's, on its grid, and its passage runs north to
# south as the game scrolls; a wall that runs north to south cannot have one.
const GATE_MAX_TURN := 30.0


static func new_path(id: String, kind: String, points: Array) -> Dictionary:
	var s: Dictionary = STYLES[kind]
	var path := {"id": id, "kind": kind, "width": s["width"], "height": s["height"],
			"smooth": false, "closed": false, "points": points}
	if s["merlons"]:
		path["merlons"] = {"side": "left", "step": MERLON_STEP}
	return path


static func is_path(s: Dictionary) -> bool:
	return s.has("points")


static func is_gate_point(element: Variant) -> bool:
	return element is Dictionary


# Where a GATE entity's Gate object puts its frame, and the frame's axis --
# the way across the passage -- or {} for a gate with no Gate.
static func gate_frame(doc: Dictionary, gate: String) -> Dictionary:
	for o in doc["objects"]:
		if o.get("entity", "") == gate and o["asset"] == "Gate":
			var yaw := deg_to_rad(float(o["yaw"]))
			return {"at": Vector2(float(o["pos"][0]), float(o["pos"][2])), "axis": Vector2(cos(yaw), -sin(yaw))}
	return {}


# The ids of the gates a path goes through.
# Whether a wall from `a` to `b` runs near enough along a gate's `axis` to go
# through it.
static func runs_across(a: Vector2, b: Vector2, axis: Vector2) -> bool:
	var d := b - a
	return d.length() < 1e-6 or absf(d.normalized().dot(axis)) >= cos(deg_to_rad(GATE_MAX_TURN))


static func gates_in(path: Dictionary) -> Array:
	var out: Array = []
	for element in path["points"]:
		if is_gate_point(element):
			out.append(element["gate"])
	return out


static func _element_at(element: Variant, doc: Dictionary) -> Variant:
	if is_gate_point(element):
		var frame := gate_frame(doc, element["gate"])
		return null if frame.is_empty() else frame["at"]
	return _v(element)


# The points the curve goes through, each {"p", "axis" -- the gate's, which the
# curve is held to there, or ZERO -- and "open", whether the way on to the
# next is a gate's passage}. A gate is its two posts' outer faces, the one
# nearer the point before it first.
static func controls(path: Dictionary, doc: Dictionary) -> Array:
	var elements: Array = path["points"]
	var closed: bool = path["closed"]
	var out: Array = []
	for i in elements.size():
		var element: Variant = elements[i]
		if not is_gate_point(element):
			out.append({"p": _v(element), "axis": Vector2.ZERO, "open": false, "element": i})
			continue
		var frame := gate_frame(doc, element["gate"])
		if frame.is_empty():
			continue
		var a: Vector2 = frame["at"] - frame["axis"] * GATE_HALF_GAP
		var b: Vector2 = frame["at"] + frame["axis"] * GATE_HALF_GAP
		var before: Variant = null
		var after: Variant = null
		if elements.size() > 1 and (i > 0 or closed):
			before = _element_at(elements[posmod(i - 1, elements.size())], doc)
		if elements.size() > 1 and (i < elements.size() - 1 or closed):
			after = _element_at(elements[(i + 1) % elements.size()], doc)
		var flip := false
		if before != null:
			flip = (before as Vector2).distance_to(b) < (before as Vector2).distance_to(a)
		elif after != null:
			flip = (after as Vector2).distance_to(a) < (after as Vector2).distance_to(b)
		if flip:
			var t := a
			a = b
			b = t
		var axis := (b - a).normalized()
		out.append({"p": a, "axis": axis, "open": true, "element": i})
		out.append({"p": b, "axis": axis, "open": false, "element": i})
	return out


# The posts of the gate at element `i` of a path, in the order the path goes
# through them: what the gate becomes when it is taken out and the wall
# closes across where it stood.
static func gate_posts(path: Dictionary, doc: Dictionary, i: int) -> Array:
	var out: Array = []
	for c in controls(path, doc):
		if c["element"] == i:
			out.append(c["p"])
	return out


# The centre line: runs of points, cut at the gates, each {"closed", "points"}.
static func runs_of(path: Dictionary, doc: Dictionary) -> Array:
	var c := controls(path, doc)
	var n := c.size()
	if n < 2:
		return []
	var closed: bool = path["closed"] and n >= 3
	var smooth: bool = path["smooth"]
	var runs: Array = []
	var current := PackedVector2Array()
	var any_open := false
	for i in (n if closed else n - 1):
		var j := (i + 1) % n
		if c[i]["open"]:
			any_open = true
			if current.size() >= 2:
				runs.append(current)
			current = PackedVector2Array()
			continue
		var piece := _piece(c, i, j, closed) if smooth else PackedVector2Array([c[i]["p"], c[j]["p"]])
		if current.is_empty():
			current.append_array(piece)
		else:
			current.append_array(piece.slice(1))
	if current.size() >= 2:
		runs.append(current)
	if runs.is_empty():
		return []
	if closed and not any_open:
		var ring: PackedVector2Array = runs[0]
		ring.resize(ring.size() - 1)
		return [{"closed": true, "points": ring}]
	# A closed path with a gate in it: the run that ends back at the first
	# point goes on into the one that starts there.
	if closed and runs.size() >= 2 and not c[n - 1]["open"] and not c[0]["open"]:
		var last: PackedVector2Array = runs.pop_back()
		last.append_array((runs[0] as PackedVector2Array).slice(1))
		runs[0] = last
	return runs.map(func(r): return {"closed": false, "points": r})


# The curve from control i to control j, both included: a cubic through them,
# along the tangent at each -- the gate's axis at a gate, else the way from
# the point before to the point after -- as long as the chord.
static func _piece(c: Array, i: int, j: int, closed: bool) -> PackedVector2Array:
	var p0: Vector2 = c[i]["p"]
	var p1: Vector2 = c[j]["p"]
	var chord := p0.distance_to(p1)
	var m0 := _tangent(c, i, closed) * chord
	var m1 := _tangent(c, j, closed) * chord
	var k := maxi(1, ceili(chord / PATH_STEP))
	var out := PackedVector2Array()
	for step in k + 1:
		var s := float(step) / k
		var s2 := s * s
		var s3 := s2 * s
		out.append(p0 * (2 * s3 - 3 * s2 + 1) + m0 * (s3 - 2 * s2 + s) + p1 * (-2 * s3 + 3 * s2) + m1 * (s3 - s2))
	return out


static func _tangent(c: Array, i: int, closed: bool) -> Vector2:
	if c[i]["axis"] != Vector2.ZERO:
		return c[i]["axis"]
	var n := c.size()
	var before: Vector2 = c[posmod(i - 1, n)]["p"] if i > 0 or closed else c[i]["p"]
	var after: Vector2 = c[(i + 1) % n]["p"] if i < n - 1 or closed else c[i]["p"]
	var d := after - before
	return d.normalized() if d.length() > 1e-6 else Vector2.RIGHT


# The two edges of a run's wall, `width` across, the corners mitred.
static func ribbon(points: PackedVector2Array, closed: bool, width: float) -> Array:
	var n := points.size()
	var half := width * 0.5
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in n:
		var into := Vector2.ZERO
		var onward := Vector2.ZERO
		if k > 0 or closed:
			into = (points[k] - points[posmod(k - 1, n)]).normalized()
		if k < n - 1 or closed:
			onward = (points[(k + 1) % n] - points[k]).normalized()
		if into == Vector2.ZERO:
			into = onward
		if onward == Vector2.ZERO:
			onward = into
		var n0 := Vector2(into.y, -into.x)
		var n1 := Vector2(onward.y, -onward.x)
		var normal := (n0 + n1).normalized() if (n0 + n1).length() > 1e-6 else n0
		var reach := half / maxf(normal.dot(n0), 1.0 / MITER_LIMIT)
		left.append(points[k] + normal * reach)
		right.append(points[k] - normal * reach)
	return [left, right]


# The ground each run's wall covers, a quad to a joint, and the frame of each
# gate it goes through, as wide as the wall.
static func path_polygons(path: Dictionary, doc: Dictionary) -> Array:
	var out: Array = []
	var width := float(path["width"])
	for run in path.get("runs", []):
		var points := points_of(run["points"])
		var edges := ribbon(points, run["closed"], width)
		var left: PackedVector2Array = edges[0]
		var right: PackedVector2Array = edges[1]
		var n := points.size()
		for k in (n if run["closed"] else n - 1):
			var m := (k + 1) % n
			out.append(PackedVector2Array([left[k], left[m], right[m], right[k]]))
	for gate in gates_in(path):
		var frame := gate_frame(doc, gate)
		if frame.is_empty():
			continue
		var along: Vector2 = frame["axis"] * GATE_HALF_GAP
		var across := Vector2(along.y, -along.x).normalized() * width * 0.5
		var at: Vector2 = frame["at"]
		out.append(PackedVector2Array([at - along - across, at + along - across, at + along + across, at - along + across]))
	return out


static func points_of(rows: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in rows:
		out.append(_v(p))
	return out


# The merlons along a run: MERLON_FIRST from its start and MERLON_STEP apart
# as on a straight wall, or, round a closed one, as many as fit evenly. Each
# [its middle, its yaw in degrees].
static func merlons_along(points: PackedVector2Array, closed: bool, width: float, side: String,
		step: float) -> Array:
	var n := points.size()
	var ends: Array = []
	var total := 0.0
	for k in (n if closed else n - 1):
		var a := points[k]
		var b := points[(k + 1) % n]
		ends.append([total, a, b])
		total += a.distance_to(b)
	var at: Array = []
	if closed:
		var count := floori(total / step)
		for k in count:
			at.append((k + 0.5) * total / count)
	else:
		var room := total - MERLON_FIRST - MERLON_END
		if room >= 0.0:
			for k in floori(room / step) + 1:
				at.append(MERLON_FIRST + k * step)
	var out: Array = []
	var off := width * 0.5 - MERLON_INSET
	var s := 0
	for distance: float in at:
		while s < ends.size() - 1 and float(ends[s + 1][0]) <= distance:
			s += 1
		var a: Vector2 = ends[s][1]
		var b: Vector2 = ends[s][2]
		var d := (b - a).normalized()
		var left := Vector2(d.y, -d.x)
		var p: Vector2 = a + d * (distance - float(ends[s][0])) + (left if side == "left" else -left) * off
		out.append([p, rad_to_deg(atan2(-d.y, d.x))])
	return out


# What a path makes, into the path: its runs and its merlons.
static func lay_path(path: Dictionary, doc: Dictionary) -> void:
	var runs: Array = []
	var merlons: Array = []
	for run in runs_of(path, doc):
		var rows: Array = []
		for p in run["points"]:
			rows.append(_a(p))
		runs.append({"closed": run["closed"], "points": rows})
		if path.has("merlons"):
			for m in merlons_along(points_of(rows), run["closed"], float(path["width"]),
					path["merlons"]["side"], float(path["merlons"]["step"])):
				var p: Vector2 = m[0]
				merlons.append([Level3DIO.round_mm(p.x), Level3DIO.round_mm(p.y), snappedf(m[1], 0.001)])
	path["runs"] = runs
	path["merlon_at"] = merlons


# How far `p` is from the path's wall.
static func distance_to_path(path: Dictionary, p: Vector2) -> float:
	var best := INF
	for run in path.get("runs", []):
		var points := points_of(run["points"])
		var n := points.size()
		for k in (n if run["closed"] else n - 1):
			var q := Geometry2D.get_closest_point_to_segment(p, points[k], points[(k + 1) % n])
			best = minf(best, p.distance_to(q))
	return maxf(best - float(path["width"]) * 0.5, 0.0)


static func path_length(path: Dictionary) -> float:
	var total := 0.0
	for run in path.get("runs", []):
		var points := points_of(run["points"])
		var n := points.size()
		for k in (n if run["closed"] else n - 1):
			total += points[k].distance_to(points[(k + 1) % n])
	return total


# Where a gate at `at`, across `axis`, goes into `path`: {"after": the element
# it goes after, "inside": the points within its frame, which it replaces},
# or {} when the path does not pass near enough -- or passes only where it
# runs north to south (runs_across). The path is measured by its points,
# which the curve goes through.
static func gate_insertion(path: Dictionary, doc: Dictionary, at: Vector2, axis: Vector2) -> Dictionary:
	var elements: Array = path["points"]
	var n := elements.size()
	var best := -1
	var best_d := GATE_REACH + float(path["width"]) * 0.5
	for k in (n if path["closed"] else n - 1):
		var a: Variant = _element_at(elements[k], doc)
		var b: Variant = _element_at(elements[(k + 1) % n], doc)
		if a == null or b == null or not runs_across(a, b, axis):
			continue
		var d := at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
		if d < best_d:
			best_d = d
			best = k
	if best < 0:
		return {}
	var inside: Array = []
	for k in n:
		var e: Variant = elements[k]
		if is_gate_point(e):
			continue
		var rel := _v(e) - at
		if absf(rel.dot(axis)) < GATE_HALF_GAP + 0.05 and absf(rel.dot(Vector2(axis.y, -axis.x))) < GATE_REACH:
			inside.append(k)
	return {"after": best, "inside": inside}
