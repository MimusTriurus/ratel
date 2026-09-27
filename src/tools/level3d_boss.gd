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
#     Here the tank is the sprite's blue throughout, and the round shows in its
#     shape: Breach, played once with Damage for the jolt -- three skirt
#     plates and an armour plate blown off, three holes torn open with fire in
#     them -- then Breached, held: the plates gone and the holes open. The
#     model's damage layer (jackal_heavy_tank.py) is made for this. What the
#     holes do is drawn here rather than in the model (EFFECTS): each glows,
#     a ball of the blasts' fire that flares as it is torn open and flickers
#     after (_burn); throws three sparks then and one every so often after;
#     and smokes, Level3DPuffs' wisps out of it (puffs).
#   * It is the sprite's size and, from above, its shape (SCALE): it was drawn
#     half as big again, on an 8 m hull twice as long as wide, with boxes
#     grown to match, and it is not any more.
#   * The spawn below the frame is below this frame's bottom edge, as the
#     game's is below its own, and the preview's frame is taller than the
#     game's 1152 px -- 1686 at zoom 1, and it moves with the zoom. So the
#     drive in from below is not the game's 42 ticks from wherever that is but
#     as long as it takes to reach where the game's ends (ARENA_ENTRY), and
#     never shorter. And it goes up the lane the game picked only when the
#     tank fits on drivable ground all the way (_lane_clear): below row 35
#     the arena is a corridor between x 736 and 1311, and 640 and 1408 are in
#     the forest either side of it. A tank driven in there, as it was, came
#     out of its drive with every way blocked and turned on the spot for
#     good. Otherwise it comes up the middle of the corridor (CORRIDOR_X),
#     or failing that the other lane. Zoomed in to 3 or so the rocks in rows
#     12 to 23 cross all three, and from 5 the frame's bottom is in the
#     forest along the top of the map; then the drive is made longer or
#     shorter until it ends clear, which is what matters
#     (_drive_in_from_below).
#   * It fires from the muzzle and its turret leads a turn, as the brown
#     tanks' do; the rounds still go the way the hull faces. Its exhaust and
#     its dust are Level3DPuffs', as theirs are (puffs).
#   * The game removes a destroyed tank and draws an Explosion; here it plays
#     Death in the blast and stays, burnt black and smoking -- Level3DPuffs'
#     column, as a brown tank's wreck's (Level3DTanks). GameMode's
#     destroy_all when the fourth goes is not done: the preview has nothing
#     else in the arena.
class_name Level3DBoss
extends Node3D

const TANK_PATH := "res://resources/3d/jackal_heavy_tank.glb"
const PX := Level3DMap.PX
# The sprite, seen from above, is a hull 80 px across and 92 nose to tail,
# the gun 8 px past the nose -- 1.17 x 1.35 m on the level's scale, a little
# under the BTR's 1.8 x 1.1 and wider. The model is built to that shape
# (jackal_heavy_tank.py, K): 3.8 m across the skirts, 4.4 nose to tail, so
# it is drawn at the scale that makes its width the sprite's.
const SPRITE_WIDTH := 80.0
const MODEL_WIDTH := 3.8
const SCALE := SPRITE_WIDTH * PX / MODEL_WIDTH
# BossBlueTank's boxes, the game's own: the model is the sprite's size.
const HIT := 50.0
const MINE := 40.0
const SOLID := 54.0
const POINTS := 800
const HITS := 5               # BossBlueTank.bullet_hits, each round of damage
const SPAWN_X := [640.0, 1408.0]
# 52 px beyond the frame, as the game's.
const SPAWN_OUTSIDE := 52.0
const INTRO_FROM_TOP := 128
const INTRO_FROM_BOTTOM := 42
# Where the game's drive in from below ends: its frame's bottom, 52 px beyond,
# and 42 ticks back up. And the corridor's middle, for a tank whose lane is in
# the forest.
const ARENA_ENTRY := Main.SCREEN_HEIGHT + SPAWN_OUTSIDE - INTRO_FROM_BOTTOM * BossBlueTank.SPEED
const CORRIDOR_X := 1024.0
const TURRET_TURN := 4.0      # rad/s
const BLAST_HEIGHT := 0.5
const BLAST_SCALE := 1.1
# How far the tracks move in one loop of Tracks and Spin, in the model's
# metres (jackal_heavy_tank.py: TRACK_STEPS * LOOP.step), and how far out
# from the middle a track runs (TRACK_X).
const TRACK_TRAVEL := 0.770
const TRACK_X := 1.36
# A track's width and the pads in one loop of Tracks (TRACK_STEPS), as
# Level3DTanks': the marks it leaves, in model metres.
const TRACK_WIDTH := 0.8
const TRACK_PADS := 2.0
# The medium tank's five layers under the same names, and the damage layer.
# The glTF export gives every clip a track for every bone any clip moves, so
# each layer's clips are cut down to its own bones.
const LAYERS := {
	"tracks": {"bones": ["Pad.", "Wheel."], "clips": ["Tracks", "Spin_L", "Spin_R"]},
	"hull": {"bones": ["Hull", "Ring"], "clips": ["Idle", "Drive", "Damage", "Death"]},
	"weapon": {"bones": ["Gun", "Barrel"], "clips": ["Shoot"]},
	"damage": {"bones": ["Skirt.", "Fender.", "Breach."], "clips": ["Breach", "Breached"]},
}
const LOOPS := ["Tracks", "Spin_L", "Spin_R", "Idle", "Drive", "Breached"]
# The model's effects, by bone, as the brown tanks' (Level3DTanks.EFFECTS),
# and the holes' glow, sparks and wisps with them.
const EFFECTS := ["Blast.", "Flash", "Smoke.", "Glow.", "Spark.", "Wisp."]
# Made here: it does not survive the glTF export, and a damage layer left
# unplayed shows the breaches.
const INTACT := "Intact"
const LOST := ["Skirt.", "Fender."]
const BLEND := 0.25
const CHAR_TIME := 1.2
const CHAR := 0.28
# Level3DPuffs': a puff's radius, level metres, out of the exhausts standing,
# and off the tracks -- the brown tanks', grown with the tank.
const EXHAUST_SIZE := 0.1
const DUST_SIZE := 0.22
# Level3DPuffs' smoke, in the model's metres scaled, as Level3DTanks': the
# wreck's column off Smoke.0, as Burn drew it (the bone's 2.1 times the 0.6 m
# ball, rising 3.85 m in a second); and each hole's wisps off its Glow bone,
# as Breached drew them, two to a hole on a 0.75 s loop, 0.4 m across and
# rising 1.75 m, from WISP_AFTER into Breach.
const WRECK_SMOKE := {"kind": "smoke", "colour": "smoke", "every": 0.2, "life": 1.0,
		"size": 1.26 * SCALE, "rise": 3.85 * SCALE}
const WISP := {"kind": "smoke", "colour": "exhaust", "every": 0.375, "life": 0.75,
		"size": 0.41 * SCALE, "rise": 1.75 * SCALE}
const WISP_AFTER := 0.3
# A hole's glow: the fire's ball GLOW_SIZE across, model metres (the model's
# was 0.24), flaring to GLOW_FLARE times that as it is torn open and back
# over GLOW_SETTLE seconds, then flickering by GLOW_FLICKER; its fire's age,
# which is its colour (level3d_fire.gdshader), about GLOW_AGE, the yellow and
# orange of the model's HT_Flash and HT_Fire.
const GLOW_SIZE := 0.24
const GLOW_FLARE := 1.7
const GLOW_SETTLE := 0.5
const GLOW_FLICKER := 0.15
const GLOW_AGE := 0.45
# Its sparks, level metres and seconds: three off each hole as it is torn
# open, and one every SPARK_EVERY or so after, smaller and shorter. Out from
# the hull and up, falling.
const BURST_SPARKS := 3
const BURST_SPARK := {"size": 0.036, "life": 0.55, "speed": 0.9}
const SPARK := {"size": 0.022, "life": 0.22, "speed": 0.6}
const SPARK_EVERY := 0.35
const SPARK_FALL := 1.5
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
var _exhaust_bones := PackedInt32Array()
var _dust_bones := PackedInt32Array()
var _smoke_bone := -1
var _glow_bones := PackedInt32Array()
var _effect_bones := PackedInt32Array()
var _fire_material: ShaderMaterial
var _glow_mesh: ArrayMesh
var _spark_mesh: ArrayMesh
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
	var breach_time := -1.0          # seconds since it was breached
	var glows: Array[MeshInstance3D] = []
	var spark_next := PackedFloat32Array()


func _ready() -> void:
	_scene = load(TANK_PATH)
	if _scene == null:
		push_error("Cannot load %s -- run export() in jackal_heavy_tank_lowpoly.blend" % TANK_PATH)
		return
	_make_libraries()
	_fire_material = Level3DFx.fire()
	_glow_mesh = Level3DFx.ball(1, 0.06, 6)
	_spark_mesh = Level3DFx.ball(0, 0.25, 2)
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
	# Intact: the plates the first round blows off where they were modelled,
	# every breach bone scaled to nothing.
	(_libraries.damage as AnimationLibrary).add_animation(INTACT, _still(skeleton, prefix, "damage", LOST))
	_turret_pivot = skeleton.get_bone_global_rest(skeleton.find_bone("Turret")).origin
	_muzzle_from_turret = skeleton.get_bone_global_rest(skeleton.find_bone("Flash")).origin - _turret_pivot
	for side in ["L", "R"]:
		_exhaust_bones.append(skeleton.find_bone("Exhaust." + side))
		_dust_bones.append(skeleton.find_bone("Dust." + side))
	_smoke_bone = skeleton.find_bone("Smoke.0")
	for i in 3:
		_glow_bones.append(skeleton.find_bone("Glow.%d" % i))
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		if EFFECTS.any(func(e: String): return bone == e or (e.ends_with(".") and bone.begins_with(e))):
			_effect_bones.append(i)
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


# Level3DPuffs' emitters, as the brown tanks' (Level3DTanks.puffs): the
# exhausts and the tracks of every tank running, the column off every wreck,
# and the wisps out of the holes of every tank breached, wreck or not.
func puffs() -> Array:
	var out := []
	for t in _wrecks:
		out.append(_smoke_from(t, _smoke_bone, WRECK_SMOKE, "s"))
	for t in tanks + _wrecks:
		if t.breach_time >= WISP_AFTER:
			for i in _glow_bones.size():
				out.append(_smoke_from(t, _glow_bones[i], WISP, "w%d" % i))
	for t in tanks:
		var id := t.root.get_instance_id()
		var mouths: Array[Vector3] = []
		for bone in _exhaust_bones:
			mouths.append(t.skeleton.global_transform * t.skeleton.get_bone_global_pose(bone).origin)
		var tail := (mouths[0] + mouths[1]) * 0.5 - t.root.global_position
		var back := Vector3(tail.x, 0.0, tail.z).normalized()
		for i in mouths.size():
			out.append({"key": "%d:e%d" % [id, i], "kind": "exhaust", "at": mouths[i], "back": back,
					"size": EXHAUST_SIZE, "working": 1.0 if t.busy else 0.0})
		# The bone is a little over the ground, off the back of the track:
		# brought down to where the tank stands.
		for i in _dust_bones.size():
			var at := t.skeleton.global_transform * t.skeleton.get_bone_global_pose(_dust_bones[i]).origin
			at.y = t.root.global_position.y
			out.append({"key": "%d:d%d" % [id, i], "kind": "dust", "at": at, "size": DUST_SIZE})
	return out


func _smoke_from(t: Tank, bone: int, smoke: Dictionary, key: String) -> Dictionary:
	var e := smoke.duplicate()
	e.key = "%d:%s" % [t.root.get_instance_id(), key]
	e.at = _bone_at(t, bone)
	return e


func _bone_at(t: Tank, bone: int) -> Vector3:
	return t.skeleton.global_transform * t.skeleton.get_bone_global_pose(bone).origin


func reset() -> void:
	for child in get_children():
		if child.has_meta("spark"):
			child.queue_free()
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
	t.intro_delay = INTRO_FROM_TOP
	if not from_top:
		_drive_in_from_below(t)
	t.root = _scene.instantiate() as Node3D
	t.root.scale = Vector3.ONE * SCALE
	add_child(t.root)
	# Lit by its own flash (Level3DGuns.muzzle_flash).
	Level3DFx.flash_lit(t.root, Level3DFx.ENEMY_FLASH_LAYER)
	_split_players(t)
	t.skeleton = t.root.find_child("Skeleton3D", true, false) as Skeleton3D
	# No clip keys them any more, so this holds.
	for bone in _effect_bones:
		t.skeleton.set_bone_pose_scale(bone, Vector3.ONE * 0.001)
	t.turret_bone = t.skeleton.find_bone("Turret")
	_place(t)
	t.turret_yaw = t.root.rotation.y
	tanks.append(t)
	if verbose:
		print("boss tank %d appears at %.0f, %.0f" % [_spawned, t.x, y])


# The lane and the length of a drive in from below (the head comment has
# why): to ARENA_ENTRY and at least the game's 42 ticks, up the first of the
# game's lane, the corridor's middle and the other lane that is clear all the
# way. Failing that, the drive that ends clear nearest that length, a tick at
# a time either way, the lanes in that order at each: one that stops short
# waits below the frame and drives in by the flow field like any other.
func _drive_in_from_below(t: Tank) -> void:
	var ticks := maxi(INTRO_FROM_BOTTOM, ceili((t.y - ARENA_ENTRY) / BossBlueTank.SPEED))
	var lanes := [t.x, CORRIDOR_X, SPAWN_X[0] + SPAWN_X[1] - t.x]
	t.intro_delay = ticks
	for lane in lanes:
		if _lane_clear(lane, t.y - ticks * BossBlueTank.SPEED, t.y):
			t.x = lane
			return
	for k in ticks + int(t.y / BossBlueTank.SPEED):
		for lane in lanes:
			for n in [ticks - k, ticks + k]:
				var end: float = t.y - n * BossBlueTank.SPEED
				if n >= 0 and end > 0.0 and _lane_clear(lane, end, end):
					t.x = lane
					t.intro_delay = n
					return


# Whether a tank driven up x from y `from` below to `to` is on drivable
# ground the whole way where it is on the map: _test_corners' two corners
# ahead of it, a tile at a time. Below the map it is off the grid, and
# tile_type would clamp it to the bottom row.
func _lane_clear(x: float, to: float, from: float) -> bool:
	var y := to
	while y <= minf(from, map.stage.map_height * 32.0 - 1.0):
		if not map.is_driveable_box(x - BossBlueTank.DIMENSION_2, y - BossBlueTank.DIMENSION_1,
				x + BossBlueTank.DIMENSION_2, y + BossBlueTank.DIMENSION_1):
			return false
		y += 32.0
	return true


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
# With a flash, as the brown tanks' (Level3DGuns.muzzle_flash).
func _fire(t: Tank) -> void:
	var muzzle := _muzzle(t)
	guns.enemy_bullet(Vector2(muzzle.x, muzzle.z), t.direction * 2.0 * EnemyBullet.SPEED,
			BossBlueTank.BULLET_TRAVEL_TIME, muzzle.y, false, true)
	guns.muzzle_flash(muzzle, Vector3(t.direction.x, 0.0, t.direction.y), Level3DGuns.TANK_FLASH)
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
		_burn(t, delta)
	for t in _wrecks:
		t.dead_time += delta
		var k := lerpf(1.0, CHAR, clampf(t.dead_time / CHAR_TIME, 0.0, 1.0))
		for pair in t.charred:
			var c: Color = pair[1]
			(pair[0] as StandardMaterial3D).albedo_color = Color(c.r * k, c.g * k, c.b * k, c.a)
		_pose(t, delta)
		_burn(t, delta)


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
	for layer in ["hull", "weapon", "damage"]:
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
		_breach(t)
		if verbose:
			print("boss tank breached (%s) at %.0f, %.0f, tick %d" % [by, t.x, t.y, Engine.get_physics_frames()])
		return
	tanks.remove_at(i)
	var at := t.root.position
	guns.blast.call(at + Vector3.UP * BLAST_HEIGHT, BLAST_SCALE)
	guns.explode(at)
	(t.players.hull as AnimationPlayer).play("Death", 0.05)
	_char(t)
	_wrecks.append(t)
	scored.call(POINTS)
	_destroyed += 1
	if verbose:
		print("boss tank destroyed (%s) at %.0f, %.0f, tick %d" % [by, t.x, t.y, Engine.get_physics_frames()])
		if _destroyed == BossBlueTanksManager.TANKS:
			print("boss: all four destroyed, stage completed")


# The holes torn open: a glow in each, under the tank's root so that it goes
# with it, and a burst of sparks out of each.
func _breach(t: Tank) -> void:
	t.breach_time = 0.0
	t.spark_next.resize(_glow_bones.size())
	for i in _glow_bones.size():
		var glow := MeshInstance3D.new()
		glow.mesh = _glow_mesh
		glow.material_override = _fire_material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.root.add_child(glow)
		t.glows.append(glow)
		t.spark_next[i] = _rng.randf_range(0.5, 1.5) * SPARK_EVERY + GLOW_SETTLE
	_burn(t, 0.0)
	for i in _glow_bones.size():
		for k in BURST_SPARKS:
			_spark(t, i, BURST_SPARK)


# Per rendered frame, once it is breached: each glow put on its hole, flared
# and then flickering, and a spark out of each hole when its time comes.
func _burn(t: Tank, delta: float) -> void:
	if t.breach_time < 0.0:
		return
	t.breach_time += delta
	var flare := 1.0 + (GLOW_FLARE - 1.0) * clampf(1.0 - t.breach_time / GLOW_SETTLE, 0.0, 1.0)
	var grow := smoothstep(0.0, 0.08, t.breach_time)
	for i in t.glows.size():
		var glow := t.glows[i]
		var phase := t.breach_time * 11.0 + i * 2.1
		var flicker := 1.0 + GLOW_FLICKER * (0.6 * sin(phase) + 0.4 * sin(phase * 2.3 + 1.0))
		var r := GLOW_SIZE * SCALE * flare * flicker * grow
		glow.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(r, 0.001)),
				_bone_at(t, _glow_bones[i]))
		glow.set_instance_shader_parameter("age", GLOW_AGE + 0.1 * sin(phase * 0.7))
		t.spark_next[i] -= delta
		if t.spark_next[i] <= 0.0:
			t.spark_next[i] = _rng.randf_range(0.5, 1.5) * SPARK_EVERY
			_spark(t, i, SPARK)


# A spark out of hole `i`: a speck of fire out from the hull and up, falling
# and cooling as it goes, as the jeep's rounds strike off a wall (Level3DGun).
func _spark(t: Tank, i: int, kind: Dictionary) -> void:
	var at := _bone_at(t, _glow_bones[i])
	var off := at - t.root.global_position
	var out := Vector3(off.x, 0.0, off.z).normalized()
	var way := (out + Vector3.UP * 0.7 + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.2, 0.3),
			_rng.randf_range(-0.5, 0.5))).normalized()
	var velocity: Vector3 = way * float(kind.speed) * _rng.randf_range(0.7, 1.2)
	var life: float = float(kind.life) * _rng.randf_range(0.8, 1.2)
	var size: float = float(kind.size) * _rng.randf_range(0.8, 1.2)
	var spark := MeshInstance3D.new()
	spark.mesh = _spark_mesh
	spark.material_override = _fire_material
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark.set_meta("spark", true)
	add_child(spark)
	var fly := func(s: float):
		var k := s / life
		spark.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(size * (1.0 - k), 0.001)),
				at + velocity * s + Vector3.DOWN * SPARK_FALL * s * s)
		spark.set_instance_shader_parameter("age", k)
	fly.call(0.0)
	var tween := spark.create_tween()
	tween.tween_method(fly, 0.0, life, life)
	tween.tween_callback(spark.queue_free)


func _char(t: Tank) -> void:
	for node in t.root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null:
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
