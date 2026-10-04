# The title's scene, the default (--splash-3d and --splash-picture the
# others): Level3DSplash3D's sunset, ground and jeeps, and a Chinook. It
# comes in over the camera as the
# title opens, flies off into the sun slowing, and sets down in front of it,
# tail to the camera, in a cloud of its own dust, and lowers its ramp. A game
# picked turns the jeeps it is for round at once and drives them up into it,
# one behind the other -- waiting short of it if its ramp is not down yet;
# the ramp goes up, and once the stage is built under the title too
# (game_ready) it lifts off with them, and the title fades out over it --
# into the stage, which opens on a Chinook unloading them
# (level3d_chinook.gd): the one loads them, the other unloads them. So the
# game answers the pick at once, and what is left of the building is played
# through rather than waited out.
#
# Everything else is Level3DSplash3D's, the menu's lamps and turrets too
# (show_menu); what is new is the Chinook and the way the jeeps go (launch,
# _drive_off).
class_name Level3DSplashLanding
extends Level3DSplash3D

const CHINOOK := "res://resources/3d/jackal_chinook.glb"
# The Chinook is at the BTR's scale in the preview, Level3DChinook.MODEL_SCALE,
# and the jeep at Level3DBtr.VEHICLES' 0.375; here the jeep is 1:1, and the
# Chinook the same against it: 24 m from rotor tip to rotor tip.
const CHINOOK_SCALE := Level3DChinook.MODEL_SCALE / 0.375
# Where it sets down, nose away from the camera: in the middle of the sun,
# three times as far as the jeeps -- the near ground ends at 67 m
# (GROUND_SIZE), and its wheels would stand off the far ground's plane.
const LANDING := Vector3(0.0, 0.0, -62.0)
# Its way in, a cubic Bezier from behind and above the camera to a hover over
# the landing, ARRIVE_TIME seconds of it slowing all the way, ARRIVE_DELAY
# after the title opens; then SETTLE_TIME down onto its wheels, and the ramp
# after RAMP_WAIT. It slows less and less as it comes to the hover, and so
# flares less and less: slowed at a constant rate, it was nose up to the last
# and dropped its nose in three frames as it stopped.
const ARRIVE := [Vector3(10.0, 24.0, 30.0), Vector3(6.0, 16.0, -20.0), Vector3(0.0, 9.0, -50.0),
		Vector3(0.0, 5.0, -62.0)]
const ARRIVE_DELAY := 0.6
const ARRIVE_TIME := 7.0
const SETTLE_TIME := 2.2
const RAMP_WAIT := 0.4
# A game picked before it is down: the rest of its way in, the settling and
# the ramp go ARRIVE_HURRY times as fast, coming up to it over HURRY_EASE
# seconds rather than at once -- the jeeps are on their way, and wait for it
# no longer than they have to.
const ARRIVE_HURRY := 1.8
const HURRY_EASE := 0.6
# How it leans, radians for every m/s^2: its nose up as it slows and down as
# it speeds up, over into a turn; and no further than LEAN_MOST. It comes
# round to that over LEAN_TIME seconds or so rather than at once: a change of
# speed -- a hurry, a lift -- is not a jolt of the airframe.
const PITCH_GAIN := 0.03
const ROLL_GAIN := 0.04
const LEAN_MOST := 0.3
const LEAN_TIME := 0.3
# Its rotors' wash raises dust under it below WASH_HEIGHT metres, up to
# WASH_RATE clouds a second on the ground -- not under it but at the edge of
# its hull (_hull_edge), WASH_OUT metres out and HOVER_OUT more for each metre
# it is up, where the air the rotors drive down comes out along the ground
# from under it -- each born WASH_BORN of its size and growing as it rolls
# out, thrown away from the hull at WASH_SPEED m/s; WASH_CLOUD as
# WHEEL_CLOUD. Raised all round it under it, from a ring about its middle,
# they stood through the hull and rose out of the ground beside it full
# grown; the wash is a wall of air coming out from under, and its dust is
# born small at the edge and swells as it goes. More and
# smaller clouds than a gust's: at 1.3 of a wind cloud's radius, 2 m across
# and more out where the Chinook lands (_raise_cloud grows them with the
# distance), they were blobs as broad as its cabin once the camera came in
# after the jeeps (CHASE_*).
const WASH_HEIGHT := 7.0
const WASH_RATE := 18.0
const WASH_OUT := 0.4
const HOVER_OUT := 0.6
const WASH_BORN := 0.1
const WASH_SPEED := Vector2(2.5, 5.0)
const WASH_CLOUD := Vector2(0.75, 0.5)
# Thrown out at twice WASH_SPEED, slowing over WASH_THROW_TIME: the wash
# hits the ground and rolls out, and stops.
const WASH_THROW_TIME := 0.8
# As one cloud (Level3DSplash3D, CEL_*), bigger and CEL_WASH_RATE times as
# many, so that they overlap into one: at the cards' they were stones.
const CEL_WASH := Vector2(1.3, 0.5)
const CEL_WASH_RATE := 1.5
# And the veil it raises (Level3DSplash3D, VEIL_*): VEIL_RATE sheets a
# second at the most, from the hull's edge too, blown out at VEIL_SPEED and
# slowing, VEIL_SIZE metres high at their fullest and VEIL_LONG times as
# wide, for VEIL_LIFE seconds -- a haze rolling out from under it.
const VEIL_RATE := 4.0
const VEIL_SPEED := Vector2(2.0, 4.0)
const VEIL_SIZE := Vector2(2.0, 3.0)
const VEIL_LONG := 2.0
const VEIL_LIFE := Vector2(3.5, 5.5)
const ROTOR_SOUND := Level3DChinook.SOUND
# Heard at full this close, and falling off as one over the distance past it.
const SOUND_NEAR := 25.0
const SOUND_VOLUME := 0.6

# The jeeps' way in: a U-turn out to their side, towards the camera, RIM
# metres outside the rocks on that side (ROCKS) -- out round them, since
# they stand between the jeeps and the sun -- straight on past the rocks,
# swinging in onto the Chinook's line, APPROACH metres of it straight before
# the ramp's lip, and up the ramp to their places in the cabin: the first
# FIRST_PLACE metres ahead of the Chinook's origin, model metres, the second
# behind it, CABIN_GAP bumper to bumper. The ramp's foot and hinge, the
# cabin's floor and width are Level3DChinook's.
const ROCK_RIM := 0.7
const APPROACH := 4.0
const FIRST_PLACE := 1.0
const CABIN_GAP := 0.4
const JEEP_LENGTH := 3.98      # Level3DBtr.VEHICLES' jeep body, 1:1
const JEEP_HALF_WIDTH := 1.33
const AXLES := Vector2(1.2, -1.1)  # front, rear, along the jeep (ramp_axles)
# Their heading: the way between the points HEADING_SPAN metres either side of
# them along their way, fewer behind them as they set off -- the window
# clamped at the start turned them by the first 0.3 m of the U-turn, five
# degrees, in the frame they moved -- and eased in off where they stood over
# that first HEADING_SPAN. The U-turn and the bend onto the Chinook's line
# are ARC_STEPS straight steps each, short enough that a turn at speed does
# not lurch from one to the next, as it did at 32 and 24.
const HEADING_SPAN := 0.6
const ARC_STEPS := 96
# Their speed: up to DRIVE_SPEED at DRIVE_ACCEL, down to RAMP_SPEED at
# DRIVE_BRAKE by the lip, and to a stop at their places -- or, the ramp not
# down yet, to a stop HOLD_BACK metres short of the lip, to wait for it.
const DRIVE_SPEED := 16.0
const DRIVE_ACCEL := 9.0
const DRIVE_BRAKE := 7.0
const RAMP_SPEED := 4.0
const HOLD_BACK := 8.0
# Their dust: fewer and smaller clouds than Level3DSplash3D's drive-off
# (WHEEL_DUST_STEP, WHEEL_CLOUD), which go past the camera and are gone; these
# turn in front of it, where theirs, lit through, were broad bright bands --
# and the camera comes in after them, where at 0.5 they were lumps as big as
# a wheel arch.
const DUST_STEP := 1.4
const DUST_CLOUD := Vector2(0.32, 0.3)
# The second jeep sets off FOLLOW seconds after the first, and slows and
# stops rather than come nearer than a jeep's length and SPACING to it while
# the first is on its way -- in their places in the cabin they stand closer.
const FOLLOW := 0.6
const SPACING := 1.0
# After the last is in: the ramp goes up after CLOSE_WAIT, and LIFT_WAIT
# after it is shut, the stage built, the Chinook lifts -- up at up to LIFT_UP
# m/s^2, and on into the sun from LIFT_LEAN seconds at up to LIFT_ON, each
# coming up to it over LIFT_RAMP seconds (_ramped): set off at once, it
# pitched its nose down in four frames -- and the title fades out over it
# LIFT_SHOWN seconds into that (fade_after).
const CLOSE_WAIT := 0.2
const CLOSE_SPEED := 1.5       # the ramp's clip, faster going up
const LIFT_WAIT := 0.2
const LIFT_UP := 2.5
const LIFT_ON := 5.0
const LIFT_LEAN := 0.6
const LIFT_RAMP := 0.8
const LIFT_SHOWN := 1.2
# A jeep in, its engine is put out at once (Level3DSplash3D's ENGINE_*), and
# what is left of it dying away is heard through the hull once the ramp
# goes up, MUFFLED as loud, coming down to that over MUFFLE_TIME.
const MUFFLED := 0.35
const MUFFLE_TIME := 0.8
# The camera after the jeeps once they set off: the sun rising as they go
# (Level3DSplash3D, RISE_*) and the frame open to the screen's foot, the
# ground between the camera and them was a wide empty floor under it all. So
# it follows them in, CHASE_BEHIND metres behind the middle of those on their
# way, forward only -- their U-turn brings them back towards it, and it holds
# rather than backs off -- and no nearer the Chinook than CHASE_NEAREST, where
# it stands whole in the frame, rotors and all, as it lifts off; up by
# CHASE_RISE as it goes, so that the jeeps ahead do not hide it. It lags them
# by CHASE_LAG seconds or so, so that it sets off and stops gently.
const CHASE_BEHIND := 13.0
const CHASE_NEAREST := 26.0
const CHASE_RISE := 0.8
const CHASE_LAG := 0.9
# What the camera comes in over (_chase): the boulders of ROCKS and the
# palms of PALMS are behind it by then or out of the frame, and the ground
# up to the Chinook was bare. So a few more, by hand, as ROCKS has them and
# out of their way: not in ROCKS, which the jeeps' way goes round (_plan) --
# clumps out to the sides of where the jeeps bend in onto the Chinook's line
# and either side of it, low, none over a metre high, so that from where the
# title opens they stand below the horizon, dark on the dark ground, and the
# sun's frame is as it was; and the last stones behind the Chinook, small at
# that distance. [position, radius, seed, squash, turn], as ROCKS.
const SCATTER := [
	# Left of the Chinook's line, where the left jeep has bent in past.
	[Vector3(-8.5, 0.0, -53.0), 0.85, 31, 0.7, 40.0],
	[Vector3(-9.6, 0.0, -54.2), 0.45, 32, 0.8, 160.0],
	[Vector3(-7.6, 0.0, -51.6), 0.25, 33, 0.85, 280.0],
	# Out to the left, seen as the camera comes in.
	[Vector3(-21.0, 0.0, -42.0), 0.7, 34, 0.75, 110.0],
	[Vector3(-19.9, 0.0, -43.3), 0.3, 35, 0.8, 20.0],
	[Vector3(-17.0, 0.0, -66.0), 1.0, 36, 0.6, 250.0],
	[Vector3(-15.6, 0.0, -64.8), 0.4, 37, 0.85, 75.0],
	[Vector3(-18.4, 0.0, -64.9), 0.28, 38, 0.8, 190.0],
	# Right of the line, and out to the right.
	[Vector3(9.8, 0.0, -57.5), 0.9, 39, 0.68, 300.0],
	[Vector3(11.1, 0.0, -56.4), 0.38, 40, 0.85, 130.0],
	[Vector3(19.5, 0.0, -38.5), 0.6, 41, 0.75, 220.0],
	[Vector3(20.6, 0.0, -39.6), 0.26, 42, 0.8, 50.0],
	[Vector3(20.0, 0.0, -71.0), 0.85, 43, 0.65, 15.0],
	[Vector3(18.7, 0.0, -70.2), 0.32, 44, 0.85, 140.0],
	# Nearer, either side of where the jeeps are in on the line, low in the
	# frame's corners where the camera stops.
	[Vector3(-7.5, 0.0, -46.5), 0.55, 51, 0.75, 60.0],
	[Vector3(-8.4, 0.0, -45.6), 0.22, 52, 0.85, 230.0],
	[Vector3(8.5, 0.0, -45.5), 0.5, 53, 0.7, 330.0],
	[Vector3(9.3, 0.0, -46.6), 0.24, 54, 0.8, 100.0],
	# Single stones on the open ground.
	[Vector3(-12.5, 0.0, -47.0), 0.22, 45, 0.85, 0.0],
	[Vector3(15.5, 0.0, -48.5), 0.25, 46, 0.8, 90.0],
	[Vector3(-4.8, 0.0, -73.0), 0.3, 47, 0.8, 200.0],
	[Vector3(6.5, 0.0, -76.0), 0.35, 48, 0.75, 310.0],
	[Vector3(26.0, 0.0, -58.0), 0.3, 49, 0.8, 60.0],
	[Vector3(-27.0, 0.0, -52.0), 0.28, 50, 0.85, 170.0],
]
# And two palms further back, out past PALMS' on either side, so that the
# frame's sides are not empty as it comes in; as PALMS has them. Out of the
# frame the title opens with they would be out of the camera's too by the
# time it has come in, so they are in it, at the half of its width that the
# disc leaves -- 0.5 of their distance off the middle, well clear of PALMS'
# at 0.43 and 0.375, beside which a palm read as a second trunk of theirs.
const SCATTER_PALMS := [
	[Vector3(-42.0, 0.0, -80.0), 3, 70.0, 0.8],
	[Vector3(41.0, 0.0, -82.0), 2, 300.0, 0.85],
]

var _chinook: Node3D
var _rotors: AnimationPlayer
var _ramp: AnimationPlayer
var _skeleton: Skeleton3D
var _sound: AudioStreamPlayer
var _clock := 0.0            # seconds since the title opened
var _flight := 0.0           # the Chinook's own: the same, but hurried (ARRIVE_HURRY)
var _rate := 1.0             # how fast _flight goes
var _hurry := 0.0            # 0 to 1, the way from 1 to ARRIVE_HURRY
var _lean := Vector2.ZERO    # its pitch and roll now, coming round (LEAN_TIME)
var _wash := 0.0             # clouds of wash owed
var _veil_owed := 0.0        # sheets of the veil owed
var _chase_to := CAMERA_AT.z  # where the camera is headed (CHASE_*), forward only
var _ramp_state := ""        # "", "opening", "open", "closing", "shut"
var _ramp_open_at := 0.0
var _launched := false
var _close_at := INF         # when the ramp goes up, once the jeeps are in (_flight)
var _lift_at := INF          # when it lifts, once it is shut and the stage built (_flight)
var _game_ready := false
var _plans: Array[Dictionary] = []   # per jeep, its way in (_plan)


func _build() -> void:
	super()
	var world := camera.get_parent()
	_chinook = (load(CHINOOK) as PackedScene).instantiate() as Node3D
	world.add_child(_chinook)
	for mesh in _chinook.find_children("*", "MeshInstance3D", true, false):
		_dress(mesh as MeshInstance3D)
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# It flies through the frame from behind the camera.
		(mesh as MeshInstance3D).extra_cull_margin = 4.0
	var players := Level3DChinook.split_clips(_chinook)
	_rotors = players[0]
	_ramp = players[1]
	_ramp.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_skeleton = _chinook.find_child("Skeleton3D", true, false) as Skeleton3D
	_ramp_open_at = ARRIVE_DELAY + ARRIVE_TIME + SETTLE_TIME + RAMP_WAIT
	for entry in SCATTER:
		var at: Vector3 = entry[0]
		_rock(world, Vector3(at.x, _ground_y(at.x, at.z), at.z), entry[1], entry[2], entry[3], entry[4],
				_rock_paint)
	for entry in SCATTER_PALMS:
		_palm(world, entry)
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	for i in _rigs.size():
		var plan := _plan(_rigs[i], i)
		_plans.append(plan)
		_rigs[i].plan = plan
		_rigs[i].index = i
		_rigs[i].speed = 0.0
		_rigs[i].muffle = 0.0
	_fly()


# ----------------------------------------------------------------------------
# The Chinook

# Where it is at `t` seconds since the title opened: on its way in, settling,
# on the ground and lifting off.
func _chinook_at(t: float) -> Vector3:
	var ground: Vector3 = LANDING + Vector3.UP * _height.call(LANDING.x, LANDING.z)
	if t > _lift_at:
		var up := t - _lift_at
		return ground + Vector3(0.0, _ramped(up, LIFT_UP), -_ramped(up - LIFT_LEAN, LIFT_ON))
	var k := clampf((t - ARRIVE_DELAY) / ARRIVE_TIME, 0.0, 1.0)
	if k < 1.0:
		var u := 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k)
		var w := 1.0 - u
		return ARRIVE[0] * w * w * w + ARRIVE[1] * 3.0 * w * w * u + ARRIVE[2] * 3.0 * w * u * u \
				+ ARRIVE[3] * u * u * u
	var hover: Vector3 = ARRIVE[3]
	# Smootherstep: its acceleration starts and ends at nothing too.
	var x := clampf((t - ARRIVE_DELAY - ARRIVE_TIME) / SETTLE_TIME, 0.0, 1.0)
	var settle := x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
	return Vector3(ground.x, lerpf(hover.y, ground.y, settle), ground.z)


# How far it has gone `t` seconds after setting off from rest, its
# acceleration coming up from nothing to `most` over LIFT_RAMP seconds.
static func _ramped(t: float, most: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < LIFT_RAMP:
		return most * t * t * t / (6.0 * LIFT_RAMP)
	var on := t - LIFT_RAMP
	return most * (LIFT_RAMP * LIFT_RAMP / 6.0 + LIFT_RAMP * 0.5 * on + 0.5 * on * on)


# The Chinook where _chinook_at has it, leaning as it slows, speeds up and
# turns, its nose into the way it goes and, slow, away from the camera; its
# ramp where its clip has it; its dust and its sound. `delta`: how long since
# the last, for the lean to come round over; none puts it straight there.
func _fly(delta := -1.0) -> void:
	var h := 1.0 / 30.0
	var p := _chinook_at(_flight)
	var before := _chinook_at(_flight - h)
	var after := _chinook_at(_flight + h)
	# In seconds, not the Chinook's own: hurried, it leans the harder.
	var velocity := (after - before) / (2.0 * h) * _rate
	var acceleration := (after - 2.0 * p + before) / (h * h) * _rate * _rate
	var flat := Vector2(velocity.x, velocity.z)
	var yaw := lerp_angle(PI, atan2(velocity.x, velocity.z), clampf(flat.length() / 6.0 - 0.2, 0.0, 1.0))
	var nose := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := nose.cross(Vector3.UP)
	var lean := Vector2(clampf(-acceleration.dot(nose) * PITCH_GAIN, -LEAN_MOST, LEAN_MOST),
			clampf(acceleration.dot(right) * ROLL_GAIN, -LEAN_MOST, LEAN_MOST))
	_lean = lean if delta < 0.0 else _lean.lerp(lean, 1.0 - exp(-delta / LEAN_TIME))
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -_lean.x) * Basis(Vector3.BACK, _lean.y)
	_chinook.transform = Transform3D(basis.scaled(Vector3.ONE * CHINOOK_SCALE), p)
	_chinook.visible = _flight > ARRIVE_DELAY


func _drive_ramp(delta: float) -> void:
	if _ramp_state == "" and _flight >= _ramp_open_at:
		_play_ramp("Ramp_Open", "opening")
	elif _ramp_state == "open" and _flight >= _close_at:
		_play_ramp("Ramp_Close", "closing")
	if _ramp_state in ["opening", "closing"]:
		_ramp.advance(delta * (CLOSE_SPEED if _ramp_state == "closing" else _rate))
		if _ramp.current_animation_position >= _ramp.current_animation_length:
			_ramp_state = "open" if _ramp_state == "opening" else "shut"
	Level3DChinook.hold_ramp(_skeleton)


func _play_ramp(clip: String, state: String) -> void:
	_ramp.play(clip)
	_ramp.seek(0.0, true)
	_ramp_state = state


func _ramp_length() -> float:
	return _ramp.get_animation("Ramp_Open").length


# The wash: clouds round it, more the nearer the ground, blown out from under
# it.
func _raise_wash(delta: float) -> void:
	var under: Vector3 = LANDING + Vector3.UP * _height.call(LANDING.x, LANDING.z)
	var height: float = _chinook.position.y - under.y
	if height > WASH_HEIGHT or not _chinook.visible:
		return
	var cel := _dust_style == "cel"
	var out_by := WASH_OUT + HOVER_OUT * maxf(height, 0.0)
	var puff: Vector2 = CEL_WASH if cel else WASH_CLOUD
	_wash += WASH_RATE * (CEL_WASH_RATE if cel else 1.0) * (1.0 - height / WASH_HEIGHT) * delta
	while _wash >= 1.0:
		_wash -= 1.0
		var edge := _hull_edge(out_by)
		_raise_cloud(edge[0], 1.0, puff.x, puff.y, WIND * 0.5, 0.0, "wash",
				edge[1] * _dust_rng.randf_range(WASH_SPEED.x, WASH_SPEED.y) * 2.0, WASH_THROW_TIME,
				{"born": WASH_BORN, "grow_time": WASH_THROW_TIME * 1.5})
	if not _veil_on:
		return
	_veil_owed += VEIL_RATE * (1.0 - height / WASH_HEIGHT) * delta
	while _veil_owed >= 1.0:
		_veil_owed -= 1.0
		var edge := _hull_edge(out_by)
		var from: Vector3 = edge[0]
		from.y = 0.0
		_raise_veil(from, edge[1] * _dust_rng.randf_range(VEIL_SPEED.x, VEIL_SPEED.y) + WIND * 0.5,
				_dust_rng.randf_range(VEIL_SIZE.x, VEIL_SIZE.y), VEIL_LONG,
				_dust_rng.randf_range(VEIL_LIFE.x, VEIL_LIFE.y))


# A point at the edge of the Chinook's hull on the ground, `out` metres
# outside it, and the way out from there, flat: on the outline of
# Level3DChinook.HULL_BOXES seen from above -- the cabin and the sponsons --
# by its length, the way out the side's own, turned a little from the
# middle at random so that the puffs off one side do not run in a row.
func _hull_edge(out: float) -> Array:
	var boxes := Level3DChinook.HULL_BOXES
	var basis := _chinook.transform.basis
	for attempt in 16:
		var box: AABB = boxes[_dust_rng.randi() % boxes.size()]
		var a := Vector2(box.position.x, box.position.z)
		var b := Vector2(box.end.x, box.end.z)
		var side := b - a
		var t := _dust_rng.randf() * 2.0 * (side.x + side.y)
		var p: Vector2
		var n: Vector2
		if t < side.x:
			p = Vector2(a.x + t, a.y)
			n = Vector2(0.0, -1.0)
		elif t < side.x + side.y:
			p = Vector2(b.x, a.y + t - side.x)
			n = Vector2(1.0, 0.0)
		elif t < 2.0 * side.x + side.y:
			p = Vector2(b.x - (t - side.x - side.y), b.y)
			n = Vector2(0.0, 1.0)
		else:
			p = Vector2(a.x, b.y - (t - 2.0 * side.x - side.y))
			n = Vector2(-1.0, 0.0)
		# On the outline of the two together, not inside the other one.
		var inside := false
		for other in boxes:
			if other != box and p.x > other.position.x + 0.01 and p.x < other.end.x - 0.01 \
					and p.y > other.position.z + 0.01 and p.y < other.end.z - 0.01:
				inside = true
		if inside:
			continue
		var at := _chinook.transform * Vector3(p.x, 0.0, p.y)
		var way := basis * Vector3(n.x, 0.0, n.y)
		way.y = 0.0
		var spread := basis * Vector3(p.x, 0.0, p.y)
		spread.y = 0.0
		way = (way.normalized() * 0.75 + spread.normalized() * 0.25
				+ way.normalized().cross(Vector3.UP) * _dust_rng.randf_range(-0.3, 0.3)).normalized()
		return [at + way * out, way]
	var away := Vector3(_dust_rng.randf_range(-1.0, 1.0), 0.0, _dust_rng.randf_range(-1.0, 1.0)).normalized()
	return [_chinook.position + away * out, away]


# A puff thinned by the Chinook's hull (Level3DChinook.HULL_BOXES), as the
# tank bench's CelSolids thins its puffs by the tanks': whole while its
# middle is a quarter of its radius outside, none half its radius inside,
# smoothly between, so that a puff the wash throws against the hull shrinks
# into it rather than stand through it -- as they did -- and a puff pushed
# out of the nearest face stood over the roof.
func _thin(at: Vector3, r: float) -> float:
	if not _chinook.visible:
		return 1.0
	var p := _chinook.transform.affine_inverse() * at
	var radius := r / CHINOOK_SCALE
	var inside := INF
	for box in Level3DChinook.HULL_BOXES:
		var q := (p - box.get_center()).abs() - box.size * 0.5
		var out := Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length()
		inside = minf(inside, out + minf(maxf(q.x, maxf(q.y, q.z)), 0.0))
	return smoothstep(-0.5 * radius, 0.25 * radius, inside)


func _play_sound() -> void:
	var wanted := Level3DAudio.stream(ROTOR_SOUND)
	if _sound.stream != wanted:
		_sound.stop()
		_sound.stream = wanted
		_sound.bus = Level3DAudio.bus(ROTOR_SOUND)
	var near := clampf(SOUND_NEAR / maxf(_chinook.position.distance_to(camera.position), 1.0), 0.0, 1.0)
	var volume := SOUND_VOLUME * near * (1.0 if _chinook.visible else 0.0)
	_sound.volume_db = Level3DAudio.volume_db(ROTOR_SOUND) + linear_to_db(maxf(volume, 0.0001))
	if wanted != null and not _sound.playing:
		_sound.play()


# ----------------------------------------------------------------------------
# The jeeps' way in

# Jeep `index`'s way from where it stands to its place in the cabin, as a
# curve on the ground, and how far along it the lip and its place are.
func _plan(rig: Dictionary, index: int) -> Dictionary:
	var rest: Transform3D = rig.jeep_rest
	var side: float = rig.side
	var from := Vector2(rest.origin.x, rest.origin.z)
	var ahead := Vector2(rest.basis.z.x, rest.basis.z.z).normalized()
	# Out past the rocks on its side.
	var clear := 0.0
	var behind := 0.0
	for entry in ROCKS:
		var at: Vector3 = entry[0]
		if signf(at.x) == side:
			clear = maxf(clear, absf(at.x) + entry[1])
			behind = minf(behind, at.z - entry[1])
	var out_x := side * (clear + ROCK_RIM + JEEP_HALF_WIDTH)
	var points := PackedVector2Array()
	# The U-turn: a half circle and the toe, out to its side, ending on -Z at
	# out_x.
	var across := Vector2(-ahead.y, ahead.x)
	if across.x * side < 0.0:
		across = -across
	# Turning towards `across` until it heads down -Z, and as wide as takes
	# it to out_x.
	var sweep := fposmod(atan2(-across.y, -ahead.y), TAU)
	var radius := (out_x - from.x) / (across.x * (1.0 - cos(sweep)) + ahead.x * sin(sweep))
	var centre := from + across * radius
	for k in ARC_STEPS + 1:
		var a := sweep * k / ARC_STEPS
		points.append(centre - across * radius * cos(a) + ahead * radius * sin(a))
	var turned := points[points.size() - 1]
	# Straight on past the rocks.
	var past := Vector2(turned.x, behind - ROCK_RIM - JEEP_HALF_WIDTH)
	points.append(past)
	# In onto the Chinook's line, and up it.
	var lip_z := LANDING.z + (Level3DChinook.HINGE_BACK + Level3DChinook.RAMP_LEN
			* cos(Level3DChinook._ramp_down())) * CHINOOK_SCALE
	var line := Vector2(LANDING.x, lip_z + APPROACH)
	var bend := (past.y - line.y) * 0.5
	for k in range(1, ARC_STEPS + 1):
		var u := float(k) / ARC_STEPS
		var w := 1.0 - u
		points.append(past * w * w * w + (past + Vector2(0.0, -bend)) * 3.0 * w * w * u
				+ (line + Vector2(0.0, bend)) * 3.0 * w * u * u + line * u * u * u)
	var place := FIRST_PLACE - index * (JEEP_LENGTH / CHINOOK_SCALE + CABIN_GAP)
	var end := Vector2(LANDING.x, LANDING.z - place * CHINOOK_SCALE)
	points.append(Vector2(LANDING.x, lip_z))
	points.append(end)
	var curve := Curve2D.new()
	curve.bake_interval = 0.2
	for point in points:
		curve.add_point(point)
	var length := curve.get_baked_length()
	var lip := length - (lip_z - end.y)
	return {"curve": curve, "length": length, "lip": lip, "hold": lip - HOLD_BACK, "start": INF}


func _place_at(plan: Dictionary, run: float) -> Vector2:
	return (plan.curve as Curve2D).sample_baked(clampf(run, 0.0, plan.length), true)


# The height of the ground at p, or of the Chinook's floor and ramp where they
# are over it (Level3DChinook._surface).
func _surface(p: Vector3) -> float:
	var outside: float = _height.call(p.x, p.z)
	var into := _chinook.transform.affine_inverse() * p
	if absf(into.x) > Level3DChinook.CABIN_HALF_WIDTH:
		return outside
	var back := -into.z
	var slope := Level3DChinook.ramp_angle(_skeleton)
	var deck := -INF
	if back <= Level3DChinook.HINGE_BACK:
		deck = Level3DChinook.FLOOR
	elif back <= Level3DChinook.HINGE_BACK + Level3DChinook.RAMP_LEN * cos(slope):
		deck = Level3DChinook.FLOOR + (back - Level3DChinook.HINGE_BACK) * tan(slope)
	if deck == -INF:
		return outside
	return maxf(outside, _chinook.position.y + deck * CHINOOK_SCALE)


# ----------------------------------------------------------------------------
# The menu's calls

# A game for `count` players: the jeeps it is for, the left one first, set off
# for the Chinook at once, the second FOLLOW after. When the title is to fade
# is not known yet (fade_after).
func launch(count: int) -> float:
	_launch_time = 0.0
	_launched = true
	for i in mini(count, _rigs.size()):
		var rig: Dictionary = _rigs[i]
		if not rig.on:
			rig.flicker = 0.0
		rig.on = true
		_engine_on(rig)
		_kick(rig, ENGINE_KICK * 0.6)
		rig.rev = 1.0
		rig.plan.start = _clock + LAUNCH_REV + i * FOLLOW
	return INF


# Seconds until the title is to fade out over the Chinook lifting off, or INF
# while it is not known: until the jeeps are in, the ramp is shut and the
# stage is built.
func fade_after() -> float:
	return (_lift_at + LIFT_SHOWN - _flight) / _rate


# The same, sooner and reckoned: from when the jeeps are in, the ramp to go
# up, the time it takes and the lift after it -- if the stage is built by
# then, INF until both. The title fades its song out over that, the ramp
# and the lift-off, rather than over the lift-off alone (Level3DTitle).
func music_fade_after() -> float:
	if is_finite(_lift_at):
		return fade_after()
	if is_inf(_close_at) or not _game_ready:
		return INF
	var closing := _ramp_length() / CLOSE_SPEED
	if _ramp_state == "closing":
		closing *= 1.0 - _ramp.current_animation_position / _ramp.current_animation_length
	elif _ramp_state == "open":
		closing += maxf(_close_at - _flight, 0.0) / _rate
	return closing + (LIFT_WAIT + LIFT_SHOWN) / _rate


# The stage under the title is built (Level3DTitle.game_ready): the Chinook
# may go.
func game_ready() -> void:
	_game_ready = true


# The title opened again: the Chinook back behind the camera, to come in
# again, and the jeeps where they stood.
func reset_launch() -> void:
	super()
	_chase_to = CAMERA_AT.z
	camera.position = CAMERA_AT
	_haze_mesh.position.z = CAMERA_AT.z - HAZE_DISTANCE
	_clock = 0.0
	_flight = 0.0
	_rate = 1.0
	_hurry = 0.0
	_wash = 0.0
	_veil_owed = 0.0
	_launched = false
	_close_at = INF
	_lift_at = INF
	_ramp_state = ""
	_ramp.play("Ramp_Close")
	_ramp.seek(_ramp_length(), true)
	for plan in _plans:
		plan.start = INF
	for rig in _rigs:
		(rig.jeep as Node3D).visible = true
		rig.speed = 0.0
		rig.muffle = 0.0
	_fly()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _sound != null and _sound.playing:
			_sound.stop()
		_silence_engines()
		return
	_clock += delta
	var hurry := _launched and _ramp_state in ["", "opening"]
	# Eased both ends: set off at a steady rate, the speeding up was a jolt.
	_hurry = move_toward(_hurry, 1.0 if hurry else 0.0, delta / HURRY_EASE)
	_rate = lerpf(1.0, ARRIVE_HURRY, smoothstep(0.0, 1.0, _hurry))
	_flight += delta * _rate
	var aboard := _launched
	for i in _rigs.size():
		var rig: Dictionary = _rigs[i]
		if not rig.going and _clock >= float(_plans[i].start):
			rig.going = true
		if is_finite(float(_plans[i].start)) and float(rig.run) < float(_plans[i].length) - 0.01:
			aboard = false
	if aboard and is_inf(_close_at):
		_close_at = _flight + CLOSE_WAIT
	if _ramp_state == "shut" and _game_ready and is_inf(_lift_at):
		_lift_at = _flight + LIFT_WAIT
	_drive_ramp(delta)
	_fly(delta)
	_raise_wash(delta)
	_play_sound()
	super(delta)
	_chase(delta)


# The camera after the jeeps on their way (CHASE_*), and the haze's sheet of
# warm air with it, HAZE_DISTANCE ahead: left where it stood, the camera came
# up to it, and it was a ripple across the whole frame.
func _chase(delta: float) -> void:
	var sum := 0.0
	var going := 0
	for rig in _rigs:
		if rig.going:
			sum += (rig.jeep as Node3D).position.z
			going += 1
	var nearest := LANDING.z + CHASE_NEAREST
	if going > 0:
		_chase_to = minf(_chase_to, clampf(sum / going + CHASE_BEHIND, nearest, CAMERA_AT.z))
	var z := lerpf(_chase_to, camera.position.z, exp(-delta / CHASE_LAG))
	var way := inverse_lerp(CAMERA_AT.z, nearest, z)
	camera.position = Vector3(CAMERA_AT.x, CAMERA_AT.y + CHASE_RISE * smoothstep(0.0, 1.0, way), z)
	_haze_mesh.position.z = z - HAZE_DISTANCE


# Shut in, its engine dying away is heard through the hull (MUFFLED).
func _engine_gain(rig: Dictionary, delta: float) -> float:
	var inside: bool = _ramp_state in ["closing", "shut"] and float(rig.run) >= float(rig.plan.length) - 0.01
	rig.muffle = move_toward(float(rig.muffle), 1.0 if inside else 0.0, delta / MUFFLE_TIME)
	return super(rig, delta) * lerpf(1.0, MUFFLED, float(rig.muffle))


# A jeep on its way in: along its plan as fast as the way allows (DRIVE_*),
# held short of the lip while the ramp is not down and behind the jeep ahead,
# its heading the curve's, riding the ground, the ramp and the floor by its
# axles, its wheels rolling, dust off its rear wheels on the ground; its
# lamps off once it is in, and out of sight once the ramp is shut on it.
func _drive_off(rig: Dictionary, delta: float) -> void:
	var plan: Dictionary = rig.plan
	var length: float = plan.length
	var lip: float = plan.lip
	var run: float = rig.run
	var most := minf(DRIVE_SPEED, sqrt(RAMP_SPEED * RAMP_SPEED + 2.0 * DRIVE_BRAKE * maxf(lip - run, 0.0)))
	most = minf(most, sqrt(2.0 * DRIVE_BRAKE * maxf(length - run, 0.0)) + 0.3)
	if _ramp_state != "open":
		most = minf(most, sqrt(2.0 * DRIVE_BRAKE * maxf(float(plan.hold) - run, 0.0)))
	var index: int = rig.index
	if index > 0:
		var ahead: Dictionary = _rigs[index - 1]
		if ahead.going and float(ahead.run) < float(ahead.plan.length) - 0.01:
			var between := (ahead.jeep as Node3D).position - (rig.jeep as Node3D).position
			between.y = 0.0
			most = minf(most, maxf(between.length() - JEEP_LENGTH - SPACING, 0.0) * 2.0)
	rig.speed = minf(float(rig.speed) + DRIVE_ACCEL * delta, most)
	var step: float = minf(float(rig.speed) * delta, length - run)
	run += step
	rig.run = run
	var at := _place_at(plan, run)
	var span := minf(run, HEADING_SPAN)
	var way := _place_at(plan, run + span) - _place_at(plan, run - span)
	var yaw := atan2(way.x, way.y) if span > 0.0 else 0.0
	var stood := (rig.jeep_rest as Transform3D).basis.get_euler().y
	yaw = lerp_angle(stood, yaw, smoothstep(0.0, HEADING_SPAN, run))
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	var centre := Vector3(at.x, 0.0, at.y)
	var front := _surface(centre + ahead * AXLES.x)
	var rear := _surface(centre + ahead * AXLES.y)
	var wheelbase := AXLES.x - AXLES.y
	centre.y = rear + (front - rear) * -AXLES.y / wheelbase
	var pitch := atan2(front - rear, wheelbase)
	var jeep := rig.jeep as Node3D
	jeep.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch), centre)
	for k in rig.wheels.size():
		var wheel_rest: Transform3D = rig.wheel_rests[k]
		(rig.wheels[k] as Node3D).transform = Transform3D(wheel_rest.basis * Basis(Vector3.RIGHT, run / WHEEL_RADIUS),
				wheel_rest.origin)
	if run < float(plan.lip) - 1.0:
		rig.dust_run += step
		var dust_step := _wheel_step(DUST_STEP)
		while rig.dust_run >= dust_step:
			rig.dust_run -= dust_step
			_wheel_dust(rig, DUST_CLOUD.x, DUST_CLOUD.y)
	if run >= float(plan.length) - 0.01 and rig.on:
		rig.on = false
		_engine_off(rig, true)
	jeep.visible = _ramp_state != "shut"
