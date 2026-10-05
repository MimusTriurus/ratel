# The rain over the game over's cemetery (Level3DGameOver): drops falling
# through a box over the frame, slanting with the wind's way
# (level3d_wind.gdshaderinc's WIND_TO, its part across the frame), and where
# they land on the ground near the camera -- the ground there sampled once,
# as points the splashes stand on: a crown of thin jets a few centimetres
# high, gone in a sixth of a second, and a ring spreading round it. Round
# drops thrown up and falling back, as they were at first, read as hail.
#
# CPUParticles3D, not GPU ones: the project renders in Compatibility, and a
# few thousand streaks are nothing to the processor. Each drop is a quad
# stretched along the way it falls (particle_flag_align_y), facing the
# camera, which looks down the scene's -z, across it; drawn by
# level3d_rain.gdshader. Already falling when the scene comes up
# (preprocess), and going on while the tree is paused, with its owner.
class_name Level3DRain
extends Node3D

const SHADER := preload("res://src/game3d/shaders/level3d_rain.gdshader")

# The drops: how many in the air at once, how fast they fall (m/s), how long
# and thin a streak is (m), and how far they lean with the wind (m/s across).
const DROPS := 7000
const FALL := 16.0
const STREAK := Vector2(0.018, 0.5)
const LEAN := 3.0
# Where they land: the crowns, how many at once, their life (s) and their
# quad's size (m, width and height); the rings, the same, a ring's quad
# square; the ground points both stand on, how many.
const CROWNS := 320
const CROWN_LIFE := 0.16
const CROWN_SIZE := Vector2(0.11, 0.075)
const RINGS := 220
const RING_LIFE := 0.45
const RING_SIZE := 0.16
const SPLASH_POINTS := 1500


# `box`: where the drops start, the scene's metres -- from over the top of
# the frame, high enough that they fill it down to the ground before they
# die; `splash_area`: the ground the splashes come off, x and z, and
# `ground_at`, the ground's height at a scene x, z; `layer`, the render
# layer both are drawn on.
func build(box: AABB, splash_area: Rect2, ground_at: Callable, layer := 1) -> void:
	var drops := CPUParticles3D.new()
	drops.amount = DROPS
	drops.lifetime = (box.size.y + box.position.y) / FALL + 0.2
	drops.preprocess = drops.lifetime
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drops.emission_box_extents = box.size * 0.5
	drops.position = box.get_center()
	drops.direction = Vector3(LEAN / FALL, -1.0, 0.0).normalized()
	drops.spread = 2.0
	drops.initial_velocity_min = FALL * 0.9
	drops.initial_velocity_max = FALL * 1.1
	drops.gravity = Vector3.ZERO
	drops.particle_flag_align_y = true
	drops.local_coords = false
	var streak := QuadMesh.new()
	streak.size = STREAK
	streak.material = _material(0)
	drops.mesh = streak
	drops.visibility_aabb = AABB(-box.size, box.size * 2.0)
	drops.extra_cull_margin = 10.0
	drops.layers = layer
	add_child(drops)

	var points := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in SPLASH_POINTS:
		var x := rng.randf_range(splash_area.position.x, splash_area.end.x)
		var z := rng.randf_range(splash_area.position.y, splash_area.end.y)
		points.append(Vector3(x, float(ground_at.call(x, z)) + 0.02, z))
	# A crown's quad stands on its foot, so that growing it grows it up.
	var crown := QuadMesh.new()
	crown.size = CROWN_SIZE
	crown.center_offset = Vector3(0.0, CROWN_SIZE.y * 0.5, 0.0)
	crown.material = _material(1)
	(crown.material as ShaderMaterial).set_shader_parameter("aspect", CROWN_SIZE.x / CROWN_SIZE.y)
	add_child(_landing(points, CROWNS, CROWN_LIFE, crown, layer))
	var ring := PlaneMesh.new()
	ring.size = Vector2.ONE * RING_SIZE
	ring.center_offset = Vector3(0.0, 0.01, 0.0)
	ring.material = _material(2)
	add_child(_landing(points, RINGS, RING_LIFE, ring, layer))


# Particles standing where the drops land, `mesh` each, growing from a
# third of its size and fading out over `life` seconds.
static func _landing(points: PackedVector3Array, amount: int, life: float, mesh: Mesh, layer: int) -> CPUParticles3D:
	var out := CPUParticles3D.new()
	out.amount = amount
	out.lifetime = life
	out.preprocess = life
	out.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	out.emission_points = points
	out.initial_velocity_min = 0.0
	out.initial_velocity_max = 0.0
	out.gravity = Vector3.ZERO
	out.local_coords = false
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1.0, 1.1))
	out.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.3, Color(1.0, 1.0, 1.0, 0.9))
	out.color_ramp = fade
	out.mesh = mesh
	out.extra_cull_margin = 10.0
	out.layers = layer
	return out


# The shader's `kind`: 0 a drop, 1 a crown, 2 a ring.
static func _material(kind: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("kind", kind)
	if kind > 0:
		material.set_shader_parameter("colour", Color(0.86, 0.9, 0.96, 0.6))
	return material
