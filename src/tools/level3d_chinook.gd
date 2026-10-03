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
#     invincible, as Player.make_invincible has it. Here the BTR is the
#     player's as soon as it is at FINAL_X, FINAL_Y (_hand_over).
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
#     down that much further north: LANDING_SHIFT px, 234. It stops with the
#     underside of its lip on the sand, a little short of the model's clip
#     (_ramp_down), and throws up a cloud of dust along the lip as it does.
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
#   * The original's is gone at 38 degrees, still in the frame; this one flies
#     on west until it is out of it (_in_frame), in the top view at the size
#     it had there (Z_AWAY).
#   * The enemies' rounds strike it (strike): the original's pass under the
#     sprite, which is drawn over them, and here the rounds are drawn over
#     everything, so they flew through it. They strike sparks off it and do
#     nothing else; the jeep in it is not the player's yet.
#   * Two players, two vehicles (the preview's co-op). They ride one behind
#     the other, the first player's by the ramp and out first, down its
#     diagonal to the west; the second's backs down after it and takes the
#     same diagonal mirrored, to the east, so that they end on either side of
#     the ramp (second_side). Where the east has no room for it, it cuts the
#     west diagonal short and backs straight down for the rest of the way, to
#     end beside the first rather than on it, as the game's second jeep does
#     (IntroPlayer, second_spawn_x). Both are the players' when both are out.
class_name Level3DChinook
extends Node3D

const MODEL_PATH := "res://resources/3d/jackal_chinook.glb"
# Level3DAudio's: helicopter.ogg, the original's, in the original mode.
const SOUND := "chinook"
const MODEL_SCALE := Level3DBtr.MODEL_SCALE
const PX := Level3DMap.PX

# From jackal_chinook.py, in model metres, along the Chinook's length
# measured backwards from its origin.
const CARGO_BACK := 2.0         # CARGO: where the BTR rides
const HINGE_BACK := 7.5         # HINGE_Y
const FLOOR := 1.0              # the cabin floor, and the hinge's height
const RAMP_LEN := 4.6
# The ramp's skin under its deck at the lip (C_BodyDark), measured off the
# model: what lies on the ground when it is down (_ramp_down).
const RAMP_PLATE := 0.15
# The dust the ramp raises coming down (_ramp_dust): puffs along the lip, and
# how big, level metres -- twice a wheel's (Level3DBtr.DUST_SIZE).
const RAMP_DUST := 9
const RAMP_DUST_SIZE := 0.28
const CABIN_HALF_WIDTH := 1.9   # CABIN_W
const MODEL_HEIGHT := 7.6       # the rear rotor's top, over the wheels
# What stops the enemies' rounds (strike), in the model's own metres and axes,
# nose +Z: the cabin, nose to tail, from the ground up to its roof, and the
# sponsons either side of its back half. Off the model's own surfaces --
# C_Body, C_Glass and C_BodyDark -- without the pylons over the roof, which
# nothing flies as high as, and without the rotors.
const HULL_BOXES: Array[AABB] = [
	AABB(Vector3(-2.25, 0.0, -11.3), Vector3(4.5, 4.7, 22.1)),
	AABB(Vector3(-4.1, 0.0, -10.75), Vector3(8.2, 2.6, 9.65)),
]
# The vehicle rides the ramp by its axles, which it knows (Level3DBtr's
# VEHICLES, ramp_axles), as it knows its bow (body_front).

const ALTITUDE := 7.4
# The original's arcs: their radius and where the first is centred.
const RADIUS := 1024.0
const ARC_CENTRE := Vector2(1540.0, 10780.0)
const ARC_LANDING := Vector2(516.0, 10780.0)   # where the original sets down
const AWAY_ANGLE := -128.0
# The height it has climbed to there: z = -t * IPI2 at angle = t in degrees - 90.
const Z_AWAY := -(AWAY_ANGLE + 90.0) / Chinook.TO_DEGREES * Chinook.IPI2
const SOUND_VOLUME := 0.5
# Between the two vehicles in the cabin, level metres, bumper to bumper.
const CARGO_GAP := 0.25

enum { FORWARDS, OPENING, OUT, AWAY, DONE }
# A vehicle's own way out, from OUT on: down the ramp, the diagonal, the second
# one's straight run down, the turn back to north, out.
enum { BACKING, DIAGONAL, DOWN, REVERSE, UNLOADED }

# IntroPlayer, one a vehicle aboard.
class Cargo:
	var btr: Level3DBtr
	var state := BACKING
	# Its position in map px, its heading in game degrees, its countdown, and
	# how far behind the Chinook's origin it is, px.
	var unit := Vector2.ZERO
	var unit_angle := -90.0
	var delay := 0
	var backed := 0.0
	var aboard := 0.0       # `backed` where it rides
	var final_x := IntroPlayer.FINAL_X
	var diagonal := IntroPlayer.DIAGONAL_TIME
	var down_time := 0
	# Which way its diagonal goes across: -1 west, as IntroPlayer's, 1 east.
	var side := -1.0

# Asked of the scene, as the BTR is: `ground.call(x, z)` -> {"height", ...}.
var ground: Callable
# The vehicles it brings, the first player's first; and the map, for where
# the second can end up.
var btrs: Array[Level3DBtr] = []
var map: Level3DMap
# `dust.call(at, across, out, size, count)`: a cloud of dust off a line on the
# ground (Level3DPuffs.cloud), which the ramp raises coming down on it.
var dust: Callable
# Called once, when the BTR is the player's; and `left` once, when the
# Chinook has gone and freed itself, which is later.
var finished: Callable
var left: Callable
# The frame, level x, z (Level3DPreview's _view_frame): the rotor fades in and
# out at its edge (Level3DAudio.edge_fade).
var frame: Callable
# The preview's sun, for where the shadow falls (_in_frame).
var sun: DirectionalLight3D
var handed_over := false
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
var cargo: Array[Cargo] = []

var _model: Node3D
var _shadow: Node3D
var _players: Array[AnimationPlayer] = []   # the rotors, on both copies
var _ramps: Array[AnimationPlayer] = []     # the ramp, on both copies
var _sound: AudioStreamPlayer
var _landed_height := 0.0
var _shift := 0.0
var _ramp_landed := false   # the ramp has come down and raised its dust


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
	return (lip + btrs[0].body_front() + 0.1) / PX


# The ramp's angle when it is down, the underside of its lip on the ground.
# jackal_chinook.py's RAMP_DOWN, -asin(FLOOR / RAMP_LEN), puts the deck's lip
# there, and the skin under the deck, RAMP_PLATE thick, went into the sand;
# so the ramp stops short of the clip's end, a couple of degrees up
# (_hold_ramp). One step of Newton's from RAMP_DOWN is exact to a millimetre.
static func _ramp_down() -> float:
	var a := -asin(FLOOR / RAMP_LEN)
	var lip := FLOOR + RAMP_LEN * sin(a) - RAMP_PLATE * cos(a)
	return a - lip / (RAMP_LEN * cos(a) + RAMP_PLATE * sin(a))


func _ready() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	if scene == null:
		push_error("Cannot load %s -- run export() in jackal_chinook_lowpoly.blend" % MODEL_PATH)
		state = DONE
		return
	# And as far again as the level is longer than stage 1.
	_shift = landing_shift() + Level3DMap.extra_px()
	_model = _instance(scene, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_shadow = _instance(scene, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	var landing := Level3DMap.to_level(ARC_LANDING + Vector2(0.0, _shift))
	_landed_height = ground.call(landing.x, landing.y).height
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	_load()
	# Chinook.update's first tick has not run: where it starts from.
	x = ARC_CENTRE.x + RADIUS * cos(t)
	y = ARC_CENTRE.y + _shift + RADIUS * sin(t)
	angle = 90.0 + Chinook.TO_DEGREES * t
	_pose()


# One copy of the model, its clips split in two players (split_clips).
func _instance(scene: PackedScene, shadows: int) -> Node3D:
	var root := scene.instantiate() as Node3D
	add_child(root)
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = shadows
	var players := split_clips(root)
	# The ramp goes by the tick, not by the frame.
	players[1].callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_players.append(players[0])
	_ramps.append(players[1])
	return root


# A copy of the model's clips split in two players as the boat's are, the
# rotors' turning and the ramp shut: the glTF export gives every clip a track
# for every bone any clip moves, so Fly would hold the ramp shut and the
# ramp's clips would stop the rotors. [the rotors' player, the ramp's].
# The title's splash flies one too (level3d_splash_landing.gd).
static func split_clips(root: Node3D) -> Array[AnimationPlayer]:
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
	ramp_player.play("Ramp_Close")
	ramp_player.seek(ramp_player.current_animation_length, true)
	return [imported, ramp_player]


# The vehicles aboard, hidden till the ramp is down: the first at CARGO_BACK,
# the second as far again ahead of it as the vehicle is long.
func _load() -> void:
	var aboard := CARGO_BACK * MODEL_SCALE / PX
	for i in btrs.size():
		var c := Cargo.new()
		c.btr = btrs[i]
		c.btr.visible = false
		c.aboard = aboard
		if i > 0 and second_side():
			c.side = 1.0
			c.final_x = 2.0 * ARC_LANDING.x - IntroPlayer.FINAL_X
		elif i > 0:
			c.final_x = second_spawn_x()
			var shift := roundi((c.final_x - IntroPlayer.FINAL_X) / Player.SPEED)
			if shift > 0 and shift < IntroPlayer.DIAGONAL_TIME:
				c.diagonal = IntroPlayer.DIAGONAL_TIME - shift
				c.down_time = shift
		cargo.append(c)
		var body: Array = c.btr.vehicle.body
		aboard -= ((body[1] - body[0]) * c.btr.model_scale + CARGO_GAP) / PX


# Whether the second vehicle can end east of the ramp, where IntroPlayer's
# diagonal mirrored about the landing ends.
func second_side() -> bool:
	var at := 2.0 * ARC_LANDING.x - IntroPlayer.FINAL_X
	var y0 := IntroPlayer.FINAL_Y + Level3DMap.extra_px()
	return map == null or map.is_driveable_box(at - 32, y0 - 32, at + 32, y0 + 32)


# GameMode.second_spawn_x at IntroPlayer's spot: COOP_SPAWN_SPREAD to the east
# if the jeep fits there, to the west if not, or the first one's spot.
func second_spawn_x() -> float:
	var y0 := IntroPlayer.FINAL_Y + Level3DMap.extra_px()
	for dx in [GameMode.COOP_SPAWN_SPREAD, -GameMode.COOP_SPAWN_SPREAD]:
		var at: float = IntroPlayer.FINAL_X + dx
		if map == null or map.is_driveable_box(at - 32, y0 - 32, at + 32, y0 + 32):
			return at
	return IntroPlayer.FINAL_X


func done() -> bool:
	return state == DONE


# The top of the model, for the top camera, which has to be above it.
func top() -> float:
	if _model == null:
		return 0.0
	return _model.position.y + MODEL_HEIGHT * _model.scale.y


# Where a round at `at` strikes the hull, {"point", "normal"} on its surface,
# or empty. The game's Chinook is no HitElement -- its rounds pass under the
# sprite, which is drawn over them -- but here the rounds are drawn over
# everything, the Chinook included, so they went through it. So a round
# strikes it where it is seen on it: where the camera's ray through the round
# meets the hull, on the face that ray sees -- whatever the round's height
# and the Chinook's. By its height the round passed under a Chinook coming
# down, which the tilted view shows where it is, over the round, and the top
# view at the original's scale for its height (enlarge); both drew the round
# on it.
func strike(at: Vector3) -> Dictionary:
	if _model == null or state == DONE:
		return {}
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var screen := camera.unproject_position(at)
	var origin := camera.project_ray_origin(screen)
	var inverse := _model.global_transform.affine_inverse()
	var a := inverse * origin
	var b := inverse * (origin + camera.project_ray_normal(screen) * camera.far)
	var best := {}
	var nearest := INF
	for box in HULL_BOXES:
		var entry: Variant = box.intersects_segment(a, b)
		if entry == null or a.distance_to(entry) >= nearest:
			continue
		nearest = a.distance_to(entry)
		var face := _nearest_face(box, entry)
		best = {"point": _model.global_transform * (face.point as Vector3),
				"normal": (_model.global_basis * (face.normal as Vector3)).normalized()}
	return best


# The face of `box` nearest `p`, in it or on it: {"point" on it, "normal"}.
# Not the bottom, which stands on the ground and is never seen.
static func _nearest_face(box: AABB, p: Vector3) -> Dictionary:
	var point := p
	var normal := Vector3.ZERO
	var nearest := INF
	for axis in 3:
		for side in [-1.0, 1.0]:
			if axis == 1 and side < 0.0:
				continue
			var face: float = box.position[axis] + (box.size[axis] if side > 0.0 else 0.0)
			if absf(p[axis] - face) < nearest:
				nearest = absf(p[axis] - face)
				point = p
				point[axis] = face
				normal = Vector3.ZERO
				normal[axis] = side
	return {"point": point, "normal": normal}


# The continue: the jeep is just there, as Chinook.init does when
# main.continued.
func skip() -> void:
	if state == DONE:
		return
	_hand_over()
	_leave()


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
				for c in cargo:
					c.backed = c.aboard
					c.unit = Vector2(x, y + c.backed)
					c.btr.visible = true
			_play_sound(SOUND_VOLUME)
		OPENING:
			var over := _advance_ramp()
			if not _ramp_landed and _ramp_angle() <= _ramp_down() + 0.001:
				_ramp_landed = true
				_ramp_dust()
			if over:
				state = OUT
			_play_sound(SOUND_VOLUME)
		OUT:
			var all_out := true
			for c in cargo:
				_unload(c)
				all_out = all_out and c.state == UNLOADED
			if all_out:
				_unload_completed()
				_hand_over()
			_play_sound(SOUND_VOLUME)
		AWAY:
			_advance_ramp()
			vt += Chinook.AT
			if t > -PI / 2.0:
				angle = Chinook.TO_DEGREES * t - 90.0
				z = -t * Chinook.IPI2
				t -= vt
				x = X + RADIUS * cos(t)
				y = Y + RADIUS * sin(t)
			else:
				# Past the original's quarter circle (below): on west, level, at
				# the arc's speed, and on up to the top of its climb.
				angle = -180.0
				x -= vt * RADIUS
				z = minf(z + vt * Chinook.IPI2, 1.0)
			# The original is gone at AWAY_ANGLE, still in the frame, and so was
			# this one, in either view; it flies on until it is out of it rather
			# than vanishing in the middle of it. LEAVE_X only in case it never
			# is: a frame's width off the map's west edge its shadow was still
			# on the sea at the left of the tilted view.
			if angle < AWAY_ANGLE and (not _in_frame() or x < LEAVE_X):
				_leave()
				return
			# Chinook.update's fade, which is gone by AWAY_ANGLE, still in the
			# frame: the original's, in the original mode. The modern and the
			# classic one fly on heard and die away at the edge of the frame,
			# as they came in.
			_play_sound(SOUND_VOLUME + (angle + 90.0) / 76.0 if Level3DAudio.as_original()
					else SOUND_VOLUME)
	_pose()
	if state != FORWARDS and not handed_over:
		for c in cargo:
			_pose_unit(c)


# One vehicle's tick of IntroPlayer.update, once the ramp is down.
func _unload(c: Cargo) -> void:
	match c.state:
		BACKING:
			c.backed = minf(c.backed + Player.SPEED, clear_back())
			c.unit = Vector2(x, y + c.backed)
			if c.backed >= clear_back():
				c.state = DIAGONAL
				c.delay = c.diagonal
		DIAGONAL:
			c.unit += Vector2(c.side * Player.SPEED, Player.SPEED)
			# Backing out, the nose points away from the way it goes.
			c.unit_angle = move_toward(c.unit_angle, -90.0 - 45.0 * c.side, Player.ANGLE_VELOCITY)
			c.delay -= 1
			if c.delay == 0:
				c.state = DOWN if c.down_time > 0 else REVERSE
				c.delay = c.down_time if c.down_time > 0 else IntroPlayer.REVERSE_TIME
		DOWN:
			c.unit.y += Player.SPEED
			c.unit_angle = move_toward(c.unit_angle, -90.0, Player.ANGLE_VELOCITY)
			c.delay -= 1
			if c.delay == 0:
				c.state = REVERSE
				c.delay = IntroPlayer.REVERSE_TIME
		REVERSE:
			c.unit_angle = move_toward(c.unit_angle, -90.0, Player.ANGLE_VELOCITY)
			c.delay -= 1
			if c.delay == 0:
				c.unit = Vector2(c.final_x, IntroPlayer.FINAL_Y + Level3DMap.extra_px())
				c.state = UNLOADED


func _unload_completed() -> void:
	state = AWAY
	X = x - RADIUS
	Y = y
	vt = 0.0
	t = 0.0
	_play_ramp("Ramp_Close")


# The BTR is the player's the tick it is unloaded, not when the Chinook has
# gone as in the original: the original's jeep sat still under a sprite that
# took another 90 ticks to turn away, and in a cabin with its ramp going up
# that reads as the game waiting on nothing.
func _hand_over() -> void:
	if handed_over:
		return
	handed_over = true
	for c in cargo:
		c.btr.visible = true
		var at := hand_over_at(c.final_x)
		c.btr.place(Vector3(at.x, 0.0, at.y), PI / 2.0)
	finished.call()


# Freed once the rotor has died away (Level3DAudio.fade_out): out of the
# frame already, and hidden till then, with nothing ticking it.
func _leave() -> void:
	state = DONE
	visible = false
	Level3DAudio.fade_out(_sound, queue_free)
	if left.is_valid():
		left.call()


# Whether any of the Chinook, a box LEAVE_BOX metres round the middle of its
# height, is in the camera's frame -- or its shadow, a box as wide and as tall
# as the model cast down the sun onto the ground: up at the top of its climb the shadow falls well off
# to one side of it, and was left behind in the frame, gone from one frame to
# the next, when the Chinook went only by itself.
const LEAVE_BOX := 4.0
const LEAVE_X := -4.0 * RADIUS

func _in_frame() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _model == null:
		return false
	var middle := _model.global_position + Vector3.UP * MODEL_HEIGHT * _model.scale.y * 0.5
	var down := -sun.global_basis.z if sun != null else Vector3.DOWN
	for i in 8:
		var side := Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1)
		if camera.is_position_in_frustum(middle + side * LEAVE_BOX):
			return true
		# The shadow's box is as tall as the shadow copy, which is not
		# enlarged: the whole of LEAVE_BOX cast down the sun is a shadow
		# several metres longer than the one there is.
		var corner := _shadow.global_position + Vector3(side.x * LEAVE_BOX,
				(MODEL_HEIGHT * MODEL_SCALE if side.y > 0 else 0.0), side.z * LEAVE_BOX)
		if down.y < -0.01 and camera.is_position_in_frustum(_cast(corner, down)):
			return true
	return false


# Where `p` falls on the ground down the sun's `down`: onto the height under
# where it would fall at the landing's height, which is near enough to the
# ground there, the shadow being a box's anyway.
func _cast(p: Vector3, down: Vector3) -> Vector3:
	var at := p + down * ((p.y - _landed_height) / -down.y)
	var height: float = ground.call(at.x, at.z).height
	return p + down * ((p.y - height) / -down.y)


# Where the BTR is the player's, level x, z: IntroPlayer's FINAL_X, FINAL_Y,
# as far from the level's south end as from stage 1's -- or at `final_x`, the
# second one's.
static func hand_over_at(final_x := IntroPlayer.FINAL_X) -> Vector2:
	return Level3DMap.to_level(Vector2(final_x, IntroPlayer.FINAL_Y + Level3DMap.extra_px()))


# Where the preview's frame stands for the whole run, `half_height` metres
# either side (Level3DPreview's _process), as the game's stands still until
# the player is updated: over hand_over_at() -- with two vehicles, over the
# middle of their two -- so that it need not move when the BTR is handed
# over, unless the frame is too short for the landing, 6.6 m
# north of it, to be in it as well -- zoomed in past 2 or so; then as far
# north as keeps the landing FRAME_MARGIN inside the top edge, and the frame
# catches up with the BTR once it has it.
const FRAME_MARGIN := 2.0

func frame_centre(half_height: float) -> Vector2:
	var at := hand_over_at()
	if not cargo.is_empty():
		at.x = (hand_over_at(cargo[0].final_x).x + hand_over_at(cargo[-1].final_x).x) * 0.5
	var landing := Level3DMap.to_level(ARC_LANDING + Vector2(0.0, _shift))
	at.y = minf(at.y, landing.y + half_height - FRAME_MARGIN)
	return at


func _play_ramp(clip: String) -> void:
	for p in _ramps:
		p.play(clip)
		p.seek(0.0, true)
	_hold_ramp()


# The ramp no lower than _ramp_down, on both copies: the clip goes on down
# past it, and is turned back up about the hinge -- the bone's origin -- by
# what it went past, after each step of it. The ramp's players are advanced
# by hand, so what this sets stands until the next step.
func _hold_ramp() -> void:
	for copy in [_model, _shadow]:
		hold_ramp((copy as Node3D).find_child("Skeleton3D", true, false) as Skeleton3D)


# One copy's ramp turned back up to _ramp_down, if its clip has taken it past.
static func hold_ramp(skeleton: Skeleton3D) -> void:
	var past := _ramp_down() - ramp_angle(skeleton)
	if past > 0.0:
		var bone := skeleton.find_bone("Ramp")
		var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
		var pose := Basis(Vector3.RIGHT, past) * skeleton.get_bone_global_pose(bone).basis
		skeleton.set_bone_pose_rotation(bone, (parent.inverse() * pose).get_rotation_quaternion())


# The ramp one tick on; true once the clip is over.
func _advance_ramp() -> bool:
	var over := true
	for p in _ramps:
		p.advance(1.0 / Engine.physics_ticks_per_second)
		over = over and p.current_animation_position >= p.current_animation_length
	_hold_ramp()
	return over


# The ramp's lip coming down on the sand throws it up: a line of dust along
# the lip, blown out behind and to the sides, RAMP_DUST puffs RAMP_DUST_SIZE
# big. Off the shadow's copy, which is where the Chinook really is.
func _ramp_dust() -> void:
	if not dust.is_valid():
		return
	var frame := _shadow.global_transform
	var lip := frame * Vector3(0.0, 0.0, -(HINGE_BACK + RAMP_LEN * cos(_ramp_down())))
	var across := frame.basis * Vector3(CABIN_HALF_WIDTH, 0.0, 0.0)
	var out := (frame.basis * Vector3(0.0, 0.0, -1.0)).normalized()
	dust.call(lip, across, out, RAMP_DUST_SIZE, RAMP_DUST)


# Main.play_sound_if_not_playing.
#
# The volume is set every time, not only when it starts: a looped modern sound
# never runs out to be started again, and would keep the volume it began at.
# The stream is asked for every tick, since the menu can change the sound's
# mode under it: a new one replaces the old at once.
func _play_sound(volume: float) -> void:
	var wanted := Level3DAudio.stream(SOUND)
	if _sound.stream != wanted:
		_sound.stop()
		_sound.stream = wanted
		_sound.bus = Level3DAudio.bus(SOUND)
	if frame.is_valid():
		volume *= Level3DAudio.edge_fade(Level3DMap.to_level(Vector2(x, y)), frame.call())
	_sound.volume_db = Level3DAudio.volume_db(SOUND) + linear_to_db(clampf(volume, 0.0001, 1.0))
	if wanted != null and not _sound.playing:
		_sound.play()


# ----------------------------------------------------------------------------
# Where things are

func _pose() -> void:
	var at := Level3DMap.to_level(Vector2(x, y))
	var position_3d := Vector3(at.x, _landed_height + z * ALTITUDE, at.y)
	# The model's nose is its +Z; a game angle a points (cos a, sin a) in x, z.
	var facing := Basis(Vector3.UP, PI / 2.0 - deg_to_rad(angle))
	# Held at its size at AWAY_ANGLE past it: the original's scale goes on to
	# ten times at the top of the climb, which the original never drew.
	var scale_now := Chinook.Z0 / (Chinook.Z0 - minf(z, Z_AWAY)) if enlarge else 1.0
	_model.transform = Transform3D(facing.scaled(Vector3.ONE * MODEL_SCALE * scale_now), position_3d)
	_shadow.transform = Transform3D(facing.scaled(Vector3.ONE * MODEL_SCALE), position_3d)


# The BTR where IntroPlayer is, riding on whatever is under its axles: the
# cabin floor, the ramp or the ground.
func _pose_unit(c: Cargo) -> void:
	var btr := c.btr
	var at := Level3DMap.to_level(c.unit)
	var heading := deg_to_rad(-c.unit_angle)
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
	var slope := _ramp_angle()
	var deck := -INF
	if back <= HINGE_BACK:
		deck = FLOOR
	elif back <= HINGE_BACK + RAMP_LEN * cos(slope):
		deck = FLOOR + (back - HINGE_BACK) * tan(slope)
	if deck == -INF:
		return outside
	return maxf(outside, _shadow.position.y + deck * MODEL_SCALE)


# The ramp's angle up from level now, off the ramp bone's pose: the clip is
# the one place that knows it.
func _ramp_angle() -> float:
	return ramp_angle(_shadow.find_child("Skeleton3D", true, false) as Skeleton3D)


static func ramp_angle(skeleton: Skeleton3D) -> float:
	var bone := skeleton.find_bone("Ramp")
	var rest := skeleton.get_bone_global_rest(bone)
	var now := skeleton.get_bone_global_pose(bone)
	# The ramp runs back from the hinge: model -Z, which the bone's pose
	# carries from its closed position.
	var closed := deg_to_rad(48.0)
	var along := (now.basis * rest.basis.inverse()) * Vector3(0.0, sin(closed), -cos(closed))
	return atan2(along.y, -along.z)
