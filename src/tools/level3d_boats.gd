# The green boats on the 3D stage 1 preview: jackal.GreenBoat, on
# jackal_boat.glb (jackal_boat_lowpoly.blend).
#
# Nothing here is part of the game, and the rules are the game's, as the
# soldiers' are (level3d_soldiers.gd): stage-0.json's GREEN_BOAT triggers on
# normal -- two, on the river -- spawned as GameMode._process_triggers spawns
# them, run in map pixels and ticks. Their rounds are Level3DGuns' EnemyBullets
# and the explosion they die in is its Explosion.
#
# What the game does, and so this:
#   * A boat appears when its trigger row comes to the top of the frame, at
#     (72, 56) px into the trigger's corner.
#   * It drifts down the river, down and to the left, 0.75 px a tick on each
#     axis for 181 ticks, and then holds where it is.
#   * From its first tick on it fires a white round at the player every 92
#     ticks, which flies for 182.
#   * It takes six machine-gun rounds and one grenade or missile, and dies in
#     any explosion but the player's own (Enemy.attack); its hit box is 40 px
#     either side. It is neither solid nor a mine: the player drives through it
#     -- which on the river it cannot anyway. 800 points.
#
# Where this departs from the game, and why:
#   * It fires from the muzzle, at the player, not from (-16, +16) px of its
#     centre, the sprite's gun: the turret stands 1.6 m aft of the model's
#     centre and the muzzle 2.2 m out from the turret's axis, both scaled.
#   * The sprite's two frames are the wake; here the clips say what it does --
#     Move while it drifts, Idle when it holds, Damage on a hit that does not
#     sink it -- and Shoot, the barrel's recoil and the flash, plays over
#     whichever of them is on, on a player of its own: the clips come in two
#     layers that key no bone in common (jackal_boat.py), so a round never
#     starts the hull's motion over. The turret is keyed by no clip; it turns
#     to the player from here, which the sprite's cannot.
#   * The game removes it and draws an Explosion. Here the blast is drawn over
#     it and it plays Death underneath, rolls over and sinks, before it goes.
class_name Level3DBoats
extends Node3D

const BOAT_PATH := "res://resources/3d/jackal_boat.glb"
const PX := Level3DMap.PX
# The model is an 8 m boat; the sprite's hull is some 150 px long, 2.2 m on
# the level's scale. A little over that, so the turret reads from above.
const SCALE := 0.3
const HIT := 40.0
const POINTS := 800
const TRIGGER_OFFSET := Vector2(72, 56)
# The sprite's heading: down the screen and to the left, the way it drifts.
const HEADING := Vector2(-1.0, 1.0)
# The turret's pivot, and the muzzle from it with the barrel run out, in the
# model's metres and axes (bow +z): jackal_boat.py's TURRET_AT, GUN_AT and the
# Flash bone, 1.73 m down the barrel.
const TURRET_PIVOT := Vector3(0.0, 1.35, -1.6)
const MUZZLE_FROM_TURRET := Vector3(0.0, 0.71, 0.45 + 1.73)
const TURRET_TURN := 3.0      # rad/s: fast enough to be on the player by its next round
const BLAST_HEIGHT := 0.4
const BLAST_SCALE := 0.8
const IDLE := "Idle"
const MOVE := "Move"
const SHOOT := "Shoot"
const DAMAGE := "Damage"
const DEATH := "Death"
const LOOPS := ["Idle", "Move", "Turn_L", "Turn_R"]
const HULL_CLIPS := ["Idle", "Move", "Turn_L", "Turn_R", "Damage", "Death"]
# The bones of each layer (jackal_boat.py's HULL_BONES and WEAPON_BONES).
const HULL_BONES := ["Root", "Motor.R", "Motor.L"]
const WEAPON_BONES := ["Gun", "Barrel", "Flash"]
const BLEND := 0.25

var map: Level3DMap
var guns: Level3DGuns
# `frame.call()`: the frame the player sees, Rect2 in level x, z.
var frame: Callable
# `ground.call(x, z)`: {"height": ...} as the preview's -- the water, here.
var ground: Callable
# `player_position.call()`: the player's level x, z.
var player_position: Callable
var scored: Callable
var verbose := false

var boats: Array[Boat] = []
var _wrecks: Array[Boat] = []
var _scene: PackedScene
var _hull_clips: AnimationLibrary
var _weapon_clips: AnimationLibrary
var _trigger_y := -1
var _furthest_top := INF


class Boat:
	var x: float            # map pixels
	var y: float
	var movement_delay := GreenBoat.MOVEMENT_TIME
	var bullet_delay := 0
	var bullet_hits := 6
	var turret_yaw := 0.0   # radians from the bow, as the turret is drawn
	var aim_yaw := 0.0      # where the player is, the same way
	var sink_left := 0.0
	var root: Node3D
	var player: AnimationPlayer     # the hull's clips
	var weapon: AnimationPlayer     # Shoot
	var skeleton: Skeleton3D
	var turret_bone := -1


func _ready() -> void:
	_scene = load(BOAT_PATH)
	if _scene == null:
		push_error("Cannot load %s -- run export() in jackal_boat_lowpoly.blend" % BOAT_PATH)
		return
	_make_libraries()
	reset()


# The two layers' clips, shared by every boat. The glTF export gives every clip
# a track for every bone any clip moves, holding it at rest where the clip does
# not -- so Shoot would pin the hull and Idle the barrel. Each clip keeps only
# its own layer's bones here.
func _make_libraries() -> void:
	var probe := _scene.instantiate()
	var imported := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_hull_clips = AnimationLibrary.new()
	_weapon_clips = AnimationLibrary.new()
	for clip in HULL_CLIPS + [SHOOT]:
		var a := imported.get_animation(clip).duplicate() as Animation
		var keep: Array = WEAPON_BONES if clip == SHOOT else HULL_BONES
		for i in range(a.get_track_count() - 1, -1, -1):
			if str(a.track_get_path(i).get_concatenated_subnames()) not in keep:
				a.remove_track(i)
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPS else Animation.LOOP_NONE
		(_weapon_clips if clip == SHOOT else _hull_clips).add_animation(clip, a)
	probe.free()


func reset() -> void:
	for b in boats + _wrecks:
		b.root.queue_free()
	boats.clear()
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
	for i in range(boats.size() - 1, -1, -1):
		var b := boats[i]
		_update(b, player)
		# Enemy.check_bounds, on its hit box: it is not solid.
		if b.y - HIT > _furthest_top + Level3DSoldiers.CAMERA_BOUND + Level3DSoldiers.REMOVE_BOUND:
			b.root.queue_free()
			boats.remove_at(i)


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
			if t[0] == Triggers.GREEN_BOAT:
				_spawn(t[1] + TRIGGER_OFFSET.x, t[2] + TRIGGER_OFFSET.y)


func _spawn(x: float, y: float) -> void:
	var b := Boat.new()
	b.x = x
	b.y = y
	b.root = _scene.instantiate() as Node3D
	b.root.scale = Vector3.ONE * SCALE
	b.root.rotation.y = atan2(HEADING.x, HEADING.y)
	add_child(b.root)
	_split_players(b)
	b.skeleton = b.root.find_child("Skeleton3D", true, false) as Skeleton3D
	b.turret_bone = b.skeleton.find_bone("Turret")
	b.player.play(MOVE)
	# On the player from the start: it fires on its first tick.
	_aim(b, Level3DMap.to_map(player_position.call()))
	b.turret_yaw = b.aim_yaw
	boats.append(b)
	_place(b)
	if verbose:
		print("boat appears at %.0f, %.0f" % [x, y])


# The imported player split in two, one for each layer's library: a player
# resets every track its library has, so one that held both would undo the
# other's. Both are advanced by hand in _process, the turret turned after
# them, before the frame is drawn.
func _split_players(b: Boat) -> void:
	var imported := b.root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	b.player = imported
	b.weapon = AnimationPlayer.new()
	imported.get_parent().add_child(b.weapon)
	b.weapon.root_node = b.weapon.get_path_to(imported.get_node(imported.root_node))
	b.player.remove_animation_library("")
	b.player.add_animation_library("", _hull_clips)
	b.weapon.add_animation_library("", _weapon_clips)
	for p in [b.player, b.weapon]:
		p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Out of a hit, back to whatever it is doing; blended, as it comes out
	# from under a knock rather than jumping to the loop's first frame.
	b.player.animation_finished.connect(func(clip: StringName):
		if clip == DAMAGE:
			b.player.play(_base(b), BLEND))
	# Shoot's last frame is the gun at rest with no flash: held there until
	# the first round.
	b.weapon.play(SHOOT)
	b.weapon.seek(b.weapon.current_animation_length, true)


# GreenBoat.update.
func _update(b: Boat, player: Vector2) -> void:
	if b.movement_delay > 0:
		b.movement_delay -= 1
		b.x -= GreenBoat.SPEED
		b.y += GreenBoat.SPEED
		if b.movement_delay == 0:
			_settle(b, IDLE)
	_place(b)
	_aim(b, player)
	b.bullet_delay -= 1
	if b.bullet_delay < 0:
		b.bullet_delay = GreenBoat.BULLET_DELAY
		_fire(b, player)


# Where the turret is to point: the player, as a yaw from the bow.
func _aim(b: Boat, player: Vector2) -> void:
	var to := player - Vector2(b.x, b.y)
	b.aim_yaw = wrapf(atan2(to.x, to.y) - b.root.rotation.y, -PI, PI)


# The muzzle in level metres, the turret as it is drawn: the round comes out of
# the barrel, and flies from there at the player.
func _muzzle(b: Boat) -> Vector3:
	var local := TURRET_PIVOT + MUZZLE_FROM_TURRET.rotated(Vector3.UP, b.turret_yaw)
	return b.root.global_transform * local


func _fire(b: Boat, player: Vector2) -> void:
	var muzzle := _muzzle(b)
	var at := Vector2(muzzle.x, muzzle.z)
	var d := (Level3DMap.to_level(player) - at).normalized()
	guns.enemy_bullet(at, d * EnemyBullet.SPEED, GreenBoat.BULLET_TRAVEL_TIME, muzzle.y, true)
	b.weapon.play(SHOOT)
	b.weapon.seek(0.0, true)
	if verbose:
		print("boat fires from %.2f, %.2f, %.2f" % [muzzle.x, muzzle.y, muzzle.z])


# What it plays when it is doing nothing else: drifting or holding.
func _base(b: Boat) -> String:
	return MOVE if b.movement_delay > 0 else IDLE


# Over to `clip` now if a loop is on; a hit plays out first and comes back
# to _base by itself.
func _settle(b: Boat, clip: String) -> void:
	if b.player.current_animation in LOOPS:
		b.player.play(clip, BLEND)


func _place(b: Boat) -> void:
	var at := Level3DMap.to_level(Vector2(b.x, b.y))
	var height: float = ground.call(at.x, at.y).height
	b.root.position = Vector3(at.x, height, at.y)


# Per rendered frame: the clips, then the turret over them, turning towards
# the player -- or, for a wreck, left where it was when the boat was hit.
func _process(delta: float) -> void:
	for b in boats:
		b.turret_yaw = rotate_toward(b.turret_yaw, b.aim_yaw, TURRET_TURN * delta)
		_pose(b, delta)
	for i in range(_wrecks.size() - 1, -1, -1):
		var b := _wrecks[i]
		_pose(b, delta)
		b.sink_left -= delta
		if b.sink_left <= 0.0:
			b.root.queue_free()
			_wrecks.remove_at(i)


func _pose(b: Boat, delta: float) -> void:
	b.player.advance(delta)
	b.weapon.advance(delta)
	b.skeleton.set_bone_pose_rotation(b.turret_bone, Quaternion(Vector3.UP, b.turret_yaw))


# ----------------------------------------------------------------------------
# Dying

# Enemy.do_remove + Explosion + add_points: the blast over it, an Explosion
# that goes on to hit what is next to it, and Death played underneath.
func _kill(i: int, by: String) -> void:
	var b := boats[i]
	boats.remove_at(i)
	var at := Level3DMap.to_level(Vector2(b.x, b.y))
	var height: float = ground.call(at.x, at.y).height
	guns.blast.call(Vector3(at.x, height + BLAST_HEIGHT, at.y), BLAST_SCALE)
	guns.explode(Vector3(at.x, height, at.y))
	b.player.play(DEATH, 0.05)
	b.sink_left = b.player.get_animation(DEATH).length
	_wrecks.append(b)
	scored.call(POINTS)
	if verbose:
		print("boat sunk (%s) at %.0f, %.0f, tick %d" % [by, b.x, b.y, Engine.get_physics_frames()])


func _hit_box(b: Boat, margin: float) -> Rect2:
	var h := HIT + margin
	var box := Rect2(Vector2(b.x - h, b.y - h), Vector2(h, h) * 2.0)
	return Rect2(Level3DMap.to_level(box.position), box.size * PX)


# The first boat a weapon's flight from `from` to `to` meets, its box grown by
# the weapon's `margin` px: {"t", "boat"} or empty. `in_frame` is the grenade's
# and missile's rule, as Level3DGuns.intercept's.
func intercept(from: Vector3, to: Vector3, margin: float, in_frame := false) -> Dictionary:
	var view: Rect2 = frame.call()
	var best := {}
	for b in boats:
		var box := _hit_box(b, margin)
		if in_frame and not view.intersects(box):
			continue
		var t := Level3DGuns._segment_enters(Vector2(from.x, from.z), Vector2(to.x, to.z), box)
		if t >= 0.0 and (best.is_empty() or t < best.t):
			best = {"t": t, "boat": b}
	return best


# Enemy.bullet_attack: six rounds, and the ones before the sixth knock it about.
func bullet_attack(found: Dictionary) -> void:
	var i := boats.find(found.boat)
	if i < 0:
		return
	var b := boats[i]
	b.bullet_hits -= 1
	if b.bullet_hits <= 0:
		_kill(i, "machine gun")
		return
	if verbose:
		print("boat hit, %d left" % b.bullet_hits)
	if b.player.current_animation != DAMAGE:
		b.player.play(DAMAGE, 0.05)


# Enemy.attack from a grenade or missile: gone at once.
func attack(found: Dictionary) -> void:
	var i := boats.find(found.boat)
	if i >= 0:
		_kill(i, "rocket")


# An Explosion's box this tick (Level3DGuns): any boat in it sinks, unless the
# explosion is the player's.
func explosion_hit(box: Rect2, player: bool) -> void:
	if player:
		return
	for i in range(boats.size() - 1, -1, -1):
		if box.intersects(_hit_box(boats[i], 0.0)):
			_kill(i, "explosion")
