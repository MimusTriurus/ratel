# Wrote stage 1's ground into its level file, assets/level3d/stage-0.json:
# the land, the water, the shore's profile and the forest, traced off the
# level as it was built by hand in Blender. docs/level-editor-plan.md,
# stage 4; Level3DTerrain says what the blocks mean.
#
# jackal_stage1.glb is built from the file now, so tracing it would only
# trace the file back into itself, and a run with no --glb compares instead
# (see below). The hand-built glb is in git, the last one at 7d0abb6; to
# trace it again, put it where Godot imports it and name it:
#
#     git show 7d0abb6:resources/3d/jackal_stage1.glb > build/level3d/jackal_stage1_hand.glb
#     godot --path . --headless --import
#     godot --path . --headless --script tools/level_terrain_from_glb.gd -- --glb res://build/level3d/jackal_stage1_hand.glb
#
# 1. The ground meshes are rasterized from above into heights every SAMPLE,
#    the highest face winning; where there are none the ground is the bed.
#    The forest floor is rasterized into a mask the same way.
# 2. The brow is where the ground comes up to BROW, just under the sand; the
#    waterline where it goes down through the water's level. Both are traced
#    by marching squares and simplified to TOLERANCE. The water is cut into
#    sea and river along RIVER_CUT: they are one body in the glb, joined at
#    the mouth, and only the sea has surf.
# 3. The profile is measured, not assumed: across every slope, the median
#    height at each t, and below every waterline, at each distance.
# 4. The file is read back through Level3DTerrain.heights and compared with
#    the glb on a grid of CHECK, which is the number that says whether the
#    file describes the level.
#
# Only these blocks are rewritten; entities, objects and the grid are kept.
#
# --compare, or no --glb at all, traces nothing and writes nothing: it
# rasterizes that glb (jackal_stage1.glb by default) and compares the level
# file with it. That is how a level built from the file
# (tools/blender/build_level.py) is held to it.
extends SceneTree

const STAGE := 0
const LEVEL_GLB := "res://resources/3d/jackal_stage1.glb"
# The level's ground, by name prefix: the sand, the shore's slope and its old
# cliff, the river's banks and bed, and what lies past the map's edges. Not
# the plates buried under it all, the skirts (vertical), or Shore_Lines. The
# forest floor is ground as well: north of the map, Forest_Floor_N5 is all
# the ground there is.
const GROUND: Array[String] = ["Sand", "Beach_", "Cliff", "Terrain_", "Beyond_East_Flat",
		"Beyond_East_River", "Forest_Floor"]
const FOREST: Array[String] = ["Forest_Floor"]
# And past the east edge the forest floor is a material of Beyond_East_Flat
# rather than an object of its own.
const FOREST_MATERIAL := "J_ForestFloor"
# The level as far as it is built: the sea to x = -27 (SEA_WEST in the
# preview), the land to the east edge of Beyond_East and to NORTH.
const BOUNDS := Rect2(-27.0, -142.0, 46.2, 175.6)
# What the preview's camera may show: the frame it measured off this glb
# (Level3DPreview, level_aabb: every mesh but Beyond* and Ocean, the sea's
# old edge west and the map's end north). A level built from the file has
# ground to its bounds, so the frame cannot be measured off that one.
const FRAME := [-27.0, -135.0312, 16.917, 33.654]
const SAMPLE := 0.05
const CHECK := 0.1
const BED := -1.3
const WATER_LEVEL := -1.0
const BROW := -0.01
const TOLERANCE := 0.015
const FOREST_TOLERANCE := 0.03
# The river is the water east of the map's west edge and north of the south
# shore's end: x > -15, z < -15. The mouth, between the spit at z = -19.72 and
# z = -15, counts as river.
const RIVER_CUT := Vector2(-15.0, -15.0)
const SLOPE_BINS := 20
const FOOT_STEP := 0.025
const FOOT_REACH := 0.6

var grid: Level3DTerrain.Grid


func _init() -> void:
	var started := Time.get_ticks_msec()
	grid = Level3DTerrain.Grid.new(BOUNDS, SAMPLE)
	var args := OS.get_cmdline_user_args()
	var glb := args[args.find("--glb") + 1] if args.has("--glb") else LEVEL_GLB
	var level: Node3D = (load(glb) as PackedScene).instantiate()
	var heights := PackedFloat32Array()
	heights.resize(grid.w * grid.h)
	heights.fill(BED)
	var forest := PackedFloat32Array()
	forest.resize(grid.w * grid.h)
	for child in level.get_children():
		var node := child as MeshInstance3D
		if node == null:
			continue
		var name := String(node.name)
		if GROUND.any(func(p): return name.begins_with(p)):
			_rasterize(node, heights, false)
		if FOREST.any(func(p): return name.begins_with(p)):
			_rasterize(node, forest, true)
		elif GROUND.any(func(p): return name.begins_with(p)):
			_rasterize(node, forest, true, FOREST_MATERIAL)
	level.free()
	print("  %s rasterized %d x %d at %.2f m (%.1f s)" % [glb, grid.w, grid.h, SAMPLE, _since(started)])
	if args.has("--compare") or not args.has("--glb"):
		_compare(Level3DIO.read(STAGE), heights, forest)
		quit()
		return

	var n := grid.w * grid.h
	var land_field := PackedFloat32Array()
	land_field.resize(n)
	var sea_field := PackedFloat32Array()
	sea_field.resize(n)
	var river_field := PackedFloat32Array()
	river_field.resize(n)
	for j in grid.h:
		for i in grid.w:
			var k := j * grid.w + i
			var p := grid.centre(i, j)
			var wet := WATER_LEVEL - heights[k]
			land_field[k] = heights[k] - BROW
			var river_side := minf(p.x - RIVER_CUT.x, RIVER_CUT.y - p.y)
			sea_field[k] = minf(wet, -river_side)
			river_field[k] = minf(wet, river_side)
	var forest_field := _smoothed(forest)

	var land := _polygons(land_field, TOLERANCE, "land")
	for polygon in land:
		polygon["height"] = 0.0
		polygon["profile"] = "shore"
	var water: Array = []
	for polygon in _polygons(sea_field, TOLERANCE, "sea"):
		polygon["kind"] = "sea"
		polygon["level"] = WATER_LEVEL
		water.append(polygon)
	for polygon in _polygons(river_field, TOLERANCE, "river"):
		polygon["kind"] = "river"
		polygon["level"] = WATER_LEVEL
		water.append(polygon)
	var forests := _polygons(forest_field, FOREST_TOLERANCE, "forest")
	for k in forests.size():
		forests[k]["spacing"] = 0.55
		forests[k]["jitter"] = 0.22
		forests[k]["pines"] = 0.12
		forests[k]["seed"] = k + 1
	print("  traced %d land, %d water, %d forest polygons, %d points (%.1f s)" % [
		land.size(), water.size(), forests.size(),
		_count(land) + _count(water) + _count(forests), _since(started)])

	var terrain := {
		"bounds": [BOUNDS.position.x, BOUNDS.position.y, BOUNDS.end.x, BOUNDS.end.y],
		"frame": FRAME,
		"profile": "shore",
		"profiles": {"shore": {"slope": [[0.0, 0.0], [1.0, WATER_LEVEL]],
				"foot": [[0.0, WATER_LEVEL], [FOOT_REACH, BED]]}},
		"land": land,
	}
	terrain["profiles"]["shore"] = _measure_profile(terrain, water, heights)
	print("  profile measured (%.1f s)" % _since(started))

	var doc := Level3DIO.read(STAGE)
	doc["terrain"] = terrain
	doc["water"] = water
	doc["forest"] = forests
	var error := Level3DIO.save(doc)
	print("%s -- %s" % [Level3DIO.path(STAGE), "written" if error == OK else "FAILED"])
	_compare(Level3DIO.read(STAGE), heights, forest)
	print("  done in %.1f s" % _since(started))
	quit(0 if error == OK else 1)


static func _since(started: int) -> float:
	return (Time.get_ticks_msec() - started) / 1000.0


# The mesh's faces seen from above: every cell centre inside one takes the
# face's height there, the highest face winning -- or, for a mask, 1. With a
# material, only the faces of that material.
func _rasterize(node: MeshInstance3D, into: PackedFloat32Array, mask: bool, material := "") -> void:
	var xf := node.transform
	var mesh := node.mesh
	for s in mesh.get_surface_count():
		if material != "":
			var m := mesh.surface_get_material(s)
			if m == null or m.resource_name != material:
				continue
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var index := PackedInt32Array()
		if indices == null or (indices as PackedInt32Array).is_empty():
			for k in vertices.size():
				index.append(k)
		else:
			index = indices
		var world := PackedVector3Array()
		world.resize(vertices.size())
		for k in vertices.size():
			world[k] = xf * vertices[k]
		for t in range(0, index.size() - 2, 3):
			var a := world[index[t]]
			var b := world[index[t + 1]]
			var c := world[index[t + 2]]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var ac := Vector2(c.x - a.x, c.z - a.z)
			var area := ab.cross(ac)
			if absf(area) < 1e-10:
				continue
			var i0 := maxi(0, ceili((minf(a.x, minf(b.x, c.x)) - grid.x0) / grid.r - 0.5))
			var i1 := mini(grid.w - 1, floori((maxf(a.x, maxf(b.x, c.x)) - grid.x0) / grid.r - 0.5))
			var j0 := maxi(0, ceili((minf(a.z, minf(b.z, c.z)) - grid.z0) / grid.r - 0.5))
			var j1 := mini(grid.h - 1, floori((maxf(a.z, maxf(b.z, c.z)) - grid.z0) / grid.r - 0.5))
			var inv := 1.0 / area
			for j in range(j0, j1 + 1):
				var z := grid.z0 + (j + 0.5) * grid.r
				for i in range(i0, i1 + 1):
					var x := grid.x0 + (i + 0.5) * grid.r
					var ap := Vector2(x - a.x, z - a.z)
					var wb := ap.cross(ac) * inv
					var wc := ab.cross(ap) * inv
					var wa := 1.0 - wb - wc
					if wa < -1e-6 or wb < -1e-6 or wc < -1e-6:
						continue
					var k := j * grid.w + i
					if mask:
						into[k] = 1.0
					else:
						var y := wa * a.y + wb * b.y + wc * c.y
						if y > into[k]:
							into[k] = y


# The forest floor's mask as a field: a 3 x 3 mean, less a half, so its edge
# is traced between cells instead of along their stairs.
func _smoothed(mask: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(mask.size())
	for j in grid.h:
		for i in grid.w:
			var sum := 0.0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := clampi(i + di, 0, grid.w - 1)
					var jj := clampi(j + dj, 0, grid.h - 1)
					sum += mask[jj * grid.w + ii]
			out[j * grid.w + i] = sum / 9.0 - 0.5
	return out


# Traced, simplified, nested and sorted north to south, then west to east, by
# each polygon's first point after sorting its ring to start at its
# northernmost -- an order that does not move when a stretch far off changes.
func _polygons(field: PackedFloat32Array, tolerance: float, stem: String) -> Array:
	var rings := Level3DTerrain.contours(grid, field)
	var simple: Array[PackedVector2Array] = []
	for r in rings:
		var s := Level3DTerrain.simplify(_from_north(r), tolerance)
		if s.size() >= 3 and absf(Level3DTerrain.area(s)) > SAMPLE * SAMPLE * 4.0:
			simple.append(s)
	var polys := Level3DTerrain.polygons(simple)
	polys.sort_custom(func(p, q):
		var a: Vector2 = p["outer"][0]
		var b: Vector2 = q["outer"][0]
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array = []
	for k in polys.size():
		var outer := _from_north(polys[k]["outer"])
		var holes: Array = []
		for hole in polys[k]["holes"]:
			holes.append(_points(_from_north(hole)))
		out.append({"id": "%s_%d" % [stem, k], "outer": _points(outer), "holes": holes})
	return out


static func _from_north(ring: PackedVector2Array) -> PackedVector2Array:
	var first := 0
	for k in ring.size():
		if ring[k].y < ring[first].y or (ring[k].y == ring[first].y and ring[k].x < ring[first].x):
			first = k
	var out := ring.slice(first)
	out.append_array(ring.slice(0, first))
	return out


# Rounded to the millimetre, and put on the bounds where a ring runs along
# them: marching squares closes a ring between the last cell's centre and
# the border outside it, a centimetre or two short of the edge, and the sliver
# left between the ring and the bounds is ground no polygon claims.
static func _points(ring: PackedVector2Array) -> Array:
	var out: Array = []
	var snap := SAMPLE
	for p in ring:
		var x := p.x
		var z := p.y
		if absf(x - BOUNDS.position.x) < snap:
			x = BOUNDS.position.x
		elif absf(x - BOUNDS.end.x) < snap:
			x = BOUNDS.end.x
		if absf(z - BOUNDS.position.y) < snap:
			z = BOUNDS.position.y
		elif absf(z - BOUNDS.end.y) < snap:
			z = BOUNDS.end.y
		out.append([Level3DIO.round_mm(x), Level3DIO.round_mm(z)])
	return out


static func _count(polygons: Array) -> int:
	var n := 0
	for p in polygons:
		n += (p["outer"] as Array).size()
		for hole in p["holes"]:
			n += (hole as Array).size()
	return n


# Across the slopes the file now draws: the median height of the glb in each
# of SLOPE_BINS slices of t, and under the water in each FOOT_STEP of distance
# past the waterline, on the CHECK grid.
func _measure_profile(terrain: Dictionary, water: Array, heights: PackedFloat32Array) -> Dictionary:
	var check := Level3DTerrain.Grid.new(BOUNDS, CHECK)
	var land_mask := Level3DTerrain.rasterize_all(check, terrain["land"])
	var water_mask := Level3DTerrain.rasterize_all(check, water)
	var brows := Level3DTerrain.edges(check, terrain["land"], land_mask)
	var shores := Level3DTerrain.edges(check, water, water_mask)
	var slope_bins: Array = []
	for b in SLOPE_BINS:
		slope_bins.append([])
	var foot_bins: Array = []
	for b in ceili(FOOT_REACH / FOOT_STEP):
		foot_bins.append([])
	for j in check.h:
		for i in check.w:
			var k := j * check.w + i
			if land_mask[k]:
				continue
			var p := check.centre(i, j)
			var h := _sample(heights, p)
			if water_mask[k]:
				var d := shores.distance(p, FOOT_REACH)
				if d < FOOT_REACH:
					foot_bins[mini(int(d / FOOT_STEP), foot_bins.size() - 1)].append(h)
				continue
			var db := brows.distance(p, Level3DTerrain.SEARCH)
			var dw := shores.distance(p, Level3DTerrain.SEARCH)
			if db >= Level3DTerrain.SEARCH and dw >= Level3DTerrain.SEARCH:
				continue  # no slope here: see Level3DTerrain.heights
			var t := db / maxf(db + dw, 1e-6)
			slope_bins[mini(int(t * SLOPE_BINS), SLOPE_BINS - 1)].append(h)
	var slope: Array = [[0.0, 0.0]]
	for b in SLOPE_BINS:
		if not (slope_bins[b] as Array).is_empty():
			slope.append([Level3DIO.round_mm((b + 0.5) / SLOPE_BINS), Level3DIO.round_mm(_median(slope_bins[b]))])
	slope.append([1.0, WATER_LEVEL])
	# Down to the first step that reaches the bed: past it the table would only
	# say BED again.
	var foot: Array = [[0.0, WATER_LEVEL]]
	for b in foot_bins.size():
		if (foot_bins[b] as Array).is_empty():
			continue
		var h := _median(foot_bins[b])
		if h <= BED + 0.001:
			foot.append([Level3DIO.round_mm((b + 0.5) * FOOT_STEP), BED])
			break
		foot.append([Level3DIO.round_mm((b + 0.5) * FOOT_STEP), Level3DIO.round_mm(h)])
	return {"slope": slope, "foot": foot}


func _sample(heights: PackedFloat32Array, p: Vector2) -> float:
	var c := grid.cell_of(p)
	c = c.clamp(Vector2i.ZERO, Vector2i(grid.w - 1, grid.h - 1))
	return heights[c.y * grid.w + c.x]


static func _median(values: Array) -> float:
	values.sort()
	return float(values[values.size() / 2])


# How far the file's ground is from the glb's: by what the file calls each
# cell, the share within 5 and 15 cm and the rms; and how often file and glb
# agree on what is land, what is water and where the forest is.
func _compare(doc: Dictionary, heights: PackedFloat32Array, forest: PackedFloat32Array) -> void:
	var check := Level3DTerrain.Grid.new(BOUNDS, CHECK)
	var from_file := Level3DTerrain.heights(check, doc["terrain"], doc["water"])
	var file_heights: PackedFloat32Array = from_file["height"]
	var kinds: PackedByteArray = from_file["kind"]
	var forest_mask := Level3DTerrain.rasterize_all(check, doc["forest"])
	var names := ["land", "slope", "water"]
	var stats: Array = []
	for n in 3:
		stats.append({"count": 0, "sq": 0.0, "near": 0, "close": 0})
	var land_agree := 0
	var water_agree := 0
	var forest_agree := 0
	var total := check.w * check.h
	# -- --debug out.png: the check grid, land grey, water blue, slope yellow,
	# and every cell more than 15 cm out red.
	var args := OS.get_cmdline_user_args()
	var debug: Image = null
	if args.has("--debug"):
		debug = Image.create(check.w, check.h, false, Image.FORMAT_RGB8)
	for j in check.h:
		for i in check.w:
			var k := j * check.w + i
			var p := check.centre(i, j)
			var glb := _sample(heights, p)
			var d := absf(file_heights[k] - glb)
			if debug:
				var colour: Color = [Color(0.6, 0.6, 0.6), Color(0.9, 0.8, 0.2), Color(0.2, 0.4, 0.9)][kinds[k]]
				debug.set_pixel(i, j, Color.RED if d >= 0.15 else colour)
			var s: Dictionary = stats[kinds[k]]
			s.count += 1
			s.sq += d * d
			if d < 0.05:
				s.near += 1
			if d < 0.15:
				s.close += 1
			if (kinds[k] == Level3DTerrain.LAND) == (glb > BROW):
				land_agree += 1
			if (kinds[k] == Level3DTerrain.WATER) == (glb < WATER_LEVEL):
				water_agree += 1
			var c := grid.cell_of(p).clamp(Vector2i.ZERO, Vector2i(grid.w - 1, grid.h - 1))
			if (forest_mask[k] == 1) == (forest[c.y * grid.w + c.x] > 0.5):
				forest_agree += 1
	if debug:
		debug.save_png(args[args.find("--debug") + 1])
	print("  file against glb, every %.2f m:" % CHECK)
	for n in 3:
		var s: Dictionary = stats[n]
		if s.count == 0:
			continue
		print("    %-5s %7d cells  rms %.3f m  within 5 cm %5.1f%%  within 15 cm %5.1f%%" % [
			names[n], s.count, sqrt(s.sq / s.count), 100.0 * s.near / s.count, 100.0 * s.close / s.count])
	print("    land agrees %.2f%%, water %.2f%%, forest %.2f%%" % [
		100.0 * land_agree / total, 100.0 * water_agree / total, 100.0 * forest_agree / total])
