# How a helicopter of the 3D preview sits in the air, off the path it flies:
# Level3DRescue's and Level3DChinook's. The game slides their sprites along
# their paths, turned to them; a model doing that flew as if on a rail. So
# where one is and which way it goes stay the game's, and this, given where it
# is each tick, works out its tilt as a helicopter's would be:
#
#   * its rotor tilted to give it the acceleration it has -- atan(a / G) along
#     and across, nose down speeding up and up braking, banked into a turn --
#     and its nose a little lower for its speed, up to cruise_pitch, each at
#     most its max, on a spring of its own;
#   * its heading after the path's, on a stiffer spring with the path's rate
#     fed forward, so that it takes the corners off a turn that changes at
#     once and does not trail a steady one;
#   * `airborne`, 0 to 1, how far the tilts are let go -- none on the ground;
#   * a slow sway while it hovers, under sway_speed, and a rock on its wheels
#     or skids by `shake`.
#
# One a tick (step); `snap` puts it straight where it is next tick.
class_name Level3DFlight
extends RefCounted

const G := 9.8

# Nose down for its speed alone, rising to cruise_pitch: 63% of it at
# cruise_speed m/s. Linear, it went on down past the tilt for any speed.
var cruise_pitch := deg_to_rad(8.0)
var cruise_speed := 8.0
var pitch_max := deg_to_rad(25.0)
var bank_max := deg_to_rad(30.0)
# More than this, m/s^2, is the path jumping, not the helicopter speeding up.
var accel_max := 6.0
# The springs, rad/s, and the tilts' damping. The pitch's is the quickest: a
# flare as it brakes can have under half a second.
var pitch_omega := 14.0
var tilt_omega := 9.0
var tilt_zeta := 0.75
var yaw_omega := 12.0
# Hovering: how far it bobs, sways, swings round and drifts, level metres and
# radians, below sway_speed m/s. And the rock on the ground.
var sway_height := 0.03
var sway_tilt := deg_to_rad(1.5)
var sway_yaw := deg_to_rad(2.5)
var sway_drift := 0.05
var sway_speed := 2.0
var shake_tilt := deg_to_rad(0.6)

# Its velocity the last tick, level x, z m/s.
var velocity := Vector2.ZERO

var _ticks := 0
var _snap := true
var _fresh := false
var _was_at := Vector2.ZERO
var _was_heading := 0.0
var _pitch := 0.0
var _pitch_rate := 0.0
var _roll := 0.0
var _roll_rate := 0.0
var _yaw := 0.0
var _yaw_rate := 0.0


func snap() -> void:
	_snap = true


# A tick at `at`, level x, z, the path's `heading` a turn about +Y of a model
# whose nose is its +Z: its attitude, and the sway's offset to where it is.
# {"basis": Basis, "offset": Vector3}.
func step(at: Vector2, heading: float, airborne: float, shake: float) -> Dictionary:
	_ticks += 1
	var dt := 1.0 / Engine.physics_ticks_per_second
	if _snap:
		_snap = false
		_fresh = true
		_was_at = at
		_was_heading = heading
		velocity = Vector2.ZERO
		_yaw = heading
		_yaw_rate = 0.0
		_pitch = 0.0
		_pitch_rate = 0.0
		_roll = 0.0
		_roll_rate = 0.0
	var now := (at - _was_at) / dt
	# The tick after a snap has the first velocity, and no acceleration: one
	# that appears already flying -- the Chinook on its arc, the rescue
	# helicopter coming in -- did not speed up to it in a tick.
	var accel := ((now - velocity) / dt).limit_length(accel_max) if not _fresh else Vector2.ZERO
	_fresh = false
	_was_at = at
	velocity = now

	var heading_rate := wrapf(heading - _was_heading, -PI, PI) / dt
	_was_heading = heading
	_yaw_rate += (yaw_omega * yaw_omega * wrapf(heading - _yaw, -PI, PI)
			+ 2.0 * yaw_omega * (heading_rate - _yaw_rate)) * dt
	_yaw = wrapf(_yaw + _yaw_rate * dt, -PI, PI)
	var facing := Basis(Vector3.UP, _yaw)
	var nose3 := facing * Vector3.BACK
	var right3 := facing * Vector3.LEFT
	var nose := Vector2(nose3.x, nose3.z)
	var right := Vector2(right3.x, right3.z)
	# Nose down is a positive turn about the model's +X, a bank to its right
	# one about its +Z.
	var along := velocity.dot(nose)
	var for_speed := cruise_pitch * (1.0 - exp(-absf(along) / cruise_speed)) * signf(along)
	var pitch_goal := clampf(atan(accel.dot(nose) / G) + for_speed,
			-pitch_max, pitch_max) * airborne
	var roll_goal := clampf(atan(accel.dot(right) / G), -bank_max, bank_max) * airborne
	_pitch_rate += (pitch_omega * pitch_omega * (pitch_goal - _pitch)
			- 2.0 * tilt_zeta * pitch_omega * _pitch_rate) * dt
	_pitch += _pitch_rate * dt
	_roll_rate += (tilt_omega * tilt_omega * (roll_goal - _roll) - 2.0 * tilt_zeta * tilt_omega * _roll_rate) * dt
	_roll += _roll_rate * dt
	if airborne <= 0.0:
		_yaw = heading
		_yaw_rate = 0.0
		_pitch = 0.0
		_pitch_rate = 0.0
		_roll = 0.0
		_roll_rate = 0.0

	var t := _ticks * dt
	var sway := airborne * clampf(1.0 - velocity.length() / sway_speed, 0.0, 1.0)
	var pitch := _pitch + sway_tilt * sway * _wave(t, 0.37, 0.71) + shake_tilt * shake * sin(t * 19.0)
	var roll := _roll + sway_tilt * sway * _wave(t, 0.29, 0.83) + shake_tilt * shake * sin(t * 23.0 + 1.0)
	var yaw := _yaw + sway_yaw * sway * _wave(t, 0.19, 0.53)
	var drift := Vector2(_wave(t, 0.23, 0.61), _wave(t, 0.31, 0.67)) * sway_drift * sway
	var lift := sway_height * sway * _wave(t, 0.45, 1.1)
	return {"basis": Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll),
			"offset": Vector3(drift.x, lift, drift.y)}


# Its tilts now, radians: for what is printed of them.
func pitch() -> float:
	return _pitch


func roll() -> float:
	return _roll


# A slow wobble, -1 to 1, of two waves that do not keep step.
static func _wave(t: float, f1: float, f2: float) -> float:
	return 0.5 * (sin(TAU * f1 * t) + sin(TAU * f2 * t + 1.3))
