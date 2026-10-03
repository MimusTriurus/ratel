# The title's other 3D scene, under --splash-landing: Level3DSplash3D's
# sunset, ground and jeeps, and a Chinook. It comes in over the camera as the
# title opens, flies off into the sun slowing, and sets down in front of it,
# tail to the camera, in a cloud of its own dust, and lowers its ramp. A game
# picked turns the jeeps it is for round and drives them up into it, one
# behind the other; the ramp goes up, it lifts off with them, and the title
# fades out over it -- into the stage, which opens on a Chinook unloading
# them (level3d_chinook.gd): the one loads them, the other unloads them.
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
# the landing, ARRIVE_TIME seconds of it slowing all the way (a constant
# deceleration, so a constant flare, nose up), ARRIVE_DELAY after the title
# opens; then SETTLE_TIME down onto its wheels, and the ramp after RAMP_WAIT.
const ARRIVE := [Vector3(10.0, 24.0, 30.0), Vector3(6.0, 16.0, -20.0), Vector3(0.0, 9.0, -50.0),
		Vector3(0.0, 5.0, -62.0)]
const ARRIVE_DELAY := 0.6
const ARRIVE_TIME := 7.0
const SETTLE_TIME := 2.2
const RAMP_WAIT := 0.4
# How it leans, radians for every m/s^2: its nose up as it slows and down as
# it speeds up, over into a turn; and no further than LEAN_MOST.
const PITCH_GAIN := 0.03
const ROLL_GAIN := 0.04
const LEAN_MOST := 0.3
# Its rotors' wash raises dust under it below WASH_HEIGHT metres, up to
# WASH_RATE clouds a second on the ground, WASH_RING metres out from under
# it, blown out at WASH_SPEED m/s; WASH_CLOUD as WHEEL_CLOUD.
const WASH_HEIGHT := 7.0
const WASH_RATE := 14.0
const WASH_RING := Vector2(3.0, 8.0)
const WASH_SPEED := Vector2(2.5, 5.0)
const WASH_CLOUD := Vector2(1.3, 0.6)
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
# Their speed: up to DRIVE_SPEED at DRIVE_ACCEL, down to RAMP_SPEED at
# DRIVE_BRAKE by the lip, and to a stop at their places.
const DRIVE_SPEED := 16.0
const DRIVE_ACCEL := 9.0
const DRIVE_BRAKE := 7.0
const RAMP_SPEED := 4.0
# Their dust: fewer and smaller clouds than Level3DSplash3D's drive-off
# (WHEEL_DUST_STEP, WHEEL_CLOUD), which go past the camera and are gone; these
# turn in front of it, where theirs, lit through, were broad bright bands.
const DUST_STEP := 1.4
const DUST_CLOUD := Vector2(0.5, 0.35)
# The second jeep sets off at least FOLLOW seconds after the first, and later
# if it would come nearer than a jeep's length and SPACING to it.
const FOLLOW := 0.6
const SPACING := 1.0
# After the last is in: the ramp goes up after CLOSE_WAIT, and LIFT_WAIT
# after it is shut, the Chinook lifts -- LIFT_UP m/s^2 up, LIFT_ON m/s^2 on
# into the sun from LIFT_LEAN seconds -- and the title fades out over it
# LIFT_SHOWN seconds into that (launch's hold).
const CLOSE_WAIT := 0.2
const CLOSE_SPEED := 1.5       # the ramp's clip, faster going up
const LIFT_WAIT := 0.2
const LIFT_UP := 2.5
const LIFT_ON := 5.0
const LIFT_LEAN := 0.6
const LIFT_SHOWN := 1.2

var _chinook: Node3D
var _rotors: AnimationPlayer
var _ramp: AnimationPlayer
var _skeleton: Skeleton3D
var _sound: AudioStreamPlayer
var _clock := 0.0            # seconds since the title opened
var _wash := 0.0             # clouds of wash owed
var _ramp_state := ""        # "", "opening", "open", "closing", "shut"
var _ramp_open_at := 0.0
var _close_at := INF         # when the ramp goes up, once it is known
var _lift_at := INF
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
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	for i in _rigs.size():
		var plan := _plan(_rigs[i], i)
		_plans.append(plan)
		_rigs[i].plan = plan
	_fly()


# ----------------------------------------------------------------------------
# The Chinook

# Where it is at `t` seconds since the title opened: on its way in, settling,
# on the ground and lifting off.
func _chinook_at(t: float) -> Vector3:
	var ground: Vector3 = LANDING + Vector3.UP * _height.call(LANDING.x, LANDING.z)
	if t > _lift_at:
		var up := t - _lift_at
		var on := maxf(up - LIFT_LEAN, 0.0)
		return ground + Vector3(0.0, 0.5 * LIFT_UP * up * up, -0.5 * LIFT_ON * on * on)
	var k := clampf((t - ARRIVE_DELAY) / ARRIVE_TIME, 0.0, 1.0)
	if k < 1.0:
		var u := 1.0 - (1.0 - k) * (1.0 - k)
		var w := 1.0 - u
		return ARRIVE[0] * w * w * w + ARRIVE[1] * 3.0 * w * w * u + ARRIVE[2] * 3.0 * w * u * u \
				+ ARRIVE[3] * u * u * u
	var hover: Vector3 = ARRIVE[3]
	var settle := smoothstep(0.0, 1.0, (t - ARRIVE_DELAY - ARRIVE_TIME) / SETTLE_TIME)
	return Vector3(ground.x, lerpf(hover.y, ground.y, settle), ground.z)


# The Chinook where _chinook_at has it, leaning as it slows, speeds up and
# turns, its nose into the way it goes and, slow, away from the camera; its
# ramp where its clip has it; its dust and its sound.
func _fly() -> void:
	var h := 1.0 / 30.0
	var p := _chinook_at(_clock)
	var before := _chinook_at(_clock - h)
	var after := _chinook_at(_clock + h)
	var velocity := (after - before) / (2.0 * h)
	var acceleration := (after - 2.0 * p + before) / (h * h)
	var flat := Vector2(velocity.x, velocity.z)
	var yaw := lerp_angle(PI, atan2(velocity.x, velocity.z), clampf(flat.length() / 6.0 - 0.2, 0.0, 1.0))
	var nose := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := nose.cross(Vector3.UP)
	var pitch := clampf(-acceleration.dot(nose) * PITCH_GAIN, -LEAN_MOST, LEAN_MOST)
	var roll := clampf(acceleration.dot(right) * ROLL_GAIN, -LEAN_MOST, LEAN_MOST)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.BACK, roll)
	_chinook.transform = Transform3D(basis.scaled(Vector3.ONE * CHINOOK_SCALE), p)
	_chinook.visible = _clock > ARRIVE_DELAY


func _drive_ramp(delta: float) -> void:
	if _ramp_state == "" and _clock >= _ramp_open_at:
		_play_ramp("Ramp_Open", "opening")
	elif _ramp_state == "open" and _clock >= _close_at:
		_play_ramp("Ramp_Close", "closing")
	if _ramp_state in ["opening", "closing"]:
		_ramp.advance(delta * (CLOSE_SPEED if _ramp_state == "closing" else 1.0))
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
	var at := Vector3(_chinook.position.x, 0.0, _chinook.position.z)
	_wash += WASH_RATE * (1.0 - height / WASH_HEIGHT) * delta
	while _wash >= 1.0:
		_wash -= 1.0
		var angle := _dust_rng.randf() * TAU
		var out := Vector3(cos(angle), 0.0, sin(angle))
		# The rotors are fore and aft: the wash is long along the Chinook.
		var reach := _dust_rng.randf_range(WASH_RING.x, WASH_RING.y)
		var cloud := _raise_cloud(at + out * reach * Vector3(0.7, 0.0, 1.3), 1.0, WASH_CLOUD.x, WASH_CLOUD.y)
		cloud.drift = out * _dust_rng.randf_range(WASH_SPEED.x, WASH_SPEED.y) + WIND * 0.5


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
	for k in 33:
		var a := sweep * k / 32.0
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
	for k in range(1, 25):
		var u := k / 24.0
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
	# How far along it the jeep is, every 1/60 s from when it sets off.
	var runs := PackedFloat32Array([0.0])
	var run := 0.0
	var speed := 0.0
	var dt := 1.0 / 60.0
	while run < length - 0.01:
		var most := minf(DRIVE_SPEED, sqrt(RAMP_SPEED * RAMP_SPEED + 2.0 * DRIVE_BRAKE * maxf(lip - run, 0.0)))
		most = minf(most, sqrt(2.0 * DRIVE_BRAKE * maxf(length - run, 0.0)) + 0.3)
		speed = minf(speed + DRIVE_ACCEL * dt, most)
		run = minf(run + speed * dt, length)
		runs.append(run)
	return {"curve": curve, "length": length, "lip": lip, "runs": runs, "start": INF}


# Along jeep `plan`'s way at `t` seconds since it set off.
func _run_at(plan: Dictionary, t: float) -> float:
	var runs: PackedFloat32Array = plan.runs
	var i := t * 60.0
	if i <= 0.0:
		return 0.0
	if i >= runs.size() - 1:
		return runs[runs.size() - 1]
	var j := floori(i)
	return lerpf(runs[j], runs[j + 1], i - j)


func _place_at(plan: Dictionary, run: float) -> Vector2:
	return (plan.curve as Curve2D).sample_baked(clampf(run, 0.0, plan.length), true)


# Seconds from setting off to the lip, and to its place.
func _time_to(plan: Dictionary, run: float) -> float:
	var runs: PackedFloat32Array = plan.runs
	for i in runs.size():
		if runs[i] >= run - 0.01:
			return i / 60.0
	return (runs.size() - 1) / 60.0


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
# for the Chinook -- as soon as they can, or later, to be at the ramp no
# sooner than it is down -- and the second once it will not run into the
# first. Returns how long the title is to wait before fading out.
func launch(count: int) -> float:
	_launch_time = 0.0
	var ramp_down := _ramp_open_at + _ramp_length()
	var last := 0.0
	for i in _rigs.size():
		var rig: Dictionary = _rigs[i]
		var plan := _plans[i]
		if i >= count:
			continue
		if not rig.on:
			rig.pitch_speed -= ENGINE_KICK
			rig.flicker = 0.0
		rig.on = true
		rig.pitch_speed -= ENGINE_KICK * 0.6
		var start := maxf(_clock + LAUNCH_REV, ramp_down - _time_to(plan, plan.lip))
		if i > 0:
			start = maxf(start, _plans[i - 1].start + FOLLOW)
			while _too_near(_plans[i - 1], plan, start):
				start += 0.05
		plan.start = start
		last = maxf(last, start + _time_to(plan, plan.length))
	_close_at = last + CLOSE_WAIT
	_lift_at = _close_at + _ramp_length() / CLOSE_SPEED + LIFT_WAIT
	return _lift_at + LIFT_SHOWN - _clock


# Whether `plan`, setting off at `start`, would come nearer to `ahead` than a
# jeep's length and SPACING, centre to centre, at any moment while `ahead` is
# on its way -- in their places in the cabin they stand closer than that.
func _too_near(ahead: Dictionary, plan: Dictionary, start: float) -> bool:
	var end := minf(start + _time_to(plan, plan.length), float(ahead.start) + _time_to(ahead, ahead.length))
	var t := start
	while t <= end:
		var a := _place_at(ahead, _run_at(ahead, t - float(ahead.start)))
		var b := _place_at(plan, _run_at(plan, t - start))
		if a.distance_to(b) < JEEP_LENGTH + SPACING:
			return true
		t += 1.0 / 30.0
	return false


# The title opened again: the Chinook back behind the camera, to come in
# again, and the jeeps where they stood.
func reset_launch() -> void:
	super()
	_clock = 0.0
	_wash = 0.0
	_close_at = INF
	_lift_at = INF
	_ramp_state = ""
	_ramp.play("Ramp_Close")
	_ramp.seek(_ramp_length(), true)
	for plan in _plans:
		plan.start = INF
	for rig in _rigs:
		(rig.jeep as Node3D).visible = true
	_fly()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _sound != null and _sound.playing:
			_sound.stop()
		return
	_clock += delta
	for i in _rigs.size():
		var rig: Dictionary = _rigs[i]
		if not rig.going and _clock >= float(_plans[i].start):
			rig.going = true
	_drive_ramp(delta)
	_fly()
	_raise_wash(delta)
	_play_sound()
	super(delta)


# A jeep on its way in: along its plan, its heading the curve's, riding the
# ground, the ramp and the floor by its axles, its wheels rolling, dust off
# its rear wheels on the ground; its lamps off once it is in, and out of
# sight once the ramp is shut on it.
func _drive_off(rig: Dictionary, _delta: float) -> void:
	var plan: Dictionary = rig.plan
	var run := _run_at(plan, _clock - float(plan.start))
	var step: float = run - float(rig.run)
	rig.run = run
	var at := _place_at(plan, run)
	var way := _place_at(plan, run + 0.6) - _place_at(plan, run - 0.6)
	var yaw := atan2(way.x, way.y)
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	var centre := Vector3(at.x, 0.0, at.y)
	var front := _surface(centre + ahead * AXLES.x)
	var rear := _surface(centre + ahead * AXLES.y)
	var span := AXLES.x - AXLES.y
	centre.y = rear + (front - rear) * -AXLES.y / span
	var pitch := atan2(front - rear, span)
	var jeep := rig.jeep as Node3D
	jeep.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch), centre)
	for k in rig.wheels.size():
		var wheel_rest: Transform3D = rig.wheel_rests[k]
		(rig.wheels[k] as Node3D).transform = Transform3D(wheel_rest.basis * Basis(Vector3.RIGHT, run / WHEEL_RADIUS),
				wheel_rest.origin)
	if run < float(plan.lip) - 1.0:
		rig.dust_run += step
		while rig.dust_run >= DUST_STEP:
			rig.dust_run -= DUST_STEP
			for wheel in rig.rear:
				var under: Vector3 = (wheel as Node3D).global_position
				_raise_cloud(under + Vector3(_dust_rng.randf_range(-0.2, 0.2), 0.0, _dust_rng.randf_range(-0.3, 0.3)),
						1.0, DUST_CLOUD.x, DUST_CLOUD.y)
	if run >= float(plan.length) - 0.01:
		rig.on = false
	jeep.visible = _ramp_state != "shut"
