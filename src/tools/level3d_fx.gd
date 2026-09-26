# What the 3D preview's procedural effects share -- the guns' rounds and
# flashes and the gun's dust and chips (level3d_gun.gd, level3d_guns.gd), the
# rocket's fire, smoke and debris (level3d_rocket.gd):
# their cel-shading, docs/cel-shading.md, and the faceted balls they are made
# of.
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
const FIRE_SHADER := preload("res://src/tools/level3d_fire.gdshader")
const FIRE_CONTOUR_SHADER := preload("res://src/tools/level3d_fire_contour.gdshader")
const RIPPLE_SHADER := preload("res://src/tools/level3d_ripple.gdshader")
const ROUND_SHADER := preload("res://src/tools/level3d_round.gdshader")
# A round's colours, core, ring and rim, by EnemyBullet's `white`: the yellow
# round, which the player fires too, is the fire's white, yellow and red; the
# white one is the sprite's white, grey and black, the grey a little cold.
const ROUND_COLOURS := {
	false: [Color(1.0, 0.98, 0.85), Color(1.0, 0.86, 0.12), Color(0.6, 0.06, 0.02)],
	true: [Color(1.0, 1.0, 1.0), Color(0.62, 0.66, 0.72), Color(0.16, 0.16, 0.2)],
}
# The sprite's diamond is 24 px of its 32 across.
const ROUND_SIZE := 24.0 * Level3DMap.PX

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


# Fire, drawn round (level3d_fire.gdshader), for a ball: one material for
# every blast, each node's heat and burn its own instance uniforms, `age` and
# `burn`, which the contour's `burn` follows.
static func fire() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FIRE_SHADER
	var line := ShaderMaterial.new()
	line.shader = FIRE_CONTOUR_SHADER
	line.set_shader_parameter("width", CONTOUR)
	material.next_pass = line
	return material


const FLASH_ROCK := deg_to_rad(30.0)
# The jeep's machine gun's flash, its long flame from the bore, in the level's
# metres: every other gun's is this, scaled by what it is
# (Level3DGuns.muzzle_flash).
const FLASH_LENGTH := 0.5
const FLASH_WIDTH := 0.22

static var _round_mesh: QuadMesh
static var _round_materials := {}

# A round, EnemyBullet's `white` or yellow, not yet in the tree
# (level3d_round.gdshader): the game's size, and drawn over everything.
static func round_node(white: bool) -> MeshInstance3D:
	if _round_mesh == null:
		_round_mesh = QuadMesh.new()
		_round_mesh.size = Vector2.ONE * ROUND_SIZE
		for colour in ROUND_COLOURS:
			var material := ShaderMaterial.new()
			material.shader = ROUND_SHADER
			material.render_priority = Level3DGuns.ROUND_PRIORITY
			for k in 3:
				material.set_shader_parameter(["core", "ring", "rim"][k], ROUND_COLOURS[colour][k])
			_round_materials[colour] = material
	var node := MeshInstance3D.new()
	node.mesh = _round_mesh
	node.material_override = _round_materials[white]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# A muzzle's flash, fire in a star (level3d_fire.gdshader): a long flame out
# along the holder's +x, `length` and `width` metres, and two shorter ones
# splayed either side of it in the holder's x, z plane, which the holder's
# roll about x rocks round the shot -- by no more than FLASH_ROCK, since with
# them upright the star is one flame from above. Its parts, whose `age` is the caller's
# to run (set_fire), so that it cools from white to red as it goes out.
static func flash(holder: Node3D, mesh: Mesh, material: Material, length: float,
		width: float) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	for flame in [[0.0, 1.0, 0.0], [deg_to_rad(60.0), 0.5, 0.12], [deg_to_rad(-60.0), 0.5, 0.12]]:
		var way := Vector3.RIGHT.rotated(Vector3.UP, flame[0])
		var half: float = length * 0.5 * float(flame[1])
		var thick := width * 0.5 * (1.0 if flame[1] == 1.0 else 0.7)
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(part)
		part.transform = Transform3D(Basis(way * half, Vector3.UP * thick, way.cross(Vector3.UP) * thick),
				way * half + Vector3.RIGHT * length * float(flame[2]))
		parts.append(part)
	return parts


static func set_fire(parts: Array, age: float, burn := 0.0) -> void:
	for part in parts:
		(part as GeometryInstance3D).set_instance_shader_parameter("age", age)
		(part as GeometryInstance3D).set_instance_shader_parameter("burn", burn)


static var _ripple_mesh: PlaneMesh
static var _ripple_material: ShaderMaterial

# A ring of foam spreading on the water from `at`, the water's height there, out
# to `reach` metres over `life` seconds, starting `delay` in
# (level3d_ripple.gdshader): a patch of foam at first, opening into a ring
# that slows and thins as it goes, and is gone when it is a line. `seed`
# makes its edges its own.
static func ripple(parent: Node, at: Vector3, reach: float, life: float, delay: float, seed: float) -> void:
	if _ripple_mesh == null:
		_ripple_mesh = PlaneMesh.new()
		_ripple_mesh.size = Vector2(2.0, 2.0)
		_ripple_material = ShaderMaterial.new()
		_ripple_material.shader = RIPPLE_SHADER
	var ring := MeshInstance3D.new()
	ring.mesh = _ripple_mesh
	ring.material_override = _ripple_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.set_instance_shader_parameter("seed", seed)
	var spread := func(t: float):
		var k := clampf((t - delay) / life, 0.0, 1.0)
		ring.visible = t >= delay
		var radius := lerpf(reach * 0.12, reach, 1.0 - pow(1.0 - k, 2.0))
		var band := reach * lerpf(0.14, 0.012, k)
		ring.global_transform = Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)),
				at + Vector3.UP * 0.01)
		ring.set_instance_shader_parameter("inner", clampf(1.0 - band / radius, 0.0, 1.0))
	# Placed now: until the tween's first step, the next frame, it would be
	# a patch two metres across wherever the parent's origin is.
	spread.call(0.0)
	var tween := ring.create_tween()
	tween.tween_method(spread, 0.0, delay + life, delay + life)
	tween.tween_callback(ring.queue_free)


# A crater, radius 1 to the foot of its rim (level3d_rocket.gd, _crater): two
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
# down to its floor. The ground has a hole in it there: its shader does not
# draw inside the rim's inner foot (level3d_holes.gdshaderinc), which is why
# that foot, unlike the rest of the crater, is a regular RIM_SEGMENTS-gon of
# radius RIM_IN -- the shader draws the same one. The bowl is then plain
# geometry, seen as anything is, and whatever stands in it is too.
#
# `crater_profile` gives what goes over it the same shape.
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


# {"rim", "bowl"}.
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
		var inner := RIM_IN
		crest_in.append(way * crest + Vector3.UP * height)
		crest_out.append(way * (crest + RIM_LINE) + Vector3.UP * (height - RIM_LINE * 0.3))
		var even := TAU * i / RIM_SEGMENTS
		foot.append(Vector3(cos(even), 0.0, sin(even)) * inner)
		# The wall goes on down as steep as the rim's inner face, then
		# rounds into the floor.
		wall.append(way * inner * 0.72 + Vector3.DOWN * BOWL_DEPTH * rng.randf_range(0.6, 0.75))
		floor_edge.append(way * inner * 0.38 + Vector3.DOWN * BOWL_DEPTH * rng.randf_range(0.92, 1.0))
		outer.append(way * RIM_OUT * rng.randf_range(0.9, 1.08))
	var bottom := Vector3.DOWN * BOWL_DEPTH
	return {
		"rim": _bands([foot, crest_in, crest_out, outer], [RIM_SCORCHED, RIM_BLACK, RIM_SAND]),
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


# How far the unit crater raises or lowers the ground `d` out from its middle
# (1 is the outer foot): RIM_HEIGHT on the crest, falling smoothly to nothing
# at either foot, and a bowl BOWL_DEPTH deep inside. Times the crater's
# height scale; `d` is measured in its radii, which for an oval one are two.
static func crater_profile(d: float) -> float:
	if d >= RIM_OUT:
		return 0.0
	if d >= RIM_TOP:
		return RIM_HEIGHT * smoothstep(RIM_OUT, RIM_TOP, d)
	if d >= RIM_IN:
		return RIM_HEIGHT * smoothstep(RIM_IN, RIM_TOP, d)
	return -BOWL_DEPTH * (1.0 - (d / RIM_IN) * (d / RIM_IN))


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
