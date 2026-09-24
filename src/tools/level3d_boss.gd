# The stage 1 boss on the 3D preview: jackal.BossBlueTanksManager and
# jackal.BossBlueTank, on jackal_heavy_tank.glb (jackal_heavy_tank_lowpoly.blend).
#
# Nothing here is part of the game, and the rules are the game's, as the
# brown tanks' are (level3d_tanks.gd), in map pixels and ticks on the game's
# own grid and flow field (Level3DMap):
#   * stage-0.json's BOSS_BLUE_TANKS trigger, on normal, fires four rows early
#     as MapIO files it, and the camera pans to the top of the map at 4 px a
#     tick and stays there (camera_top: Level3DPreview takes the frame from
#     it). The first tank comes 91 ticks after the pan, the other three 273
#     apart, each at x 640 or 1408 and from above the frame or below it, and
#     each drives straight in until it is in, never through another.
#   * A tank drives the flow field towards the player at 2.5 px a tick,
#     turning at most 45 degrees a run and 2.5 degrees a tick, and fires
#     yellow rounds along its facing in pairs, 16 ticks apart and 91 between
#     pairs, that fly 455 ticks.
#   * It takes two rounds of damage, each five machine-gun rounds or one
#     grenade or missile, and nothing but the player's weapons hurt it.
#     Running into it kills the player and not the tank. 800 points; the
#     stage is done when all four are.
#
# Where this departs from the game, and why:
#   * The first round of damage repaints the game's tank from blue to brown.
#     Here the tank is dark gunmetal throughout, and the round shows in its
#     shape: Breach, played once with Damage for the jolt -- three skirt
#     plates and an armour plate blown off, three holes torn open with fire in
#     them -- then Breached, held: the holes glowing and smoking. The model's
#     damage layer (jackal_heavy_tank.py) is made for this.
#   * It is drawn half as big again as the game's sprite would make it, and
#     its hit, mine and solid boxes are grown with it (SCALE, GROWN).
#   * The spawn below the frame is below this frame's bottom edge, as the
#     game's is below its own, and the preview's frame is taller than the
#     game's 1152 px.
#   * It fires from the muzzle and its turret leads a turn, as the brown
#     tanks' do; the rounds still go the way the hull faces.
#   * The game removes a destroyed tank and draws an Explosion; here it plays
#     Death in the blast and stays, burnt black and smoking. GameMode's
#     destroy_all when the fourth goes is not done: the preview has nothing
#     else in the arena.
class_name Level3DBoss
extends Node3D

const TANK_PATH := "res://resources/3d/jackal_heavy_tank.glb"
const PX := Level3DMap.PX
# The model is an 8 m tank, 3.8 m wide; the sprite is 96 x 80 px side on,
# 1.41 x 1.17 m on the level's scale, about the jeep's size. The boss is drawn
# bigger than that, 2.88 x 1.37 m against the BTR's 1.8 x 1.1, so that it
# reads as the heavy one: GROWN times the 0.23 that would have matched the
# brown tanks' rule.
const SCALE := 0.36
const GROWN := SCALE / 0.23
# BossBlueTank's boxes -- hit 50 px, mine 40, solid 54 -- grown with the
# model, or rounds would pass through its nose and tail and the four would
# drive into one another. What it steers by (the sensor and the corners, on
# the game's grid) is left the game's, so that it paths as the game's does;
# the price is a hull that can overhang the forest edge a little.
const HIT := 50.0 * GROWN
const MINE := 40.0 * GROWN
const SOLID := 54.0 * GROWN
const POINTS := 800
const HITS := 5               # BossBlueTank.bullet_hits, each round of damage
const SPAWN_X := [640.0, 1408.0]
# 52 px beyond the frame, grown too, so that no part of the longer hull shows
# where it appears; the drive in from below grown with it, to stop as far
# inside the frame as the game's does.
const SPAWN_OUTSIDE := 52.0 * GROWN
const INTRO_FROM_TOP := 128
const INTRO_FROM_BOTTOM := 66
const TURRET_TURN := 4.0      # rad/s
const BLAST_HEIGHT := 0.5 * GROWN
const BLAST_SCALE := 1.1 * GROWN
# How far the tracks move in one loop of Tracks and Spin, in the model's
# metres (jackal_heavy_tank.py: TRACK_STEPS * LOOP.step), and how far out
# from the middle a track runs (TRACK_X).
const TRACK_TRAVEL := 0.763
const TRACK_X := 1.36
# The medium tank's five layers under the same names, and the damage layer.
# The glTF export gives every clip a track for every bone any clip moves, so
# each layer's clips are cut down to its own bones.
const LAYERS := {
	"tracks": {"bones": ["Pad.", "Wheel."], "clips": ["Tracks", "Spin_L", "Spin_R"]},
	"hull": {"bones": ["Hull", "Ring", "Blast."], "clips": ["Idle", "Drive", "Damage", "Death"]},
	"weapon": {"bones": ["Gun", "Barrel", "Flash"], "clips": ["Shoot"]},
	"exhaust": {"bones": ["Exhaust.", "Dust."], "clips": ["Exhaust", "Exhaust_Drive"]},
	"smoke": {"bones": ["Smoke."], "clips": ["Smoke", "Burn"]},
	"damage": {"bones": ["Skirt.", "Fender.", "Breach.", "Glow.", "Spark.", "Wisp."],
			"clips": ["Breach", "Breached"]},
}
const LOOPS := ["Tracks", "Spin_L", "Spin_R", "Idle", "Drive", "Exhaust", "Exhaust_Drive", "Smoke",
		"Burn", "Breached"]
# Made here, as the brown tanks' Off is: neither survives the glTF export.
# Intact matters more -- a damage layer left unplayed shows the breaches.
const OFF := "Off"
const INTACT := "Intact"
const LOST := ["Skirt.", "Fender."]
const BLEND := 0.25
const CHAR_TIME := 1.2
const CHAR := 0.28
const KEEP_COLOUR := ["HT_Fire", "HT_Flash", "HT_Smoke", "HT_SmokeDark", "HT_Dust"]

var map: Level3DMap
var guns: Level3DGuns
# `frame.call()`: the frame the player sees, Rect2 in level x, z.
var frame: Callable
# `ground.call(x, z)`: {"height": ...} as the preview's.
var ground: Callable
# `player_position.call()`: the player's level x, z.
var player_position: Callable
var scored: Callable
var verbose := false

var tanks: Array[Tank] = []
var _wrecks: Array[Tank] = []
var _scene: PackedScene
var _libraries := {}
var _turret_pivot: Vector3        # model metres, Godot axes
var _muzzle_from_turret: Vector3
var _trigger_row := -1
var _armed := false               # the trigger has fired: the pan, then the fight
var _pan_top := -1.0              # the frame's top, map px, while armed
var _fighting := false            # BossBlueTanksManager.ready: the pan is over
var _spawn_delay := 91
var _spawned := 0
var _destroyed := 0
var _rng := RandomNumberGenerator.new()


class Tank:
	var x: float            # map pixels
	var y: float
	var shoot_delay := BossBlueTank.SHOOT_DELAY
	var shoot_count := BossBlueTank.SHOOT_COUNT
	var move_steps := 0
	var target_angle := 90
	var display_angle := 90.0
	var direction := Vector2.ZERO
	var v := Vector2.ZERO
	var sensor := Vector2.ZERO
	var last_d := Vector2.ZERO
	var handling_loop := 0
	var loop_target := Vector2.ZERO
	var trail := PackedInt32Array([0, -1, -2, -3, -4, -5, -6, -7])
	var trail_index := 7
	var intro_vy := 0.0
	var intro_delay := 0
	var bullet_hits := HITS
	var breached := false   # BossBlueTank.color_offset != 0
	var turret_yaw := 0.0
	var moved := 0.0
	var turned := 0.0
	var busy := false
	var track_phase := 0.0
	var spin_phase := 0.0
	var root: Node3D
	var players := {}
	var skeleton: Skeleton3D
	var turret_bone := -1
	var dead_time := 0.0
	var charred: Array = []


func _ready() -> void:
	_scene = load(TANK_PATH)
	if _scene == null:
		push_error("Cannot load %s -- run export() in jackal_heavy_tank_lowpoly.blend" % TANK_PATH)
		return
	_make_libraries()
	for row in map.stage.trigger_map[0].size():
		for t in map.stage.trigger_map[0][row]:
			if t[0] == Triggers.BOSS_BLUE_TANKS:
				_trigger_row = row
	_rng.seed = 11
	reset()


static func _layer_of(bone: String) -> String:
	for layer in LAYERS:
		for b: String in LAYERS[layer].bones:
			if bone == b or (b.ends_with(".") and bone.begins_with(b)):
				return layer
	return ""


func _make_libraries() -> void:
	var probe := _scene.instantiate()
	var imported := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := probe.find_child("Skeleton3D", true, false) as Skeleton3D
	for layer in LAYERS:
		_libraries[layer] = AnimationLibrary.new()
	var prefix := ""
	for clip in imported.get_animation_list():
		var a := imported.get_animation(clip).duplicate() as Animation
		var layer := ""
		for l in LAYERS:
			if clip in LAYERS[l].clips:
				layer = l
		if layer == "":
			continue
		for i in range(a.get_track_count() - 1, -1, -1):
			var path := a.track_get_path(i)
			prefix = str(path).get_slice(":", 0)
			if _layer_of(str(path.get_concatenated_subnames())) != layer:
				a.remove_track(i)
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPS else Animation.LOOP_NONE
		(_libraries[layer] as AnimationLibrary).add_animation(clip, a)
	for layer in ["exhaust", "smoke"]:
		(_libraries[layer] as AnimationLibrary).add_animation(OFF, _still(skeleton, prefix, layer, []))
	# Intact: the plates the first round blows off where they were modelled,
	# every breach bone scaled to nothing.
	(_libraries.damage as AnimationLibrary).add_animation(INTACT, _still(skeleton, prefix, "damage", LOST))
	_turret_pivot = skeleton.get_bone_global_rest(skeleton.find_bone("Turret")).origin
	_muzzle_from_turret = skeleton.get_bone_global_rest(skeleton.find_bone("Flash")).origin - _turret_pivot
	probe.free()


# A one-frame clip for a layer's bones: those named by a prefix in `shown` at
# rest, every other one scaled to nothing.
static func _still(skeleton: Skeleton3D, prefix: String, layer: String, shown: Array) -> Animation:
	var a := Animation.new()
	a.length = 1.0 / 24.0
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		if _layer_of(bone) != layer:
			continue
		var path := NodePath("%s:%s" % [prefix, bone])
		var keep := shown.any(func(p: String): return bone.begins_with(p))
		var rest := skeleton.get_bone_rest(i)
		var t := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t, path)
		a.position_track_insert_key(t, 0.0, rest.origin)
		t = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, path)
		a.rotation_track_insert_key(t, 0.0, rest.basis.get_rotation_quaternion())
		t = a.add_track(Animation.TYPE_SCALE_3D)
		a.track_set_path(t, path)
		a.scale_track_insert_key(t, 0.0, Vector3.ONE if keep else Vector3.ONE * 0.001)
	return a


func reset() -> void:
	for t in tanks + _wrecks:
		t.root.queue_free()
	tanks.clear()
	_wrecks.clear()
	_armed = false
	_pan_top = -1.0
	_fighting = false
	_spawn_delay = 91
	_spawned = 0
	_destroyed = 0


# The frame's top in map pixels while the boss has the camera, -1 while it
# has not: Level3DPreview puts the frame there.
func camera_top() -> float:
	return _pan_top if _armed else -1.0


# ----------------------------------------------------------------------------
# The tick: BossBlueTanksManager, then each tank.

func tick() -> void:
	var view: Rect2 = frame.call()
	var top := Level3DMap.to_map(view.position).y
	if not _armed:
		# GameMode._process_triggers: the trigger's row has come to the top.
		if _trigger_row >= 0 and (int(top) >> 5) - 1 < _trigger_row:
			_armed = true
			_pan_top = top
			if verbose:
				print("boss: the pan begins at %.0f px, tick %d" % [top, Engine.get_physics_frames()])
		return
	if not _fighting:
		# GameMode's boss pan: 4 px a tick up to the top, and there it stays.
		_pan_top -= GameMode.BOSS_PAN_CAMERA_SPEED
		if _pan_top <= 0.0:
			_pan_top = 0.0
			_fighting = true
			if verbose:
				print("boss: the pan is over, tick %d" % Engine.get_physics_frames())
		return
	if _spawned < BossBlueTanksManager.TANKS:
		_spawn_delay -= 1
		if _spawn_delay == 0:
			_spawned += 1
			_spawn_delay = BossBlueTanksManager.SPAWN_DELAY
			var sx: float = SPAWN_X[_rng.randi_range(0, 1)]
			var from_top := _rng.randi_range(0, 1) == 0
			var bottom := Level3DMap.to_map(view.end).y
			_spawn(sx, -SPAWN_OUTSIDE if from_top else bottom + SPAWN_OUTSIDE, from_top)
	var player := Level3DMap.to_map(player_position.call())
	for t in tanks:
		_update(t, player)


func _spawn(x: float, y: float, from_top: bool) -> void:
	var t := Tank.new()
	t.x = x
	t.y = y
	var sgn := 1.0 if from_top else -1.0
	t.display_angle = 90.0 if from_top else 270.0
	t.target_angle = 90 if from_top else 270
	t.direction = Vector2(0, sgn)
	t.v = t.direction * BossBlueTank.SPEED
	t.intro_vy = sgn * BossBlueTank.SPEED
	t.intro_delay = INTRO_FROM_TOP if from_top else INTRO_FROM_BOTTOM
	t.root = _scene.instantiate() as Node3D
	t.root.scale = Vector3.ONE * SCALE
	add_child(t.root)
	_split_players(t)
	t.skeleton = t.root.find_child("Skeleton3D", true, false) as Skeleton3D
	t.turret_bone = t.skeleton.find_bone("Turret")
	_place(t)
	t.turret_yaw = t.root.rotation.y
	tanks.append(t)
	if verbose:
		print("boss tank %d appears at %.0f, %.0f" % [_spawned, x, y])


# A player per layer, each with its own library, all advanced by hand in
# _process (Level3DTanks._split_players has why).
func _split_players(t: Tank) -> void:
	var imported := t.root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for layer in LAYERS:
		var p := imported
		if layer != "hull":
			p = AnimationPlayer.new()
			imported.get_parent().add_child(p)
			p.root_node = p.get_path_to(imported.get_node(imported.root_node))
		else:
			p.remove_animation_library("")
		p.add_animation_library("", _libraries[layer])
		p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		t.players[layer] = p
	var hull: AnimationPlayer = t.players.hull
	hull.animation_finished.connect(func(clip: StringName):
		if clip == "Damage":
			hull.play(_base(t), BLEND))
	# Breach ends on Breached's first frame: straight on, no blend.
	var damage: AnimationPlayer = t.players.damage
	damage.animation_finished.connect(func(clip: StringName):
		if clip == "Breach":
			damage.play("Breached"))
	hull.play("Idle")
	damage.play(INTACT)
	(t.players.tracks as AnimationPlayer).play("Tracks")
	(t.players.exhaust as AnimationPlayer).play("Exhaust")
	(t.players.smoke as AnimationPlayer).play(OFF)
	var weapon: AnimationPlayer = t.players.weapon
	weapon.play("Shoot")
	weapon.seek(weapon.current_animation_length, true)


func _update(t: Tank, player: Vector2) -> void:
	var was := Vector2(t.x, t.y)
	var angle_was := t.display_angle
	_drive(t, player)
	t.moved = (Vector2(t.x, t.y) - was).length() * PX
	t.turned = t.display_angle - angle_was
	if absf(t.turned) > 180.0:
		t.turned -= signf(t.turned) * 360.0
	_place(t)
	t.busy = t.moved > 0.0 or t.turned != 0.0
	var hull: AnimationPlayer = t.players.hull
	if hull.current_animation in LOOPS and hull.current_animation != _base(t):
		hull.play(_base(t), BLEND)
	var exhaust: AnimationPlayer = t.players.exhaust
	var puff := "Exhaust_Drive" if t.busy else "Exhaust"
	if exhaust.current_animation != puff:
		exhaust.play(puff, BLEND)


# BossBlueTank.update.
func _drive(t: Tank, player: Vector2) -> void:
	# Drive straight in from off-screen, but never through another tank.
	if t.intro_delay > 0:
		var entry := Vector2(t.x, t.y + t.intro_vy)
		for o in tanks:
			if o != t and _solid_box(o).intersects(_box_at(entry, SOLID)) \
					and not _solid_box(o).intersects(_box_at(Vector2(t.x, t.y), SOLID)):
				return
		t.intro_delay -= 1
		t.y = entry.y
		return

	if t.display_angle != t.target_angle:
		t.shoot_count = BossBlueTank.SHOOT_COUNT
		var delta_angle := fmod(t.target_angle - t.display_angle + 180, 360.0)
		if delta_angle < 0:
			delta_angle += 180
		else:
			delta_angle -= 180
		if absf(delta_angle) < BossBlueTank.ANGLE_VELOCITY:
			t.display_angle = t.target_angle
		elif delta_angle < 0:
			t.display_angle -= BossBlueTank.ANGLE_VELOCITY
		else:
			t.display_angle += BossBlueTank.ANGLE_VELOCITY
		return

	if t.handling_loop > 0:
		t.handling_loop -= 1

	t.move_steps -= 1
	if t.move_steps <= 0:
		var d := Vector2.ZERO
		if _rng.randi_range(0, 4) == 4:
			d = Vector2(_rng.randi_range(0, 511) - 256, _rng.randi_range(0, 511) - 256)
		var goal := (t.loop_target if t.handling_loop > 0 else player) + d
		var s := map.suggest_direction_turning(t.x, t.y, goal.x, goal.y, t.target_angle)
		t.direction = Vector2(s.x, s.y)
		t.v = t.direction * BossBlueTank.SPEED
		t.target_angle = int(s.z)
		t.sensor = t.direction * BossBlueTank.SENSOR_RADIUS
		_compute_move_steps(t)

	var next := Vector2(t.x, t.y) + t.v
	_test_corners(t, next)
	# The boss's sensor wants drivable ground, swamp and all, where the brown
	# tank's wants land.
	var driveable := map.is_driveable(next.x + t.sensor.x, next.y + t.sensor.y)
	if driveable:
		for o in tanks:
			if o != t and _solid_box(o).intersects(_box_at(next, SOLID)) \
					and not _solid_box(o).intersects(_box_at(Vector2(t.x, t.y), SOLID)):
				driveable = false
				break
	if driveable:
		t.x = next.x
		t.y = next.y
		_update_trail(t)
		if _trail_contains_loop(t):
			_handle_loop(t, player)
	else:
		_drive_at_right_angle_to_barrier(t)

	var dd := player - Vector2(t.x, t.y)
	if t.move_steps == 1 and ((t.v.y != 0 and int(player.x) >> 7 == int(t.x) >> 7)
			or (t.v.x != 0 and int(player.y) >> 7 == int(t.y) >> 7)):
		t.move_steps = 2
	if (t.last_d.x * dd.x <= 0 or t.last_d.y * dd.y <= 0) and _rng.randi_range(0, 2) != 2:
		t.move_steps = 0
	t.last_d = dd

	t.shoot_delay -= 1
	if t.shoot_delay <= 0:
		t.shoot_count -= 1
		if t.shoot_count <= 0:
			t.shoot_count = BossBlueTank.SHOOT_COUNT
			t.shoot_delay = BossBlueTank.SHOOT_LONG_DELAY
		else:
			t.shoot_delay = BossBlueTank.SHOOT_DELAY
		_fire(t)


func _turn(t: Tank, quarter: int) -> void:
	# A quarter turn, +1 clockwise on the map (x east, y south), -1 the other
	# way, 2 about.
	if quarter == 2:
		t.v = -t.v
		t.direction = -t.direction
		t.target_angle += 180
	elif quarter == 1:
		t.v = Vector2(-t.v.y, t.v.x)
		t.direction = Vector2(-t.direction.y, t.direction.x)
		t.target_angle += 90
	else:
		t.v = Vector2(t.v.y, -t.v.x)
		t.direction = Vector2(t.direction.y, -t.direction.x)
		t.target_angle -= 90
	if t.target_angle >= 360:
		t.target_angle -= 360
	elif t.target_angle < 0:
		t.target_angle += 360
	t.sensor = t.direction * BossBlueTank.SENSOR_RADIUS
	if _rng.randi_range(0, 4) != 4:
		_compute_move_steps(t)


func _drive_at_right_angle_to_barrier(t: Tank) -> void:
	if _rng.randi_range(0, 4) == 4:
		_turn(t, 2)
	elif _rng.randi_range(0, 2) == 2:
		_turn(t, -1)
	else:
		_turn(t, 1)


func _compute_move_steps(t: Tank) -> void:
	var v := t.direction.x if t.direction.x != 0 else t.direction.y
	if v == 0:
		return
	var d := 32 - fmod(v, 32.0) if v > 0 else fmod(v, 32.0)
	d += 32 * (1 + _rng.randi_range(0, BossBlueTank.MAX_MOVE_SQUARES - 1))
	t.move_steps = roundi(d / BossBlueTank.SPEED)


func _test_corners(t: Tank, next: Vector2) -> void:
	var a := BossBlueTank.DIMENSION_1
	var b := BossBlueTank.DIMENSION_2
	var c1: Vector2
	var c2: Vector2
	match t.target_angle:
		0:
			c1 = next + Vector2(a, -b)
			c2 = next + Vector2(a, b)
		90:
			c1 = next + Vector2(b, a)
			c2 = next + Vector2(-b, a)
		180:
			c1 = next + Vector2(-a, b)
			c2 = next + Vector2(-a, -b)
		270:
			c1 = next + Vector2(-b, -a)
			c2 = next + Vector2(b, -a)
		_:
			return
	var drive1 := map.is_driveable(c1.x, c1.y)
	var drive2 := map.is_driveable(c2.x, c2.y)
	if drive1 and drive2:
		return
	if not (drive1 or drive2):
		_drive_at_right_angle_to_barrier(t)
	elif drive2:
		_turn(t, 1)
	else:
		_turn(t, -1)


func _update_trail(t: Tank) -> void:
	var cell := ((int(t.y) >> 7) << 4) | (int(t.x) >> 7)
	if cell != t.trail[t.trail_index]:
		t.trail_index = (t.trail_index + 7) % 8
		t.trail[t.trail_index] = cell


func _trail_contains_loop(t: Tank) -> bool:
	var r := func(k: int) -> int: return t.trail[(t.trail_index + k) & 7]
	if r.call(0) == r.call(2) and r.call(1) == r.call(3):
		return true
	if r.call(0) == r.call(3) and r.call(1) == r.call(4) and r.call(2) == r.call(5):
		return true
	return r.call(0) == r.call(4) and r.call(1) == r.call(5) and r.call(2) == r.call(6) \
			and r.call(3) == r.call(7)


func _handle_loop(t: Tank, player: Vector2) -> void:
	if t.handling_loop == 0:
		t.handling_loop = 91 * (2 + _rng.randi_range(0, 4))
		t.loop_target = Vector2(_rng.randf() * 2048, _rng.randf() * player.y)


# A yellow round from the muzzle, along the facing, twice the brown tank's
# speed: EnemyBullet(direction * 2), which the bullet scales by its SPEED.
func _fire(t: Tank) -> void:
	var muzzle := _muzzle(t)
	guns.enemy_bullet(Vector2(muzzle.x, muzzle.z), t.direction * 2.0 * EnemyBullet.SPEED,
			BossBlueTank.BULLET_TRAVEL_TIME, muzzle.y, false)
	var weapon: AnimationPlayer = t.players.weapon
	weapon.play("Shoot")
	weapon.seek(0.0, true)
	if verbose:
		print("boss tank fires from %.2f, %.2f, %.2f at %d degrees" % [muzzle.x, muzzle.y, muzzle.z, t.target_angle])


func _muzzle(t: Tank) -> Vector3:
	var yaw := t.turret_yaw - t.root.rotation.y
	return t.root.global_transform * (_turret_pivot + _muzzle_from_turret.rotated(Vector3.UP, yaw))


func _base(t: Tank) -> String:
	return "Drive" if t.busy else "Idle"


func _place(t: Tank) -> void:
	var at := Level3DMap.to_level(Vector2(t.x, t.y))
	var height: float = ground.call(at.x, at.y).height
	t.root.position = Vector3(at.x, height, at.y)
	t.root.rotation.y = Level3DTanks._heading(t.display_angle)


func _process(delta: float) -> void:
	for t in tanks:
		t.turret_yaw = rotate_toward(t.turret_yaw, Level3DTanks._heading(t.target_angle), TURRET_TURN * delta)
		_run_tracks(t, delta)
		_pose(t, delta)
	for t in _wrecks:
		t.dead_time += delta
		var k := lerpf(1.0, CHAR, clampf(t.dead_time / CHAR_TIME, 0.0, 1.0))
		for pair in t.charred:
			var c: Color = pair[1]
			(pair[0] as StandardMaterial3D).albedo_color = Color(c.r * k, c.g * k, c.b * k, c.a)
		_pose(t, delta)


func _run_tracks(t: Tank, delta: float) -> void:
	var ticks := delta * Engine.physics_ticks_per_second
	var p: AnimationPlayer = t.players.tracks
	if t.turned != 0.0:
		var run := deg_to_rad(absf(t.turned)) * TRACK_X / TRACK_TRAVEL * ticks
		t.spin_phase = fposmod(t.spin_phase + run, 1.0)
		var clip := "Spin_R" if t.turned > 0.0 else "Spin_L"
		if p.current_animation != clip:
			p.play(clip)
		p.seek(t.spin_phase * p.current_animation_length, true)
	else:
		t.track_phase = fposmod(t.track_phase + t.moved / SCALE / TRACK_TRAVEL * ticks, 1.0)
		if p.current_animation != "Tracks":
			p.play("Tracks")
		p.seek(t.track_phase * p.current_animation_length, true)


func _pose(t: Tank, delta: float) -> void:
	for layer in ["hull", "weapon", "exhaust", "smoke", "damage"]:
		(t.players[layer] as AnimationPlayer).advance(delta)
	t.skeleton.set_bone_pose_rotation(t.turret_bone,
			Quaternion(Vector3.UP, t.turret_yaw - t.root.rotation.y))


# ----------------------------------------------------------------------------
# Hits

# BossBlueTank._attacked: a round of damage spent. The first breaches it,
# the second destroys it.
func _attacked(i: int, by: String) -> void:
	var t := tanks[i]
	t.bullet_hits = HITS
	if not t.breached:
		t.breached = true
		(t.players.hull as AnimationPlayer).play("Damage", 0.05)
		(t.players.damage as AnimationPlayer).play("Breach")
		if verbose:
			print("boss tank breached (%s) at %.0f, %.0f, tick %d" % [by, t.x, t.y, Engine.get_physics_frames()])
		return
	tanks.remove_at(i)
	var at := t.root.position
	guns.blast.call(at + Vector3.UP * BLAST_HEIGHT, BLAST_SCALE)
	guns.explode(at)
	(t.players.hull as AnimationPlayer).play("Death", 0.05)
	(t.players.smoke as AnimationPlayer).play("Burn", 0.3)
	(t.players.exhaust as AnimationPlayer).play(OFF, 0.2)
	_char(t)
	_wrecks.append(t)
	scored.call(POINTS)
	_destroyed += 1
	if verbose:
		print("boss tank destroyed (%s) at %.0f, %.0f, tick %d" % [by, t.x, t.y, Engine.get_physics_frames()])
		if _destroyed == BossBlueTanksManager.TANKS:
			print("boss: all four destroyed, stage completed")


func _char(t: Tank) -> void:
	for node in t.root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null or m.resource_name in KEEP_COLOUR:
				continue
			var own := m.duplicate() as StandardMaterial3D
			mi.set_surface_override_material(s, own)
			t.charred.append([own, m.albedo_color])


static func _box_at(at: Vector2, half: float) -> Rect2:
	return Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)


func _solid_box(t: Tank) -> Rect2:
	return _box_at(Vector2(t.x, t.y), SOLID)


func _hit_box(t: Tank, margin: float) -> Rect2:
	var box := _box_at(Vector2(t.x, t.y), HIT + margin)
	return Rect2(Level3DMap.to_level(box.position), box.size * PX)


# The first tank a weapon's flight from `from` to `to` meets: {"t", "boss"}
# or empty, as Level3DTanks.intercept's.
func intercept(from: Vector3, to: Vector3, margin: float, in_frame := false) -> Dictionary:
	var view: Rect2 = frame.call()
	var best := {}
	for t in tanks:
		var box := _hit_box(t, margin)
		if in_frame and not view.intersects(box):
			continue
		var s := Level3DGuns._segment_enters(Vector2(from.x, from.z), Vector2(to.x, to.z), box)
		if s >= 0.0 and (best.is_empty() or s < best.t):
			best = {"t": s, "boss": t}
	return best


# BossBlueTank.bullet_attack: five rounds to a round of damage.
func bullet_attack(found: Dictionary) -> void:
	var i := tanks.find(found.boss)
	if i < 0:
		return
	var t := tanks[i]
	t.bullet_hits -= 1
	if t.bullet_hits == 0:
		_attacked(i, "machine gun")
	elif verbose:
		print("boss tank hit, %d left in this round" % t.bullet_hits)


# BossBlueTank.attack from a grenade or missile: a whole round of damage.
func attack(found: Dictionary) -> void:
	var i := tanks.find(found.boss)
	if i >= 0:
		_attacked(i, "rocket")


# BossBlueTank.bump: running into one kills the player, not the tank.
func bump(player_box: Rect2, invincible: bool) -> bool:
	if invincible:
		return false
	for t in tanks:
		var box := _box_at(Vector2(t.x, t.y), MINE)
		if player_box.intersects(Rect2(Level3DMap.to_level(box.position), box.size * PX)):
			return true
	return false
