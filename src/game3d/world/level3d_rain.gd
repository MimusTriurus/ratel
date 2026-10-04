# The rain over the game over's cemetery (Level3DGameOver): drops falling
# through a box over the frame, slanting with the wind's way
# (level3d_wind.gdshaderinc's WIND_TO, its part across the frame), and the
# splashes they make on the ground near the camera -- the ground there
# sampled once, as points the splashes are thrown up from.
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
# The splashes: how many at once, their life (s), their size (m) and how high
# they jump (m/s); the ground points they come off, how many.
const SPLASHES := 260
const SPLASH_LIFE := 0.22
const SPLASH_SIZE := 0.05
const SPLASH_JUMP := 1.2
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
	streak.material = _material(false)
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
	var splashes := CPUParticles3D.new()
	splashes.amount = SPLASHES
	splashes.lifetime = SPLASH_LIFE
	splashes.preprocess = SPLASH_LIFE
	splashes.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	splashes.emission_points = points
	splashes.direction = Vector3.UP
	splashes.spread = 35.0
	splashes.initial_velocity_min = SPLASH_JUMP * 0.5
	splashes.initial_velocity_max = SPLASH_JUMP
	splashes.gravity = Vector3(0.0, -9.8, 0.0)
	splashes.local_coords = false
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.6))
	fade.add_point(Vector2(0.3, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	splashes.scale_amount_curve = fade
	var drop := QuadMesh.new()
	drop.size = Vector2.ONE * SPLASH_SIZE
	var splash_material := _material(true)
	drop.material = splash_material
	splashes.mesh = drop
	splashes.particle_flag_align_y = false
	splashes.extra_cull_margin = 10.0
	splashes.layers = layer
	add_child(splashes)


static func _material(splash: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("splash", splash)
	if splash:
		material.set_shader_parameter("colour", Color(0.86, 0.9, 0.96, 0.5))
	return material
