# The bunkers' guns on the 3D stage 1 preview: jackal.RotatingGun, with the
# damage it takes and deals, played on the low-poly stage.
#
# Nothing here is part of the game, but the rules are the game's, taken from
# the port rather than restated -- RotatingGun, Enemy, EnemyBullet, Explosion,
# PlayerBullet, PlayerMissile and Player -- and run the way the game runs them,
# one logic tick per physics frame at 100 Hz, in the game's own units: degrees,
# ticks, pixels. Pixels become level metres through PX, the scale
# level3d_btr.gd sized the BTR by. Map x is level x, map y (down the screen) is
# level z (south), so an angle means the same thing in both.
#
# Stage 1 has fifteen: fourteen GRAY_GUN and one YELLOW_GUN in stage-0.json,
# one on each of the scene's fifteen bunkers (the rows and their order across
# match one to one; the yellow one is BunkerN3_5). Each is
# jackal_dest_BunkerGun.glb from jackal_assets.blend, set on its bunker by the
# preview, with the turret turned and the barrel recoiled from here and the
# destruction played as the stage's buildings' is.
#
# What the game does, and so this:
#   * A gun appears when its trigger row comes to the top of the frame
#     (GameMode._process_triggers): its centre 64 px above the top edge.
#   * It turns towards the player at ROTATION_SPEED a tick, fires when on
#     target, three rounds with a recoil and a pause between, then waits
#     PAUSE_BETWEEN_GROUPS. The yellow one fires faster rounds and cannot turn
#     past 45 degrees either side of south.
#   * Its shot flies BULLET_DISTANCE and stops at anything solid or at the
#     player, who explodes (Player.attack): one shot is a life.
#   * The gun takes three machine-gun rounds (bullet_hits) and one grenade or
#     missile (Enemy.attack), and dies in any explosion but the player's --
#     including another enemy's, so guns next to each other can go together.
#     Its hit box is 40 px either side of its centre; a machine-gun round's is
#     16 and a missile's 21, and the weapon hits when the two overlap anywhere
#     along its
#     flight, not only where it lands.
#   * Driving into it (its mine box, 28 px) blows up both.
#
# Two things the game does that this does not: a gun far behind the camera is
# removed (REMOVE_BOUND) and here it stays, which changes nothing a player can
# see -- its rounds only live inside the frame -- and there is no sound.
class_name Level3DGuns
extends Node3D

const GUN_PATH := "res://resources/3d/jackal_dest_BunkerGun.glb"
const ANIMATION := "Scene"

# A map pixel in level metres: level3d_btr.gd's scale, the hut's 192 px to its
# model's 3.3 m.
const PX := 3.3 / 192.0

# RotatingGun.init()'s boxes, in pixels either side of the centre.
const HIT := 40.0
const MINE := 28.0
const BULLET_HITS := 3
const POINTS := 500
# Where RotatingGun._fire puts a shot, along the barrel.
const MUZZLE := 60.0
# GameMode._process_triggers fires a trigger once its row is one above the top
# row of the frame; for a 4 x 4 gun that is its centre 64 px above the edge.
const SPAWN_ABOVE := 64.0
# Explosion's box grows from a 32 px sprite at GROW_RATE a tick until 128.
const EXPLOSION_START := 32.0
const EXPLOSION_END := 128.0
const EXPLOSION_MARGIN := 0.35

# The height a shot flies at: the barrel's axis on the model.
const ROUND_HEIGHT := 0.83
const ROUND_RADIUS := 0.06
# Where the destruction's blast goes off, and its size: GUN_CENTRE and the
# scale in jackal_bunker_dest.py.
const BLAST_HEIGHT := 0.85
const BLAST_SCALE := 0.7

const STATE_FIRING := 0
const STATE_PAUSED_BETWEEN_FIRING := 1
const STATE_TRACKING := 2

# `frame.call()` is the frame the player sees, as a Rect2 in x, z.
var frame: Callable
# `solid.call(x, z)`: whether a shot stops there (GameMode.is_solid).
var solid: Callable
# `player_attack.call(x, z)`: whether a shot at x, z kills the player
# (Player.attack), who is then the preview's to blow up.
var player_attack: Callable
# `player_position.call()`: the player's x, z.
var player_position: Callable
# `blast.call(at, scale)`: an explosion to be seen at `at`.
var blast: Callable
# `scored.call(points)`.
var scored: Callable
# Prints what happens, for --shot runs.
var verbose := false

var guns: Array[Gun] = []
var _shots := []
var _explosions := []
var _shot_meshes := {}
var _hit_mesh: SphereMesh


class Gun:
	var name: String
	var root: Node3D
	var player: AnimationPlayer
	var turret: Node3D
	var barrel: Node3D
	var barrel_rest: Vector3
	var at: Vector2         # level x, z
	var white := true
	var spawned := false
	var dead := false
	var bullet_hits := BULLET_HITS
	var state := STATE_PAUSED_BETWEEN_FIRING
	var angle := 90.0
	var recoil := 0.0
	var pause := 0
	var group := 0
	var group_size := RotatingGun.GROUP_SIZE
	var recoil_index := 0


func _ready() -> void:
	_hit_mesh = SphereMesh.new()
	_hit_mesh.radial_segments = 5
	_hit_mesh.rings = 2
	_hit_mesh.radius = 1.0
	_hit_mesh.height = 2.0
	_hit_mesh.material = _unshaded(Color(1.0, 0.95, 0.7))
	for white in [true, false]:
		var mesh := SphereMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 3
		mesh.radius = ROUND_RADIUS
		mesh.height = ROUND_RADIUS * 2.0
		mesh.material = _unshaded(Color(1.0, 1.0, 1.0) if white else Color(1.0, 0.85, 0.2))
		_shot_meshes[white] = mesh


# One gun, its model already in the tree and prepared as a destructible is.
func add(gun_name: String, root: Node3D, player: AnimationPlayer, white: bool) -> void:
	var gun := Gun.new()
	gun.name = gun_name
	gun.root = root
	gun.player = player
	gun.white = white
	gun.at = Vector2(root.global_position.x, root.global_position.z)
	gun.turret = root.find_child("Bunker_Turret", true, false)
	gun.barrel = root.find_child("Bunker_Barrel", true, false)
	gun.barrel_rest = gun.barrel.position
	guns.append(gun)
	_reset(gun)


# Every gun back as it was at the start, and nothing in the air.
func reset() -> void:
	for gun in guns:
		_reset(gun)
	for shot in _shots:
		(shot.node as Node3D).queue_free()
	_shots.clear()
	_explosions.clear()


func _reset(gun: Gun) -> void:
	gun.spawned = false
	gun.dead = false
	gun.bullet_hits = BULLET_HITS
	gun.state = STATE_PAUSED_BETWEEN_FIRING
	gun.angle = 90.0
	gun.recoil = 0.0
	gun.pause = 0
	gun.group = 0
	gun.recoil_index = 0
	gun.player.play(ANIMATION)
	gun.player.seek(0.0, true)
	gun.player.pause()
	_pose(gun)


# ----------------------------------------------------------------------------
# The tick

func tick() -> void:
	var view: Rect2 = frame.call()
	for gun in guns:
		if not gun.dead and not gun.spawned and gun.at.y >= view.position.y - SPAWN_ABOVE * PX:
			gun.spawned = true
			if verbose:
				print("gun %s appears" % gun.name)
	# Layer by layer the game updates elements in reverse; within one kind the
	# order only matters to who is hit first, so the guns go as listed.
	for gun in guns:
		if gun.spawned and not gun.dead:
			_update(gun)
			_pose(gun)
	_update_shots(view)
	_update_explosions(view)


# RotatingGun.update, line for line.
func _update(gun: Gun) -> void:
	match gun.state:
		STATE_FIRING:
			gun.recoil_index -= 1
			if gun.recoil_index < 0:
				gun.recoil = 0
				gun.group += 1
				if gun.group == gun.group_size:
					gun.state = STATE_TRACKING
					gun.pause = RotatingGun.PAUSE_BETWEEN_GROUPS
					gun.group = 0
				else:
					gun.state = STATE_PAUSED_BETWEEN_FIRING
					gun.pause = RotatingGun.PAUSE_AFTER_RECOIL
			else:
				gun.recoil = RotatingGun.RECOILS[gun.recoil_index]
		STATE_PAUSED_BETWEEN_FIRING:
			if gun.pause > 0:
				gun.pause -= 1
			else:
				_fire(gun)
		STATE_TRACKING:
			if gun.pause > 0:
				gun.pause -= 1
			var player: Vector2 = player_position.call()
			var target_angle := rad_to_deg(atan2(player.y - gun.at.y, player.x - gun.at.x))
			var delta_angle := fmod(target_angle - gun.angle + 180, 360.0)
			if delta_angle < 0:
				delta_angle += 180
			else:
				delta_angle -= 180
			if absf(delta_angle) < RotatingGun.ROTATION_SPEED:
				gun.angle = target_angle
				if gun.pause == 0:
					_fire(gun)
			else:
				if delta_angle < 0:
					gun.angle -= RotatingGun.ROTATION_SPEED
				else:
					gun.angle += RotatingGun.ROTATION_SPEED
			# Yellow guns are mounted and cannot swing past the horizontal.
			if not gun.white:
				gun.angle = clampf(gun.angle, 45.0, 135.0)


# RotatingGun._fire: a shot from MUZZLE px out along the barrel.
func _fire(gun: Gun) -> void:
	gun.state = STATE_FIRING
	gun.recoil_index = RotatingGun.RECOIL_DURATION - 1
	var a := deg_to_rad(gun.angle)
	var unit := Vector2(cos(a), sin(a))
	var speed := EnemyBullet.SPEED * (1.0 if gun.white else RotatingGun.YELLOW_BULLET_SPEED)
	var node := MeshInstance3D.new()
	node.mesh = _shot_meshes[gun.white]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var shot := {"at": gun.at + unit * MUZZLE * PX, "v": unit * speed * PX,
			"travel": RotatingGun.BULLET_TRAVEL_TIME, "node": node}
	_place_shot(shot)
	_shots.append(shot)


# The model's angle 90 is south: the barrel is modelled along level +z.
func _pose(gun: Gun) -> void:
	gun.turret.rotation.y = deg_to_rad(90.0 - gun.angle)
	gun.barrel.position = gun.barrel_rest + Vector3(0.0, 0.0, -gun.recoil * PX)


# EnemyBullet.update.
func _update_shots(view: Rect2) -> void:
	for i in range(_shots.size() - 1, -1, -1):
		var shot: Dictionary = _shots[i]
		shot.at += shot.v
		var at: Vector2 = shot.at
		if _outside(view, at, EnemyBullet.MARGIN * PX):
			_drop_shot(i, false)
			continue
		shot.travel -= 1
		if shot.travel < 0 or solid.call(at.x, at.y) or player_attack.call(at.x, at.y):
			_drop_shot(i, true)
			continue
		_place_shot(shot)


func _place_shot(shot: Dictionary) -> void:
	(shot.node as Node3D).position = Vector3(shot.at.x, ROUND_HEIGHT, shot.at.y)


# BulletHit where it stopped, a spark that shrinks away.
func _drop_shot(i: int, spark: bool) -> void:
	var shot: Dictionary = _shots[i]
	_shots.remove_at(i)
	var node: MeshInstance3D = shot.node
	if not spark:
		node.queue_free()
		return
	node.mesh = _hit_mesh
	node.position = Vector3(shot.at.x, ROUND_HEIGHT, shot.at.y)
	node.scale = Vector3.ONE * 0.12
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.001, 0.12)
	tween.tween_callback(node.queue_free)


# Explosion.update: a box growing from the centre at GROW_RATE a tick, which
# kills any enemy it overlaps while it is in the frame.
func _update_explosions(view: Rect2) -> void:
	for i in range(_explosions.size() - 1, -1, -1):
		var e: Dictionary = _explosions[i]
		e.size *= Explosion.GROW_RATE
		var margin: float = e.size * EXPLOSION_MARGIN * PX
		var box := Rect2(e.at - Vector2(margin, margin), Vector2(margin, margin) * 2.0)
		if e.damages and view.intersects(box):
			for gun in guns:
				if gun.spawned and not gun.dead and box.intersects(_box(gun, HIT)):
					_destroy(gun, "explosion")
		if e.size > EXPLOSION_END:
			_explosions.remove_at(i)


# ----------------------------------------------------------------------------
# What the player's weapons ask

# The first gun a weapon's flight from `from` to `to` meets, with the weapon's
# own box `margin` px either side: {"t": 0-1 along the line, "gun": index}, or
# empty. `in_frame` is the grenade's and missile's rule: they only attack what
# is on screen.
func intercept(from: Vector3, to: Vector3, margin: float, in_frame := false) -> Dictionary:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var view: Rect2 = frame.call()
	var best := {}
	for i in guns.size():
		var gun := guns[i]
		if not gun.spawned or gun.dead:
			continue
		var box := _box(gun, HIT + margin)
		if in_frame and not view.intersects(box):
			continue
		var t := _segment_enters(a, b, box)
		if t >= 0.0 and (best.is_empty() or t < best.t):
			best = {"t": t, "gun": i}
	return best


# Enemy.bullet_attack: a machine-gun shot arrived at gun `i`.
func bullet_attack(i: int) -> void:
	var gun := guns[i]
	if gun.dead:
		return
	gun.bullet_hits -= 1
	if verbose:
		print("gun %s hit, %d left" % [gun.name, maxi(gun.bullet_hits, 0)])
	if gun.bullet_hits <= 0:
		_destroy(gun, "machine gun")


# Enemy.attack from a grenade or missile: gone at once.
func attack(i: int) -> void:
	if not guns[i].dead:
		_destroy(guns[i], "rocket")


# An Explosion at `at`: the grenade's or missile's at the end of its flight,
# which kills what it grows over.
func explode(at: Vector3) -> void:
	_explosions.append({"at": Vector2(at.x, at.z), "size": EXPLOSION_START, "damages": true})


# Enemy.bump from Player.update: the player's box against every gun's mine
# box. True when the player ran into one and is to explode; a player who is
# invincible neither dies nor destroys it.
func bump(player_box: Rect2, invincible: bool) -> bool:
	if invincible:
		return false
	for gun in guns:
		if gun.spawned and not gun.dead and player_box.intersects(_box(gun, MINE)):
			_destroy(gun, "ran into")
			return true
	return false


# Enemy.do_remove + Explosion + add_points: the destruction played from its
# blast, the preview's blast over it, and an explosion of its own that goes on
# to hit whatever is next to it.
func _destroy(gun: Gun, by: String) -> void:
	gun.dead = true
	gun.recoil = 0.0
	_pose(gun)
	gun.player.play(ANIMATION)
	gun.player.seek(Level3DGuns.blast_start(), true)
	_explosions.append({"at": gun.at, "size": EXPLOSION_START, "damages": true})
	blast.call(Vector3(gun.at.x, BLAST_HEIGHT, gun.at.y), BLAST_SCALE)
	scored.call(POINTS)
	if verbose:
		print("gun %s destroyed (%s)" % [gun.name, by])


# ----------------------------------------------------------------------------

# The destruction's blast frame, F0 = 10 in jackal_bunker_dest.py, as the
# preview's BLAST_START is for the buildings.
static func blast_start() -> float:
	return (10 - 1) / 24.0


func _box(gun: Gun, half: float) -> Rect2:
	var h := half * PX
	return Rect2(gun.at - Vector2(h, h), Vector2(h, h) * 2.0)


static func _outside(view: Rect2, at: Vector2, margin: float) -> bool:
	return not view.intersects(Rect2(at - Vector2(margin, margin), Vector2(margin, margin) * 2.0))


# Where along a -> b the segment first is inside `box`, 0-1, or -1.
static func _segment_enters(a: Vector2, b: Vector2, box: Rect2) -> float:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		var lo: float = box.position[axis]
		var hi: float = box.end[axis]
		if absf(d[axis]) < 1e-9:
			if a[axis] < lo or a[axis] > hi:
				return -1.0
			continue
		var ta: float = (lo - a[axis]) / d[axis]
		var tb: float = (hi - a[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return -1.0
	return t0


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
