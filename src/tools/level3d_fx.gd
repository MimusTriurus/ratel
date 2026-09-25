# What the 3D preview's procedural effects share -- the gun's dust and chips
# (level3d_gun.gd), the rocket's smoke and debris (level3d_rocket.gd): their
# cel-shading, docs/cel-shading.md, and the faceted balls they are made of.
#
# The stage and the units are cel-shaded in Blender, by modifiers the glTF
# export applies; these are built at run time, so their contour is a shader
# instead, level3d_contour.gdshader, the next pass of their material, CONTOUR
# wide as the level's is. Their two-tone light is the preview's _toon, as
# everything's is, which a material only gets if it is on the mesh when the
# node enters the tree.
#
# A ball is an icosphere with its faces flat, as the blasts' puffs and the
# smoke in the stage's destruction are: under two-tone light each facet is lit
# or not, which is what makes a puff read as a lump of dust and not a bubble.
class_name Level3DFx
extends RefCounted

const CONTOUR := 0.014
const CONTOUR_SHADER := preload("res://src/tools/level3d_contour.gdshader")

# The icosahedron: twelve corners on three golden rectangles.
const _T := 1.618034
const _CORNERS := [
	Vector3(-1, _T, 0), Vector3(1, _T, 0), Vector3(-1, -_T, 0), Vector3(1, -_T, 0),
	Vector3(0, -1, _T), Vector3(0, 1, _T), Vector3(0, -1, -_T), Vector3(0, 1, -_T),
	Vector3(_T, 0, -1), Vector3(_T, 0, 1), Vector3(-_T, 0, -1), Vector3(-_T, 0, 1),
]
const _FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
	[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
	[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]


# `material` with a contour drawn round it. `extent` is the mesh's radius
# about its origin -- 1 for a ball, 0.5 for a unit box -- or 0 to grow it along
# the normals instead (level3d_contour.gdshader).
static func contour(material: BaseMaterial3D, extent := 1.0) -> BaseMaterial3D:
	var line := ShaderMaterial.new()
	line.shader = CONTOUR_SHADER
	line.set_shader_parameter("width", CONTOUR)
	line.set_shader_parameter("extent", extent)
	material.next_pass = line
	return material


# A crater, radius 1 to the foot of its rim (level3d_rocket.gd, _crater): three
# meshes off one ring, the rim's inner foot, so that they meet.
#
# The rim is thrown-up sand in a ring -- up from the hole's edge at RIM_IN to a
# crest at RIM_TOP, down to the ground at RIM_OUT -- ragged in radius and
# height, its facets flat so that the side to the sun is lit and the far one
# not. Its inner wall is steep, steeper than the sun is low (47 degrees up),
# so the half of it with its back to the sun is in shadow and the other half
# lit: the hole's two tones. The outer slope is gentle and lit all round. Each
# face is one colour, as the models' are, and the crest is a black chamfer,
# as their sharp edges are -- the line that draws the ring from above.
#
# The hole goes on down below the ground, a bowl BOWL_DEPTH deep, scorched
# down to its floor. The ground cannot be cut, and Compatibility has no
# decals, so the bowl is drawn through it: the mask, the opening, marks the
# stencil, and the bowl is drawn where it is marked and nowhere else
# (level3d_crater_mask.gdshader, level3d_crater_bowl.gdshader).
#
# `crater_height` gives vehicles the same shape.
const RIM_IN := 0.5
const RIM_TOP := 0.62
const RIM_OUT := 1.0
const RIM_HEIGHT := 0.2
const BOWL_DEPTH := 0.22
const RIM_SEGMENTS := 11
# The crest's chamfer, in the unit crater: OUTLINE (docs/cel-shading.md) on a
# crater of 0.7 m.
const RIM_LINE := 0.016
# sRGB, as vertex colours are taken: the sand dug out, a little browner than
# the sand it lies on; its inner face scorched, and more so further down.
const RIM_SAND := Color(0.86, 0.53, 0.1)
const RIM_SCORCHED := Color(0.5, 0.3, 0.1)
const RIM_BLACK := Color(0.0, 0.0, 0.0)
const SOOT := Color(0.2, 0.13, 0.07)


# {"rim", "mask", "bowl"}.
static func crater_mesh(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Down from the crest: its two edges; the inner foot, where the ground
	# is; two rings of the bowl, and the middle of its floor. And the outer
	# foot.
	var crest_in: Array[Vector3] = []
	var crest_out: Array[Vector3] = []
	var foot: Array[Vector3] = []
	var wall: Array[Vector3] = []
	var floor_edge: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i in RIM_SEGMENTS:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / RIM_SEGMENTS
		var way := Vector3(cos(a), 0.0, sin(a))
		var crest := RIM_TOP * rng.randf_range(0.95, 1.05)
		var height := RIM_HEIGHT * rng.randf_range(0.75, 1.25)
		var inner := RIM_IN * rng.randf_range(0.93, 1.05)
		crest_in.append(way * crest + Vector3.UP * height)
		crest_out.append(way * (crest + RIM_LINE) + Vector3.UP * (height - RIM_LINE * 0.3))
		foot.append(way * inner)
		# The wall goes on down as steep as the rim's inner face, then
		# rounds into the floor.
		wall.append(way * inner * 0.72 + Vector3.DOWN * BOWL_DEPTH * rng.randf_range(0.6, 0.75))
		floor_edge.append(way * inner * 0.38 + Vector3.DOWN * BOWL_DEPTH * rng.randf_range(0.92, 1.0))
		outer.append(way * RIM_OUT * rng.randf_range(0.9, 1.08))
	var bottom := Vector3.DOWN * BOWL_DEPTH
	return {
		"rim": _bands([foot, crest_in, crest_out, outer], [RIM_SCORCHED, RIM_BLACK, RIM_SAND]),
		"mask": _fan(Vector3.ZERO, foot, RIM_BLACK).commit(),
		# The floor only a shade darker than the walls: in soot it read as a
		# black hole through the middle.
		"bowl": _bands([floor_edge, wall, foot], [RIM_SCORCHED.lerp(SOOT, 0.15), RIM_SCORCHED],
				_fan(bottom, floor_edge, RIM_SCORCHED.lerp(SOOT, 0.3))),
	}


# Rings of RIM_SEGMENTS points joined band by band, each band one colour, on
# to `st` if one is given.
static func _bands(rings: Array, colours: Array, st: SurfaceTool = null) -> ArrayMesh:
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in RIM_SEGMENTS:
		var j := (i + 1) % RIM_SEGMENTS
		for r in colours.size():
			var c: Color = colours[r]
			var quad := [[rings[r][i], c], [rings[r][j], c], [rings[r + 1][j], c], [rings[r + 1][i], c]]
			_face_up(st, quad[0], quad[1], quad[2])
			_face_up(st, quad[0], quad[2], quad[3])
	return st.commit()


# A fan from `centre` to a ring, in one colour, on a fresh SurfaceTool, left
# uncommitted for _bands to go on with.
static func _fan(centre: Vector3, ring: Array[Vector3], colour: Color) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in RIM_SEGMENTS:
		_face_up(st, [centre, colour], [ring[i], colour], [ring[(i + 1) % RIM_SEGMENTS], colour])
	return st



# One flat-shaded triangle of [position, colour] corners, wound to face up.
static func _face_up(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var normal: Vector3 = (b[0] - a[0]).cross(c[0] - a[0]).normalized()
	# Godot's front faces wind clockwise seen from their front, which puts
	# the cross product behind them.
	if normal.y > 0.0:
		var swap := b
		b = c
		c = swap
	else:
		normal = -normal
	st.set_normal(normal)
	for corner in [a, b, c]:
		st.set_color(corner[1])
		st.add_vertex(corner[0])


# How far a crater of radius `size` at `centre` (x, z) raises or lowers the
# ground at `at`: RIM_HEIGHT on the crest, falling smoothly to nothing at
# either foot, and a bowl BOWL_DEPTH deep inside.
static func crater_height(centre: Vector2, size: float, at: Vector2) -> float:
	var d := centre.distance_to(at) / size
	if d >= RIM_OUT:
		return 0.0
	if d >= RIM_TOP:
		return size * RIM_HEIGHT * smoothstep(RIM_OUT, RIM_TOP, d)
	if d >= RIM_IN:
		return size * RIM_HEIGHT * smoothstep(RIM_IN, RIM_TOP, d)
	return -size * BOWL_DEPTH * (1.0 - (d / RIM_IN) * (d / RIM_IN))


# A ball of radius about 1: an icosahedron split `subdivisions` times, each
# corner pushed in or out by up to `jitter` so that no two look alike, its
# faces flat.
static func ball(subdivisions: int, jitter: float, seed: int) -> ArrayMesh:
	var corners: Array[Vector3] = []
	for c in _CORNERS:
		corners.append((c as Vector3).normalized())
	var faces: Array = _FACES.duplicate(true)
	for _i in subdivisions:
		var middles := {}
		var split: Array = []
		for f in faces:
			var m: Array[int] = []
			for k in 3:
				var a: int = f[k]
				var b: int = f[(k + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not middles.has(key):
					middles[key] = corners.size()
					corners.append((corners[a] + corners[b]).normalized())
				m.append(middles[key])
			split.append_array([[f[0], m[0], m[2]], [f[1], m[1], m[0]], [f[2], m[2], m[1]], [m[0], m[1], m[2]]])
		faces = split
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in corners.size():
		corners[i] *= 1.0 + rng.randf_range(-jitter, jitter)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a := corners[f[0]]
		var b := corners[f[1]]
		var c := corners[f[2]]
		var normal := (b - a).cross(c - a).normalized()
		# Godot's front faces wind clockwise seen from outside, which puts
		# the cross product inward.
		if normal.dot(a + b + c) > 0.0:
			var swap := b
			b = c
			c = swap
		else:
			normal = -normal
		st.set_normal(normal)
		for p in [a, b, c]:
			st.add_vertex(p)
	return st.commit()
