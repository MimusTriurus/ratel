# The BTR on the 3D stage 1 preview: its model, and how it drives.
#
# Nothing here is part of the game. The model is resources/3d/ratel_btr.glb,
# exported from ratel_btr_lowpoly.blend in its default fit (rail launcher,
# single gun); the level it drives on is level3d_preview.gd's.
#
# The driving is the tank bench's in BlenderMCP/godot -- TankTick.AdvanceOrder
# with a MovementProfile row -- carried from hex legs to free ground:
#
#   * A class is a top speed, an acceleration and a turn rate, and it is the
#     acceleration that reads as mass, not the top speed.
#   * Braking is a ceiling, not a pedal: the fastest the vehicle may be going
#     and still stop in what is left, sqrt(v_end^2 + 2 a d). Read every frame it
#     has no moment of engagement to miss, so an order ends at rest on the point
#     instead of arriving at a third of cruise and stopping dead.
#   * At a bend the speed comes down to a crawl, and the ceiling for a straight
#     run ends at that crawl rather than at zero. A standing start with the goal
#     off the nose begins with the turn.
#   * What it cannot drive into is the scene's to say, not the vehicle's: the
#     ground is asked what kind it is under the nose (water, forest and walls
#     stop it) and whether the footprint at the next step overlaps anything
#     solid (walls, palm trunks). See _add_collision in level3d_preview.gd.
#   * The body pitch is BodyPitch's spring, driven by acceleration.
#   * The turret has its own traverse rate; unaimed, it comes round to the bow
#     while the hull is moving and stays where it was left when it is not.
#   * The gun (level3d_gun.gd) asks it where the muzzle is and kicks the same
#     pitch spring on every round.
#
# One deliberate departure: wheels cannot pivot. The bench's tanks swing round
# on the spot at the crawl floor; a BTR has to roll to turn, so the crawl is a
# target it speeds up to while turning, the yaw rate is capped by the speed over
# MIN_TURN_RADIUS, and a goal inside the turning circle is reached by backing
# out of it first -- a three-point turn instead of a pivot.
class_name Level3DBtr
extends Node3D

const MODEL_PATH := "res://resources/3d/ratel_btr.glb"

# The model is modelled at 1:1 (5.8 m long); the level is not, and at 1:1 the
# BTR would be four bunkers long. At half size it is 2.9 m, about one and a
# half bunkers, which is what a vehicle a little bigger than the jeep reads as
# against the stage's own props.
const MODEL_SCALE := 0.5

# The profile row, in level metres (the tank bench's px/s at its board scale,
# re-read against the BTR's length: MTP cruises at about 2.2 hull lengths per
# second and reaches it in 0.58 s).
const TOP_SPEED := 6.0
const ACCEL := 10.0
const TURN_RATE := deg_to_rad(110.0)
const REVERSE_FRACTION := 0.4
# The bench's CornerFraction is 0.12 for a tank that pivots; a vehicle that has
# to roll through a corner needs more than that to get round at all.
const CORNER_FRACTION := 0.35
const MIN_TURN_RADIUS := 2.2
const TURRET_RATE := deg_to_rad(175.0)
# Above this much heading error the order slows to the crawl to swing round.
const SWING_THRESHOLD := deg_to_rad(25.0)
const ARRIVE_RADIUS := 0.3
# The ground kinds the wheels may not go on to.
const IMPASSABLE: Array[String] = ["water", "forest", "wall"]
# The hull follows the ground's slope, but not across a jump bigger than this
# between its ends, which is an edge rather than a slope.
const TILT_STEP := 0.3

# BodyPitch, verbatim: gain in radians at full acceleration, zeta 0.65 at
# omega 21.9. Positive is nose down.
const PITCH_GAIN := 0.030
const PITCH_STIFFNESS := 480.0
const PITCH_DAMPING := 28.5
const BUMP_JOLT := 1.5

# In model metres, from the Blender scene.
const WHEEL_RADIUS := 0.66
const WHEELBASE := 3.06
# Where the ground is sampled, ahead of and beside the origin.
const NOSE := 3.5
const HALF_WIDTH := 1.3
# The hull and wheels as one box, centre and half extents: x from the tail at
# -2.35 to the nose at 3.47, the wheels' outer faces at +-1.75, the roof at 2.1.
const FOOTPRINT_CENTRE := Vector3(0.56, 1.05, 0.0)
const FOOTPRINT_HALF := Vector3(2.91, 0.95, 1.75)

# Asked of the scene: `ground.call(x, z)` returns
# {"height": float, "kind": String, "hit": bool} for the top surface there, and
# `solid.call(transform, half_extents)` whether a box there overlaps anything
# solid.
var ground: Callable
var solid: Callable

var heading := 0.0          # radians, 0 = +X, counter-clockwise from above
var speed := 0.0            # m/s along the heading, negative in reverse
var yaw_rate := 0.0
var turret := 0.0           # relative to the hull
var aim_point = null        # Vector3 or null
var turret_input := 0.0     # -1..1 from the keys
var throttle := 0.0         # -1..1 from the keys
var steer := 0.0            # -1..1 from the keys
var waypoints: Array[Vector3] = []
var backing := false

var _pitch := 0.0
var _pitch_velocity := 0.0
var _wheel_spin := 0.0
var _steer_angle := 0.0
var _model: Node3D
var _hull: Node3D
var _turret_pivot: Node3D
var _bore: Node3D
var _hull_rest: Transform3D
var _turret_rest: Transform3D
var _wheels: Array[Node3D] = []
var _wheel_rest: Array[Transform3D] = []
var _front_wheels: Array[bool] = []
var _tilt := Basis()


func _ready() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	_model = scene.instantiate()
	add_child(_model)
	_model.scale = Vector3.ONE * MODEL_SCALE
	_hull = _model.find_child("BTR_Hull", true, false)
	_turret_pivot = _model.find_child("BTR_TurretPivot", true, false)
	# The bore mesh's own axes are the cylinder's, its length along local Y, so
	# the muzzle is a node of its own: on the turret, where the bore is, facing
	# the turret's +X, which is where the gun points.
	var bore := _turret_pivot.find_child("BTR_GunBore", true, false) as Node3D
	_bore = Node3D.new()
	_bore.name = "Muzzle"
	_turret_pivot.add_child(_bore)
	_bore.position = _turret_pivot.global_transform.affine_inverse() * bore.global_position
	_hull_rest = _hull.transform
	_turret_rest = _turret_pivot.transform
	for side in ["L", "R"]:
		for axle in 3:
			var wheel := _model.find_child("BTR_Wheel_%s%d" % [side, axle + 1], true, false) as Node3D
			if wheel == null:
				continue
			_wheels.append(wheel)
			_wheel_rest.append(wheel.transform)
			_front_wheels.append(axle == 0)


# The gun's bore: where rounds leave from, its +X the way they go.
func muzzle_node() -> Node3D:
	return _bore


func muzzle() -> Transform3D:
	return _bore.global_transform.orthonormalized()


# A shot's kick into the body spring, signed along the bow: firing ahead
# lifts the nose, firing astern dips it, firing abeam does neither.
func recoil(direction: Vector3, kick: float) -> void:
	_pitch_velocity -= kick * direction.dot(forward())


func top_speed() -> float:
	return TOP_SPEED


func corner_speed() -> float:
	return top_speed() * CORNER_FRACTION


func forward() -> Vector3:
	return Vector3(cos(heading), 0.0, -sin(heading))


func place(at: Vector3, facing: float) -> void:
	position = at
	heading = facing
	speed = 0.0
	yaw_rate = 0.0
	waypoints.clear()
	backing = false
	_pitch = 0.0
	_pitch_velocity = 0.0
	_settle(0.0, true)
	_pose()


func order(to: Vector3, append: bool) -> void:
	if not append:
		waypoints.clear()
	waypoints.append(Vector3(to.x, 0.0, to.z))
	backing = false


func stop() -> void:
	waypoints.clear()
	backing = false


func step(delta: float) -> void:
	var before := speed
	if throttle != 0.0 or steer != 0.0:
		waypoints.clear()
		_drive_by_keys(delta)
	elif not waypoints.is_empty():
		_drive_order(delta)
	else:
		_coast(delta)

	var moved := speed * delta
	var next := position + forward() * moved
	if moved != 0.0 and _blocked(next, signf(moved)):
		# Hit something taller than a step. The hull stops where it is and the
		# nose takes the knock -- the bench's FallJolt, the other way round.
		_pitch_velocity += BUMP_JOLT * signf(speed)
		speed = 0.0
		waypoints.clear()
		backing = false
		moved = 0.0
	else:
		position = next
	heading = wrapf(heading + yaw_rate * delta, -PI, PI)
	_wheel_spin -= moved / (WHEEL_RADIUS * MODEL_SCALE)

	# What the body felt, not which branch ran: signed along the bow, so pulling
	# away in reverse dips the nose just as braking does.
	var accel_ratio := clampf((speed - before) / (ACCEL * delta), -1.0, 1.0) if delta > 0.0 else 0.0
	_update_pitch(accel_ratio, delta)
	_update_turret(delta)
	_settle(delta, false)
	_pose()


# ----------------------------------------------------------------------------
# Driving

func _drive_by_keys(delta: float) -> void:
	var target := throttle * top_speed() * (1.0 if throttle >= 0.0 else REVERSE_FRACTION)
	speed = move_toward(speed, target, ACCEL * delta)
	_set_yaw(steer * TURN_RATE)


func _coast(delta: float) -> void:
	speed = move_toward(speed, 0.0, ACCEL * delta)
	_set_yaw(0.0)


func _drive_order(delta: float) -> void:
	var goal: Vector3 = waypoints[0]
	var to := Vector3(goal.x - position.x, 0.0, goal.z - position.z)
	var distance := to.length()
	if distance < ARRIVE_RADIUS:
		waypoints.remove_at(0)
		if waypoints.is_empty():
			_coast(delta)
		return

	var wanted := atan2(-to.z, to.x)
	var diff := wrapf(wanted - heading, -PI, PI)

	# A goal inside the turning circle on the side it lies can never be driven
	# on to forwards; back out, wheels the other way, until it is outside.
	var side := signf(diff) if diff != 0.0 else 1.0
	var left := Vector3(-sin(heading), 0.0, -cos(heading))
	var centre := position + left * side * MIN_TURN_RADIUS
	var inside := Vector3(goal.x - centre.x, 0.0, goal.z - centre.z).length() < MIN_TURN_RADIUS * 1.05
	if backing:
		backing = inside or absf(diff) > deg_to_rad(100.0) and distance < MIN_TURN_RADIUS * 2.0
	else:
		backing = inside and absf(diff) > SWING_THRESHOLD
	if backing:
		speed = move_toward(speed, -corner_speed(), ACCEL * delta)
		_set_yaw(-side * TURN_RATE)
		return

	if absf(diff) > SWING_THRESHOLD:
		# Slow to the crawl and swing round. The bench's crawl is a floor it
		# never speeds up to, because a tank pivots; wheels have to roll to
		# turn, so here it is the target from below as well.
		speed = move_toward(speed, corner_speed(), ACCEL * delta)
		_set_yaw(side * TURN_RATE)
		return

	var run := _remaining_run()
	var ceiling := sqrt(run.y * run.y + 2.0 * ACCEL * maxf(run.x, 0.0))
	var allowed := minf(top_speed(), ceiling)
	# Slowed into rather than snapped to: a cap that drops by more than the
	# engine can take off in a frame is approached at the engine's own rate.
	speed = maxf(allowed, speed - ACCEL * delta) if speed > allowed \
			else minf(speed + ACCEL * delta, allowed)
	_set_yaw(clampf(diff / maxf(delta, 0.0001), -TURN_RATE, TURN_RATE))


# Distance left along the straight run and the speed to be doing at its end:
# the run carries on through waypoints that do not bend it, and ends at the
# crawl at a bend or at rest at the last one -- the bench's RemainingRun.
func _remaining_run() -> Vector2:
	var from := Vector3(position.x, 0.0, position.z)
	var total := 0.0
	var direction := Vector3.ZERO
	for i in waypoints.size():
		var leg := waypoints[i] - from
		var d := leg.normalized()
		if i > 0 and d.dot(direction) < cos(SWING_THRESHOLD):
			return Vector2(total, corner_speed())
		total += leg.length()
		direction = d
		from = waypoints[i]
	return Vector2(total, 0.0)


# The yaw asked for, cut to what the wheels allow at this speed. No speed, no
# turn: the one place the bench's pivoting tank and this vehicle differ.
func _set_yaw(wanted: float) -> void:
	var cap := minf(TURN_RATE, absf(speed) / MIN_TURN_RADIUS)
	yaw_rate = clampf(wanted, -cap, cap) * (1.0 if speed >= 0.0 else -1.0) \
			if absf(speed) > 0.001 else 0.0
	# A reversing vehicle's yaw goes the other way for the same wheel angle, so
	# the wheel angle is what is kept in the sign above, and the steering shown
	# on the front axle follows it.
	var target := atan(WHEELBASE * MODEL_SCALE * yaw_rate / speed) if absf(speed) > 0.05 else 0.0
	_steer_angle = move_toward(_steer_angle, clampf(target, -0.6, 0.6), 3.0 * get_physics_process_delta_time())


# Two questions, because the level has two kinds of obstacle. Water and forest
# are ground the wheels may not go on to, asked of the ground under the leading
# end and its two corners; walls and trunks are things in the way, asked of the
# whole footprint at the next step, since a trunk is thinner than the gap
# between two probes.
func _blocked(at: Vector3, direction: float) -> bool:
	var f := forward() * direction
	var left := Vector3(-sin(heading), 0.0, -cos(heading))
	for offset in [0.0, HALF_WIDTH, -HALF_WIDTH]:
		var probe: Vector3 = at + (f * NOSE * 0.5 + left * offset) * MODEL_SCALE
		var there: Dictionary = ground.call(probe.x, probe.z)
		if not there.hit or there.kind in IMPASSABLE:
			return true
	var pose := Transform3D(Basis(Vector3.UP, heading), at)
	return solid.call(pose.translated_local(FOOTPRINT_CENTRE * MODEL_SCALE),
			FOOTPRINT_HALF * MODEL_SCALE)


# ----------------------------------------------------------------------------
# Body

func _update_pitch(accel_ratio: float, delta: float) -> void:
	if delta <= 0.0:
		return
	var target := -PITCH_GAIN * clampf(accel_ratio, -1.0, 1.0)
	_pitch_velocity += (-PITCH_STIFFNESS * (_pitch - target) - PITCH_DAMPING * _pitch_velocity) * delta
	_pitch += _pitch_velocity * delta


# The turret's one writer. Aimed: it turns towards the aim point at its own
# rate, holding a world bearing through the hull's turns. Keys: the keys.
# Neither: stowed to the bow while moving, left alone while standing -- the
# bench's UpdateTurret.
func _update_turret(delta: float) -> void:
	var budget := TURRET_RATE * delta
	if turret_input != 0.0:
		turret = wrapf(turret + turret_input * budget, -PI, PI)
		return
	var wanted := turret
	if aim_point != null:
		var to: Vector3 = aim_point - global_position
		if Vector2(to.x, to.z).length() > 0.2:
			wanted = wrapf(atan2(-to.z, to.x) - heading, -PI, PI)
	elif absf(speed) > 0.05:
		wanted = 0.0
	# The bearing is taken against this frame's heading, so an aimed turret
	# holds it through the hull's turns instead of being carried round with it.
	var diff := wrapf(wanted - turret, -PI, PI)
	turret = wrapf(turret + clampf(diff, -budget, budget), -PI, PI)


# Sits the vehicle on the ground under it, tilted to the ground under its ends
# and sides.
func _settle(delta: float, snap: bool) -> void:
	var centre: Dictionary = ground.call(position.x, position.z)
	var target_y: float = centre.height
	position.y = target_y if snap else lerpf(position.y, target_y, clampf(delta * 8.0, 0.0, 1.0))

	var f := forward()
	var left := Vector3(-sin(heading), 0.0, -cos(heading))
	var half := NOSE * 0.5 * MODEL_SCALE
	var side := HALF_WIDTH * MODEL_SCALE
	var hf: Dictionary = ground.call(position.x + f.x * half, position.z + f.z * half)
	var hb: Dictionary = ground.call(position.x - f.x * half, position.z - f.z * half)
	var hl: Dictionary = ground.call(position.x + left.x * side, position.z + left.z * side)
	var hr: Dictionary = ground.call(position.x - left.x * side, position.z - left.z * side)
	var pitch := 0.0
	var roll := 0.0
	# Only over a jump it could be a slope, so a wall beside the hull does not
	# tip it over.
	var dp: float = hf.height - hb.height
	var dr: float = hl.height - hr.height
	if absf(dp) < TILT_STEP:
		pitch = atan2(dp, half * 2.0)
	if absf(dr) < TILT_STEP:
		roll = atan2(dr, side * 2.0)
	var target := Basis(Vector3.UP, heading) * Basis(Vector3(0, 0, 1), pitch) * Basis(Vector3(1, 0, 0), roll)
	_tilt = target if snap else _tilt.slerp(target, clampf(delta * 8.0, 0.0, 1.0))


func _pose() -> void:
	basis = _tilt
	# Nose down is positive in the spring; a rotation about +Z lifts +X.
	_hull.transform = Transform3D(Basis(Vector3(0, 0, 1), -_pitch) * _hull_rest.basis, _hull_rest.origin)
	_turret_pivot.transform = Transform3D(Basis(Vector3.UP, turret) * _turret_rest.basis, _turret_rest.origin)
	for i in _wheels.size():
		var rest := _wheel_rest[i]
		var steer_basis := Basis(Vector3.UP, _steer_angle) if _front_wheels[i] else Basis()
		_wheels[i].transform = Transform3D(steer_basis * Basis(Vector3(0, 0, 1), _wheel_spin) * rest.basis, rest.origin)
