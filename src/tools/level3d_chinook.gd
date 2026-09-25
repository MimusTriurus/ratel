# The Chinook that flies the BTR in at the start of the stage, on the 3D stage 1
# preview: jackal.Chinook and jackal.IntroPlayer, on jackal_chinook.glb
# (jackal_chinook_lowpoly.blend).
#
# Nothing here is part of the game. The run is the original's, tick for tick,
# in the game's pixels on the game's map (level3d_map.gd):
#
#   * In along a quarter circle of 1024 px from the south, decelerating at a
#     constant rate over 364 ticks from high up to the ground, nose first,
#     and down facing north.
#   * The jeep backs out: 75 ticks south-west on the diagonal at Player.SPEED,
#     then 11 ticks swinging its nose back round to north, and there it is,
#     at IntroPlayer's FINAL_X, FINAL_Y.
#   * Out along another quarter circle, climbing and turning west, until it
#     has turned 38 degrees; then it is gone and the BTR is the player's,
#     invincible, as Player.make_invincible has it.
#
# What is not the original's, and why:
#
#   * Size. The model is at the BTR's scale, Level3DBtr.MODEL_SCALE, because it
#     carries the BTR: 6.9 m nose to tail against the sprite's 308 px, 4.5 m.
#   * The ramp. The jeep came out from under a sprite; the BTR is in a cabin,
#     so the ramp comes down once it is on the ground (Ramp.Open, 1.5 s),
#     the BTR backs straight down it until its bow is clear of the lip, and
#     only then starts the original's diagonal. The ramp goes up again as it
#     lifts off. To end the diagonal where the original does, the Chinook sets
#     down that much further north: LANDING_SHIFT px, 234.
#   * The diagonal's heading turns at the jeep's Player.ANGLE_VELOCITY rather
#     than jumping to -45, which a hull shows and a sprite hid.
#   * Height. The original draws it as a scale, Z0 / (Z0 - z) -- a pinhole
#     camera Z0 above the ground -- and a shadow thrown out from under it.
#     Here it is also real height, z * ALTITUDE, which the tilted view shows
#     as it is; the top view is orthographic, so there the model is also
#     scaled by the original's own factor, and its shadow is thrown by an
#     unscaled copy of it that only casts shadows, from where it really is.
#     ALTITUDE is set so that the shadow is as far out at the top as the
#     original's.
class_name Level3DChinook
extends Node3D

const MODEL_PATH := "res://resources/3d/jackal_chinook.glb"
const SOUND_PATH := "res://assets/soundeffects/helicopter.ogg"
const MODEL_SCALE := Level3DBtr.MODEL_SCALE
const PX := Level3DMap.PX

# From jackal_chinook.py, in model metres, along the Chinook's length
# measured backwards from its origin.
const CARGO_BACK := 2.0         # CARGO: where the BTR rides
const HINGE_BACK := 7.5         # HINGE_Y
const FLOOR := 1.0              # the cabin floor, and the hinge's height
const RAMP_LEN := 4.6
const CABIN_HALF_WIDTH := 1.9   # CABIN_W
const MODEL_HEIGHT := 7.6       # the rear rotor's top, over the wheels
# The vehicle rides the ramp by its axles, which it knows (Level3DBtr's
# VEHICLES, ramp_axles), as it knows its bow (body_front).

const ALTITUDE := 7.4
# The original's arcs: their radius and where the first is centred.
const RADIUS := 1024.0
const ARC_CENTRE := Vector2(1540.0, 10780.0)
const ARC_LANDING := Vector2(516.0, 10780.0)   # where the original sets down
const AWAY_ANGLE := -128.0
const SOUND_VOLUME := 0.5

enum { FORWARDS, OPENING, OUT, DIAGONAL, REVERSE, AWAY, DONE }

# Asked of the scene, as the BTR is: `ground.call(x, z)` -> {"height", ...}.
var ground: Callable
var btr: Level3DBtr
# Called once, when the BTR is the player's.
var finished: Callable
# The top view: the model drawn at the original's scale for its height.
var enlarge := true

var state := FORWARDS
# Chinook's, verbatim: game degrees, its height 0..1, and the arc's clock.
var angle := 0.0
var z := 1.0
var t := Chinook.DT
var vt := Chinook.VT0
var X := 0.0
var Y := 0.0
var x := 0.0
var y := 0.0
# IntroPlayer's: its position in map px, its heading in game degrees, its
# countdown, and how far it has backed down the ramp.
var unit := Vector2.ZERO
var unit_angle := -90.0
var delay := 0
var backed := 0.0

var _model: Node3D
var _shadow: Node3D
var _players: Array[AnimationPlayer] = []   # the rotors, on both copies
var _ramps: Array[AnimationPlayer] = []     # the ramp, on both copies
var _sound: AudioStreamPlayer
var _landed_height := 0.0
var _shift := 0.0


# How far the Chinook sets down north of the original's spot, in px: the
# original's jeep ends FINAL_Y - 294 px behind it, the BTR has to back as far
# as clear_back() before it starts the same diagonal.
func landing_shift() -> float:
	return IntroPlayer.FINAL_Y - IntroPlayer.DIAGONAL_TIME * Player.SPEED - clear_back() \
			- ARC_LANDING.y


# In px behind the Chinook's origin: where the vehicle's origin is when its bow
# is clear of the lowered ramp's lip.
func clear_back() -> float:
	var lip := (HINGE_BACK + RAMP_LEN * cos(_ramp_down())) * MODEL_SCALE
	return (lip + btr.body_front() + 0.1) / PX


# The ramp's angle when it is down, its lip on the ground: jackal_chinook.py's
# RAMP_DOWN.
static func _ramp_down() -> float:
	return -asin(FLOOR / RAMP_LEN)


func _ready() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	if scene == null:
		push_error("Cannot load %s -- run export() in jackal_chinook_lowpoly.blend" % MODEL_PATH)
		state = DONE
		return
	_shift = landing_shift()
	_model = _instance(scene, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_shadow = _instance(scene, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	var landing := Level3DMap.to_level(ARC_LANDING + Vector2(0.0, _shift))
	_landed_height = ground.call(landing.x, landing.y).height
	_sound = AudioStreamPlayer.new()
	_sound.stream = load(SOUND_PATH)
	add_child(_sound)
	btr.visible = false
	# Chinook.update's first tick has not run: where it starts from.
	x = ARC_CENTRE.x + RADIUS * cos(t)
	y = ARC_CENTRE.y + _shift + RADIUS * sin(t)
	angle = 90.0 + Chinook.TO_DEGREES * t
	_pose()


# One copy of the model, its clips split in two players as the boat's are:
# the glTF export gives every clip a track for every bone any clip moves, so
# Fly would hold the ramp shut and the ramp's clips would stop the rotors.
func _instance(scene: PackedScene, shadows: int) -> Node3D:
	var root := scene.instantiate() as Node3D
	add_child(root)
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = shadows
	var imported := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var rotors := AnimationLibrary.new()
	var ramp := AnimationLibrary.new()
	for clip in imported.get_animation_list():
		var a := imported.get_animation(clip).duplicate() as Animation
		var is_ramp := String(clip).begins_with("Ramp")
		for i in range(a.get_track_count() - 1, -1, -1):
			var bone := str(a.track_get_path(i).get_concatenated_subnames())
			if (bone == "Ramp") != is_ramp:
				a.remove_track(i)
		a.loop_mode = Animation.LOOP_NONE if is_ramp else Animation.LOOP_LINEAR
		(ramp if is_ramp else rotors).add_animation(clip, a)
	var ramp_player := AnimationPlayer.new()
	imported.get_parent().add_child(ramp_player)
	ramp_player.root_node = ramp_player.get_path_to(imported.get_node(imported.root_node))
	imported.remove_animation_library("")
	imported.add_animation_library("", rotors)
	ramp_player.add_animation_library("", ramp)
	# The original turns its rotor 30 degrees a frame at 60 fps, five turns a
	# second; Fly is two.
	imported.speed_scale = 2.5
	imported.play("Fly")
	# The ramp goes by the tick, not by the frame.
	ramp_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ramp_player.play("Ramp_Close")
	ramp_player.seek(ramp_player.current_animation_length, true)
	_players.append(imported)
	_ramps.append(ramp_player)
	return root


func done() -> bool:
	return state == DONE


# The top of the model, for the top camera, which has to be above it.
func top() -> float:
	if _model == null:
		return 0.0
	return _model.position.y + MODEL_HEIGHT * _model.scale.y


# The continue: the jeep is just there, as Chinook.init does when
# main.continued.
func skip() -> void:
	if state == DONE:
		return
	_hand_over()


# ----------------------------------------------------------------------------
# The tick

func tick() -> void:
	match state:
		FORWARDS:
			vt -= Chinook.AT
			if vt >= 0:
				angle = 90.0 + Chinook.TO_DEGREES * t
				z = (PI - t) * Chinook.IPI2
				t += vt
				x = ARC_CENTRE.x + RADIUS * cos(t)
				y = ARC_CENTRE.y + _shift + RADIUS * sin(t)
			else:
				state = OPENING
				_play_ramp("Ramp_Open")
				backed = CARGO_BACK * MODEL_SCALE / PX
				unit = Vector2(x, y + backed)
				btr.visible = true
			_play_sound(SOUND_VOLUME)
		OPENING:
			if _advance_ramp():
				state = OUT
			_play_sound(SOUND_VOLUME)
		OUT:
			backed = minf(backed + Player.SPEED, clear_back())
			unit = Vector2(x, y + backed)
			if backed >= clear_back():
				state = DIAGONAL
				delay = IntroPlayer.DIAGONAL_TIME
			_play_sound(SOUND_VOLUME)
		DIAGONAL:
			unit += Vector2(-Player.SPEED, Player.SPEED)
			unit_angle = move_toward(unit_angle, -45.0, Player.ANGLE_VELOCITY)
			delay -= 1
			if delay == 0:
				state = REVERSE
				delay = IntroPlayer.REVERSE_TIME
			_play_sound(SOUND_VOLUME)
		REVERSE:
			if unit_angle > -90:
				unit_angle -= Player.ANGLE_VELOCITY
			else:
				unit_angle = -90
			delay -= 1
			if delay == 0:
				unit = Vector2(IntroPlayer.FINAL_X, IntroPlayer.FINAL_Y)
				_unload_completed()
			_play_sound(SOUND_VOLUME)
		AWAY:
			_advance_ramp()
			vt += Chinook.AT
			angle = Chinook.TO_DEGREES * t - 90.0
			z = -t * Chinook.IPI2
			t -= vt
			x = X + RADIUS * cos(t)
			y = Y + RADIUS * sin(t)
			if angle < AWAY_ANGLE:
				_hand_over()
				return
			_play_sound(SOUND_VOLUME + (angle + 90.0) / 76.0)
	_pose()
	if state != FORWARDS:
		_pose_unit()


func _unload_completed() -> void:
	state = AWAY
	X = x - RADIUS
	Y = y
	vt = 0.0
	t = 0.0
	_play_ramp("Ramp_Close")


func _hand_over() -> void:
	state = DONE
	btr.visible = true
	var at := Level3DMap.to_level(Vector2(IntroPlayer.FINAL_X, IntroPlayer.FINAL_Y))
	btr.place(Vector3(at.x, 0.0, at.y), PI / 2.0)
	if _sound != null:
		_sound.stop()
	queue_free()
	finished.call()


func _play_ramp(clip: String) -> void:
	for p in _ramps:
		p.play(clip)
		p.seek(0.0, true)


# The ramp one tick on; true once the clip is over.
func _advance_ramp() -> bool:
	var over := true
	for p in _ramps:
		p.advance(1.0 / Engine.physics_ticks_per_second)
		over = over and p.current_animation_position >= p.current_animation_length
	return over


# Main.play_sound_if_not_playing.
func _play_sound(volume: float) -> void:
	if not _sound.playing:
		_sound.volume_db = linear_to_db(clampf(volume, 0.0001, 1.0))
		_sound.play()


# ----------------------------------------------------------------------------
# Where things are

func _pose() -> void:
	var at := Level3DMap.to_level(Vector2(x, y))
	var position_3d := Vector3(at.x, _landed_height + z * ALTITUDE, at.y)
	# The model's nose is its +Z; a game angle a points (cos a, sin a) in x, z.
	var facing := Basis(Vector3.UP, PI / 2.0 - deg_to_rad(angle))
	var scale_now := Chinook.Z0 / (Chinook.Z0 - z) if enlarge else 1.0
	_model.transform = Transform3D(facing.scaled(Vector3.ONE * MODEL_SCALE * scale_now), position_3d)
	_shadow.transform = Transform3D(facing.scaled(Vector3.ONE * MODEL_SCALE), position_3d)


# The BTR where IntroPlayer is, riding on whatever is under its axles: the
# cabin floor, the ramp or the ground.
func _pose_unit() -> void:
	var at := Level3DMap.to_level(unit)
	var heading := deg_to_rad(-unit_angle)
	var ahead := Vector3(cos(heading), 0.0, -sin(heading))
	var centre := Vector3(at.x, 0.0, at.y)
	var front := centre + ahead * btr.front_axle()
	var rear := centre + ahead * btr.rear_axle()
	var hf := _surface(front)
	var hr := _surface(rear)
	var span := btr.front_axle() - btr.rear_axle()
	centre.y = hr + (hf - hr) * -btr.rear_axle() / span
	btr.carry(centre, heading, atan2(hf - hr, span))


# The height of the ground at p, or of the Chinook's floor and ramp where
# they are over it: the ground everywhere once it has lifted off.
func _surface(p: Vector3) -> float:
	var outside: float = ground.call(p.x, p.z).height
	if state == AWAY:
		return outside
	var into := _shadow.global_transform.affine_inverse() * p   # model metres
	if absf(into.x) > CABIN_HALF_WIDTH:
		return outside
	var back := -into.z
	var ramp_angle := _ramp_angle()
	var deck := -INF
	if back <= HINGE_BACK:
		deck = FLOOR
	elif back <= HINGE_BACK + RAMP_LEN * cos(ramp_angle):
		deck = FLOOR + (back - HINGE_BACK) * tan(ramp_angle)
	if deck == -INF:
		return outside
	return maxf(outside, _shadow.position.y + deck * MODEL_SCALE)


# The ramp's angle up from level now, off the ramp bone's pose: the clip is
# the one place that knows it.
func _ramp_angle() -> float:
	var skeleton := _shadow.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skeleton.find_bone("Ramp")
	var rest := skeleton.get_bone_global_rest(bone)
	var now := skeleton.get_bone_global_pose(bone)
	# The ramp runs back from the hinge: model -Z, which the bone's pose
	# carries from its closed position.
	var closed := deg_to_rad(48.0)
	var along := (now.basis * rest.basis.inverse()) * Vector3(0.0, sin(closed), -cos(closed))
	return atan2(along.y, -along.z)
