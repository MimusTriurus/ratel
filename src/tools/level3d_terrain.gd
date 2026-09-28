# The ground of a 3D level as its file describes it (docs/level-editor-plan.md,
# stage 4): land at a height inside its brow, water at its level inside its
# waterline, and between the two the shore's slope, read off a profile.
#
#   land    polygons, each an outer ring and holes, the brow of the sand: flat
#           at "height" inside.
#   water   polygons at "level", the line where the water meets the slope.
#   slope   everything between a brow and a waterline. A point there has come
#           t of the way across -- t = d_brow / (d_brow + d_waterline) -- and
#           the profile's "slope" table gives its height at t.
#   foot    under the water, the slope goes on down to the bed: the profile's
#           "foot" table, by distance past the waterline, ends at the bed.
#
# This is what the editor draws as a proxy and what the Blender builder
# builds with a better hand; tools/level_terrain_from_glb.gd wrote stage 1's
# from its glb, and measures how close it comes.
#
# Rasters here are row-major over a Grid, cell (i, j) sampled at its centre.
class_name Level3DTerrain
extends RefCounted

# How far a slope point looks for its brow and waterline, in metres. Stage 1's
# slopes are under 1.5 m across; a point further than this from either line
# is not on one.
const SEARCH := 3.0
const BUCKET := 1.0


class Grid:
	var x0: float
	var z0: float
	var r: float
	var w: int
	var h: int

	func _init(bounds: Rect2, cell: float) -> void:
		x0 = bounds.position.x
		z0 = bounds.position.y
		r = cell
		# A hair under before the ceiling: 46.2 / 0.1 is 462.00000000000006,
		# and a column past the bounds is ground nobody built. A thousandth of
		# a cell, because a Rect2 is single precision: its 175.6 is
		# 175.600006, 3512.0001 cells of 5 cm. (snappedf does not do it:
		# 3512.0000000000005 snaps to itself.)
		w = ceili(bounds.size.x / cell - 1e-3)
		h = ceili(bounds.size.y / cell - 1e-3)

	func centre(i: int, j: int) -> Vector2:
		return Vector2(x0 + (i + 0.5) * r, z0 + (j + 0.5) * r)

	func cell_of(p: Vector2) -> Vector2i:
		return Vector2i(floori((p.x - x0) / r), floori((p.y - z0) / r))

	func has(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


# Segments bucketed on a square grid, for the nearest distance from a point.
class SegmentIndex:
	var buckets := {}           # Vector2i -> PackedInt32Array of segment indices
	var a := PackedVector2Array()
	var b := PackedVector2Array()

	func add(p: Vector2, q: Vector2) -> void:
		var index := a.size()
		a.append(p)
		b.append(q)
		var lo := Vector2i((p.min(q) / BUCKET).floor())
		var hi := Vector2i((p.max(q) / BUCKET).floor())
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var key := Vector2i(x, y)
				if not buckets.has(key):
					buckets[key] = PackedInt32Array()
				var list: PackedInt32Array = buckets[key]
				list.append(index)
				buckets[key] = list

	# The distance to the nearest segment, or `cap` if there is none that near.
	func distance(p: Vector2, cap: float) -> float:
		var best := cap
		var reach := ceili(cap / BUCKET)
		var home := Vector2i((p / BUCKET).floor())
		for y in range(home.y - reach, home.y + reach + 1):
			for x in range(home.x - reach, home.x + reach + 1):
				var list: Variant = buckets.get(Vector2i(x, y))
				if list == null:
					continue
				for index in list as PackedInt32Array:
					var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a[index], b[index]))
					if d < best:
						best = d
		return best


# --- Rings and rasters ------------------------------------------------------------


static func ring(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


# The rings of a polygon entry of the file, outer first.
static func rings_of(polygon: Dictionary) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [ring(polygon["outer"])]
	for hole in polygon.get("holes", []):
		out.append(ring(hole))
	return out


# The cells whose centres are inside the rings, even-odd: an outer ring and its
# holes fill as the polygon. Scanline, with each edge filed under the rows it
# crosses, so a ring of thousands of points costs its own length and not that
# times the rows.
static func rasterize(grid: Grid, rings: Array, into := PackedByteArray()) -> PackedByteArray:
	if into.is_empty():
		into.resize(grid.w * grid.h)
	var crossings: Array = []
	crossings.resize(grid.h)
	for points in rings:
		var pts := points as PackedVector2Array
		var n := pts.size()
		for k in n:
			var p := pts[k]
			var q := pts[(k + 1) % n]
			if is_equal_approx(p.y, q.y):
				continue
			var lo := minf(p.y, q.y)
			var hi := maxf(p.y, q.y)
			var j0 := maxi(0, ceili((lo - grid.z0) / grid.r - 0.5))
			var j1 := mini(grid.h - 1, ceili((hi - grid.z0) / grid.r - 0.5) - 1)
			for j in range(j0, j1 + 1):
				var z := grid.z0 + (j + 0.5) * grid.r
				var x := p.x + (q.x - p.x) * (z - p.y) / (q.y - p.y)
				if crossings[j] == null:
					crossings[j] = PackedFloat32Array()
				var row: PackedFloat32Array = crossings[j]
				row.append(x)
				crossings[j] = row
	var mark := PackedByteArray()
	for j in grid.h:
		if crossings[j] == null:
			continue
		var row: PackedFloat32Array = crossings[j]
		row.sort()
		for k in range(0, row.size() - 1, 2):
			var i0 := maxi(0, ceili((row[k] - grid.x0) / grid.r - 0.5))
			var i1 := mini(grid.w - 1, ceili((row[k + 1] - grid.x0) / grid.r - 0.5) - 1)
			for i in range(i0, i1 + 1):
				into[j * grid.w + i] = 1
	return into


# Every polygon of a list, each filled even-odd and all of them together: land
# pieces and water bodies may share an edge, and overlap by a sliver there.
static func rasterize_all(grid: Grid, polygons: Array) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(grid.w * grid.h)
	for polygon in polygons:
		var one := rasterize(grid, rings_of(polygon))
		for k in mask.size():
			if one[k]:
				mask[k] = 1
	return mask


# The boundary segments of polygons that are a real edge of the mask: in on one
# side and out on the other. The edge two water bodies share, and the stretch
# of a ring along the level's bounds, are not a shore, and a point near them
# must not be given a slope.
static func edges(grid: Grid, polygons: Array, mask: PackedByteArray) -> SegmentIndex:
	var index := SegmentIndex.new()
	var probe := grid.r * 1.5
	for polygon in polygons:
		for points in rings_of(polygon):
			var n := points.size()
			for k in n:
				var p := points[k]
				var q := points[(k + 1) % n]
				var along := q - p
				if along.length_squared() < 1e-12:
					continue
				var normal := along.orthogonal().normalized() * probe
				var middle := (p + q) * 0.5
				var c1 := grid.cell_of(middle + normal)
				var c2 := grid.cell_of(middle - normal)
				if not grid.has(c1) or not grid.has(c2):
					continue
				if mask[c1.y * grid.w + c1.x] != mask[c2.y * grid.w + c2.x]:
					index.add(p, q)
	return index


static func profile_at(table: Array, t: float) -> float:
	if table.is_empty():
		return 0.0
	if t <= float(table[0][0]):
		return float(table[0][1])
	for k in range(1, table.size()):
		var t1 := float(table[k][0])
		if t <= t1:
			var t0 := float(table[k - 1][0])
			var f := (t - t0) / maxf(t1 - t0, 1e-9)
			return lerpf(float(table[k - 1][1]), float(table[k][1]), f)
	return float(table[-1][1])


# --- Heights --------------------------------------------------------------------


# The ground's height at every cell of `grid`, and what the cell is:
# "kind" is a PackedByteArray of LAND, SLOPE, WATER.
const LAND := 0
const SLOPE := 1
const WATER := 2


static func heights(grid: Grid, terrain: Dictionary, water: Array) -> Dictionary:
	var lands: Array = terrain["land"]
	var profile: Dictionary = terrain["profiles"][terrain.get("profile", "shore")]
	var slope: Array = profile["slope"]
	var foot: Array = profile["foot"]
	var foot_reach := float(foot[-1][0])
	var bed := float(foot[-1][1])
	var land_mask := rasterize_all(grid, lands)
	var water_mask := rasterize_all(grid, water)
	var brows := edges(grid, lands, land_mask)
	var shores := edges(grid, water, water_mask)
	var land_height := float(lands[0].get("height", 0.0)) if not lands.is_empty() else 0.0

	var out := PackedFloat32Array()
	out.resize(grid.w * grid.h)
	var kinds := PackedByteArray()
	kinds.resize(grid.w * grid.h)
	for j in grid.h:
		for i in grid.w:
			var k := j * grid.w + i
			if land_mask[k]:
				out[k] = land_height
				kinds[k] = LAND
				continue
			var p := grid.centre(i, j)
			if water_mask[k]:
				kinds[k] = WATER
				var d := shores.distance(p, foot_reach)
				out[k] = profile_at(foot, d) if d < foot_reach else bed
				continue
			var db := brows.distance(p, SEARCH)
			var dw := shores.distance(p, SEARCH)
			if db >= SEARCH and dw >= SEARCH:
				# Neither in a polygon nor near the edge of one: a sliver where a
				# ring runs along the bounds. Called land, which the level's edges
				# are.
				out[k] = land_height
				kinds[k] = LAND
				continue
			kinds[k] = SLOPE
			out[k] = profile_at(slope, db / maxf(db + dw, 1e-6))
	return {"height": out, "kind": kinds}


# --- Contours -------------------------------------------------------------------


# The closed rings where `field` crosses zero, in level metres: marching
# squares over the cell centres, with the grid bordered by -1 so that every
# ring closes inside it. Inside is where the field is positive. Rings are
# returned as they are found; nesting sorts outer from hole (polygons()).
static func contours(grid: Grid, field: PackedFloat32Array) -> Array[PackedVector2Array]:
	var w := grid.w
	var h := grid.h
	# The field bordered by -1 all round, so that the loop below reads it
	# straight: (i', j') = (i + 1, j + 1) at bw * j' + i'.
	var bw := w + 2
	var f := PackedFloat32Array()
	var edge := PackedFloat32Array()
	edge.resize(bw)
	edge.fill(-1.0)
	f.append_array(edge)
	var one := PackedFloat32Array([-1.0])
	for j in h:
		f.append_array(one)
		f.append_array(field.slice(j * w, (j + 1) * w))
		f.append_array(one)
	f.append_array(edge)
	# Crossing points by edge: key 2 * (j' * (w + 2) + i') + axis over the
	# bordered grid, axis 0 along x and 1 along z.
	var points := {}
	var links := {}
	for jb in h + 1:
		var row := jb * bw
		var below := row + bw
		# The cell's corners a b / d c, carried along the row.
		var va := f[row]
		var vd := f[below]
		for ib in w + 1:
			var vb := f[row + ib + 1]
			var vc := f[below + ib + 1]
			var case_ := (8 if va > 0 else 0) | (4 if vb > 0 else 0) 					| (2 if vc > 0 else 0) | (1 if vd > 0 else 0)
			if case_ == 0 or case_ == 15:
				va = vb
				vd = vc
				continue
			var i := ib - 1
			var j := jb - 1
			# The cell's four edges: top a-b, right b-c, bottom d-c, left a-d.
			var top := 2 * (row + ib)
			var bottom := 2 * (below + ib)
			var left := top + 1
			var right := 2 * (row + ib + 1) + 1
			var a := grid.centre(i, j)
			var crossed := {}
			if (va > 0) != (vb > 0):
				crossed[top] = a.lerp(grid.centre(i + 1, j), va / (va - vb))
			if (vb > 0) != (vc > 0):
				crossed[right] = grid.centre(i + 1, j).lerp(grid.centre(i + 1, j + 1), vb / (vb - vc))
			if (vd > 0) != (vc > 0):
				crossed[bottom] = grid.centre(i, j + 1).lerp(grid.centre(i + 1, j + 1), vd / (vd - vc))
			if (va > 0) != (vd > 0):
				crossed[left] = a.lerp(grid.centre(i, j + 1), va / (va - vd))
			for e in crossed:
				points[e] = crossed[e]
			var pairs: Array = []
			match case_:
				5, 10:
					# A saddle: joined round the centre the way its mean falls.
					var inside_centre := (va + vb + vc + vd) > 0
					if (case_ == 10) == inside_centre:
						pairs = [[top, right], [bottom, left]]
					else:
						pairs = [[top, left], [bottom, right]]
				_:
					var ends: Array = crossed.keys()
					pairs = [[ends[0], ends[1]]]
			for pair in pairs:
				_link(links, pair[0], pair[1])
				_link(links, pair[1], pair[0])
			va = vb
			vd = vc

	var rings: Array[PackedVector2Array] = []
	var seen := {}
	for start in links:
		if seen.has(start):
			continue
		var out := PackedVector2Array()
		var previous := -1
		var at: int = start
		while not seen.has(at):
			seen[at] = true
			out.append(points[at])
			var pair: Array = links[at]
			var next: int = pair[0] if pair[0] != previous else pair[1]
			previous = at
			at = next
		if out.size() >= 3:
			rings.append(out)
	return rings


static func _link(links: Dictionary, from: int, to: int) -> void:
	if not links.has(from):
		links[from] = [to]
	else:
		(links[from] as Array).append(to)


# Douglas-Peucker on a closed ring: split at the point furthest from the first,
# simplify both halves to `tolerance`.
static func simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	var n := points.size()
	if n < 4:
		return points
	var far := 0
	var far_d := -1.0
	for k in n:
		var d := points[0].distance_squared_to(points[k])
		if d > far_d:
			far_d = d
			far = k
	var keep := PackedByteArray()
	keep.resize(n)
	keep[0] = 1
	keep[far] = 1
	var stack: Array = [[0, far], [far, n]]
	while not stack.is_empty():
		var span: Array = stack.pop_back()
		var s: int = span[0]
		var e: int = span[1]
		if e - s < 2:
			continue
		var p := points[s]
		var q := points[e % n]
		var worst := -1
		var worst_d := tolerance
		for k in range(s + 1, e):
			var d := points[k].distance_to(Geometry2D.get_closest_point_to_segment(points[k], p, q))
			if d > worst_d:
				worst_d = d
				worst = k
		if worst >= 0:
			keep[worst] = 1
			stack.append([s, worst])
			stack.append([worst, e])
	var out := PackedVector2Array()
	for k in n:
		if keep[k]:
			out.append(points[k])
	return out


# Rings sorted into polygons: a ring inside an odd number of others is a hole
# of the innermost one that holds it; the rest are outer rings. Outer rings
# are wound one way and holes the other, as area() tells.
static func polygons(rings: Array[PackedVector2Array]) -> Array:
	var depth: Array[int] = []
	var parent: Array[int] = []
	for k in rings.size():
		var inside: Array[int] = []
		for m in rings.size():
			if m != k and Geometry2D.is_point_in_polygon(rings[k][0], rings[m]):
				inside.append(m)
		depth.append(inside.size())
		var best := -1
		for m in inside:
			if best < 0 or absf(area(rings[m])) < absf(area(rings[best])):
				best = m
		parent.append(best)
	var out: Array = []
	var by_ring := {}
	for k in rings.size():
		if depth[k] % 2 == 0:
			by_ring[k] = out.size()
			out.append({"outer": _wound(rings[k], true), "holes": []})
	for k in rings.size():
		if depth[k] % 2 == 1 and by_ring.has(parent[k]):
			(out[by_ring[parent[k]]]["holes"] as Array).append(_wound(rings[k], false))
	return out


static func area(points: PackedVector2Array) -> float:
	var sum := 0.0
	var n := points.size()
	for k in n:
		sum += points[k].cross(points[(k + 1) % n])
	return sum * 0.5


static func _wound(points: PackedVector2Array, outer: bool) -> PackedVector2Array:
	if (area(points) > 0) != outer:
		points.reverse()
	return points


# --- The proxy ------------------------------------------------------------------
#
# What the editor draws in the file's place: the ground as a height grid of
# `cell`, coloured by what each cell is; the water as its polygons at their
# level; the forest as cones and balls where its rule puts trees. Rough on
# purpose -- the Blender builder makes the real thing out of the same file --
# but every height is Level3DTerrain.heights', so it is right where it is.

const SAND := Color(0.94, 0.56, 0.0)
const FLOOR := Color(0.2, 0.38, 0.16)
const SLOPE_COLOUR := Color(0.55, 0.36, 0.18)
const BED_COLOUR := Color(0.3, 0.24, 0.18)
const SEA := Color(0.05, 0.3, 0.65, 0.75)
const RIVER := Color(0.15, 0.55, 0.75, 0.75)
const FLOOR_LIFT := 0.015


static func proxy(doc: Dictionary, cell: float) -> Node3D:
	var terrain: Dictionary = doc["terrain"]
	var water: Array = doc.get("water", [])
	var forests: Array = doc.get("forest", [])
	var b: Array = terrain["bounds"]
	var grid := Grid.new(Rect2(b[0], b[1], float(b[2]) - float(b[0]), float(b[3]) - float(b[1])), cell)
	var field := heights(grid, terrain, water)
	var h: PackedFloat32Array = field["height"]
	var kinds: PackedByteArray = field["kind"]
	var floor_mask := rasterize_all(grid, forests)

	var root := Node3D.new()
	root.name = "GroundProxy"
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	vertices.resize(grid.w * grid.h)
	colours.resize(grid.w * grid.h)
	for j in grid.h:
		for i in grid.w:
			var k := j * grid.w + i
			var p := grid.centre(i, j)
			var y := h[k]
			var colour: Color = [SAND, SLOPE_COLOUR, BED_COLOUR][kinds[k]]
			if kinds[k] == LAND and floor_mask[k]:
				colour = FLOOR
				y += FLOOR_LIFT
			vertices[k] = Vector3(p.x, y, p.y)
			colours[k] = colour
	var indices := PackedInt32Array()
	indices.resize((grid.w - 1) * (grid.h - 1) * 6)
	var n := 0
	for j in grid.h - 1:
		for i in grid.w - 1:
			var k := j * grid.w + i
			indices[n] = k
			indices[n + 1] = k + 1
			indices[n + 2] = k + grid.w
			indices[n + 3] = k + 1
			indices[n + 4] = k + grid.w + 1
			indices[n + 5] = k + grid.w
			n += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	ground.material_override = material
	root.add_child(ground)

	for polygon in water:
		var outer := ring(polygon["outer"])
		var triangles := Geometry2D.triangulate_polygon(outer)
		if triangles.is_empty():
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_normal(Vector3.UP)
		var y := float(polygon.get("level", -1.0))
		for t in triangles:
			surface.add_vertex(Vector3(outer[t].x, y, outer[t].y))
		var sheet := MeshInstance3D.new()
		sheet.name = "Water_" + str(polygon["id"])
		sheet.mesh = surface.commit()
		var wet := StandardMaterial3D.new()
		wet.albedo_color = SEA if polygon.get("kind") == "sea" else RIVER
		wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wet.cull_mode = BaseMaterial3D.CULL_DISABLED
		wet.roughness = 0.3
		sheet.material_override = wet
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sheet)

	root.add_child(_trees(grid, forests))
	return root


# The trees a forest's rule puts down, as tree_positions says.
static func _trees(grid: Grid, forests: Array) -> Node3D:
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	var pines := MultiMesh.new()
	pines.transform_format = MultiMesh.TRANSFORM_3D
	var broad: Array[Transform3D] = []
	var tall: Array[Transform3D] = []
	for polygon in forests:
		for tree in tree_positions(grid, polygon):
			var xf := Transform3D(Basis(Vector3.UP, tree.yaw).scaled(Vector3.ONE * tree.scale),
					Vector3(tree.at.x, FLOOR_LIFT, tree.at.y))
			(tall if tree.pine else broad).append(xf)
	var ball := SphereMesh.new()
	ball.radius = 0.32
	ball.height = 0.5
	ball.radial_segments = 8
	ball.rings = 4
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.26
	cone.height = 0.9
	cone.radial_segments = 8
	var root := Node3D.new()
	root.name = "Trees"
	for kind in [[crowns, broad, ball, Color(0.16, 0.45, 0.2), 0.55], [pines, tall, cone, Color(0.1, 0.32, 0.18), 0.45]]:
		var multi: MultiMesh = kind[0]
		var list: Array = kind[1]
		var shape: Mesh = kind[2]
		var material := StandardMaterial3D.new()
		material.albedo_color = kind[3]
		material.roughness = 1.0
		shape.surface_set_material(0, material)
		multi.mesh = shape
		multi.instance_count = list.size()
		for k in list.size():
			var xf: Transform3D = list[k]
			xf.origin.y += float(kind[4]) * xf.basis.get_scale().y
			multi.set_instance_transform(k, xf)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		root.add_child(instance)
	return root


# Where a forest's trees stand: one to each square of its spacing on a grid
# aligned to the level's origin, moved up to `jitter` either way, kept if it
# lands inside the forest; one in `pines` a pine. Every choice is hash01 of the
# square and the forest's seed, integer arithmetic on 32 bits, so the Blender
# builder can make the same forest in Python.
static func tree_positions(grid: Grid, polygon: Dictionary) -> Array:
	var spacing := float(polygon["spacing"])
	var jitter := float(polygon["jitter"])
	var pine_share := float(polygon["pines"])
	var seed := int(polygon["seed"])
	var rings := rings_of(polygon)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in rings[0]:
		lo = lo.min(p)
		hi = hi.max(p)
	var inside := rasterize(grid, rings)
	var out: Array = []
	for b in range(floori(lo.y / spacing), ceili(hi.y / spacing) + 1):
		for a in range(floori(lo.x / spacing), ceili(hi.x / spacing) + 1):
			var at := Vector2((a + 0.5) * spacing + (hash01(a, b, seed, 0) * 2.0 - 1.0) * jitter,
					(b + 0.5) * spacing + (hash01(a, b, seed, 1) * 2.0 - 1.0) * jitter)
			var c := grid.cell_of(at)
			if not grid.has(c) or not inside[c.y * grid.w + c.x]:
				continue
			out.append({
				"at": at, "pine": hash01(a, b, seed, 2) < pine_share,
				"yaw": hash01(a, b, seed, 3) * TAU, "scale": 0.7 + 0.4 * hash01(a, b, seed, 4),
			})
	return out


# A number in [0, 1) from integers, the same in any language with 64-bit
# integers: a multiply-xorshift mix, masked to 32 bits at every step.
static func hash01(a: int, b: int, seed: int, salt: int) -> float:
	const MASK := 0xFFFFFFFF
	var h := (a * 374761393 + b * 668265263 + seed * 1442695041 + salt * 3266489917) & MASK
	# Multipliers under 2^31, so that a 32-bit value times one stays inside a
	# signed 64-bit integer: GDScript would wrap where Python would not.
	h = ((h ^ (h >> 15)) * 1540483477) & MASK
	h = ((h ^ (h >> 13)) * 668265261) & MASK
	h = h ^ (h >> 16)
	return float(h) / 4294967296.0
