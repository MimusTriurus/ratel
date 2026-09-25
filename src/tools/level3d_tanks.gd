# The brown tanks on the 3D stage 1 preview: jackal.BrownTank, on
# jackal_tank.glb (jackal_tank_lowpoly.blend).
#
# Nothing here is part of the game, and the rules are the game's, as the
# boats' are (level3d_boats.gd): stage-0.json's BROWN_TANK triggers on normal
# -- two -- spawned as GameMode._process_triggers spawns them, run in map
# pixels and ticks on the game's own grid and flow field (Level3DMap). Their
# rounds are Level3DGuns' EnemyBullets and the explosion they die in is its
# Explosion.
#
# What the game does, and so this:
#   * A tank appears when its trigger row comes to the top of the frame, at
#     (32, 48) px into the trigger's corner, facing south.
#   * It drives the flow field towards the player, 1.25 px a tick, in runs
#     that end on a tile boundary; a run is re-planned when the player
#     crosses its axis, and one time in five towards a point near the player
#     instead. It turns on the spot, 1.875 degrees a tick, and only drives and
#     fires when it has come round.
#   * Its sensor, 46 px ahead, has to be on land, and both its front corners
#     on ground it can drive; a blocked corner turns it, both send it off at
#     a right angle, as does another tank in its way. A tank that goes round
#     the same cells is sent to a random point for a while.
#   * It fires bursts of three white rounds along its facing, 45 ticks apart
#     and 91 between bursts, which fly for 182 ticks.
#   * It takes four machine-gun rounds and one grenade or missile, and dies in
#     any explosion but the player's own; its hit box is 40 px either side.
#     The player running into it -- 28 px either side -- kills both. 500
#     points.
#
# Where this departs from the game, and why:
#   * It fires from the muzzle, not from 32 px ahead of its centre: the turret
#     stands on the model's middle and the muzzle 3 m out from it, scaled.
#   * The turret leads a turn: it comes round to the new facing faster than
#     the hull does, and is on it by the time the tank drives and fires. The
#     sprite has no turret to turn; the rounds still go the way the tank faces.
#   * The sprite's three frames are its facing. Here the clips (jackal_tank.py)
#     say what it does, one layer each on a player of its own, as the boat's
#     two are: the tracks run as far as it drives and spin as far as it
#     turns, the hull rocks over the ground while it moves and idles while it
#     does not, the exhaust puffs harder under way, a hit knocks it about and
#     leaves it smoking, and Shoot recoils the barrel.
#   * The game removes it and draws an Explosion. Here the blast is drawn over
#     it, it plays Death -- the turret blown off in a fireball -- and it stays
#     where it was, burnt black and smoking, until it is left behind. A wreck
#     is neither solid nor a mine.
class_name Level3DTanks
extends Node3D

const TANK_PATH := "res://resources/3d/jackal_tank.glb"
const PX := Level3DMap.PX
# The model is a 6.4 m tank, 3.9 m wide; the sprite is 84 x 64 px, 1.23 x
# 0.94 m on the level's scale. A little over that, as the boat is, so that
# the turret and the tracks read from above: 1.6 x 1 m, the BTR's width.
const SCALE := 0.25
const HIT := 40.0
const MINE := 28.0
const SOLID := 45.0
const POINTS := 500
const TRIGGER_OFFSET := Vector2(32, 48)
const TURRET_TURN := 4.0      # rad/s: three times the hull's 3.27
const BLAST_HEIGHT := 0.5
const BLAST_SCALE := 0.9
# How far the tracks move in one loop of Tracks and Spin, in the model's
# metres (jackal_tank.py: TRACK_STEPS * LOOP.step), and how far out from the
# middle a track runs (TRACK_X): what a turn on the spot moves it.
const TRACK_TRAVEL := 0.736
const TRACK_X := 1.6
# A track's width (jackal_tank.py's pads), and the pads in one loop of Tracks
# (TRACK_STEPS): the marks it leaves, in model metres.
const TRACK_WIDTH := 0.8
const TRACK_PADS := 2.0
# The layers of jackal_tank.py's clips: the bones each keys, by name or by
# prefix, and its clips. The glTF export gives every clip a track for every
# bone any clip moves, so each layer's clips are cut down to its own bones.
const LAYERS := {
	"tracks": {"bones": ["Pad.", "Wheel."], "clips": ["Tracks", "Spin_L", "Spin_R"]},
	"hull": {"bones": ["Hull", "Ring", "Blast."], "clips": ["Idle", "Drive", "Damage", "Death"]},
	"weapon": {"bones": ["Gun", "Barrel", "Flash"], "clips": ["Shoot"]},
	"exhaust": {"bones": ["Exhaust.", "Dust."], "clips": ["Exhaust", "Exhaust_Drive"]},
	"smoke": {"bones": ["Smoke."], "clips": ["Smoke", "Burn"]},
}
const LOOPS := ["Tracks", "Spin_L", "Spin_R", "Idle", "Drive", "Exhaust", "Exhaust_Drive", "Smoke", "Burn"]
# Every layer of puffs has an Off, made here: jackal_tank.py bakes one, but a
# two-frame clip does not come through the glTF export.
const OFF := "Off"
const BLEND := 0.25
# A wreck goes black over this long, all but its fireball and its smoke.
const CHAR_TIME := 1.2
const CHAR := 0.28
const KEEP_COLOUR := ["MT_Fire", "MT_Flash", "MT_Smoke", "MT_SmokeDark", "MT_Dust"]

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
var _trigger_y := -1
var _furthest_top := INF
var _rng := RandomNumberGenerator.new()


class Tank:
	var x: float            # map pixels
	var y: float
	var shoot_delay := BrownTank.SHOOT_DELAY
	var shoot_count := BrownTank.SHOOT_COUNT
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
	var bullet_hits := 4
	var turret_yaw := 0.0   # the turret's facing, level radians as root.rotation.y
	var moved := 0.0        # level metres driven this tick
	var turned := 0.0       # degrees turned this tick, + clockwise on the map
	var busy := false       # it drove or turned this tick
	var track_phase := 0.0  # loops of Tracks, of Spin
	var spin_phase := 0.0
	var root: Node3D
	var players := {}       # layer -> AnimationPlayer
	var skeleton: Skeleton3D
	var turret_bone := -1
	var dead_time := 0.0
	var charred: Array = []  # [material, colour] to blacken


func _ready() -> void:
	_scene = load(TANK_PATH)
	if _scene == null:
		push_error("Cannot load %s -- run export() in jackal_tank_lowpoly.blend" % TANK_PATH)
		return
	_make_libraries()
	_rng.seed = 7
	reset()


func _layer_of(bone: String) -> String:
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
		var off := Animation.new()
		off.length = 1.0 / 24.0
		for i in skeleton.get_bone_count():
			var bone := skeleton.get_bone_name(i)
			if _layer_of(bone) == layer:
				var t := off.add_track(Animation.TYPE_SCALE_3D)
				off.track_set_path(t, NodePath("%s:%s" % [prefix, bone]))
				off.scale_track_insert_key(t, 0.0, Vector3.ONE * 0.001)
		(_libraries[layer] as AnimationLibrary).add_animation(OFF, off)
	# The turret's pivot and the muzzle, from the skeleton rather than written
	# out again here: the Flash bone is at the muzzle.
	_turret_pivot = skeleton.get_bone_global_rest(skeleton.find_bone("Turret")).origin
	_muzzle_from_turret = skeleton.get_bone_global_rest(skeleton.find_bone("Flash")).origin - _turret_pivot
	probe.free()


# Level3DTracks' contacts: the middle of where each track touches, both sides
# of every tank still running. A wreck leaves none, and does not move.
func track_contacts() -> Array:
	var contacts := []
	for t in tanks:
		var across := t.root.basis.x.normalized() * TRACK_X * SCALE
		for side in [-1, 1]:
			contacts.append({"key": "%d:%d" % [t.root.get_instance_id(), side],
					"at": t.root.position + across * side, "width": TRACK_WIDTH * SCALE,
					"pitch": TRACK_TRAVEL / TRACK_PADS * SCALE, "tread": 1.0})
	return contacts


func reset() -> void:
	for t in tanks + _wrecks:
		t.root.queue_free()
	tanks.clear()
	_wrecks.clear()
	_trigger_y = map.stage.map_height
	_furthest_top = INF


# ----------------------------------------------------------------------------
# The tick

func tick() -> void:
	var view: Rect2 = frame.call()
	var top := Level3DMap.to_map(view.position).y
	_process_triggers(top)
	_furthest_top = minf(_furthest_top, top)
	var player := Level3DMap.to_map(player_position.call())
	var bound := _furthest_top + Level3DSoldiers.CAMERA_BOUND + Level3DSoldiers.REMOVE_BOUND
	for i in range(tanks.size() - 1, -1, -1):
		var t := tanks[i]
		_update(t, player)
		# Enemy.check_bounds, on its solid box.
		if t.y - SOLID > bound:
			t.root.queue_free()
			tanks.remove_at(i)
	for i in range(_wrecks.size() - 1, -1, -1):
		if _wrecks[i].y - SOLID > bound:
			_wrecks[i].root.queue_free()
			_wrecks.remove_at(i)


func _process_triggers(top: float) -> void:
	var row := (int(top) >> 5) - 1
	if row < 0:
		return
	var triggers: Array = map.stage.trigger_map[0]
	while _trigger_y > row:
		_trigger_y -= 1
		var list: Array = triggers[_trigger_y]
		for i in range(list.size() - 1, -1, -1):
			var t: Array = list[i]
			if t[0] == Triggers.BROWN_TANK:
				_spawn(t[1] + TRIGGER_OFFSET.x, t[2] + TRIGGER_OFFSET.y)


func _spawn(x: float, y: float) -> void:
	var t := Tank.new()
	t.x = x
	t.y = y
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
		print("tank appears at %.0f, %.0f" % [x, y])


# The imported player for the hull and one more for each other layer, each
# with its own library: a player resets every track its library has, so one
# that held two layers would undo the other's. All are advanced by hand in
# _process, the tracks by how far the tank has gone, and the turret turned
# after them.
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
	hull.play("Idle")
	(t.players.tracks as AnimationPlayer).play("Tracks")
	(t.players.exhaust as AnimationPlayer).play("Exhaust")
	(t.players.smoke as AnimationPlayer).play(OFF)
	# Shoot's last frame is the gun at rest with no flash: held there until
	# the first round.
	var weapon: AnimationPlayer = t.players.weapon
	weapon.play("Shoot")
	weapon.seek(weapon.current_animation_length, true)


# BrownTank.update.
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


func _drive(t: Tank, player: Vector2) -> void:
	if t.display_angle != t.target_angle:
		t.shoot_count = BrownTank.SHOOT_COUNT
		var delta_angle := fmod(t.target_angle - t.display_angle + 180, 360.0)
		if delta_angle < 0:
			delta_angle += 180
		else:
			delta_angle -= 180
		if absf(delta_angle) < BrownTank.ANGLE_VELOCITY:
			t.display_angle = t.target_angle
		elif delta_angle < 0:
			t.display_angle -= BrownTank.ANGLE_VELOCITY
		else:
			t.display_angle += BrownTank.ANGLE_VELOCITY
		return

	if t.handling_loop > 0:
		t.handling_loop -= 1

	t.move_steps -= 1
	if t.move_steps <= 0:
		var d := Vector2.ZERO
		if _rng.randi_range(0, 4) == 4:
			d = Vector2(_rng.randi_range(0, 511) - 256, _rng.randi_range(0, 511) - 256)
		var goal := (t.loop_target if t.handling_loop > 0 else player) + d
		var s := map.suggest_direction_exact(t.x, t.y, goal.x, goal.y)
		t.direction = Vector2(s.x, s.y)
		t.v = t.direction * BrownTank.SPEED
		t.target_angle = int(s.z)
		t.sensor = t.direction * BrownTank.SENSOR_RADIUS
		_compute_move_steps(t)

	var next := Vector2(t.x, t.y) + t.v
	_test_corners(t, next)
	# _test_corners may have turned it: the step is the one it had.
	var driveable := map.is_driveable_land(next.x + t.sensor.x, next.y + t.sensor.y)
	if driveable:
		# Avoid bumping into other tanks, but never get stuck inside one.
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
	# Don't stop on the same row/column as the player; keep going one more step.
	if t.move_steps == 1 and ((t.v.y != 0 and int(player.x) >> 7 == int(t.x) >> 7)
			or (t.v.x != 0 and int(player.y) >> 7 == int(t.y) >> 7)):
		t.move_steps = 2
	# The player crossed our axis, so usually re-plan immediately.
	if (t.last_d.x * dd.x <= 0 or t.last_d.y * dd.y <= 0) and _rng.randi_range(0, 2) != 2:
		t.move_steps = 0
	t.last_d = dd

	t.shoot_delay -= 1
	if t.shoot_delay <= 0:
		t.shoot_count -= 1
		if t.shoot_count <= 0:
			t.shoot_count = BrownTank.SHOOT_COUNT
			t.shoot_delay = BrownTank.SHOOT_LONG_DELAY
		else:
			t.shoot_delay = BrownTank.SHOOT_DELAY
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
	t.target_angle = posmod(t.target_angle, 360)
	t.sensor = t.direction * BrownTank.SENSOR_RADIUS
	if _rng.randi_range(0, 4) != 4:
		_compute_move_steps(t)


func _drive_at_right_angle_to_barrier(t: Tank) -> void:
	if _rng.randi_range(0, 4) == 4:
		_turn(t, 2)
	elif _rng.randi_range(0, 2) == 2:
		_turn(t, -1)
	else:
		_turn(t, 1)


# Runs end on a tile boundary, so the tank always stops square to the grid.
func _compute_move_steps(t: Tank) -> void:
	var v := t.direction.x if t.direction.x != 0 else t.direction.y
	if v == 0:
		return
	var d := 32 - fmod(v, 32.0) if v > 0 else fmod(v, 32.0)
	d += 32 * (1 + _rng.randi_range(0, BrownTank.MAX_MOVE_SQUARES - 1))
	t.move_steps = roundi(d / BrownTank.SPEED)


# The two leading corners; one blocked turns the tank, both blocked sends it
# off at a right angle.
func _test_corners(t: Tank, next: Vector2) -> void:
	var a := BrownTank.DIMENSION_1
	var b := BrownTank.DIMENSION_2
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


# HitElement.update_trail and trail_contains_loop: the last eight 128 px cells.
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


# The round: from the muzzle, along the facing, as the game fires it.
func _fire(t: Tank) -> void:
	var muzzle := _muzzle(t)
	guns.enemy_bullet(Vector2(muzzle.x, muzzle.z), t.direction * EnemyBullet.SPEED,
			BrownTank.BULLET_TRAVEL_TIME, muzzle.y, true)
	var weapon: AnimationPlayer = t.players.weapon
	weapon.play("Shoot")
	weapon.seek(0.0, true)
	if verbose:
		print("tank fires from %.2f, %.2f, %.2f at %d degrees" % [muzzle.x, muzzle.y, muzzle.z, t.target_angle])


func _muzzle(t: Tank) -> Vector3:
	var yaw := t.turret_yaw - t.root.rotation.y
	return t.root.global_transform * (_turret_pivot + _muzzle_from_turret.rotated(Vector3.UP, yaw))


# The model's +z is its nose; the game's angle 0 is east and 90 south.
static func _heading(angle_deg: float) -> float:
	var d := Vector2.from_angle(deg_to_rad(angle_deg))
	return atan2(d.x, d.y)


# What the hull plays when it is doing nothing else: rocking while the tank
# drives or turns, idling while it is held up.
func _base(t: Tank) -> String:
	return "Drive" if t.busy else "Idle"


func _place(t: Tank) -> void:
	var at := Level3DMap.to_level(Vector2(t.x, t.y))
	var height: float = ground.call(at.x, at.y).height
	t.root.position = Vector3(at.x, height, at.y)
	t.root.rotation.y = _heading(t.display_angle)


# Per rendered frame: the clips, the tracks as far as the tank has gone, then
# the turret over them, coming round to the facing.
func _process(delta: float) -> void:
	for t in tanks:
		t.turret_yaw = rotate_toward(t.turret_yaw, _heading(t.target_angle), TURRET_TURN * delta)
		_run_tracks(t, delta)
		_pose(t, delta)
	for t in _wrecks:
		t.dead_time += delta
		var k := lerpf(1.0, CHAR, clampf(t.dead_time / CHAR_TIME, 0.0, 1.0))
		for pair in t.charred:
			var c: Color = pair[1]
			(pair[0] as StandardMaterial3D).albedo_color = Color(c.r * k, c.g * k, c.b * k, c.a)
		_pose(t, delta)


# A tick's driving, spread over the frames it takes: drawn at 60 fps, the
# tracks would stutter if they jumped a tick's worth at a time.
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
	for layer in ["hull", "weapon", "exhaust", "smoke"]:
		(t.players[layer] as AnimationPlayer).advance(delta)
	t.skeleton.set_bone_pose_rotation(t.turret_bone,
			Quaternion(Vector3.UP, t.turret_yaw - t.root.rotation.y))


# ----------------------------------------------------------------------------
# Hits and dying

# Enemy.do_remove + Explosion + add_points: the blast over it, an Explosion
# that goes on to hit what is next to it, and Death played on the spot.
func _kill(i: int, by: String) -> void:
	var t := tanks[i]
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
	if verbose:
		print("tank destroyed (%s) at %.0f, %.0f, tick %d" % [by, t.x, t.y, Engine.get_physics_frames()])


# Its own copies of the paint, to blacken: every tank shares the imported ones.
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


func _box_at(at: Vector2, half: float) -> Rect2:
	return Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)


func _solid_box(t: Tank) -> Rect2:
	return _box_at(Vector2(t.x, t.y), SOLID)


func _hit_box(t: Tank, margin: float) -> Rect2:
	var h := HIT + margin
	var box := _box_at(Vector2(t.x, t.y), h)
	return Rect2(Level3DMap.to_level(box.position), box.size * PX)


# The first tank a weapon's flight from `from` to `to` meets, its box grown by
# the weapon's `margin` px: {"t", "tank"} or empty. `in_frame` is the grenade's
# and missile's rule, as Level3DGuns.intercept's.
func intercept(from: Vector3, to: Vector3, margin: float, in_frame := false) -> Dictionary:
	var view: Rect2 = frame.call()
	var best := {}
	for t in tanks:
		var box := _hit_box(t, margin)
		if in_frame and not view.intersects(box):
			continue
		var s := Level3DGuns._segment_enters(Vector2(from.x, from.z), Vector2(to.x, to.z), box)
		if s >= 0.0 and (best.is_empty() or s < best.t):
			best = {"t": s, "tank": t}
	return best


# Enemy.bullet_attack: four rounds, and the ones before the fourth knock it
# about and leave it smoking.
func bullet_attack(found: Dictionary) -> void:
	var i := tanks.find(found.tank)
	if i < 0:
		return
	var t := tanks[i]
	t.bullet_hits -= 1
	if t.bullet_hits <= 0:
		_kill(i, "machine gun")
		return
	if verbose:
		print("tank hit, %d left" % t.bullet_hits)
	var hull: AnimationPlayer = t.players.hull
	if hull.current_animation != "Damage":
		hull.play("Damage", 0.05)
	var smoke: AnimationPlayer = t.players.smoke
	if smoke.current_animation != "Smoke":
		smoke.play("Smoke", 0.3)


# Enemy.attack from a grenade or missile: gone at once.
func attack(found: Dictionary) -> void:
	var i := tanks.find(found.tank)
	if i >= 0:
		_kill(i, "rocket")


# An Explosion's box this tick (Level3DGuns): any tank in it is destroyed,
# unless the explosion is the player's.
func explosion_hit(box: Rect2, player: bool) -> void:
	if player:
		return
	for i in range(tanks.size() - 1, -1, -1):
		if box.intersects(_hit_box(tanks[i], 0.0)):
			_kill(i, "explosion")


# Enemy.bump for the player's box (level x, z): a tank run into is destroyed,
# and so is the player, unless it cannot be hit.
func bump(player_box: Rect2, invincible: bool) -> bool:
	if invincible:
		return false
	for i in range(tanks.size() - 1, -1, -1):
		var t := tanks[i]
		var box := _box_at(Vector2(t.x, t.y), MINE)
		if player_box.intersects(Rect2(Level3DMap.to_level(box.position), box.size * PX)):
			_kill(i, "run into")
			return true
	return false
