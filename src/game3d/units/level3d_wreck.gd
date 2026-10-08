# The player's vehicle blown up in the 3D preview (level3d_preview.gd,
# _explode_btr): the jeep's, or the BTR's under --btr.
#
# Nothing here is part of the game. Player.explode draws an Explosion where the
# jeep was, and the jeep is simply gone until it comes back RESPAWN_DELAY
# later, on the same spot. Here the blast is the same (Level3DLauncher.blast)
# and under it the vehicle comes apart: a copy of its model as it stood is
# left where it was, while the real one waits hidden to come back.
#
#   * The turret, the launcher on the hull, a front wheel and the aerials are
#     thrown off it (THROWN), each up and out from the middle, tumbling, and
#     come down round it -- a bounce, then still. So is what the shop's
#     upgrades hang on the armoured pickup that is loose enough: the Arena's
#     two heads, the spares' round on its rack and a mine off the shelf
#     (THROWN_ONE_OF), whichever of them it has on.
#   * The hull jumps and falls back askew, down on its flattened tyres.
#   * All of it goes black over CHAR_TIME, as a tank's wreck does, and it
#     smokes, with a flame or two on it at first.
#   * It is gone when the vehicle comes back -- where it was, so it cannot be
#     left behind as a tank's wreck is -- sinking into a last cloud of smoke.
#
# Made here, not a clip baked in Blender as the tanks' Death is: the vehicles
# are objects on pivots, not rigs, and what is thrown is whatever the model
# has under those names, so the BTR comes apart as the jeep does.
class_name Level3DWreck
extends Node3D

# Until the vehicle is back: Player.RESPAWN_DELAY, in seconds.
const LIFE := Player.RESPAWN_DELAY / 100.0
const GRAVITY := 9.8
# How black, and how soon.
const CHAR := 0.28
const CHAR_TIME := 0.5
# What is thrown, by name less the vehicle's prefix: how fast up and out,
# level m/s, and how fast it tumbles, rad/s. A part the model has not is
# passed over; the launcher is whichever fit is on the hull.
const THROWN := [
	["TurretPivot", 4.4, 1.1, 8.0],
	["Wheel_L1", 2.8, 1.8, 14.0],
	["AerialL0", 3.2, 1.2, 11.0],
	["AerialR0", 3.6, 1.0, 11.0],
	# The Arena's heads: light, so high and far, spinning fast.
	["UpArenaHeadL", 4.0, 1.8, 13.0],
	["UpArenaHeadR", 4.2, 1.6, 13.0],
]
# The same for the first shown of each set of names: the one round on the
# spares' rack, the step below's (the mortar's mine, Level3DBtr.RACK_MINE,
# for the first two), and one of the mines left on the shelf.
const THROWN_ONE_OF := [
	[["UpZipRound0", "UpZipRound1", "UpZipRound2", "UpZipRound3"], 3.0, 1.3, 7.0],
	[["UpMine1", "UpMine2", "UpMine3"], 3.4, 1.5, 12.0],
]
const LAUNCHER_THROW := [3.6, 1.4, 9.0]
# A thrown part coming down bounces back up this share of its speed, and
# stays down once that is less than SETTLE.
const BOUNCE := 0.3
const SETTLE := 0.7
# The hull's jump, level m/s up; how far over it comes down, pitch or roll
# between the two, radians; how far it sits down on its tyres, level metres.
const HOP := 1.3
const TILT := Vector2(0.14, 0.26)
const SQUAT := 0.05
# Its smoke: a puff every SMOKE_EVERY seconds, SMOKE_SIZE in radius, and flames
# for its first FLAME_TIME.
const SMOKE_EVERY := 0.12
const SMOKE_SIZE := Vector2(0.12, 0.2)
const FLAME_EVERY := 0.1
const FLAME_TIME := 0.9
# The end: the cloud it goes in, how many puffs, and how long it takes to sink.
const LAST_PUFFS := 6
const SINK_TIME := 0.35
const SINK := 0.35

# `ground.call(x, z)`: {"height": ..., "hit": ...}, as the launcher's.
var ground: Callable
var launcher: Level3DLauncher

var _body: Node3D
var _body_rest: Transform3D
var _tilt := Basis()
var _hop_time := 0.0          # how long the hull is in the air
var _parts: Array[Dictionary] = []
var _charred: Array = []      # [material, colour] to blacken
var _age := 0.0
var _smoke := 0.0
var _flame := 0.0
var _sinking := false
var _rng := RandomNumberGenerator.new()


# The wreck of `btr` as it stands now. Called once this is in the tree.
func build(btr: Level3DBtr) -> void:
	_rng.randomize()
	var source := btr.model_node()
	# Its nodes as they are now -- the hull's contour, the fit on the hull, the
	# aerials bent -- not the glb's again, which instantiating would give.
	_body = source.duplicate(0) as Node3D
	add_child(_body)
	_body.global_transform = source.global_transform
	_body_rest = _body.global_transform
	_char(_body)
	var prefix: String = btr.vehicle.prefix
	var middle := _body.global_position
	for entry in THROWN:
		var part := _body.find_child(prefix + entry[0], true, false) as Node3D
		if part != null and part.is_visible_in_tree():
			_throw(part, middle, entry[1], entry[2], entry[3])
	for entry in THROWN_ONE_OF:
		for name in entry[0]:
			var part := _body.find_child(prefix + name, true, false) as Node3D
			if part != null and part.is_visible_in_tree():
				_throw(part, middle, entry[1], entry[2], entry[3])
				break
	for fit in Level3DLauncher.FITS:
		var base := _body.find_child(prefix + String(fit.base).trim_prefix("BTR_"), true, false) as Node3D
		if base != null and base.is_visible_in_tree():
			_throw(base, middle, LAUNCHER_THROW[0], LAUNCHER_THROW[1], LAUNCHER_THROW[2])
	var axis := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
	_tilt = Basis(axis, _rng.randf_range(TILT.x, TILT.y))
	_hop_time = 2.0 * HOP / GRAVITY


# `part` off the wreck and on its way: up at `up`, out from `middle` at `out`
# give or take, turning about an axis of its own at `spin`.
func _throw(part: Node3D, middle: Vector3, up: float, out: float, spin: float) -> void:
	var bounds := _bounds(part)
	part.reparent(self)
	var away := part.global_position - middle
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1))
	away = away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.7, 0.7))
	_parts.append({"node": part,
			"velocity": away * out * _rng.randf_range(0.7, 1.3) + Vector3.UP * up * _rng.randf_range(0.85, 1.15),
			"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(),
			"spin": spin * _rng.randf_range(0.7, 1.3) * (1.0 if _rng.randf() < 0.5 else -1.0),
			# How far its lowest point is below its origin: what it lands on.
			"foot": maxf(part.global_position.y - bounds.position.y, 0.02),
			"down": false})


func _physics_process(delta: float) -> void:
	_age += delta
	var k := clampf(_age / CHAR_TIME, 0.0, 1.0)
	var shade := lerpf(1.0, CHAR, k)
	for pair in _charred:
		var c: Color = pair[1]
		(pair[0] as StandardMaterial3D).albedo_color = Color(c.r * shade, c.g * shade, c.b * shade, c.a)
	_hull_step()
	for part in _parts:
		_part_step(part, delta)
	_burn(delta)
	if not _sinking and _age >= LIFE - SINK_TIME:
		_sink()
	if _age >= LIFE:
		queue_free()


# The hull: up and back down on the one parabola, turning over to its tilt on
# the way, then sat down on its tyres.
func _hull_step() -> void:
	if _sinking:
		return
	var t := minf(_age, _hop_time)
	var lift := HOP * t - 0.5 * GRAVITY * t * t
	var over := smoothstep(0.0, _hop_time, _age)
	var squat := SQUAT * smoothstep(_hop_time * 0.8, _hop_time * 1.2, _age)
	var turn := Basis().slerp(_tilt, over)
	_body.global_transform = Transform3D(turn * _body_rest.basis,
			_body_rest.origin + Vector3.UP * (lift - squat))


func _part_step(part: Dictionary, delta: float) -> void:
	if part.down or _sinking:
		return
	var node: Node3D = part.node
	var velocity: Vector3 = part.velocity
	velocity.y -= GRAVITY * delta
	var at := node.global_position + velocity * delta
	node.global_basis = Basis(part.axis, part.spin * delta) * node.global_basis
	var there: Dictionary = ground.call(at.x, at.z)
	var floor_y: float = (there.height if there.hit else _body_rest.origin.y) + part.foot
	if at.y < floor_y and velocity.y < 0.0:
		at.y = floor_y
		velocity = Vector3(velocity.x * 0.5, -velocity.y * BOUNCE, velocity.z * 0.5)
		part.spin *= 0.4
		if velocity.y < SETTLE:
			part.down = true
	part.velocity = velocity
	node.global_position = at


# Smoke off the hull the whole time, and flames on it at first.
func _burn(delta: float) -> void:
	if launcher == null or _sinking:
		return
	var middle := _body.global_position + Vector3.UP * 0.25
	_smoke += delta
	while _smoke >= SMOKE_EVERY:
		_smoke -= SMOKE_EVERY
		launcher.wreck_smoke(middle + _jitter(0.3), _rng.randf_range(SMOKE_SIZE.x, SMOKE_SIZE.y))
	if _age < FLAME_TIME:
		_flame += delta
		while _flame >= FLAME_EVERY:
			_flame -= FLAME_EVERY
			launcher.wreck_flame(middle + _jitter(0.35), _rng.randf_range(0.1, 0.18), _age / FLAME_TIME)


# Gone into a last cloud of smoke: it and all that was thrown sink into the
# ground under it.
func _sink() -> void:
	_sinking = true
	var middle := _body.global_position
	if launcher != null:
		for i in LAST_PUFFS:
			launcher.wreck_smoke(middle + _jitter(0.5) + Vector3.UP * 0.2, _rng.randf_range(0.2, 0.3))
	var tween := create_tween()
	tween.set_parallel()
	for node in [_body] + _parts.map(func(part): return part.node):
		tween.tween_property(node, "global_position", (node as Node3D).global_position + Vector3.DOWN * SINK,
				SINK_TIME).set_ease(Tween.EASE_IN)


func _jitter(reach: float) -> Vector3:
	return Vector3(_rng.randf_range(-reach, reach), _rng.randf_range(0.0, reach * 0.5),
			_rng.randf_range(-reach, reach))


# Its own copies of the paint, to blacken: the model shares the imported ones
# with the vehicle, which comes back in its colours. The contour is not paint.
func _char(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var paint := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if paint == null:
				continue
			var own := paint.duplicate() as StandardMaterial3D
			# Nothing on it is lit any more: the lamps (Level3DBtr) go out.
			own.emission_energy_multiplier = 0.0
			mesh_instance.set_surface_override_material(surface, own)
			_charred.append([own, paint.albedo_color])


# The box round everything under `root` that is drawn, in the world.
static func _bounds(root: Node3D) -> AABB:
	var box := AABB(root.global_position, Vector3.ZERO)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		box = box.merge(mesh_instance.global_transform * mesh_instance.get_aabb())
	return box
