# The bunkers' guns on the 3D stage 1 preview: jackal.RotatingGun, with the
# damage it takes and deals, played on the low-poly stage.
#
# Nothing here is part of the game, but the rules are the game's, taken from
# the port rather than restated -- RotatingGun, Enemy, EnemyBullet, Explosion,
# PlayerBullet, PlayerMissile and Player -- and run the way the game runs them,
# one logic tick per physics frame at 100 Hz, in the game's own units: degrees,
# ticks, pixels. Pixels become level metres through Level3DMap.PX, the scale the
# level itself is on. Map x is level x, map y (down the screen) is level z
# (south), so an angle means the same thing in both.
#
# Three of the game's elements live here for every enemy, not only the guns:
# EnemyBullet (enemy_bullet), Explosion (explode), which the soldiers
# (level3d_soldiers.gd) fire and die in too, and TravelingExplosion (travel),
# the blasts an upgraded missile throws along the screen's axes.
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

# A map pixel in level metres (Level3DMap).
const PX := Level3DMap.PX

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
# A shot is the game's own sprite, EnemyBullet's white or yellow, turned to
# the camera at the game's size: 24 px across, a white core in a grey or
# yellow ring in a black one. A small white ball, as it was, was lost on the
# sand; the black ring is what makes it read, there as in the game.
const ROUND_SPRITES := {true: "white-bullet.png", false: "yellow-bullet.png"}
# The gun's flash. RotatingGun has none -- its second sprite is the barrel run
# back, nothing more -- but the 3D gun's round leaves from a muzzle that was
# otherwise dark: a star of fire along the shot for FLASH_TIME, and a wisp.
const FLASH_TIME := 0.07
const FLASH_LENGTH := 0.6
const FLASH_WIDTH := 0.3
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
# `explosion_hit.call(box)`: an explosion's box this tick, as a Rect2 in x, z,
# for the other enemies it may kill; `player` is whether it is the player's.
var explosion_hit: Callable
# `travel_hit.call(box)`: a TravelingExplosion's box this tick, for what it
# takes down that an Explosion's box does not here -- the preview's barracks
# and hangars, which are Hut and House (both fall to one).
var travel_hit: Callable
var blast: Callable
# `scored.call(points)`.
var scored: Callable
# Prints what happens, for --shot runs.
var verbose := false

var guns: Array[Gun] = []
var _shots := []
var _explosions := []
var _travels := []
var _shot_textures := {}
var _hit_mesh: SphereMesh
var _flash_mesh: SphereMesh
var _flash_core: SphereMesh
var _wisp_mesh: SphereMesh


class Gun:
	var name: String
	var root: Node3D
	var player: AnimationPlayer
	var turret: Node3D
	var barrel: Node3D
	var barrel_rest: Vector3
	var at: Vector2         # level x, z
	# The bunker's own target bodies, off while the gun is there (see add).
	var base_bodies: Array = []
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
	var bank := SpriteBank.new(Main.SPRITES)
	for white in ROUND_SPRITES:
		var sprite := bank.get_sprite(ROUND_SPRITES[white])
		var texture := AtlasTexture.new()
		texture.atlas = sprite.tex
		texture.region = sprite.region
		_shot_textures[white] = texture
	_flash_mesh = _ball(Color(1.0, 0.72, 0.22))
	_flash_core = _ball(Color(1.0, 0.95, 0.7))
	_wisp_mesh = SphereMesh.new()
	_wisp_mesh.radial_segments = 6
	_wisp_mesh.rings = 3
	_wisp_mesh.radius = 1.0
	_wisp_mesh.height = 2.0
	var wisp := StandardMaterial3D.new()
	wisp.albedo_color = Color(0.5, 0.48, 0.45)
	wisp.roughness = 1.0
	_wisp_mesh.material = wisp


# One gun, its model already in the tree and prepared as a destructible is.
# `base_bodies` are its bunker's target bodies, [body, layer] pairs: in the
# game the bunker is empty tiles and a round flies over it to the gun's box,
# so while the gun stands they are off -- the base's front face is further out
# than the gun's box reaches, and would take every round. Once it is gone they
# are on again, and rounds chip at the ruin.
func add(gun_name: String, root: Node3D, player: AnimationPlayer, white: bool,
		base_bodies: Array = []) -> void:
	var gun := Gun.new()
	gun.name = gun_name
	gun.root = root
	gun.player = player
	gun.white = white
	gun.at = Vector2(root.global_position.x, root.global_position.z)
	gun.turret = root.find_child("Bunker_Turret", true, false)
	gun.barrel = root.find_child("Bunker_Barrel", true, false)
	gun.barrel_rest = gun.barrel.position
	gun.base_bodies = base_bodies
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
	_travels.clear()


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
	_base_solid(gun, false)


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
	_update_travels(view)


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
	var muzzle := gun.at + unit * MUZZLE * PX
	enemy_bullet(muzzle, unit * speed, RotatingGun.BULLET_TRAVEL_TIME, ROUND_HEIGHT, gun.white)
	_muzzle_flash(Vector3(muzzle.x, ROUND_HEIGHT, muzzle.y), Vector3(unit.x, 0.0, unit.y))


# A flash at a gun's muzzle, long along `direction`, for FLASH_TIME: fire
# round a hot core, the core standing up out of it so that it shows from
# above. Then a wisp of smoke drifts off where it was.
func _muzzle_flash(at: Vector3, direction: Vector3) -> void:
	var along := Basis.looking_at(direction, Vector3.UP)
	var ahead := at + direction * FLASH_LENGTH * 0.4
	for layer in [[_flash_mesh, 1.0, 0.0], [_flash_core, 0.6, FLASH_WIDTH * 0.35]]:
		var node := MeshInstance3D.new()
		node.mesh = layer[0]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		var size: float = layer[1]
		# The ball's -Z is looking_at's forward: long that way.
		var shape := Vector3(FLASH_WIDTH, FLASH_WIDTH, FLASH_LENGTH) * 0.5 * size
		node.global_transform = Transform3D(along.scaled_local(shape), ahead + Vector3.UP * layer[2])
		get_tree().create_timer(FLASH_TIME, false, true).timeout.connect(node.queue_free)
	var wisp := MeshInstance3D.new()
	wisp.mesh = _wisp_mesh
	wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wisp.visible = false
	add_child(wisp)
	wisp.global_position = ahead
	wisp.scale = Vector3.ONE * 0.04
	var tween := wisp.create_tween()
	tween.tween_interval(FLASH_TIME)
	tween.tween_callback(wisp.show)
	tween.set_parallel()
	tween.tween_property(wisp, "scale", Vector3.ONE * 0.12, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(wisp, "global_position", ahead + direction * 0.15 + Vector3.UP * 0.3, 0.45)
	tween.tween_property(wisp, "scale", Vector3.ONE * 0.001, 0.3).set_delay(0.15).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(wisp.queue_free)


# An EnemyBullet at `at` (level x, z), moving `v` map pixels a tick for
# `travel` ticks, drawn `height` above the ground: white or yellow.
func enemy_bullet(at: Vector2, v: Vector2, travel: int, height: float, white := true) -> void:
	var node := Sprite3D.new()
	node.texture = _shot_textures[white]
	node.pixel_size = PX
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.shaded = false
	node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var shot := {"at": at, "v": v * PX, "travel": travel, "node": node, "height": height}
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
	(shot.node as Node3D).position = Vector3(shot.at.x, shot.height, shot.at.y)


# BulletHit where it stopped, a spark that shrinks away.
func _drop_shot(i: int, spark: bool) -> void:
	var shot: Dictionary = _shots[i]
	_shots.remove_at(i)
	(shot.node as Node3D).queue_free()
	if not spark:
		return
	var node := MeshInstance3D.new()
	node.mesh = _hit_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = Vector3(shot.at.x, shot.height, shot.at.y)
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
			# Enemy.attack spares everything from the player's own explosion;
			# EnemySoldier.attack does not look at where it came from.
			if not e.player:
				for gun in guns:
					if gun.spawned and not gun.dead and box.intersects(_box(gun, HIT)):
						_destroy(gun, "explosion")
			if explosion_hit.is_valid():
				explosion_hit.call(box, e.player)
		if e.size > EXPLOSION_END:
			_explosions.remove_at(i)


# TravelingExplosion.update: a box that runs VELOCITY a tick along one of the
# screen's axes for TRAVEL_TIME ticks, shrinking in three steps, and kills any
# enemy it overlaps while it is in the frame. Nothing stops it: it goes over
# walls and water alike.
func _update_travels(view: Rect2) -> void:
	for i in range(_travels.size() - 1, -1, -1):
		var e: Dictionary = _travels[i]
		e.at += e.velocity
		e.t += 1
		if e.t > TravelingExplosion.TRAVEL_TIME:
			_travels.remove_at(i)
			continue
		var margin := traveling_margin(e.t) * PX
		var box := Rect2(e.at - Vector2(margin, margin), Vector2(margin, margin) * 2.0)
		if not view.intersects(box):
			continue
		for gun in guns:
			if gun.spawned and not gun.dead and box.intersects(_box(gun, HIT)):
				_destroy(gun, "traveling explosion")
		if explosion_hit.is_valid():
			explosion_hit.call(box, false)
		if travel_hit.is_valid():
			travel_hit.call(box)


# TravelingExplosion's box, in px either side of its centre, `t` ticks out.
static func traveling_margin(t: int) -> float:
	if t < TravelingExplosion.PERIOD0:
		return 28.0 * traveling_scale(t)
	if t < TravelingExplosion.PERIOD1:
		return 18.0 * traveling_scale(t)
	return 16.0 * traveling_scale(t)


# TravelingExplosion's drawn scale `t` ticks out: big at once, then smaller in
# each of its three periods.
static func traveling_scale(t: int) -> float:
	if t < TravelingExplosion.PERIOD0:
		return 2.25 - t * TravelingExplosion.K0
	if t < TravelingExplosion.PERIOD1:
		return 1.75 - (t - TravelingExplosion.PERIOD0) * TravelingExplosion.K1
	return 1.333 - (t - TravelingExplosion.PERIOD1) * TravelingExplosion.K2


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
# which kills what it grows over, or with `player` the player's own, which only
# a soldier dies in.
func explode(at: Vector3, player := false) -> void:
	_explosions.append({"at": Vector2(at.x, at.z), "size": EXPLOSION_START, "damages": true, "player": player})


# A TravelingExplosion from `at` along `direction`, one of the screen's axes
# as a map direction: (+-1, 0) across, (0, +-1) down or up.
func travel(at: Vector3, direction: Vector2) -> void:
	_travels.append({"at": Vector2(at.x, at.z), "t": 0,
			"velocity": direction * TravelingExplosion.VELOCITY * PX})


# RotatingGun's solid box, 64 px either side: what the soldiers walk round.
# Level x, z.
func solid_boxes() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for gun in guns:
		if gun.spawned and not gun.dead:
			boxes.append(_box(gun, 64.0))
	return boxes


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
	_base_solid(gun, true)
	_pose(gun)
	gun.player.play(ANIMATION)
	gun.player.seek(Level3DGuns.blast_start(), true)
	_explosions.append({"at": gun.at, "size": EXPLOSION_START, "damages": true, "player": false})
	blast.call(Vector3(gun.at.x, BLAST_HEIGHT, gun.at.y), BLAST_SCALE)
	scored.call(POINTS)
	if verbose:
		print("gun %s destroyed (%s)" % [gun.name, by])


func _base_solid(gun: Gun, on: bool) -> void:
	for pair in gun.base_bodies:
		(pair[0] as CollisionObject3D).collision_layer = pair[1] if on else 0


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


# A unit ball, low poly, in one unshaded colour.
static func _ball(colour: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.material = _unshaded(colour)
	return mesh
