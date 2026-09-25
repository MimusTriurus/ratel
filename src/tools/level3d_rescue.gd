# The rescue helicopter on the 3D stage 1 preview: jackal.FriendlyHelicopter,
# waiting at jackal.LandingPort for the prisoners the player has picked up,
# on jackal_littlebird.glb (jackal_littlebird_lowpoly.blend).
#
# Nothing here is part of the game. The rules are the original's, tick for
# tick, in the game's pixels on the game's map (level3d_map.gd):
#
#   * Stage 1 has one landing port, LANDING_PORT_RIGHT -- the level's Helipad
#     -- and the helicopter stands on it nose north, its rotor idling.
#   * With prisoners aboard, the player east of it -- up to 320 px east, from
#     66 px north of it to 49 south -- lets them off: the first after 45
#     ticks, then one every 91. Each walks straight west to it at 1 px a tick,
#     the last of them flashing (Level3DFriends.deliver), and is 500 points
#     when he gets there; the 3rd, 8th, 13th and 18th rescued are a weapon
#     upgrade as well.
#   * When nobody is walking to it and the player is not more than 80 px south
#     of it, and either there is no prisoner left anywhere and none aboard, or
#     the player has gone on 512 px north, it waits 182 ticks, revs up for 91,
#     lifts off over 114, speeds up north for 45, banks right through 45
#     degrees and on round another 225 on a 192 px circle, and flies off south.
#
# What is not the original's, and why:
#
#   * It arrives. The original's FRIENDLY_HELICOPTER_LANDING, on row 161 of
#     stage 1, sends one up the screen from under it, north and off the top;
#     by the time the port scrolls in there is a helicopter standing on it,
#     which LandingPort made. The level is one place here and the tilted view
#     sees a long way up it, so the one that flies up is the one that lands:
#     it bends onto the pad's x on the way, slows to a hover over the pad as it
#     speeds up leaving it (ACCELERATION_TIME), comes down as it lifts off,
#     backwards, and winds its rotor down as it revs it up. If the port's row
#     comes first -- the BTR put north of row 161 with --at -- it is simply
#     standing there, as the original's is.
#   * Height. The original draws it as a scale, Z0 / (Z0 - z) with z 1 on the
#     ground and 0 up, and its shadow 32, 37 px out when it is up: 0.8 m of
#     height under the preview's sun, which would fly it through the forest
#     round the pad, 2.1 m tall. It goes ALTITUDE up instead. The top view is
#     orthographic, so there it is also scaled by the original's factor, as the
#     Chinook is (level3d_chinook.gd): a model that casts no shadow and an
#     unscaled copy that only casts one.
#   * The rotor. The original turns it 15 degrees a tick idling and 30 flying;
#     at 100 ticks a second four blades would strobe backwards at 60 fps. They
#     turn that far a frame instead, as the Chinook's do.
#   * Size. It is at the BTR's scale, Level3DBtr.MODEL_SCALE, which its lines
#     are drawn for: 2.6 m nose to fin against the sprite's 128 px, 1.9 m.
class_name Level3DRescue
extends Node3D

const MODEL_PATH := "res://resources/3d/jackal_littlebird.glb"
const SOUND_PATH := "res://assets/soundeffects/helicopter2.ogg"
const PICKUP_SOUND_PATH := "res://assets/soundeffects/helicopter_pickup.ogg"
const UPGRADE_SOUND_PATH := "res://assets/soundeffects/weapon_upgrade.ogg"
const MODEL_SCALE := Level3DBtr.MODEL_SCALE
const PX := Level3DMap.PX

const ALTITUDE := 3.0
# Fly turns the rotor twice a second, 12 degrees a frame at 60 fps: the speed
# that turns it rotor_speed degrees a frame is rotor_speed / 12.
const ROTOR_DEGREES_PER_CLIP_SPEED := 12.0
const SLOW_ROTOR := 15.0
const FAST_ROTOR := 30.0
# FriendlyHelicopter.update's STATE_ACCELERATING goes this far, px, before it
# turns; coming in it slows over the same.
const BRAKE_DISTANCE := FriendlyHelicopter.ACCELERATION * \
		(FriendlyHelicopter.ACCELERATION_TIME - 1) * FriendlyHelicopter.ACCELERATION_TIME / 2.0
const LIFT_TIME := 114
const REV_TIME := 91
# Main.friendly_soldier_picked_up: the rescues that are a weapon upgrade too.
const UPGRADES: Array[int] = [3, 8, 13, 18]
const POINTS := 500

enum { NONE, INCOMING, BRAKING, DESCENDING, REVVING_DOWN, PICK_UP, REVVING_UP, LIFTING_OFF,
		ACCELERATING, TURNING, FLYING_AWAY }

var map: Level3DMap
var friends: Level3DFriends
# `frame.call()`: the frame the player sees, Rect2 in level x, z.
var frame: Callable
# `ground.call(x, z)` -> {"height", ...}.
var ground: Callable
# `player_position.call()`: the player's level x, z.
var player_position: Callable
var scored: Callable
# The top view: the model drawn at the original's scale for its height.
var enlarge := true
var verbose := false

var state := NONE
# FriendlyHelicopter's, verbatim: map px, game degrees (0 is north, clockwise
# on the screen), its height 1..0 and its rotor's degrees a tick.
var x := 0.0
var y := 0.0
var angle := 0.0
var z := 1.0
var rotor_speed := SLOW_ROTOR
var walking_soldiers := 0
var drop_off_delay := 45
var preparing_to_take_off := FriendlyHelicopter.TAKE_OFF_DELAY
var count := 0          # the ticks the state it is in has run
var turn_x := 0.0
var turn_y := 0.0
var rescued := 0        # Main.friendly_soldiers_picked_up

# The port: where on it the helicopter stands, and whether it lets prisoners
# off to its west (TYPE_LEFT) rather than its east.
var pad := Vector2.ZERO
var left_stop := false
var _port_row := -1
var _incoming_from := Vector2.ZERO
var _pad_height := NAN
var _trigger_y := -1

var _model: Node3D
var _shadow: Node3D
var _players: Array[AnimationPlayer] = []
var _sound: AudioStreamPlayer
var _pickup_sound: AudioStreamPlayer
var _upgrade_sound: AudioStreamPlayer


func _ready() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	if scene == null:
		push_error("Cannot load %s -- run export() in jackal_littlebird_lowpoly.blend" % MODEL_PATH)
		return
	_model = _instance(scene, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_shadow = _instance(scene, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_sound = _player(SOUND_PATH)
	_pickup_sound = _player(PICKUP_SOUND_PATH)
	_upgrade_sound = _player(UPGRADE_SOUND_PATH)
	_find_port()
	reset()


func _instance(scene: PackedScene, shadows: int) -> Node3D:
	var root := scene.instantiate() as Node3D
	add_child(root)
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = shadows
	var clips := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	clips.get_animation("Fly").loop_mode = Animation.LOOP_LINEAR
	clips.play("Fly")
	_players.append(clips)
	return root


func _player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	return p


# GameMode.process_trigger's LANDING_PORT_*, and LandingPort._init's spot for
# the helicopter on each kind of port.
func _find_port() -> void:
	var triggers: Array = map.stage.trigger_map[0]
	for row in triggers.size():
		for t in triggers[row]:
			match t[0]:
				Triggers.LANDING_PORT_LEFT:
					pad = Vector2(t[1] + 320, t[2] + 192)
					left_stop = true
				Triggers.LANDING_PORT_RIGHT:
					pad = Vector2(t[1] + 192, t[2] + 192)
				Triggers.LANDING_PORT_CIRCLE:
					pad = Vector2(t[1] + 224, t[2] + 256)
				_:
					continue
			_port_row = row


func reset() -> void:
	state = NONE
	rescued = 0
	walking_soldiers = 0
	_trigger_y = map.stage.map_height
	if _sound != null:
		_sound.stop()
	visible = false


# ----------------------------------------------------------------------------
# The tick

func tick() -> void:
	if _model == null:
		return
	if is_nan(_pad_height):
		var at := Level3DMap.to_level(pad)
		_pad_height = ground.call(at.x, at.y).height
	var view: Rect2 = frame.call()
	_process_triggers(Level3DMap.to_map(view.position).y, view)
	if state == NONE:
		return
	rotor_speed = clampf(rotor_speed, SLOW_ROTOR, FAST_ROTOR)
	if state >= ACCELERATING or state <= BRAKING:
		_play_sound()
	var player := Level3DMap.to_map(player_position.call())
	match state:
		INCOMING:
			y -= FriendlyHelicopter.FLIGHT_SPEED
			if y <= pad.y + BRAKE_DISTANCE:
				y = pad.y + BRAKE_DISTANCE
				_enter(BRAKING)
			_bend_onto_pad()
		BRAKING:
			y -= (FriendlyHelicopter.ACCELERATION_TIME - 1 - count) * FriendlyHelicopter.ACCELERATION
			count += 1
			_bend_onto_pad()
			if count == FriendlyHelicopter.ACCELERATION_TIME:
				x = pad.x
				y = pad.y
				_enter(DESCENDING)
		DESCENDING:
			# LIFTING_OFF backwards: the hover first, then down.
			var i := LIFT_TIME - 1 - count
			z = FriendlyHelicopter.HEIGHTS[i] if i < 91 else 0.0
			count += 1
			if count == LIFT_TIME:
				z = 1.0
				_enter(REVVING_DOWN)
		REVVING_DOWN:
			rotor_speed = FAST_ROTOR - (FAST_ROTOR - SLOW_ROTOR) * count / 90.0
			count += 1
			if count == REV_TIME:
				_land()
		PICK_UP:
			_update_pick_up(player)
		REVVING_UP:
			rotor_speed = SLOW_ROTOR + (FAST_ROTOR - SLOW_ROTOR) * count / 90.0
			count += 1
			if count == REV_TIME:
				rotor_speed = FAST_ROTOR
				_enter(LIFTING_OFF)
		LIFTING_OFF:
			z = FriendlyHelicopter.HEIGHTS[count] if count < 91 else 0.0
			count += 1
			if count == LIFT_TIME:
				_enter(ACCELERATING)
		ACCELERATING:
			y -= count * FriendlyHelicopter.ACCELERATION
			count += 1
			if count == FriendlyHelicopter.ACCELERATION_TIME:
				_enter(TURNING)
				turn_x = x
				turn_y = y
		TURNING:
			var t: Array = FriendlyHelicopter.TURNS[count]
			x = turn_x + t[0]
			y = turn_y + t[1]
			angle = t[2]
			count += 1
			if count == FriendlyHelicopter.TURNS_LENGTH:
				_enter(FLYING_AWAY)
				angle = -180.0
		FLYING_AWAY:
			y += FriendlyHelicopter.FLIGHT_SPEED
			if y > Level3DMap.to_map(view.end).y + 128:
				if verbose:
					print("rescue helicopter gone, %d rescued" % rescued)
				reset()
				return
	_pose()


# The rows the frame's top has passed, as the other spawners take them.
func _process_triggers(top: float, view: Rect2) -> void:
	var row := (int(top) >> 5) - 1
	if row < 0:
		return
	var triggers: Array = map.stage.trigger_map[0]
	while _trigger_y > row:
		_trigger_y -= 1
		for t in triggers[_trigger_y]:
			if t[0] == Triggers.FRIENDLY_HELICOPTER_LANDING and state == NONE:
				# From under the middle of the frame, as GameMode spawns it.
				var from := Level3DMap.to_map(Vector2(view.get_center().x, view.end.y))
				x = from.x
				y = from.y + 128
				if y < pad.y + BRAKE_DISTANCE:
					# Under a frame already north of the pad: it has landed.
					_land()
					visible = true
					continue
				_incoming_from = Vector2(x, y)
				angle = 0.0
				z = 0.0
				rotor_speed = FAST_ROTOR
				_enter(INCOMING)
				visible = true
				if verbose:
					print("rescue helicopter coming in at %.0f, %.0f" % [x, y])
		if _trigger_y == _port_row and state == NONE:
			_land()
			visible = true
			if verbose:
				print("rescue helicopter standing at %.0f, %.0f" % [x, y])


# On the way in, the x it came in on bent onto the pad's, by how far north it
# has come.
func _bend_onto_pad() -> void:
	var along := inverse_lerp(_incoming_from.y, pad.y, y)
	x = lerpf(_incoming_from.x, pad.x, clampf(along, 0.0, 1.0))


# On the pad, idling, as LandingPort makes it.
func _land() -> void:
	x = pad.x
	y = pad.y
	angle = 0.0
	z = 1.0
	rotor_speed = SLOW_ROTOR
	drop_off_delay = 45
	preparing_to_take_off = FriendlyHelicopter.TAKE_OFF_DELAY
	_enter(PICK_UP)


func _enter(next: int) -> void:
	state = next
	count = 0


# FriendlyHelicopter._update_pick_up, without the air cover it sends on the
# other stages.
func _update_pick_up(player: Vector2) -> void:
	if friends.pows > 0:
		var dx := player.x - x
		if player.y > y - 66 and player.y < y + 49 \
				and ((not left_stop and dx > 0 and dx < 320) or (left_stop and dx < 0 and dx > -320)):
			if drop_off_delay > 0:
				drop_off_delay -= 1
			else:
				drop_off_delay = FriendlyHelicopter.DROP_OFF_DELAY
				friends.deliver(player.x, player.y + 28, x, friends.pows == 1,
						_friendly_soldier_picked_up)
				friends.drop_off_pow()
				walking_soldiers += 1
	if walking_soldiers == 0 and player.y < y + 80 \
			and ((friends.friends.is_empty() and friends.pows == 0) or player.y < y - 512):
		if preparing_to_take_off > 0:
			preparing_to_take_off -= 1
		else:
			_enter(REVVING_UP)
			if verbose:
				print("rescue helicopter taking off, %d rescued" % rescued)
	else:
		preparing_to_take_off = FriendlyHelicopter.TAKE_OFF_DELAY


# FriendlyHelicopter.friendly_soldier_picked_up and Main's.
func _friendly_soldier_picked_up() -> void:
	walking_soldiers -= 1
	scored.call(POINTS)
	rescued += 1
	if rescued in UPGRADES and friends.upgrade_weapon():
		_upgrade_sound.play()
	else:
		_pickup_sound.play()
	if verbose:
		print("prisoner rescued: %d so far, weapon %s" % [rescued, friends.weapon_name()])


# Main.play_sound_if_not_playing.
func _play_sound() -> void:
	if not _sound.playing:
		_sound.play()


# ----------------------------------------------------------------------------
# Where it is

func _pose() -> void:
	var at := Level3DMap.to_level(Vector2(x, y))
	var position_3d := Vector3(at.x, _pad_height + (1.0 - z) * ALTITUDE, at.y)
	# The model's nose is its +Z; game angle 0 is north, -Z, and the angle
	# turns clockwise seen from above.
	var facing := Basis(Vector3.UP, PI - deg_to_rad(angle))
	# FriendlyHelicopter.render's scale, as a factor on the one it stands at.
	var z0 := FriendlyHelicopter.Z0
	var scale_now := (z0 - 1.0) / (z0 - z) if enlarge else 1.0
	_model.transform = Transform3D(facing.scaled(Vector3.ONE * MODEL_SCALE * scale_now), position_3d)
	_shadow.transform = Transform3D(facing.scaled(Vector3.ONE * MODEL_SCALE), position_3d)
	for p in _players:
		p.speed_scale = rotor_speed / ROTOR_DEGREES_PER_CLIP_SPEED
