# The BTR's machine gun on the 3D stage 1 preview: the trigger, where each
# round goes, and what it looks like when it gets there.
#
# Nothing here is part of the game. Jackal's gun is what it follows: a stream
# of rounds with a short reach that chips at buildings without taking them
# down -- that is the rocket's job, step 3 of docs/level3d-combat-plan.md. The
# bunkers' guns are the exception, as in the game: three rounds each
# (level3d_guns.gd), found along the round's flight through `intercept`.
#
# A round is decided the moment it is fired, by a ray: at this scale a bullet's
# flight is a few frames at most, and nothing on the stage moves out of the way.
# It is aimed at the ground where the cursor is, along the turret's bearing
# rather than the cursor's -- the turret lags a fast mouse, and the stream is
# seen to swing round with it -- and no further than RANGE. What the ray meets
# first is what is hit: a wall, a building, a trunk, the ground, the sea. The
# tracer then flies there at a speed the eye can follow, and the impact is shown
# when it arrives, not when the ray found it.
#
# From the tank bench (BlenderMCP/godot, docs/combat.md), the two things it
# settled for the cannon: recoil is an impulse into the body spring, not a
# curve over time, and it is signed along the gun, so a shot over the bow
# lifts the nose and a shot over the side does not. The camera does not shake:
# the bench leaves shake off for the cannon, and this gun fires nine times a
# second.
#
# Effects are low poly and opaque, like the stage: a puff grows and shrinks
# away instead of fading, which also keeps them out of Compatibility's
# transparent pass.
#
# With the BTR driving classic (level3d_btr.gd) the gun is PlayerBullet's and
# Player.update's trigger instead: a round the tick the trigger goes down, then
# one every GUN_ARMED_DELAY ticks while it is held -- tapping is faster than
# holding, as it is in the game -- each one flying 18 px a tick for 21 ticks,
# 378 px, whatever it was aimed at, with no spread. It is still decided by the
# ray when it is fired.
class_name Level3DGun
extends Node3D

const FIRE_INTERVAL := 0.11
const SPREAD := deg_to_rad(2.0)
# Level metres. The frame is 24.6 m tall at zoom 1, so this is about half of it.
const RANGE := 12.0
const MIN_RANGE := 1.5
const RANGE_JITTER := 0.05
const TRACER_SPEED := 70.0
const TRACER_LENGTH := 0.7
const TRACER_WIDTH := 0.07
const FLASH_TIME := 0.05
const RECOIL_KICK := 0.12
# PlayerBullet, at the map's PX: it moves VELOCITY a tick and is gone on the
# tick its count passes TRAVEL_TIME, so it covers TRAVEL_TIME + 1 moves.
const CLASSIC_RANGE := (PlayerBullet.TRAVEL_TIME + 1) * PlayerBullet.VELOCITY * Level3DMap.PX
const CLASSIC_TRACER_SPEED := PlayerBullet.VELOCITY * 100.0 * Level3DMap.PX

# What the ray may stop at: the preview's ground, solid and target layers.
var mask := 0xFFFFFFFF
# `hit_kind.call(rid)` names what a body is: "water", "forest", "ground",
# "wall", "trunk" or "building".
var hit_kind: Callable
# `ground.call(x, z)` as the BTR has it.
var ground: Callable
var btr: Level3DBtr
var trigger := false
var aim_point = null        # Vector3 or null
# `intercept.call(from, to)`: whatever the round's flight meets before the ray
# does that is not a body -- the bunkers' guns, Level3DGuns.intercept -- as
# {"t": 0-1 along from -> to, ...}, or empty. `struck.call(found)` when the
# round gets there.
var intercept: Callable
var struck: Callable

var _cooldown := 0.0
# Player's gun_armed and shoot_released, for the classic trigger.
var _gun_armed := 0
var _shoot_released := true
var _rng := RandomNumberGenerator.new()
var _flash: MeshInstance3D
var _flash_left := 0.0
var _tracer_mesh: BoxMesh
var _tracer_material: StandardMaterial3D
var _puff_mesh: SphereMesh
var _chip_mesh: BoxMesh
var _materials := {}


func _ready() -> void:
	# Seeded, so a --shot of a burst is the same burst every time.
	_rng.seed = 1
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(TRACER_LENGTH, TRACER_WIDTH, TRACER_WIDTH)
	_tracer_material = _unshaded(Color(1.0, 0.85, 0.35))
	_tracer_mesh.material = _tracer_material

	var star := SphereMesh.new()
	star.radial_segments = 5
	star.rings = 2
	star.radius = 0.16
	star.height = 0.16
	star.material = _unshaded(Color(1.0, 0.75, 0.25))
	# On the bore itself, so it rides with the turret and the hull's pitch.
	_flash = MeshInstance3D.new()
	_flash.mesh = star
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	btr.muzzle_node().add_child(_flash)

	_puff_mesh = SphereMesh.new()
	_puff_mesh.radial_segments = 6
	_puff_mesh.rings = 3
	_puff_mesh.radius = 1.0
	_puff_mesh.height = 2.0
	_chip_mesh = BoxMesh.new()
	_chip_mesh.size = Vector3.ONE
	_materials = {
		"dust": _lit(Color(0.93, 0.76, 0.48)),
		"leaves": _lit(Color(0.22, 0.45, 0.16)),
		"wood": _lit(Color(0.36, 0.24, 0.13)),
		"stone": _lit(Color(0.62, 0.62, 0.60)),
		"splash": _lit(Color(0.92, 0.97, 1.0)),
		"spark": _unshaded(Color(1.0, 0.9, 0.45)),
	}


func step(delta: float) -> void:
	if btr.classic:
		# Player.update, one tick of it.
		if _gun_armed > 0:
			_gun_armed -= 1
		if trigger:
			if _shoot_released or _gun_armed == 0:
				_fire()
				_gun_armed = Player.GUN_ARMED_DELAY
			_shoot_released = false
		else:
			_shoot_released = true
			_gun_armed = 0
		_cooldown = 0.0
	else:
		_cooldown -= delta
		if trigger:
			while _cooldown <= 0.0:
				_fire()
				_cooldown += FIRE_INTERVAL
		else:
			_cooldown = maxf(_cooldown, 0.0)
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash.visible = false


func _fire() -> void:
	var muzzle := btr.muzzle()
	var from := muzzle.origin
	var bearing := Vector3(muzzle.basis.x.x, 0.0, muzzle.basis.x.z).normalized()
	var direction := bearing
	var reach := CLASSIC_RANGE
	if not btr.classic:
		direction = bearing.rotated(Vector3.UP, _rng.randf_range(-SPREAD, SPREAD))
		reach = RANGE
		if aim_point != null:
			var to: Vector3 = aim_point - from
			reach = clampf(Vector2(to.x, to.z).length(), MIN_RANGE, RANGE)
		reach *= 1.0 + _rng.randf_range(-RANGE_JITTER, RANGE_JITTER)
	var landing := from + direction * reach
	var there: Dictionary = ground.call(landing.x, landing.z)
	landing.y = there.height

	# Past the landing point a little, so a round aimed at the ground finds it.
	var line := landing - from
	var query := PhysicsRayQueryParameters3D.create(from, landing + line.normalized() * 0.5, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var point := landing
	var normal := Vector3.UP
	var kind: String = there.kind if there.hit else "ground"
	if not hit.is_empty():
		point = hit.position
		normal = hit.normal
		kind = hit_kind.call(hit.rid)
	var found := {}
	if intercept.is_valid():
		found = intercept.call(from, point)
		if not found.is_empty():
			point = from.lerp(point, found.t)
			normal = -line.normalized()
			kind = "building"

	_tracer(from, point, kind, normal, line.normalized(), found)
	# A star at the bore, turned and sized afresh each round so a burst flickers.
	_flash.visible = true
	_flash.transform = Transform3D(Basis(Vector3.RIGHT, _rng.randf() * TAU)
			.scaled(Vector3(1.6, 1.0, 1.0) * _rng.randf_range(0.8, 1.2)), Vector3(0.12, 0.0, 0.0))
	_flash_left = FLASH_TIME
	btr.recoil(direction, RECOIL_KICK)


func _tracer(from: Vector3, to: Vector3, kind: String, normal: Vector3, travel: Vector3,
		found: Dictionary) -> void:
	var tracer := _instance(_tracer_mesh)
	var along := to - from
	var length := along.length()
	# The streak's back end leaves the muzzle, its front end stops at the hit.
	var start := from + along.normalized() * TRACER_LENGTH * 0.5
	var stop := to - along.normalized() * TRACER_LENGTH * 0.5
	tracer.global_transform = Transform3D(_basis_along(along), start)
	var time := maxf(length - TRACER_LENGTH, 0.0) \
			/ (CLASSIC_TRACER_SPEED if btr.classic else TRACER_SPEED)
	var tween := tracer.create_tween()
	tween.tween_property(tracer, "global_position", stop, time)
	tween.tween_callback(func():
		tracer.queue_free()
		_impact(to, kind, normal, travel)
		if not found.is_empty():
			struck.call(found))


# What a round leaves where it lands, by what it landed on.
func _impact(at: Vector3, kind: String, normal: Vector3, travel: Vector3) -> void:
	match kind:
		"water":
			_puffs(at, "splash", 3, 0.22, 0.35)
		"forest":
			_puffs(at, "leaves", 2, 0.18, 0.30)
		"trunk":
			_chips(at, normal, travel, "wood", 4)
		"wall", "building":
			_chips(at, normal, travel, "spark", 4)
			_chips(at, normal, travel, "stone", 3)
			_puffs(at, "stone", 1, 0.15, 0.25)
		_:
			_puffs(at, "dust", 3, 0.18, 0.40)


# A few low-poly balls that swell and shrink away, rising a little.
func _puffs(at: Vector3, material: String, count: int, size: float, life: float) -> void:
	for i in count:
		var puff := _instance(_puff_mesh)
		puff.material_override = _materials[material]
		var offset := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * size
		puff.global_position = at + offset
		puff.scale = Vector3.ONE * size * 0.3
		var peak := size * _rng.randf_range(0.8, 1.3)
		var tween := puff.create_tween()
		tween.set_parallel()
		tween.tween_property(puff, "scale", Vector3.ONE * peak, life * 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "global_position", puff.global_position + Vector3.UP * size * 1.5, life)
		tween.tween_property(puff, "scale", Vector3.ONE * 0.001, life * 0.7).set_delay(life * 0.3) \
				.set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(puff.queue_free)


# Bits thrown back off a hard surface: out along the normal, back towards the
# gun, and falling.
func _chips(at: Vector3, normal: Vector3, travel: Vector3, material: String, count: int) -> void:
	var bounce := (travel - 2.0 * travel.dot(normal) * normal).normalized()
	for i in count:
		var chip := _instance(_chip_mesh)
		chip.material_override = _materials[material]
		var size := _rng.randf_range(0.03, 0.06)
		chip.scale = Vector3.ONE * size
		chip.global_position = at + normal * 0.03
		var out := (bounce + normal + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.2, 0.9),
				_rng.randf_range(-0.6, 0.6))).normalized()
		var life := _rng.randf_range(0.18, 0.3)
		var velocity := out * _rng.randf_range(2.0, 4.0)
		var tween := chip.create_tween()
		tween.tween_method(func(t: float):
			chip.global_position = at + velocity * t + Vector3.DOWN * 4.9 * t * t, 0.0, life, life)
		tween.tween_callback(chip.queue_free)


func _instance(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(node)
	return node


static func _basis_along(direction: Vector3) -> Basis:
	var x := direction.normalized()
	var up := Vector3.UP if absf(x.y) < 0.99 else Vector3.FORWARD
	var z := x.cross(up).normalized()
	return Basis(x, z.cross(x), z)


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


static func _lit(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material
