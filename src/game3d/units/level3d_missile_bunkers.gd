# The missile bunkers on the 3D preview: jackal.CliffMissileLauncher and the
# homing jackal.SwampMissile it fires, on jackal_missile_bunker.glb
# (jackal_missile_bunker_lowpoly.blend). The statues that home on the jeep in
# the game, made a blockhouse that raises a launcher out of its roof.
#
# Nothing here is part of the game; the rules are the game's where it has
# them, in map pixels and ticks as the tanks' are (level3d_tanks.gd): its
# CLIFF_MISSILE_LAUNCHER triggers -- none on stage 1, which has no enemy that
# fires missiles; a level file of its own puts them down (polygon.json) --
# spawned as GameMode._process_triggers spawns them. The explosions it and
# its missiles go off in are Level3DGuns' Explosion.
#
# What the game does, and so this:
#   * The launcher is ready once its launch point is in the frame
#     (isOutsideOfFrame), and from then on launches a SwampMissile every
#     LAUNCH_DELAY ticks.
#   * The missile leaves straight for ENTRY_DELAY ticks, then turns towards
#     the player, ROTATION_SPEED degrees a tick at most, at SPEED px a tick,
#     over walls and water alike. After EXPLODE_DELAY ticks it goes off in a
#     tiny Explosion; far off the frame (REMOVE_MARGIN) it is simply gone.
#   * One machine-gun round, a grenade or a missile, any Explosion but the
#     player's own and a TravelingExplosion destroy it (bulletHits 1, attack).
#     Its hit box is 26 px either side.
#   * It is a mine: the player's box (Player.update's) over its 8 px box sets
#     it off and blows the player up, unless the player cannot be hit.
#   * The launcher dies to the player's weapon and to a TravelingExplosion,
#     not to other explosions; 2000 points.
#
# Where this departs from the game, and why:
#   * The game draws the launcher a frame on a cliff and fires from it at
#     once. Here a launch takes its time, and shows it: the warning lamps
#     flash for WARN_TICKS (as the statues' eyes flash before their mouths
#     open), the cupola opens, the lift raises the launcher, the turntable
#     comes round to the player and the rails elevate -- the model's
#     deploy(), done here (_pose) -- then the missile leaves and the launcher
#     goes back down. One missile a cycle, of the three on the rails, all
#     three back when it is down; a cycle is about LAUNCH_DELAY long, a little
#     longer than the game's.
#   * The missile leaves along the rails, up off them, and comes down to
#     CRUISE over the ground while it flies straight, then holds that height.
#   * Machine-gun rounds: the game's launcher takes ten (bulletHits). Here the
#     shut cupola is armour and takes none; open, it takes BULLET_HITS.
#   * It is solid, a 4 x 4 block of tiles (Level3DMap.reset): the game's
#     stands on a cliff, which is.
#   * The game removes it; here, as for the guns' bunkers, the blockhouse
#     stays and the destruction is played on it: the cupola and the launcher
#     blown off, debris and soot (the glb's clip, from its blast, F0).
class_name Level3DMissileBunkers
extends Node3D

const MODEL_PATH := "res://resources/3d/jackal_missile_bunker.glb"
const ANIMATION := "Scene"
const PX := Level3DMap.PX
const PREFIX := "MissileBunker_"

# The trigger is 4 x 4 tiles (trigger-sizes.json); the plinth, 5.9 m across
# its faces (jackal_missile_bunker.py, PLINTH), is drawn that wide.
const FOOTPRINT := 128.0
const MODEL_ACROSS := 5.9
const SCALE := FOOTPRINT * PX / MODEL_ACROSS
# Its hit box, px either side of its middle: the whole block, so that the
# box with a weapon's margin reaches out past the solid tiles, which would
# otherwise stop a round before it got there.
const HIT := 64.0
const BULLET_HITS := 10
const POINTS := 2000
# CliffMissileLauncher.LAUNCH_DELAY: a missile every this many ticks.
const LAUNCH_DELAY := 3 * 91
const FIRST_DELAY := 60
const BLAST_HEIGHT := 0.6
const BLAST_SCALE := 1.1

# The cycle, ticks: the lamps flashing, deploy() from down to up, up and
# coming round before the launch, up after it, and back down.
const WARN_TICKS := 70
const DEPLOY_TICKS := 90
const AIM_TICKS := 30
const HOLD_TICKS := 30
const FLASH_PERIOD := 16
# jackal_missile_bunker.py's deploy(): its phases and travels.
const LID_PHASE := 0.3
const RISE_PHASE := 0.65
const LID_OPEN := deg_to_rad(100.0)
const LIFT_TRAVEL := 1.35
const ELEVATION := deg_to_rad(35.0)
# How fast the turntable comes round, radians a tick.
const AIM_RATE := deg_to_rad(2.5)

# SwampMissile.
const SPEED := 4.0
const ROTATION_SPEED := 0.9
const ENTRY_DELAY := 45
const EXPLODE_DELAY := 8 * 91
const REMOVE_MARGIN := 336.0
const MISSILE_HIT := 26.0
const MISSILE_MINE := 8.0
# The height it comes down to over the ground, level metres, and its blast.
const CRUISE := 0.4
const MISSILE_BLAST := 0.5
const TRAIL_EVERY := 2

# The warning lamps' glass, lit.
const BEACON_MATERIAL := "MissileBunker_Beacon"
const BEACON_LIT := Color(1.0, 0.18, 0.08)
const BEACON_ENERGY := 3.0
const LIGHT_ENERGY := 0.5
const LIGHT_RANGE := 2.0

enum { REST, WARN, OPENING, AIMING, HOLDING, CLOSING }

var map: Level3DMap
var guns: Level3DGuns
# `frame.call()`: the frame the player sees, Rect2 in level x, z.
var frame: Callable
# `ground.call(x, z)`: {"height": ...} as the preview's.
var ground: Callable
# `player_position.call(from)`: the level x, z of the player nearest `from`.
var player_position: Callable
var scored: Callable
# `trail.call(at)`: a puff of a rocket's smoke trail (Level3DLauncher.trail).
var trail: Callable
var verbose := false

var bunkers: Array[Bunker] = []
var missiles: Array[Missile] = []
var _scene: PackedScene
var _trigger_y := -1
var _lit: StandardMaterial3D


class Bunker:
	var x := 0.0          # map px, its middle
	var y := 0.0
	var root: Node3D
	var player: AnimationPlayer
	var parts := {}       # deploy()'s nodes by their names less the prefix
	var rest := {}        # their transforms as the glb has them, launcher down
	var glass: Array = [] # [MeshInstance3D, surface] of the warning lamps
	var light: OmniLight3D
	var state := REST
	var wait := FIRST_DELAY
	var deployed := 0.0
	var aim := 0.0        # the turntable's yaw, radians, + to its left
	var ready := false
	var dead := false
	var bullet_hits := BULLET_HITS
	var next_round := 0


class Missile:
	var x := 0.0          # map px
	var y := 0.0
	var angle := 0.0      # degrees, map axes
	var height := 0.0     # level metres over the ground
	var from_height := 0.0
	var ticks := 0
	var node: Node3D


func _ready() -> void:
	_scene = load(MODEL_PATH)
	if _scene == null:
		push_error("Cannot load %s -- run export() in jackal_missile_bunker_lowpoly.blend" % MODEL_PATH)
	_lit = StandardMaterial3D.new()
	_lit.albedo_color = BEACON_LIT
	_lit.emission_enabled = true
	_lit.emission = BEACON_LIT
	_lit.emission_energy_multiplier = BEACON_ENERGY
	reset()


func reset() -> void:
	for b in bunkers:
		b.root.queue_free()
		b.light.queue_free()
	bunkers.clear()
	for m in missiles:
		m.node.queue_free()
	missiles.clear()
	_trigger_y = map.stage.map_height


# --boss: the rows up to the frame's `top` (map px) passed without spawning.
func skip_to(top: float) -> void:
	_trigger_y = mini(_trigger_y, maxi((int(top) >> 5) - 1, 0))


# ----------------------------------------------------------------------------
# The tick

func tick() -> void:
	if _scene == null:
		return
	var view: Rect2 = frame.call()
	_process_triggers(Level3DMap.to_map(view.position).y)
	for b in bunkers:
		if not b.dead:
			_update(b, view)
	for i in range(missiles.size() - 1, -1, -1):
		_fly(i, view)


func _process_triggers(top: float) -> void:
	var row := (int(top) >> 5) - 1
	if row < 0:
		return
	var triggers: Array = map.triggers()
	while _trigger_y > row:
		_trigger_y -= 1
		for t in triggers[_trigger_y]:
			if t[0] == Triggers.CLIFF_MISSILE_LAUNCHER:
				_spawn(t[1] + FOOTPRINT * 0.5, t[2] + FOOTPRINT * 0.5)


func _spawn(x: float, y: float) -> void:
	var b := Bunker.new()
	b.x = x
	b.y = y
	b.root = _scene.instantiate() as Node3D
	b.root.scale = Vector3.ONE * SCALE
	add_child(b.root)
	var at := Level3DMap.to_level(Vector2(x, y))
	b.root.position = Vector3(at.x, ground.call(at.x, at.y).height, at.y)
	Level3DFx.flash_lit(b.root, Level3DFx.ENEMY_FLASH_LAYER)
	b.player = b.root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	b.player.play(ANIMATION)
	b.player.seek(0.0, true)
	b.player.pause()
	for part in ["LidL", "LidR", "Lift", "Turntable", "Rails", "RamBarrel", "RamRod",
			"Round1", "Round2", "Round3"]:
		var node := b.root.find_child(PREFIX + part, true, false) as Node3D
		b.parts[part] = node
		b.rest[part] = node.transform
	for part in ["Beacon", "Lamps"]:
		var mi := b.root.find_child(PREFIX + part, true, false) as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null and m.resource_name == BEACON_MATERIAL:
				b.glass.append([mi, s])
	# A red light over the deck's lamps, which shows on the roof from above
	# when the glass is too small to.
	b.light = OmniLight3D.new()
	b.light.light_color = BEACON_LIT
	b.light.omni_range = LIGHT_RANGE
	b.light.light_energy = 0.0
	b.light.visible = false
	add_child(b.light)
	b.light.global_position = (b.root.find_child(PREFIX + "Lamps", true, false) as Node3D).global_position \
			+ Vector3.UP * 0.3
	bunkers.append(b)
	if verbose:
		print("missile bunker appears at %.0f, %.0f" % [x, y])


func _update(b: Bunker, view: Rect2) -> void:
	# CliffMissileLauncher: ready once its launch point is in the frame.
	if not b.ready:
		b.ready = view.has_point(Level3DMap.to_level(Vector2(b.x, b.y)))
		if not b.ready:
			return
	match b.state:
		REST:
			b.wait -= 1
			if b.wait <= 0:
				_go(b, WARN, WARN_TICKS)
		WARN:
			_flash(b, (b.wait / (FLASH_PERIOD / 2)) % 2 == 0)
			b.wait -= 1
			if b.wait <= 0:
				_flash(b, false)
				_go(b, OPENING, DEPLOY_TICKS)
		OPENING:
			b.deployed = minf(1.0, b.deployed + 1.0 / DEPLOY_TICKS)
			_turn(b)
			if b.deployed >= 1.0:
				_go(b, AIMING, AIM_TICKS)
		AIMING:
			b.wait -= 1
			if _turn(b) or b.wait <= 0:
				_launch(b)
				_go(b, HOLDING, HOLD_TICKS)
		HOLDING:
			b.wait -= 1
			if b.wait <= 0:
				_go(b, CLOSING, DEPLOY_TICKS)
		CLOSING:
			b.deployed = maxf(0.0, b.deployed - 1.0 / DEPLOY_TICKS)
			if b.deployed <= 0.0:
				for part in ["Round1", "Round2", "Round3"]:
					(b.parts[part] as Node3D).visible = true
				var spent := WARN_TICKS + 2 * DEPLOY_TICKS + AIM_TICKS + HOLD_TICKS
				_go(b, REST, maxi(LAUNCH_DELAY - spent, 1) + FIRST_DELAY)
	_pose(b)


func _go(b: Bunker, state: int, ticks: int) -> void:
	b.state = state
	b.wait = ticks


# The turntable towards the player, AIM_RATE a tick: whether it is on.
func _turn(b: Bunker) -> bool:
	var me := Level3DMap.to_level(Vector2(b.x, b.y))
	var to: Vector2 = player_position.call(me) - me
	var wanted := atan2(to.x, to.y)
	b.aim = rotate_toward(b.aim, wanted, AIM_RATE)
	return absf(angle_difference(b.aim, wanted)) < 0.02


func _flash(b: Bunker, on: bool) -> void:
	for pair in b.glass:
		(pair[0] as MeshInstance3D).set_surface_override_material(pair[1], _lit if on else null)
	b.light.visible = on
	b.light.light_energy = LIGHT_ENERGY if on else 0.0


# jackal_missile_bunker.py's deploy() and ram(), in Godot's axes: the cupola
# opens, the lift rises, then the rails elevate and the turntable comes round,
# each over its share of `deployed`.
func _pose(b: Bunker) -> void:
	var f := b.deployed
	var lid := clampf(f / LID_PHASE, 0.0, 1.0)
	var rise := clampf((f - LID_PHASE) / (RISE_PHASE - LID_PHASE), 0.0, 1.0)
	var up := clampf((f - RISE_PHASE) / (1.0 - RISE_PHASE), 0.0, 1.0)
	var p: Dictionary = b.parts
	var r: Dictionary = b.rest
	# Blender's turn about its Y is Godot's about -Z, FORWARD.
	(p.LidL as Node3D).transform = (r.LidL as Transform3D) * Transform3D(Basis(Vector3.FORWARD, LID_OPEN * lid), Vector3.ZERO)
	(p.LidR as Node3D).transform = (r.LidR as Transform3D) * Transform3D(Basis(Vector3.FORWARD, -LID_OPEN * lid), Vector3.ZERO)
	var lift: Transform3D = r.Lift
	(p.Lift as Node3D).transform = lift.translated_local(Vector3.UP * LIFT_TRAVEL * rise)
	(p.Turntable as Node3D).transform = (r.Turntable as Transform3D) * Transform3D(Basis(Vector3.UP, b.aim * up), Vector3.ZERO)
	var e := -ELEVATION * up
	var rails: Transform3D = r.Rails
	(p.Rails as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, e), rails.origin)
	# The ram: the cylinder from its foot towards the lug, the rod from the lug
	# towards the foot. The cylinder is built up +Y, the rod down -Y.
	var foot: Vector3 = (r.RamBarrel as Transform3D).origin
	var lug := rails.origin + Basis(Vector3.RIGHT, e) * (r.RamRod as Transform3D).origin
	var d := lug - foot
	var a := atan2(d.z, d.y)
	(p.RamBarrel as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, a), foot)
	(p.RamRod as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, a - e), (r.RamRod as Transform3D).origin)


# SwampMissile's launch: the next of the rails' rounds hidden and flown in its
# place, along the rails, the launch's flash at its tail.
func _launch(b: Bunker) -> void:
	var part := "Round%d" % (b.next_round % 3 + 1)
	b.next_round += 1
	var round_node := b.parts[part] as Node3D
	var m := Missile.new()
	m.node = round_node.duplicate() as Node3D
	add_child(m.node)
	m.node.global_transform = round_node.global_transform
	round_node.visible = false
	var forward := round_node.global_transform.basis.z.normalized()
	var at := round_node.global_position
	var map_at := Level3DMap.to_map(Vector2(at.x, at.z))
	m.x = map_at.x
	m.y = map_at.y
	m.angle = rad_to_deg(atan2(forward.z, forward.x))
	m.from_height = at.y - ground.call(at.x, at.z).height
	m.height = m.from_height
	missiles.append(m)
	guns.muzzle_flash(at - forward * 0.25, -forward, 1.2, "rocket_launch")
	if verbose:
		print("missile launched at %.0f, %.0f, angle %.0f" % [m.x, m.y, m.angle])


# SwampMissile.update.
func _fly(i: int, view: Rect2) -> void:
	var m := missiles[i]
	m.ticks += 1
	if m.ticks > ENTRY_DELAY:
		var me := Level3DMap.to_level(Vector2(m.x, m.y))
		var target := Level3DMap.to_map(player_position.call(me))
		var wanted := rad_to_deg(atan2(target.y - m.y, target.x - m.x))
		var delta := fposmod(wanted - m.angle + 180.0, 360.0) - 180.0
		if absf(delta) < ROTATION_SPEED:
			m.angle = wanted
		else:
			m.angle += ROTATION_SPEED * signf(delta)
		m.height = CRUISE
	else:
		m.height = lerpf(m.from_height, CRUISE, float(m.ticks) / ENTRY_DELAY)
	var v := Vector2(cos(deg_to_rad(m.angle)), sin(deg_to_rad(m.angle))) * SPEED
	m.x += v.x
	m.y += v.y
	var at := Level3DMap.to_level(Vector2(m.x, m.y))
	var margin := REMOVE_MARGIN * PX
	if not view.grow(margin).has_point(at):
		_remove(i)
		return
	if m.ticks >= EXPLODE_DELAY:
		_burst(i, "out of fuel")
		return
	var y: float = ground.call(at.x, at.y).height + m.height
	var position := Vector3(at.x, y, at.y)
	var going := Vector3(v.x, 0.0, v.y).normalized()
	if m.ticks <= ENTRY_DELAY:
		going.y = (CRUISE - m.from_height) / (ENTRY_DELAY * SPEED * PX)
		going = going.normalized()
	m.node.global_transform = Transform3D(Basis.looking_at(going, Vector3.UP, true)
			.scaled(Vector3.ONE * SCALE), position)
	if trail.is_valid() and m.ticks % TRAIL_EVERY == 0:
		trail.call(position - going * 0.12)


func _remove(i: int) -> void:
	missiles[i].node.queue_free()
	missiles.remove_at(i)


# Gone off: an Explosion that goes on to hit what it grows over, and its fire.
func _burst(i: int, by: String) -> void:
	var m := missiles[i]
	var at := m.node.global_position
	_remove(i)
	guns.explode(at)
	guns.blast.call(at, MISSILE_BLAST)
	if verbose:
		print("missile gone off (%s) at %.0f, %.0f" % [by, m.x, m.y])


# ----------------------------------------------------------------------------
# Hits and dying

func _kill(b: Bunker, by: String) -> void:
	b.dead = true
	_flash(b, false)
	var at := b.root.global_position
	Level3DAudio.armor_hit(by, at + Vector3.UP * BLAST_HEIGHT)
	b.player.play(ANIMATION)
	b.player.seek(Level3DGuns.blast_start(), true)
	guns.blast.call(at + Vector3.UP * BLAST_HEIGHT, BLAST_SCALE)
	guns.explode(at)
	scored.call(POINTS)
	if verbose:
		print("missile bunker destroyed (%s) at %.0f, %.0f" % [by, b.x, b.y])


func _box_at(at: Vector2, half: float) -> Rect2:
	var box := Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)
	return Rect2(Level3DMap.to_level(box.position), box.size * PX)


# The first bunker or missile a weapon's flight from `from` to `to` meets, its
# box grown by the weapon's `margin` px: {"t", "bunker"} or {"t", "missile"},
# or empty. `in_frame` is the grenade's and missile's rule, as the guns'.
func intercept(from: Vector3, to: Vector3, margin: float, in_frame := false) -> Dictionary:
	var view: Rect2 = frame.call()
	var best := {}
	var a := Vector2(from.x, from.z)
	var b2 := Vector2(to.x, to.z)
	for b in bunkers:
		if b.dead:
			continue
		var box := _box_at(Vector2(b.x, b.y), HIT + margin)
		if in_frame and not view.intersects(box):
			continue
		var s := Level3DGuns._segment_enters(a, b2, box)
		if s >= 0.0 and (best.is_empty() or s < best.t):
			best = {"t": s, "bunker": b}
	for m in missiles:
		var box := _box_at(Vector2(m.x, m.y), MISSILE_HIT + margin)
		var s := Level3DGuns._segment_enters(a, b2, box)
		if s >= 0.0 and (best.is_empty() or s < best.t):
			best = {"t": s, "missile": m}
	return best


# Where each standing one is, level x, z: the radar's, the loopholes' and the
# airstrike's.
func targets() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for b in bunkers:
		if not b.dead:
			out.append(Level3DMap.to_level(Vector2(b.x, b.y)))
	return out


# A machine-gun round: a missile goes off; a bunker shut takes it on its
# armour, open it counts down BULLET_HITS.
func bullet_attack(found: Dictionary) -> void:
	if found.has("missile"):
		var i := missiles.find(found.missile)
		if i >= 0:
			_burst(i, "machine gun")
		return
	var b: Bunker = found.bunker
	if b.dead:
		return
	if b.deployed <= 0.0:
		Level3DAudio.play("hit_armor", b.root.global_position + Vector3.UP * BLAST_HEIGHT)
		return
	b.bullet_hits -= 1
	if b.bullet_hits <= 0:
		_kill(b, "machine gun")
	else:
		Level3DAudio.play("hit_armor", b.root.global_position + Vector3.UP * BLAST_HEIGHT)


# A grenade or a missile: gone at once, bunker or missile.
func attack(found: Dictionary) -> void:
	if found.has("missile"):
		var i := missiles.find(found.missile)
		if i >= 0:
			_burst(i, "rocket")
	elif not (found.bunker as Bunker).dead:
		_kill(found.bunker, "rocket")


# The airstrike: every bunker in `view` destroyed.
func strike(view: Rect2) -> void:
	for b in bunkers:
		if not b.dead and view.has_point(Level3DMap.to_level(Vector2(b.x, b.y))):
			_kill(b, "airstrike")


# An Explosion's box this tick: the missiles in it go off, unless it is the
# player's; the bunkers stand.
func explosion_hit(box: Rect2, player: bool) -> void:
	if player:
		return
	for i in range(missiles.size() - 1, -1, -1):
		if i < missiles.size() and box.intersects(_box_at(Vector2(missiles[i].x, missiles[i].y), MISSILE_HIT)):
			_burst(i, "explosion")


# A TravelingExplosion's box: both go.
func travel_hit(box: Rect2) -> void:
	explosion_hit(box, false)
	for b in bunkers:
		if not b.dead and box.intersects(_box_at(Vector2(b.x, b.y), HIT)):
			_kill(b, "traveling explosion")


# The missile nearest `at` (level x, z) within `reach` metres, for the
# Arena (the preview's _arena): its index, or -1.
func nearest_missile(at: Vector2, reach: float) -> int:
	var best := -1
	var best_d := reach
	for i in missiles.size():
		var d := at.distance_to(Level3DMap.to_level(Vector2(missiles[i].x, missiles[i].y)))
		if d <= best_d:
			best = i
			best_d = d
	return best


func missile_position(i: int) -> Vector3:
	return missiles[i].node.global_position


# Shot down in the air, by the Arena: it goes off as it would to a round.
func shoot_down(i: int) -> void:
	_burst(i, "the Arena")


# SwampMissile as a mine, for the player's box (level x, z): a missile it
# meets goes off, and the player with it, unless the player cannot be hit.
func bump(player_box: Rect2, invincible: bool) -> bool:
	if invincible:
		return false
	for i in range(missiles.size() - 1, -1, -1):
		if player_box.intersects(_box_at(Vector2(missiles[i].x, missiles[i].y), MISSILE_MINE)):
			_burst(i, "ran into")
			return true
	return false
