# The level editor's picture of the ground (Level3DGround): heights on a
# CELL grid, coloured by what each cell is, cut into CHUNK-cell pieces so
# that a dab rebuilds only the pieces round it. Rough on purpose -- the
# Blender builder makes the real ground out of the same file -- but the
# heights follow the builder's rule, so a hill or a shore stands where it
# will be built:
#
#   land    its rise.
#   slope   the profile's height at t = d_brow / (d_brow + d_waterline),
#           plus the rise of the brow it comes down from, fading to nothing
#           at the waterline.
#   water   the profile's foot by the distance past the waterline, then the
#           bed.
#
# Distances are chamfer distances between cell centres, each worked out over
# a window SEARCH wider than the cells it is for, which is all a slope looks.
class_name Level3DGroundView
extends Node3D

const CELL := 0.2
const CHUNK := 64

const SAND := Color(0.94, 0.56, 0.0)
const HILL := Color(0.82, 0.58, 0.22)
const FLOOR := Color(0.2, 0.38, 0.16)
const SLOPE_COLOUR := Color(0.55, 0.36, 0.18)
const BED_COLOUR := Color(0.3, 0.24, 0.18)
const RIVER_BED := Color(0.28, 0.3, 0.22)
const WATER_COLOUR := Color(0.1, 0.4, 0.75, 0.55)

const LAND := 1
const SLOPE := 0
const WATER := 2

var ground: Level3DGround
var grid: Level3DTerrain.Grid
var water_level := -1.0
var _slope: Array = []
var _foot: Array = []
var _bed := -1.3
var _foot_reach := 0.1

var _kind := PackedByteArray()      # LAND, SLOPE, WATER per cell
var _extra := PackedByteArray()     # forest, river
var _height := PackedFloat32Array()
var _chunks := {}                   # Vector2i -> MeshInstance3D
var _material: StandardMaterial3D
var _water: MeshInstance3D


func setup(doc: Dictionary, of: Level3DGround) -> void:
	ground = of
	var terrain: Dictionary = doc["terrain"]
	var profile: Dictionary = terrain["profiles"][terrain.get("profile", "shore")]
	_slope = profile["slope"]
	_foot = profile["foot"]
	_bed = float(_foot[-1][1])
	_foot_reach = float(_foot[-1][0])
	water_level = float(_slope[-1][1])
	grid = Level3DTerrain.Grid.new(of.bounds(), CELL)
	_kind.resize(grid.w * grid.h)
	_extra.resize(grid.w * grid.h)
	_height.resize(grid.w * grid.h)
	for child in get_children():
		child.queue_free()
	_chunks.clear()
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	_add_water()
	refresh(Rect2i(0, 0, of.grid.w, of.grid.h))


# Rebuilds the picture over a rectangle of the rasters' cells.
func refresh(raster_rect: Rect2i) -> void:
	if not raster_rect.has_area():
		return
	var g := ground.grid
	var lo := grid.cell_of(Vector2(g.x0 + raster_rect.position.x * g.r, g.z0 + raster_rect.position.y * g.r))
	var hi := grid.cell_of(Vector2(g.x0 + raster_rect.end.x * g.r, g.z0 + raster_rect.end.y * g.r))
	var all := Rect2i(0, 0, grid.w, grid.h)
	var reach := ceili(Level3DTerrain.SEARCH / CELL) + 1
	# What changed, the cells whose height that can move, and the window their
	# distances are worked out over.
	var changed := Rect2i(lo, hi - lo + Vector2i.ONE).intersection(all)
	var inner := changed.grow(reach).intersection(all)
	var window := inner.grow(reach).intersection(all)
	_sample(changed)
	_heights(inner, window)
	var c0 := (inner.position - Vector2i.ONE).max(Vector2i.ZERO) / CHUNK
	var c1 := (inner.end) / CHUNK
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			_build_chunk(Vector2i(cx, cy))


func height_at(p: Vector2) -> float:
	var fx := clampf((p.x - grid.x0) / CELL - 0.5, 0.0, grid.w - 1.001)
	var fz := clampf((p.y - grid.z0) / CELL - 0.5, 0.0, grid.h - 1.001)
	var i := int(fx)
	var j := int(fz)
	var a := lerpf(_height[j * grid.w + i], _height[j * grid.w + i + 1], fx - i)
	var b := lerpf(_height[(j + 1) * grid.w + i], _height[(j + 1) * grid.w + i + 1], fx - i)
	return lerpf(a, b, fz - j)


func _sample(r: Rect2i) -> void:
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			var bits := ground.bits_at(grid.centre(i, j))
			var k := j * grid.w + i
			_kind[k] = LAND if bits & Level3DGround.LAND else WATER if bits & Level3DGround.WATER else SLOPE
			_extra[k] = bits & (Level3DGround.FOREST | Level3DGround.RIVER)


func _heights(inner: Rect2i, window: Rect2i) -> void:
	var ww := window.size.x
	var wh := window.size.y
	var n := ww * wh
	var land := PackedFloat32Array()
	var wet := PackedFloat32Array()
	var dry := PackedFloat32Array()
	var brow_rise := PackedFloat32Array()
	land.resize(n)
	wet.resize(n)
	dry.resize(n)
	brow_rise.resize(n)
	var far := 1e9
	for j in wh:
		for i in ww:
			var k := (window.position.y + j) * grid.w + window.position.x + i
			var m := j * ww + i
			var kind := _kind[k]
			land[m] = 0.0 if kind == LAND else far
			wet[m] = 0.0 if kind == WATER else far
			dry[m] = 0.0 if kind != WATER else far
			brow_rise[m] = ground.rise_at(grid.centre(window.position.x + i, window.position.y + j)) \
					if kind == LAND else 0.0
	_chamfer(land, ww, wh, brow_rise)
	_chamfer(wet, ww, wh)
	_chamfer(dry, ww, wh)
	var half := CELL * 0.5
	for j in range(inner.position.y, inner.end.y):
		for i in range(inner.position.x, inner.end.x):
			var k := j * grid.w + i
			var m := (j - window.position.y) * ww + (i - window.position.x)
			match _kind[k]:
				LAND:
					_height[k] = brow_rise[m]
				WATER:
					var d := maxf(dry[m] * CELL - half, 0.0)
					_height[k] = Level3DTerrain.profile_at(_foot, d) if d < _foot_reach else _bed
				_:
					var db := maxf(land[m] * CELL - half, 0.0)
					var dw := maxf(wet[m] * CELL - half, 0.0)
					if db >= Level3DTerrain.SEARCH and dw >= Level3DTerrain.SEARCH:
						_height[k] = 0.0
						continue
					var t := db / maxf(db + dw, 1e-6)
					_height[k] = Level3DTerrain.profile_at(_slope, t) + brow_rise[m] * (1.0 - t)


# Two-pass chamfer distances, in cells, from the cells at 0; `carry`, when
# given, is taken along from each cell's nearest source.
static func _chamfer(d: PackedFloat32Array, w: int, h: int, carry := PackedFloat32Array()) -> void:
	var diag := sqrt(2.0)
	var with := not carry.is_empty()
	for j in h:
		for i in w:
			var k := j * w + i
			var best := d[k]
			var from := -1
			if i > 0 and d[k - 1] + 1.0 < best:
				best = d[k - 1] + 1.0
				from = k - 1
			if j > 0:
				if d[k - w] + 1.0 < best:
					best = d[k - w] + 1.0
					from = k - w
				if i > 0 and d[k - w - 1] + diag < best:
					best = d[k - w - 1] + diag
					from = k - w - 1
				if i < w - 1 and d[k - w + 1] + diag < best:
					best = d[k - w + 1] + diag
					from = k - w + 1
			if from >= 0:
				d[k] = best
				if with:
					carry[k] = carry[from]
	for j in range(h - 1, -1, -1):
		for i in range(w - 1, -1, -1):
			var k := j * w + i
			var best := d[k]
			var from := -1
			if i < w - 1 and d[k + 1] + 1.0 < best:
				best = d[k + 1] + 1.0
				from = k + 1
			if j < h - 1:
				if d[k + w] + 1.0 < best:
					best = d[k + w] + 1.0
					from = k + w
				if i < w - 1 and d[k + w + 1] + diag < best:
					best = d[k + w + 1] + diag
					from = k + w + 1
				if i > 0 and d[k + w - 1] + diag < best:
					best = d[k + w - 1] + diag
					from = k + w - 1
			if from >= 0:
				d[k] = best
				if with:
					carry[k] = carry[from]


func _build_chunk(chunk: Vector2i) -> void:
	var i0 := chunk.x * CHUNK
	var j0 := chunk.y * CHUNK
	if i0 >= grid.w - 1 or j0 >= grid.h - 1:
		return
	var i1 := mini(i0 + CHUNK, grid.w - 1)
	var j1 := mini(j0 + CHUNK, grid.h - 1)
	var cw := i1 - i0 + 1
	var ch := j1 - j0 + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	vertices.resize(cw * ch)
	normals.resize(cw * ch)
	colours.resize(cw * ch)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var k := j * grid.w + i
			var v := (j - j0) * cw + (i - i0)
			var p := grid.centre(i, j)
			vertices[v] = Vector3(p.x, _height[k], p.y)
			var hl := _height[k - 1] if i > 0 else _height[k]
			var hr := _height[k + 1] if i < grid.w - 1 else _height[k]
			var hu := _height[k - grid.w] if j > 0 else _height[k]
			var hd := _height[k + grid.w] if j < grid.h - 1 else _height[k]
			normals[v] = Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
			var colour: Color
			match _kind[k]:
				LAND:
					if _extra[k] & Level3DGround.FOREST:
						colour = FLOOR
					elif _height[k] > 0.02:
						colour = HILL
					else:
						colour = SAND
				WATER:
					colour = RIVER_BED if _extra[k] & Level3DGround.RIVER else BED_COLOUR
				_:
					colour = SLOPE_COLOUR
			colours[v] = colour
	var indices := PackedInt32Array()
	indices.resize((cw - 1) * (ch - 1) * 6)
	var n := 0
	for j in ch - 1:
		for i in cw - 1:
			var v := j * cw + i
			indices[n] = v
			indices[n + 1] = v + 1
			indices[n + 2] = v + cw
			indices[n + 3] = v + 1
			indices[n + 4] = v + cw + 1
			indices[n + 5] = v + cw
			n += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance: MeshInstance3D = _chunks.get(chunk)
	if instance == null:
		instance = MeshInstance3D.new()
		instance.material_override = _material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_chunks[chunk] = instance
	instance.mesh = mesh


func _add_water() -> void:
	var b := ground.bounds()
	var plane := PlaneMesh.new()
	plane.size = b.size
	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.mesh = plane
	_water.position = Vector3(b.get_center().x, water_level, b.get_center().y)
	var wet := StandardMaterial3D.new()
	wet.albedo_color = WATER_COLOUR
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness = 0.3
	_water.material_override = wet
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)
