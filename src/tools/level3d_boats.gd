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
#     centre, the sprite's gun.
#   * The sprite's two frames are the wake; here the clips say what it does --
#     Move while it drifts, Idle when it holds, Shoot on a round, Damage on a
#     hit that does not sink it -- and the turret turns to the player, which the
#     sprite's cannot.
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
# The muzzle over the waterline, and the turret's pivot, in the model's metres.
const MUZZLE_HEIGHT := 2.06
const TURRET_TURN := 3.0      # rad/s: fast enough to be on the player by its next round
const BLAST_HEIGHT := 0.4
const BLAST_SCALE := 0.8
const IDLE := "Idle"
const MOVE := "Move"
const SHOOT := "Shoot"
const DAMAGE := "Damage"
const DEATH := "Death"
const LOOPS := ["Idle", "Move", "Turn_L", "Turn_R"]
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
	var player: AnimationPlayer
	var skeleton: Skeleton3D
	var turret_bone := -1


func _ready() -> void:
	_scene = load(BOAT_PATH)
	if _scene == null:
		push_error("Cannot load %s -- run export() in jackal_boat_lowpoly.blend" % BOAT_PATH)
		return
	# The loops come out without their loop mode; shared by every boat, so set once.
	var probe := _scene.instantiate()
	var clips := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in LOOPS:
		clips.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	probe.free()
	reset()


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
	b.player = b.root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Advanced by hand in _process, so that the turret can be turned after the
	# clip has posed it and before the frame is drawn.
	b.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	b.skeleton = b.root.find_child("Skeleton3D", true, false) as Skeleton3D
	b.turret_bone = b.skeleton.find_bone("Turret")
	b.player.play(MOVE)
	boats.append(b)
	_place(b)
	if verbose:
		print("boat appears at %.0f, %.0f" % [x, y])


# GreenBoat.update.
func _update(b: Boat, player: Vector2) -> void:
	if b.movement_delay > 0:
		b.movement_delay -= 1
		b.x -= GreenBoat.SPEED
		b.y += GreenBoat.SPEED
		if b.movement_delay == 0:
			_settle(b, IDLE)
	b.bullet_delay -= 1
	if b.bullet_delay < 0:
		b.bullet_delay = GreenBoat.BULLET_DELAY
		_fire(b, player)
	var to := player - Vector2(b.x, b.y)
	b.aim_yaw = wrapf(atan2(to.x, to.y) - b.root.rotation.y, -PI, PI)
	_place(b)


func _fire(b: Boat, player: Vector2) -> void:
	var at := Level3DMap.to_level(Vector2(b.x, b.y))
	var d := (player - Vector2(b.x, b.y)).normalized()
	var height: float = ground.call(at.x, at.y).height + MUZZLE_HEIGHT * SCALE
	guns.enemy_bullet(at, d * EnemyBullet.SPEED, GreenBoat.BULLET_TRAVEL_TIME, height, true)
	b.player.play(SHOOT, 0.05)
	b.player.queue(_base(b))
	if verbose:
		print("boat fires from %.0f, %.0f" % [b.x, b.y])


# What it plays when it is doing nothing else: drifting or holding.
func _base(b: Boat) -> String:
	return MOVE if b.movement_delay > 0 else IDLE


# Back to `clip` once a one-shot has played out, or at once if a loop is on.
func _settle(b: Boat, clip: String) -> void:
	if b.player.current_animation in LOOPS:
		b.player.play(clip, BLEND)
	else:
		b.player.clear_queue()
		b.player.queue(clip)


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
	var q := b.skeleton.get_bone_pose_rotation(b.turret_bone)
	b.skeleton.set_bone_pose_rotation(b.turret_bone, Quaternion(Vector3.UP, b.turret_yaw) * q)


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
	b.player.clear_queue()
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
		b.player.clear_queue()
		b.player.queue(_base(b))


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
