# The rescue helicopter on the 3D stage 1 preview: jackal.FriendlyHelicopter,
# waiting at jackal.LandingPort for the prisoners the player has picked up,
# on jackal_littlebird_mh6.glb (jackal_littlebird_mh6_lowpoly.blend: A.I.R's
# MH-6, CC BY 4.0, resources/3d/jackal_littlebird_mh6.txt). The one built
# here, jackal_littlebird.glb, is kept beside it.
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
#   * With two players (the preview's co-op, which the NES game had and the
#     Java original has not) both jeeps are let off at once, each on its own
#     delay; a prisoner, his 500 points and the rescues that are an upgrade
#     are the jeep's that brought him, and it waits until every jeep still in
#     the game is past it or has nobody left to bring, as GameMode's does.
#   * The port's lamps pulse, red and blue half a period apart: LandingPort's
#     ALPHAS, 0.5 + sin(pi i / 91) / 2 over 182 ticks, the glow sprite over the
#     dim lamp at that alpha. Here that alpha takes the lamps' emission from
#     LAMP_DIM to LAMP_LIT (bind_lamps).
#
# What is not the original's, and why:
#
#   * The lamps' Blender clip is not what runs. jackal_assets.blend keys
#     J_LightRed's and J_LightBlue's emission strength, on and off every 8
#     frames at 24 fps, and glTF carries no material animation: the level's
#     glb has them stuck where the export left them, red dim and blue lit. So
#     the preview drives them itself, by the original's rule rather than the
#     clip's, between the clip's two strengths.
#
#   * It arrives. The original's FRIENDLY_HELICOPTER_LANDING, on row 161 of
#     stage 1, sends one up the screen from under it, north and off the top;
#     by the time the port scrolls in there is a helicopter standing on it,
#     which LandingPort made. The level is one place here and the tilted view
#     sees a long way up it, so the one that flies up is the one that lands:
#     it bends onto the pad's x on the way, slows to a hover over the pad as it
#     speeds up leaving it (FLIGHT_ACCEL), comes down as it lifts off,
#     backwards, and winds its rotor down as it revs it up.
#   * How it leaves. The original's speeds off north in under half a second,
#     2 g, and turns on a 2.8 m circle, smaller than the helicopter, at 2.8 g:
#     no helicopter could. Once it has lifted off nothing it does is the
#     game's, so it leaves as one would: turns round in its hover to face
#     south (HOVER_TURN), speeds off at 0.3 g (FLIGHT_ACCEL), climbing, and
#     flies off south as the original's does once round. It comes in slowing
#     at the same 0.3 g, which sets it down 0.9 s later than braking at the
#     original's 2 g did. If the port's row
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
#   * Size. It is at the people's scale, Level3DFriends.MODEL's 0.55, not
#     the BTR's 0.31 (Level3DBtr.MODEL_SCALE) the vehicles are at: the
#     prisoners sit in it (Level3DRescueSeats), and at the BTR's they had to
#     shrink as they sat, a man on the ground being as tall as its rotor. So
#     it is 4.4 m nose to fin against the sprite's 128 px, 1.9 m -- big, as
#     the people are next to the vehicles.
#   * How it flies (_pose). The original slides a sprite along its path,
#     turned to it; a model doing that flew as if on a rail. Where it is and
#     which way it goes are still the original's, tick for tick; how it sits
#     in the air is taken from that path (Level3DFlight): nose down for its speed and its
#     acceleration and up as it brakes, banked into its turns by how hard it
#     turns, each on a spring, its heading after the path's on a stiffer one.
#     It lifts off into a hover HOVER_HEIGHT up and climbs the rest of the
#     way as it speeds off, and comes down to the hover on its way in; it
#     sways a little while it hovers, and stirs on its skids as it lifts off
#     and sets down. Drawn between its ticks (_process): at 100 ticks a
#     second drawn at 60 frames it went 9 cm one frame and 18 the next.
class_name Level3DRescue
extends Node3D

const MODEL_PATH := "res://resources/3d/jackal_littlebird_mh6.glb"
# Level3DAudio's: helicopter2.ogg, helicopter_pickup.ogg and
# weapon_upgrade.ogg, the original's, in the original mode. The rotor is a
# player of its own, kept playing while it flies; the other two are one-shots.
const SOUND := "rescue_rotor"
const PICKUP_SOUND := "rescue_pickup"
const UPGRADE_SOUND := "upgrade"
const MODEL_SCALE: float = Level3DFriends.MODEL.scale
const PX := Level3DMap.PX

const ALTITUDE := 3.0
const TOP := 2.0                # metres over its skids to over its rotor
# How it flies (_pose, _flight_height), level metres and seconds. It hovers
# HOVER_HEIGHT up after lifting off and before setting down, climbs the rest
# to ALTITUDE as it speeds off, and comes down to the hover over the last
# APPROACH metres in, most of them braking (BRAKE_DISTANCE).
const HOVER_HEIGHT := 1.2
const APPROACH := 16.0
# It tilts (Level3DFlight, at its defaults) about this far over its skids,
# about where its weight is.
const PIVOT := 0.9
# Light on its skids: it rocks as it revs up to lift off and as it sets down,
# till they are this far off the pad.
const SKIDS_CLEAR := 0.2
# Fly turns the rotor twice a second, 12 degrees a frame at 60 fps: the speed
# that turns it rotor_speed degrees a frame is rotor_speed / 12.
const ROTOR_DEGREES_PER_CLIP_SPEED := 12.0
const SLOW_ROTOR := 15.0
const FAST_ROTOR := 30.0
# The rotor's sound at SLOW_ROTOR, idling on the pad, against FAST_ROTOR's:
# its gain and its pitch, the two going from one to the other with the
# rotor's speed as it revs up and down. The modern sound's alone.
const IDLE_GAIN := 0.5
const IDLE_PITCH := 0.8
# Its own way in and out (the header's How it flies): it speeds up and slows
# down at FLIGHT_ACCEL, px a tick a tick -- 0.3 g, which a helicopter does
# nose down or up 17 degrees -- to and from FriendlyHelicopter.FLIGHT_SPEED,
# over 3 s and BRAKE_DISTANCE, 13 m. Before it speeds off it turns round in
# its hover to face south, over HOVER_TURN_TICKS.
const FLIGHT_ACCEL := 0.3 * Level3DFlight.G / (PX * 100.0 * 100.0)
const BRAKE_DISTANCE := FriendlyHelicopter.FLIGHT_SPEED * FriendlyHelicopter.FLIGHT_SPEED / (2.0 * FLIGHT_ACCEL)
const HOVER_TURN_TICKS := 250
const LIFT_TIME := 114
const REV_TIME := 91
# Main.friendly_soldier_picked_up: the rescues that are a weapon upgrade too.
const UPGRADES: Array[int] = [3, 8, 13, 18]
const POINTS := 500

enum { NONE, INCOMING, BRAKING, DESCENDING, REVVING_DOWN, PICK_UP, REVVING_UP, LIFTING_OFF,
		HOVER_TURN, ACCELERATING, FLYING_AWAY, GONE }

var map: Level3DMap
var friends: Level3DFriends
# `frame.call()`: the frame the player sees, Rect2 in level x, z.
var frame: Callable
# `ground.call(x, z)` -> {"height", ...}.
var ground: Callable
# `players.call()`: the players still in the game, each as [level x, z,
# Level3DFriends.Carrier].
var players: Callable
# `scored.call(points, carrier)`: to the player with that carrier.
var scored: Callable
# The top view: the model drawn at the original's scale for its height.
var enlarge := true
var verbose := false
# Its crewman, out waving the jeep over while it waits for prisoners to be
# let off (Level3DRescueCrew); `_to_let_off` whether anyone is bringing some
# and not letting them off yet, as _update_pick_up last saw it.
var crew: Level3DRescueCrew
# Its pilot, its crewman when in and the prisoners aboard, sitting
# (Level3DRescueSeats).
var seats: Level3DRescueSeats
var _to_let_off := false

var state := NONE
# FriendlyHelicopter's, verbatim: map px, game degrees (0 is north, clockwise
# on the screen), its height 1..0 and its rotor's degrees a tick.
var x := 0.0
var y := 0.0
var angle := 0.0
var z := 1.0
var rotor_speed := SLOW_ROTOR
var walking_soldiers := 0
var preparing_to_take_off := FriendlyHelicopter.TAKE_OFF_DELAY
var count := 0          # the ticks the state it is in has run
var speed := 0.0        # px a tick, on its own way in and out
var rescued := 0        # all the players' Main.friendly_soldiers_picked_up

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
var _fading: Tween   # the rotor dying away once it has flown off (fade_out)
# How it flies (_pose): its tilts (Level3DFlight), and the model's and the
# shadow's last two poses, drawn between (_process). `_snap` puts it straight
# where it is, as it appears and as it lands.
var _flight := Level3DFlight.new()
var _snap := true
var _model_from := Transform3D()
var _model_to := Transform3D()
var _shadow_from := Transform3D()
var _shadow_to := Transform3D()

# The port's lamps: the level's two materials, one for every red lamp and one
# for every blue, and LandingPort's two indices into ALPHAS.
const LAMP_DIM := 0.25
const LAMP_LIT := 3.0
# J_LightRed's and J_LightBlue's Emission Color in Blender, linear; the glb's
# has the strength it was exported at multiplied in.
const RED_GLOW := Color(1.0, 0.01, 0.005)
const BLUE_GLOW := Color(0.042, 0.262, 1.0)
var _red_lamp: StandardMaterial3D
var _blue_lamp: StandardMaterial3D
var _red_index := 0
var _blue_index := 91


func _ready() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	if scene == null:
		push_error("Cannot load %s -- run export() in jackal_littlebird_mh6_lowpoly.blend" % MODEL_PATH)
		return
	_model = _instance(scene, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_shadow = _instance(scene, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	crew = Level3DRescueCrew.new()

	add_child(crew)
	seats = Level3DRescueSeats.new()
	seats.friends = friends
	seats.ground = ground
	add_child(seats)
	seats.bind(_model)
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
	set_benches(root, benches_wanted())
	return root


# The MH-6's external personnel benches, a plank either side on the skids'
# struts: UpBenches in the glb (jackal_littlebird_mh6.py's benches()), an
# upgrade of its own as the jeeps' are parts of their own, the prisoners'
# first seats (Level3DRescueSeats). On unless --no-heli-benches, here and in
# the shop.
const BENCHES := "UpBenches"


static func set_benches(model: Node, on: bool) -> void:
	var part := model.find_child(BENCHES, true, false) as Node3D
	if part != null:
		part.visible = on


static func benches_wanted() -> bool:
	return not OS.get_cmdline_user_args().has("--no-heli-benches")


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


# The level's port lamps, by their materials: every lamp of a colour shares one,
# so one write lights them all, as the original draws them all at one alpha.
func bind_lamps(level: Node) -> void:
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				continue
			match material.resource_name:
				"J_LightRed":
					_red_lamp = material
				"J_LightBlue":
					_blue_lamp = material
	for pair in [[_red_lamp, RED_GLOW], [_blue_lamp, BLUE_GLOW]]:
		if pair[0] == null:
			push_error("No %s in the level -- the port's lamps will not pulse" % (
					"J_LightRed" if pair[1] == RED_GLOW else "J_LightBlue"))
			continue
		(pair[0] as StandardMaterial3D).emission_enabled = true
		(pair[0] as StandardMaterial3D).emission = (pair[1] as Color).linear_to_srgb()
	_pulse_lamps()


# LandingPort.update and its _draw_red / _draw_blue.
func _pulse_lamps() -> void:
	_red_index = (_red_index + 1) % LandingPort.ALPHAS.size()
	_blue_index = (_blue_index + 1) % LandingPort.ALPHAS.size()
	if _red_lamp != null:
		_red_lamp.emission_energy_multiplier = lerpf(LAMP_DIM, LAMP_LIT, LandingPort.ALPHAS[_red_index])
	if _blue_lamp != null:
		_blue_lamp.emission_energy_multiplier = lerpf(LAMP_DIM, LAMP_LIT, LandingPort.ALPHAS[_blue_index])


func reset() -> void:
	state = NONE
	if crew != null:
		crew.reset()
	if seats != null:
		seats.reset()
	rescued = 0
	walking_soldiers = 0
	_snap = true
	_trigger_y = map.stage.map_height
	if _sound != null:
		if _fading != null:
			_fading.kill()
			_fading = null
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
	_pulse_lamps()
	var view: Rect2 = frame.call()
	_process_triggers(Level3DMap.to_map(view.position).y, view)
	# Flown off, it is GONE: FriendlyHelicopter removes itself, and only R
	# (reset) takes the stage's rows again, which would send it back up.
	if state == NONE or state == GONE:
		return
	rotor_speed = clampf(rotor_speed, SLOW_ROTOR, FAST_ROTOR)
	# FriendlyHelicopter.update's: heard from STATE_ACCELERATING, and here
	# coming in, which the original's never was; on the pad it is silent. The
	# modern rotor is heard on the pad as well, idling, since it turns there.
	if not Level3DAudio.as_original() or state >= ACCELERATING or state <= BRAKING:
		_play_sound()
	elif _sound.stream != Level3DAudio.stream(SOUND):
		# Switched to the original on the pad: the modern loop would play on.
		_sound.stop()
		_sound.stream = null
	match state:
		INCOMING, BRAKING:
			# At FLIGHT_SPEED until slowing at FLIGHT_ACCEL would stop it on
			# the pad, and slowing from there: the speed that stops it in the
			# way left.
			speed = minf(FriendlyHelicopter.FLIGHT_SPEED, sqrt(2.0 * FLIGHT_ACCEL * maxf(y - pad.y, 0.0)))
			y = maxf(y - speed, pad.y)
			if state == INCOMING and speed < FriendlyHelicopter.FLIGHT_SPEED:
				_enter(BRAKING)
			_bend_onto_pad()
			if y <= pad.y:
				x = pad.x
				y = pad.y
				speed = 0.0
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
			_update_pick_up()
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
				_enter(HOVER_TURN)
		HOVER_TURN:
			# Round to the right on the spot, eased in and out, to face south:
			# the way it leaves, not the original's north, a loop and back.
			count += 1
			angle = 180.0 * smoothstep(0.0, HOVER_TURN_TICKS, count)
			if count == HOVER_TURN_TICKS:
				angle = 180.0
				speed = 0.0
				_enter(ACCELERATING)
		ACCELERATING:
			# Eased off over the last quarter, so that the nose comes up as it
			# reaches its speed rather than all at once.
			var top := FriendlyHelicopter.FLIGHT_SPEED
			var ease_off := clampf((top - speed) / (0.25 * top), 0.2, 1.0)
			speed = minf(speed + FLIGHT_ACCEL * ease_off, top)
			y += speed
			count += 1
			if speed >= FriendlyHelicopter.FLIGHT_SPEED:
				_enter(FLYING_AWAY)
		FLYING_AWAY:
			y += FriendlyHelicopter.FLIGHT_SPEED
			if y > Level3DMap.to_map(view.end).y + 128:
				if verbose:
					print("rescue helicopter gone, %d rescued" % rescued)
				_enter(GONE)
				_fading = Level3DAudio.fade_out(_sound)
				visible = false
				return
	# Out while there are prisoners to let off and none walking over yet.
	if crew != null:
		crew.verbose = verbose
		crew.tick(pad_position(), -1.0 if left_stop else 1.0,
				state == PICK_UP and _to_let_off and walking_soldiers == 0)
	_pose()
	if seats != null:
		seats.verbose = verbose
		seats.tick(x, state >= LIFTING_OFF, crew == null or crew.state == Level3DRescueCrew.IN)


# The rows the frame's top has passed, as the other spawners take them.
func _process_triggers(top: float, view: Rect2) -> void:
	var row := (int(top) >> 5) - 1
	if row < 0:
		return
	var triggers: Array = map.triggers()
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
				speed = FriendlyHelicopter.FLIGHT_SPEED
				_snap = true
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
	_snap = true
	for p in players.call():
		(p[1] as Level3DFriends.Carrier).drop_off_delay = 45
	preparing_to_take_off = FriendlyHelicopter.TAKE_OFF_DELAY
	_enter(PICK_UP)


func _enter(next: int) -> void:
	state = next
	count = 0


# FriendlyHelicopter._update_pick_up, without the air cover it sends on the
# other stages, for every player.
func _update_pick_up() -> void:
	var leaving := walking_soldiers == 0
	_to_let_off = false
	for p in players.call():
		var player := Level3DMap.to_map(p[0])
		var c: Level3DFriends.Carrier = p[1]
		if c.pows > 0:
			var dx := player.x - x
			var stopped := player.y > y - 66 and player.y < y + 49 \
					and ((not left_stop and dx > 0 and dx < 320) or (left_stop and dx < 0 and dx > -320))
			_to_let_off = _to_let_off or not stopped
			if stopped:
				if c.drop_off_delay > 0:
					c.drop_off_delay -= 1
				else:
					c.drop_off_delay = FriendlyHelicopter.DROP_OFF_DELAY
					friends.deliver(player.x, player.y + 28, x, c.pows == 1,
							_friendly_soldier_picked_up.bind(c))
					c.drop_off_pow()
					walking_soldiers += 1
		leaving = leaving and player.y < y + 80 \
				and ((friends.friends.is_empty() and c.pows == 0) or player.y < y - 512)
	if leaving:
		if preparing_to_take_off > 0:
			preparing_to_take_off -= 1
		else:
			_enter(REVVING_UP)
			if verbose:
				print("rescue helicopter taking off, %d rescued" % rescued)
	else:
		preparing_to_take_off = FriendlyHelicopter.TAKE_OFF_DELAY


# FriendlyHelicopter.friendly_soldier_picked_up and Main's, for the player
# with carrier `c`, who brought him.
func _friendly_soldier_picked_up(c: Level3DFriends.Carrier) -> void:
	walking_soldiers -= 1
	scored.call(POINTS, c)
	rescued += 1
	c.rescued += 1
	if c.rescued in UPGRADES and c.upgrade_weapon():
		Level3DAudio.play(UPGRADE_SOUND)
	else:
		Level3DAudio.play(PICKUP_SOUND)
	if verbose:
		print("prisoner rescued: %d so far, weapon %s" % [rescued, c.weapon_name()])


# Whether prisoners brought now would be taken: from the moment it is on its
# way in until it revs up to leave (the HUD's arrow to the pad).
func is_waiting() -> bool:
	return state != NONE and state <= PICK_UP


# The pad it waits on, in level x, height, z.
func pad_position() -> Vector3:
	var at := Level3DMap.to_level(pad)
	var height: float = _pad_height if not is_nan(_pad_height) else ground.call(at.x, at.y).height
	return Vector3(at.x, height, at.y)


# Over its rotor, in level metres: where the points for a prisoner show
# (Level3DScorePops).
func top_position() -> Vector3:
	return _model.position + Vector3(0.0, TOP, 0.0) if _model != null else pad_position()


# Main.play_sound_if_not_playing.
#
# The stream is asked for every tick, since the menu can change the sound's
# mode under it: a new one replaces the old at once.
func _play_sound() -> void:
	var wanted := Level3DAudio.stream(SOUND)
	if _sound.stream != wanted:
		_sound.stop()
		_sound.stream = wanted
		_sound.bus = Level3DAudio.bus(SOUND)
	# Every tick, for the fade at the frame's edge, and since a looped modern
	# rotor never runs out to be started again with a new volume.
	var gain := Level3DAudio.edge_fade(Level3DMap.to_level(Vector2(x, y)), frame.call())
	_sound.pitch_scale = 1.0
	if not Level3DAudio.as_original():
		var spin := inverse_lerp(SLOW_ROTOR, FAST_ROTOR, rotor_speed)
		gain *= lerpf(IDLE_GAIN, 1.0, spin)
		_sound.pitch_scale = lerpf(IDLE_PITCH, 1.0, spin)
	_sound.volume_db = Level3DAudio.volume_db(SOUND) + linear_to_db(maxf(gain, 0.0001))
	if wanted != null and not _sound.playing:
		_sound.play()


# ----------------------------------------------------------------------------
# Where it is

# A tick of how it sits in the air (the header's How it flies): the pose for
# this tick, which _process draws it on its way to from the last.
func _pose() -> void:
	var at := Level3DMap.to_level(Vector2(x, y))
	var height := _flight_height()
	# The model's nose is its +Z; game angle 0 is north, -Z, and the angle
	# turns clockwise seen from above.
	var heading := PI - deg_to_rad(angle)
	var snapped := _snap
	if _snap:
		_flight.snap()
		_snap = false
	var pose := _flight.step(at, heading, clampf(height / HOVER_HEIGHT, 0.0, 1.0), _skid_shake(height))
	var attitude: Basis = pose.basis
	var standing := Vector3(at.x, _pad_height + height, at.y) + (pose.offset as Vector3)
	# Tilted about PIVOT over its skids, not about them.
	var origin := standing + Vector3.UP * PIVOT - attitude * (Vector3.UP * PIVOT)
	# FriendlyHelicopter.render's scale, as a factor on the one it stands at.
	var z0 := FriendlyHelicopter.Z0
	var scale_now := (z0 - 1.0) / (z0 - z) if enlarge else 1.0
	_model_from = _model_to
	_shadow_from = _shadow_to
	_model_to = Transform3D(attitude.scaled(Vector3.ONE * MODEL_SCALE * scale_now), origin)
	_shadow_to = Transform3D(attitude.scaled(Vector3.ONE * MODEL_SCALE), origin)
	if snapped:
		_model_from = _model_to
		_shadow_from = _shadow_to
	_shadow.transform = _shadow_to
	for p in _players:
		p.speed_scale = rotor_speed / ROTOR_DEGREES_PER_CLIP_SPEED


# Between its last two ticks' poses, for the frames drawn between them.
func _process(_delta: float) -> void:
	if _model == null or not visible:
		return
	var f := Engine.get_physics_interpolation_fraction()
	_model.transform = _model_from.interpolate_with(_model_to, f)
	_shadow.transform = _shadow_from.interpolate_with(_shadow_to, f)


# How high over the pad it is, level metres: the original's z drawn as a
# lift-off into a hover and a climb as it speeds off, and on the way in, a
# descent to the hover over the last APPROACH metres and the lift-off
# backwards. On the ground, nothing.
func _flight_height() -> float:
	match state:
		INCOMING, BRAKING:
			var d := absf(y - pad.y) * PX
			return lerpf(HOVER_HEIGHT, ALTITUDE, smoothstep(0.0, APPROACH, d))
		DESCENDING, LIFTING_OFF:
			return (1.0 - z) * HOVER_HEIGHT
		HOVER_TURN:
			return HOVER_HEIGHT
		ACCELERATING:
			return lerpf(HOVER_HEIGHT, ALTITUDE, smoothstep(0.0, 1.0, speed / FriendlyHelicopter.FLIGHT_SPEED))
		FLYING_AWAY:
			return ALTITUDE
	return 0.0


# How hard it rocks on its skids, 0 to 1: coming up as it revs up to lift
# off, until the skids are SKIDS_CLEAR off the pad, and from there down as it
# sets down, dying away as it revs down.
func _skid_shake(height: float) -> float:
	match state:
		REVVING_UP:
			return smoothstep(REV_TIME * 0.5, REV_TIME, count)
		LIFTING_OFF, DESCENDING:
			return clampf(1.0 - height / SKIDS_CLEAR, 0.0, 1.0)
		REVVING_DOWN:
			return 1.0 - smoothstep(0.0, REV_TIME * 0.5, count)
	return 0.0
