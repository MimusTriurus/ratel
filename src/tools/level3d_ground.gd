# The ground of a 3D level as rasters: what the level editor paints and what
# the level file keeps beside it (docs/level-editor-plan.md, part 2).
#
#   ground  a byte per cell: LAND, WATER (RIVER with it where the water is a
#           river's rather than the sea's) and FOREST bits. A cell that is
#           neither land nor water is shore slope, which Level3DTerrain
#           builds off the profile between the two.
#   rise    how far the ground is raised above its level, in metres -- hills
#           on the land, fading out down the slope. RISE_STEP a step, 0 to
#           MAX_RISE, in its PNG.
#
# Both lie on one Level3DTerrain.Grid over terrain.bounds, cell
# terrain.raster.cell, and are saved as PNGs next to the level file, where an
# image editor can open them: the ground as RGB -- red land, green forest,
# blue water, half blue a river -- and the rise as grey.
#
# The rasters are the source. The file's land, water and forest polygons,
# which the Blender builder builds from, are traced off them on save
# (trace()), the way tools/level_terrain_from_glb.gd traced stage 1 off its
# glb; the same rasters trace to the same polygons, so saving what nobody
# changed changes nothing.
class_name Level3DGround
extends RefCounted

const LAND := 1
const WATER := 2
const RIVER := 4
const FOREST := 8

const CELL := 0.05
const RISE_STEP := 0.05
const MAX_RISE := 255 * RISE_STEP
# How wide a shore the water and land brushes leave between the two.
const SHORE := 0.8
const RASTER_DIR := "rasters/"

const TOLERANCE := 0.015
const FOREST_TOLERANCE := 0.03
# A forest's rule, for every forest traced (the ones stage 1's glb had).
const FOREST_RULE := {"spacing": 0.55, "jitter": 0.22, "pines": 0.12}

var grid: Level3DTerrain.Grid
var ground := PackedByteArray()
var rise := PackedFloat32Array()


static func bounds_of(doc: Dictionary) -> Rect2:
	var b: Array = doc["terrain"]["bounds"]
	return Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))


func _init(bounds := Rect2(), cell := CELL) -> void:
	if bounds.has_area():
		grid = Level3DTerrain.Grid.new(bounds, cell)
		ground.resize(grid.w * grid.h)
		rise.resize(grid.w * grid.h)


# --- Reading and writing ----------------------------------------------------------


# The level's rasters: read from the PNGs its terrain.raster names, relative
# to `dir` (the level file's directory), or -- for a level that has none yet
# -- rasterized from its polygons (from_polygons).
static func load_for(doc: Dictionary, dir: String) -> Level3DGround:
	var raster: Dictionary = doc["terrain"].get("raster", {})
	if raster.is_empty():
		return from_polygons(doc)
	var out := Level3DGround.new(bounds_of(doc), float(raster["cell"]))
	var ground_image := Image.load_from_file(dir.path_join(raster["ground"]))
	var rise_image := Image.load_from_file(dir.path_join(raster["height"]))
	if ground_image == null or rise_image == null:
		push_error("Cannot read the rasters %s, %s under %s" % [raster["ground"], raster["height"], dir])
		return null
	if ground_image.get_width() != out.grid.w or ground_image.get_height() != out.grid.h \
			or rise_image.get_width() != out.grid.w or rise_image.get_height() != out.grid.h:
		push_error("The rasters are %dx%d and %dx%d; the level's bounds at %.2f m make %dx%d" % [
			ground_image.get_width(), ground_image.get_height(), rise_image.get_width(),
			rise_image.get_height(), out.grid.r, out.grid.w, out.grid.h])
		return null
	ground_image.convert(Image.FORMAT_RGB8)
	rise_image.convert(Image.FORMAT_L8)
	var rgb := ground_image.get_data()
	for k in out.ground.size():
		var bits := 0
		if rgb[k * 3] >= 128:
			bits |= LAND
		if rgb[k * 3 + 1] >= 128:
			bits |= FOREST
		var blue := rgb[k * 3 + 2]
		if blue >= 64:
			bits |= WATER
			if blue < 192:
				bits |= RIVER
		out.ground[k] = bits
	var steps := rise_image.get_data()
	for k in steps.size():
		out.rise[k] = steps[k] * RISE_STEP
	return out


# Writes the two PNGs under `dir` and names them in the document's
# terrain.raster, by the level file's name: <name>-ground.png, <name>-height.png.
func save_rasters(doc: Dictionary, dir: String, name: String) -> Error:
	var steps := PackedByteArray()
	steps.resize(rise.size())
	for k in rise.size():
		steps[k] = clampi(roundi(rise[k] / RISE_STEP), 0, 255)
	var rgb := PackedByteArray()
	rgb.resize(ground.size() * 3)
	for k in ground.size():
		var bits := ground[k]
		rgb[k * 3] = 255 if bits & LAND else 0
		rgb[k * 3 + 1] = 255 if bits & FOREST else 0
		rgb[k * 3 + 2] = (128 if bits & RIVER else 255) if bits & WATER else 0
	var raster := {
		"cell": grid.r, "shore": float(doc["terrain"].get("raster", {}).get("shore", SHORE)),
		"ground": RASTER_DIR + name + "-ground.png", "height": RASTER_DIR + name + "-height.png",
	}
	DirAccess.make_dir_recursive_absolute(dir.path_join(RASTER_DIR))
	var error := Image.create_from_data(grid.w, grid.h, false, Image.FORMAT_RGB8, rgb) \
			.save_png(dir.path_join(raster["ground"]))
	if error == OK:
		error = Image.create_from_data(grid.w, grid.h, false, Image.FORMAT_L8, steps) \
				.save_png(dir.path_join(raster["height"]))
	if error == OK:
		doc["terrain"]["raster"] = raster
	return error


# The rasters of a level that only has polygons: land and water as
# Level3DTerrain.heights calls them -- which is also what makes the sliver
# along the bounds land -- the river's bit from the water's kind, the forest
# from its polygons. The rise is nothing.
static func from_polygons(doc: Dictionary, cell := CELL) -> Level3DGround:
	var out := Level3DGround.new(bounds_of(doc), cell)
	var water: Array = doc.get("water", [])
	var kinds: PackedByteArray = Level3DTerrain.heights(out.grid, doc["terrain"], water)["kind"]
	var rivers := Level3DTerrain.rasterize_all(out.grid,
			water.filter(func(p): return p.get("kind") == "river"))
	var forest := Level3DTerrain.rasterize_all(out.grid, doc.get("forest", []))
	var land := Level3DTerrain.rasterize_all(out.grid, doc["terrain"]["land"])
	# heights() calls land whatever lies in no polygon and near no edge of
	# one -- a sliver where a ring runs along the bounds -- which in the sea's
	# corner is not land. Those cells take the kind of the nearest cell that
	# has one of its own, spread to them breadth first.
	var unsure := PackedByteArray()
	unsure.resize(out.ground.size())
	var queue := PackedInt32Array()
	for k in out.ground.size():
		var bits := 0
		match kinds[k]:
			Level3DTerrain.LAND:
				bits = LAND
				if not land[k]:
					unsure[k] = 1
			Level3DTerrain.WATER:
				bits = WATER | (RIVER if rivers[k] else 0)
		out.ground[k] = bits
	var w := out.grid.w
	for k in out.ground.size():
		if not unsure[k]:
			continue
		for n in [k - 1, k + 1, k - w, k + w]:
			if n >= 0 and n < unsure.size() and not unsure[n] and absi(n % w - k % w) <= 1:
				queue.append(n)
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		for n in [k - 1, k + 1, k - w, k + w]:
			if n >= 0 and n < unsure.size() and unsure[n] and absi(n % w - k % w) <= 1:
				unsure[n] = 0
				out.ground[n] = out.ground[k]
				queue.append(n)
	for k in out.ground.size():
		if forest[k]:
			out.ground[k] |= FOREST
	return out


# --- Painting ---------------------------------------------------------------------
#
# A brush is a dab at a time: a disc of `radius` metres round a point, what
# it does by the tool. Land and water are hard-edged, and each leaves a band
# of `shore` round itself where the other one was, which becomes slope: water
# painted into the land cuts a shore, land painted into the water builds one.
# The forest grows on land only, and goes where land does. The rise is soft,
# `strength` metres at the middle of a dab and nothing at its rim.
#
# A stroke keeps what it painted over, a TILE-cell square at a time, the
# first time it touches one; end_stroke() hands that over as the stroke's
# undo, and swap() puts it back.

enum Tool { LAND, SEA, RIVER, FOREST, CLEAR_FOREST, RAISE, LOWER, SMOOTH, FLATTEN }
const TILE := 64

var _stroke := {}           # Vector2i tile -> [ground, rise] as they were


func begin_stroke() -> void:
	_stroke = {}


func end_stroke() -> Dictionary:
	var out := _stroke
	_stroke = {}
	return out


# Puts back the tiles of a stroke's undo, and returns what they held, which
# undoes the undo, and the cells they cover.
func swap(tiles: Dictionary) -> Array:
	var out := {}
	var changed := Rect2i()
	for tile in tiles:
		var r := _tile_rect(tile)
		out[tile] = _copy(r)
		_paste(r, tiles[tile][0], tiles[tile][1])
		changed = r if not changed.has_area() else changed.merge(r)
	return [out, changed]


func _tile_rect(tile: Vector2i) -> Rect2i:
	return Rect2i(tile * TILE, Vector2i(TILE, TILE)).intersection(Rect2i(0, 0, grid.w, grid.h))


func _copy(r: Rect2i) -> Array:
	var g := PackedByteArray()
	var f := PackedFloat32Array()
	for j in range(r.position.y, r.end.y):
		var k := j * grid.w
		g.append_array(ground.slice(k + r.position.x, k + r.end.x))
		f.append_array(rise.slice(k + r.position.x, k + r.end.x))
	return [g, f]


func _paste(r: Rect2i, g: PackedByteArray, f: PackedFloat32Array) -> void:
	var n := 0
	for j in range(r.position.y, r.end.y):
		var k := j * grid.w
		for i in range(r.position.x, r.end.x):
			ground[k + i] = g[n]
			rise[k + i] = f[n]
			n += 1


func _touch(r: Rect2i) -> void:
	for ty in range(r.position.y / TILE, (r.end.y - 1) / TILE + 1):
		for tx in range(r.position.x / TILE, (r.end.x - 1) / TILE + 1):
			var tile := Vector2i(tx, ty)
			if not _stroke.has(tile):
				_stroke[tile] = _copy(_tile_rect(tile))


# The cells a disc of `reach` metres round `at` covers, clipped to the grid.
func _disc_rect(at: Vector2, reach: float) -> Rect2i:
	var lo := grid.cell_of(at - Vector2(reach, reach))
	var hi := grid.cell_of(at + Vector2(reach, reach)) + Vector2i.ONE
	return Rect2i(lo, hi - lo).intersection(Rect2i(0, 0, grid.w, grid.h))


# One dab; returns the cells it may have changed. `target` is FLATTEN's
# height, the rise where its stroke began.
func dab(tool: Tool, at: Vector2, radius: float, strength := 0.1, shore := SHORE,
		target := 0.0) -> Rect2i:
	var hard := tool in [Tool.LAND, Tool.SEA, Tool.RIVER]
	var reach := radius + (shore if hard else 0.0)
	var r := _disc_rect(at, reach)
	if not r.has_area():
		return r
	_touch(r)
	var w := grid.w
	var r2 := radius * radius
	var reach2 := reach * reach
	var before := PackedFloat32Array()
	var bw := r.size.x
	if tool == Tool.SMOOTH:
		before = _copy(r)[1]
	# SMOOTH averages over a ring this many cells out.
	var spread := maxi(1, roundi(radius / grid.r / 4.0))
	var blend := clampf(strength * 4.0, 0.0, 1.0)
	for j in range(r.position.y, r.end.y):
		var z := grid.z0 + (j + 0.5) * grid.r - at.y
		for i in range(r.position.x, r.end.x):
			var x := grid.x0 + (i + 0.5) * grid.r - at.x
			var d2 := x * x + z * z
			if d2 > reach2:
				continue
			var k := j * w + i
			var bits := ground[k]
			match tool:
				Tool.LAND:
					if d2 <= r2:
						ground[k] = (bits & FOREST) | LAND
					elif bits & WATER:
						ground[k] = 0
				Tool.SEA, Tool.RIVER:
					if d2 <= r2:
						ground[k] = WATER | (RIVER if tool == Tool.RIVER else 0)
					elif bits & LAND:
						ground[k] = 0
				Tool.FOREST:
					if bits & LAND:
						ground[k] = bits | FOREST
				Tool.CLEAR_FOREST:
					ground[k] = bits & ~FOREST
				_:
					var fall := 1.0 - d2 / r2
					fall *= fall
					match tool:
						Tool.RAISE:
							rise[k] = minf(rise[k] + strength * fall, MAX_RISE)
						Tool.LOWER:
							rise[k] = maxf(rise[k] - strength * fall, 0.0)
						Tool.FLATTEN:
							rise[k] = lerpf(rise[k], target, blend * fall)
						Tool.SMOOTH:
							var sum := 0.0
							for dj in [-spread, 0, spread]:
								for di in [-spread, 0, spread]:
									var ii: int = clampi(i + di, r.position.x, r.end.x - 1) - r.position.x
									var jj: int = clampi(j + dj, r.position.y, r.end.y - 1) - r.position.y
									sum += before[jj * bw + ii]
							rise[k] = lerpf(rise[k], sum / 9.0, blend * fall)
	return r


func rise_at(at: Vector2) -> float:
	var c := grid.cell_of(at)
	return rise[c.y * grid.w + c.x] if grid.has(c) else 0.0


func bits_at(at: Vector2) -> int:
	var c := grid.cell_of(at)
	return ground[c.y * grid.w + c.x] if grid.has(c) else 0


# Every cell one kind: a level started as land, or as water.
func fill(bits: int) -> void:
	ground.fill(bits)

# --- Polygons ---------------------------------------------------------------------


# The document's land, water and forest polygons, traced off the rasters.
# Each mask is smoothed over 3x3 cells first, so that a ring runs between
# cell centres rather than round them in steps. Land is at height 0 on the
# document's profile; water at -1.0, split into sea and river by the bit.
func trace(doc: Dictionary) -> void:
	var terrain: Dictionary = doc["terrain"]
	var level := -1.0
	for polygon in doc.get("water", []):
		level = float(polygon.get("level", level))
		break
	var land := _polygons(_field(LAND, 0), TOLERANCE, "land")
	for polygon in land:
		polygon["height"] = 0.0
		polygon["profile"] = terrain.get("profile", "shore")
	var water: Array = []
	for kind in ["sea", "river"]:
		var field := _field(WATER, RIVER if kind == "river" else 0, RIVER)
		for polygon in _polygons(field, TOLERANCE, kind):
			polygon["kind"] = kind
			polygon["level"] = level
			water.append(polygon)
	var forests := _polygons(_field(FOREST, 0), FOREST_TOLERANCE, "forest")
	for k in forests.size():
		forests[k].merge(FOREST_RULE)
		forests[k]["seed"] = k + 1
	# Land, then its keys in the order the file writes them.
	terrain["land"] = land.map(func(p): return {"id": p["id"], "height": p["height"],
			"profile": p["profile"], "outer": p["outer"], "holes": p["holes"]})
	doc["water"] = water.map(func(p): return {"id": p["id"], "kind": p["kind"],
			"level": p["level"], "outer": p["outer"], "holes": p["holes"]})
	doc["forest"] = forests.map(func(p): return {"id": p["id"], "spacing": p["spacing"],
			"jitter": p["jitter"], "pines": p["pines"], "seed": p["seed"],
			"outer": p["outer"], "holes": p["holes"]})


# +0.5 where a cell has `bits` (and, of `mask`, exactly `want`), -0.5 where it
# has not, averaged over the 3x3 cells round it.
func _field(bits: int, want: int, mask := 0) -> PackedFloat32Array:
	var w := grid.w
	var h := grid.h
	var on := PackedFloat32Array()
	on.resize(w * h)
	for k in on.size():
		var b := ground[k]
		on[k] = 1.0 if (b & bits) == bits and (b & mask) == want else 0.0
	# Separable: rows, then columns, each clamped at the edge.
	var rows := PackedFloat32Array()
	rows.resize(w * h)
	for j in h:
		var base := j * w
		for i in w:
			rows[base + i] = on[base + maxi(i - 1, 0)] + on[base + i] + on[base + mini(i + 1, w - 1)]
	var out := PackedFloat32Array()
	out.resize(w * h)
	for j in h:
		var up := maxi(j - 1, 0) * w
		var here := j * w
		var down := mini(j + 1, h - 1) * w
		for i in w:
			out[here + i] = (rows[up + i] + rows[here + i] + rows[down + i]) / 9.0 - 0.5
	return out


# Traced, simplified, nested and sorted north to south, then west to east, by
# each polygon's first point after its ring is turned to start at its
# northernmost -- an order that does not move when a stretch far off changes.
func _polygons(field: PackedFloat32Array, tolerance: float, stem: String) -> Array:
	var simple: Array[PackedVector2Array] = []
	for r in Level3DTerrain.contours(grid, field):
		var s := Level3DTerrain.simplify(_from_north(r), tolerance)
		if s.size() >= 3 and absf(Level3DTerrain.area(s)) > grid.r * grid.r * 4.0:
			simple.append(s)
	var polys := Level3DTerrain.polygons(simple)
	for polygon in polys:
		polygon["outer"] = _from_north(polygon["outer"])
	polys.sort_custom(func(p, q):
		var a: Vector2 = p["outer"][0]
		var b: Vector2 = q["outer"][0]
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array = []
	for k in polys.size():
		var holes: Array = []
		for hole in polys[k]["holes"]:
			holes.append(_points(_from_north(hole)))
		out.append({"id": "%s_%d" % [stem, k], "outer": _points(polys[k]["outer"]), "holes": holes})
	return out


# The level's bounds, which the rasters cover.
func bounds() -> Rect2:
	return Rect2(grid.x0, grid.z0, grid.w * grid.r, grid.h * grid.r)


static func _from_north(ring: PackedVector2Array) -> PackedVector2Array:
	var first := 0
	for k in ring.size():
		if ring[k].y < ring[first].y or (ring[k].y == ring[first].y and ring[k].x < ring[first].x):
			first = k
	var out := ring.slice(first)
	out.append_array(ring.slice(0, first))
	return out


# Rounded to the millimetre, and put on the bounds where a ring runs along
# them: marching squares closes a ring between the last cell's centre and the
# border outside it, a centimetre short of the edge, and the sliver left
# between the ring and the bounds is ground no polygon claims -- in the sea's
# corner, a wedge of slope down to the bed.
func _points(ring: PackedVector2Array) -> Array:
	var b := bounds()
	var out: Array = []
	for p in ring:
		var x := p.x
		var z := p.y
		if absf(x - b.position.x) < grid.r:
			x = b.position.x
		elif absf(x - b.end.x) < grid.r:
			x = b.end.x
		if absf(z - b.position.y) < grid.r:
			z = b.position.y
		elif absf(z - b.end.y) < grid.r:
			z = b.end.y
		out.append([Level3DIO.round_mm(x), Level3DIO.round_mm(z)])
	return out
