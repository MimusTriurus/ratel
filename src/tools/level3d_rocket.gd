# The BTR's rocket launcher on the 3D stage 1 preview: the mount, the reload,
# the rocket's flight and the explosion at the end of it.
#
# Nothing here is part of the game. It is Jackal's second weapon -- the grenade,
# later the missile -- and like it, it is what takes buildings down; the gun
# only chips at them (level3d_gun.gd). What an explosion destroys is the
# preview's to decide, through `exploded`.
#
# The launcher is on the hull, not the turret, so it has its own traverse: the
# mount turns to the cursor at its own rate, and a rocket leaves only when it is
# loaded and pointing within AIM_TOLERANCE of where it was asked to go. The
# round is the model's own -- the parts sitting on the rails or in the tube,
# copied into a node of their own at launch and hidden on the mount until the
# reload is done.
#
# The mount is the weapon: the model carries four fits (FITS), and the one on
# the hull is the one the prisoners have given, as Main's has_missiles and
# missile_power pick the game's weapon. The grenade is a mortar, and its bomb
# is lobbed -- the game's Grenade flies straight while its drawn size swells
# and shrinks, which is a lob seen from above. The missile and its upgrades
# are rockets on rails, each bigger than the last; the last is in three
# stages, and drops the two spent ones on the way.
#
# Unlike a round, a rocket is slow enough to be seen, so it is flown rather than
# decided: each physics step it moves along its path, and the segment it
# covered is asked for the enemies in the way. What stops it on the ground is
# the game's to say, on the map's collision grid (Level3DMap), as it is for the
# gun and the BTR's driving: a missile goes off over the first solid or shield
# tile it comes to, PlayerMissile's is_missile_target, and a grenade asks no
# tile at all -- Grenade goes over every wall, and off only on an enemy or at
# the end of its throw. The scene is asked only how high it strikes. It flies
# at the ground under the cursor, no further than RANGE.
#
# From the tank bench (BlenderMCP/godot, docs/combat.md): an explosion shakes
# the camera -- the one shake the bench leaves on, because without it a blast
# reads as a picture of one -- as a decaying sum of sines on two axes with a
# (1 - t/T)^2 envelope, in screen pixels rather than metres so that zoom does
# not change it. The preview owns the camera; `exploded` hands it the point.
#
# Effects are low poly and opaque, as the gun's are and the stage's
# destruction is: J_BlastFlash's colour for the fireball, J_Smoke's for the
# smoke, J_Soot's for the crater.
#
# With the BTR driving classic (level3d_btr.gd) the flight and the reload are
# the game's weapon's, Grenade or PlayerMissile by what the prisoners have
# given (`has_missiles`, `missile_power`): a steady speed from the start, the
# whole of its distance whatever it was aimed at, and one in the air at a time.
# The game re-arms when the explosion it ends in is over, not on a clock --
# Explosion.update for a grenade and a plain missile, the TravelingExplosion
# that carries the notifier for an upgraded one -- so here the rails are loaded
# that long after the rocket goes off, however soon that was. The long-range
# upgrade is not here: BossSuperTank gives it, and stage 1 has none.
#
# Where a round goes off is the game's too, in either mode, and by the weapon:
# the grenade and the plain missile make one Explosion, growing over what is
# next to it (Level3DGuns.explode, through `exploded`); the missile's upgrades
# throw TravelingExplosions from it besides, two across the screen and then
# four, which run along the ground over walls and water and take down what
# they pass (`traveled`, _travel).
class_name Level3DLauncher
extends Node3D

const TRAVERSE_RATE := deg_to_rad(120.0)
const AIM_TOLERANCE := deg_to_rad(6.0)
const RELOAD := 1.6
const RANGE := 16.0
const MIN_RANGE := 3.0
const LAUNCH_SPEED := 6.0
const THRUST := 60.0
const TOP_SPEED := 28.0
const KICK := 0.6
const SMOKE_EVERY := 0.012
const CRATERS_KEPT := 40
# A crater smaller than this is not worth drawing; its rim may stand this far
# off the height at its centre and still lie flat enough.
const CRATER_SMALLEST := 0.2
const CRATER_STEP := 0.06
# Grenade and PlayerMissile at the map's PX. Each is gone on the tick its count
# passes TRAVEL_TIME, so it flies TRAVEL_TIME + 1 moves.
const GRENADE_SPEED := Grenade.VELOCITY * 100.0 * Level3DMap.PX
const GRENADE_RANGE := (Grenade.TRAVEL_TIME + 1) * Grenade.VELOCITY * Level3DMap.PX
const MISSILE_SPEED := PlayerMissile.VELOCITY * 100.0 * Level3DMap.PX
const MISSILE_RANGE := (PlayerMissile.TRAVEL_TIME + 1) * PlayerMissile.VELOCITY * Level3DMap.PX
# How long the game's explosions last, in seconds: a grenade explosion grows
# from 32 px by GROW_RATE a tick until it is past 128, which is 47 ticks; a
# TravelingExplosion is gone when its count passes TRAVEL_TIME.
const EXPLOSION_TIME := 0.47
const TRAVELING_EXPLOSION_TIME := (TravelingExplosion.TRAVEL_TIME + 1) / 100.0
# A bomb has no motor, and Grenade draws no trail: it goes at the grenade's
# speed in either mode, 5 px a tick over the ground, and leaves nothing behind
# it. What it has is at the tube, a flash and a cough of smoke as it goes
# (_mortar_blast), and on the ground under it a spot (_place_blob) that it
# climbs away from and comes back down to -- the arc seen from above, which the
# game's Grenade shows by swelling as it rises, as the bomb here does too
# (BOMB_PEAK). The spot stands in for its shadow, which is off. It noses up
# and down a little as it flies, for the game's spinning sprite: a bomb
# steadied by fins does not spin.
const BLOB_RADIUS := 0.2
const BLOB_SHRINK := 0.7        # per metre above the ground
# No smaller than this, or straight under a high bomb it hides behind it.
const BLOB_SMALLEST := 0.12
const BLOB_LIFT := 0.015
const WOBBLE := deg_to_rad(7.0)
const WOBBLE_RATE := 15.0       # radians a second
# A spent stage falls away for this long before it is gone.
const STAGE_FALL := 0.7
# How big a round is drawn once it is off the mount. The model's are true to
# the vehicle and too small to follow from the game's camera: the bomb is
# 0.14 m across where the game's grenade is drawn 0.39 to 0.64 m, and the
# light missile 0.43 by 0.11 m where the game's is 0.64 by 0.35. So a bomb
# swells to BOMB_PEAK its size at the top of its arc and comes back down to
# its own, Grenade's parabola -- 0.6 to 1 and back, of its sprite -- with
# the peak at about the game's size. The game's missile does not swell, but
# here one would be lost: a rocket grows to ROCKET_GROWTH in its first
# ROCKET_GROW_TIME and flies at that. Both start from the model's size, so
# the round leaves the mount as the one that sat on it.
const BOMB_PEAK := 3.0
const ROCKET_GROWTH := 2.0
const ROCKET_GROW_TIME := 0.3

# The fits, by weapon level: 0 the grenade, 1 the missile, 2 and 3 its
# upgrades. Each is the base the mount turns on the hull, the pivot its tube
# or rails tilt on, and the round sitting on them: its parts by prefix, the
# part whose middle is the round's (`body`, the prefix itself unless given),
# and the two whose line is its axis. A round in stages has its parts
# numbered by stage, tail first.
const FITS := [
	{"base": "BTR_MortarBase", "pivot": "BTR_MortarPivot", "round": "BTR_Mine",
			"nose": "BTR_MineFuze", "tail": "BTR_MineTail", "lob": true},
	{"base": "BTR_LauncherBase", "pivot": "BTR_LauncherPivot", "round": "BTR_Missile",
			"nose": "BTR_MissileNose", "tail": "BTR_MissileTail"},
	{"base": "BTR_HeavyLauncherBase", "pivot": "BTR_HeavyLauncherPivot", "round": "BTR_HeavyMissile",
			"nose": "BTR_HeavyMissileNose", "tail": "BTR_HeavyMissileTail"},
	{"base": "BTR_StageLauncherBase", "pivot": "BTR_StageLauncherPivot", "round": "BTR_StageMissile",
			"body": "BTR_StageMissile2", "nose": "BTR_StageMissile3Nose",
			"tail": "BTR_StageMissile1Nozzle", "stages": 3},
]

# `ground.call(x, z)` as the BTR has it; `surface.call(x, z)` the same over the
# walls, trunks and buildings on it.
var ground: Callable
var surface: Callable
var btr: Level3DBtr
var aim_point = null        # Vector3 or null
# `exploded.call(point)` at each explosion, returning whether it destroyed
# anything.
var exploded: Callable
# `intercept.call(from, to)`: the first enemy on the rocket's flight -- a
# bunker's gun, a boat or a tank -- as {"t": 0-1 along from -> to, ...}, or
# empty. It goes off there, and `struck.call(found)` is told first.
var intercept: Callable
var struck: Callable
# `traveled.call(at, direction)`: each TravelingExplosion an upgraded missile
# throws where it goes off -- PlayerMissile.update's, two across the screen for
# the first upgrade, and two up and down it as well for the second. The rules
# are Level3DGuns.travel's; what is seen of them is here (_travel).
var traveled: Callable

var yaw := 0.0              # the mount, relative to the hull
var loaded := true
# Main's has_missiles and missile_power: which fit is on the hull, and for the
# classic weapon how it flies.
var has_missiles := false:
	set(value):
		has_missiles = value
		_refit()
var missile_power := 0:
	set(value):
		missile_power = value
		_refit()

var _reload_left := 0.0
var _mounts: Array[Dictionary] = []
var _fit := -1
# The fit on the hull, taken out of its entry in _mounts.
var _base: Node3D
var _base_rest: Transform3D
var _pivot: Node3D
var _parts: Array[MeshInstance3D] = []
var _centre := Vector3.ZERO     # the round's middle, pivot space
var _axis := Vector3.RIGHT      # tail to nose, pivot space
var _nose := 0.0                # centre to nose tip, pivot units
var _tail := 0.0
var _lob := false
var _stages := []               # a staged round's parts, stage by stage
var _stage_tails := []          # each stage's tail, centre-relative, pivot units
var _rockets := []
var _craters: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _puff_mesh: SphereMesh
var _chip_mesh: BoxMesh
var _flame_mesh: SphereMesh
var _crater_mesh: CylinderMesh
var _materials := {}


func _ready() -> void:
	_rng.seed = 2
	for entry in FITS:
		_mounts.append(_read_fit(entry))
	_refit()

	_puff_mesh = SphereMesh.new()
	_puff_mesh.radial_segments = 6
	_puff_mesh.rings = 3
	_puff_mesh.radius = 1.0
	_puff_mesh.height = 2.0
	_chip_mesh = BoxMesh.new()
	_chip_mesh.size = Vector3.ONE
	_flame_mesh = SphereMesh.new()
	_flame_mesh.radial_segments = 5
	_flame_mesh.rings = 2
	_flame_mesh.radius = 1.0
	_flame_mesh.height = 2.0
	_crater_mesh = CylinderMesh.new()
	_crater_mesh.top_radius = 1.0
	_crater_mesh.bottom_radius = 1.0
	_crater_mesh.height = 0.01
	_crater_mesh.radial_segments = 9
	_crater_mesh.rings = 1
	_materials = {
		"flash": _unshaded(Color(1.0, 0.62, 0.2)),
		"core": _unshaded(Color(1.0, 0.92, 0.6)),
		# The Blender materials' base colours are linear; a material's albedo
		# here is sRGB, and taken as it is J_Soot came out black.
		"smoke": _lit(Color(0.33, 0.31, 0.29).linear_to_srgb()),
		"trail": _lit(Color(0.78, 0.78, 0.76)),
		"splash": _lit(Color(0.92, 0.97, 1.0)),
		"soot": _lit(Color(0.09, 0.05, 0.02).linear_to_srgb()),
		"chip": _lit(Color(0.25, 0.2, 0.15)),
		# The stage's own shadows, on sand and on water.
		"blob": _unshaded(Color(0.24, 0.15, 0.03)),
		"blob_water": _unshaded(Color(0.01, 0.08, 0.22)),
	}


# One of FITS off the model: its nodes, and the round's middle, axis and ends.
# FITS names the BTR's parts; the jeep's are the same with its own prefix.
func _read_fit(fit_entry: Dictionary) -> Dictionary:
	var entry := {}
	for key in fit_entry:
		var value = fit_entry[key]
		entry[key] = btr.vehicle.prefix + value.trim_prefix("BTR_") if value is String else value
	var base := btr.launcher_node(entry.base)
	var pivot := base.find_child(entry.pivot, true, false) as Node3D
	var prefix: String = entry.round
	var parts: Array[MeshInstance3D] = []
	for child in pivot.get_children():
		if child is MeshInstance3D and String(child.name).begins_with(prefix):
			parts.append(child)
	# The parts are modelled along the rails; which way is forward is read off
	# where the nose and the tail are, not assumed.
	var nose := pivot.get_node(NodePath(entry.nose)) as Node3D
	var tail := pivot.get_node(NodePath(entry.tail)) as Node3D
	var centre := (pivot.get_node(NodePath(entry.get("body", prefix))) as Node3D).position
	var axis := (nose.position - tail.position).normalized()
	var fit := {"base": base, "rest": base.transform, "pivot": pivot, "parts": parts,
			"centre": centre, "axis": axis, "lob": entry.get("lob", false),
			"nose": _reach(parts, centre, axis, 1.0),
			"tail": (tail.position - centre).dot(axis), "stages": [], "stage_tails": []}
	for stage in entry.get("stages", 0):
		var mark := "%s%d" % [prefix, stage + 1]
		var own: Array[MeshInstance3D] = []
		for part in parts:
			if String(part.name).begins_with(mark):
				own.append(part)
		fit.stages.append(own)
		fit.stage_tails.append(-_reach(own, centre, axis, -1.0))
	return fit


# How far the parts reach from the centre along the axis, forward (way 1) or
# back (way -1).
static func _reach(parts: Array[MeshInstance3D], centre: Vector3, axis: Vector3, way: float) -> float:
	var extent := -INF
	for part in parts:
		var box: AABB = part.transform * part.get_aabb()
		for i in 8:
			extent = maxf(extent, (box.get_endpoint(i) - centre).dot(axis) * way)
	return extent


# The game's weapon as a fit: Main.upgrade_weapon's order.
func weapon_level() -> int:
	return 1 + missile_power if has_missiles else 0


# Puts the fit for the weapon on the hull, turned as the last one was and
# loaded as it was; the others are hidden.
func _refit() -> void:
	var level := weapon_level()
	if _mounts.is_empty() or level == _fit:
		return
	_fit = level
	for i in _mounts.size():
		_mounts[i].base.visible = i == level
	var fit := _mounts[level]
	_base = fit.base
	_base_rest = fit.rest
	_pivot = fit.pivot
	_parts = fit.parts
	_centre = fit.centre
	_axis = fit.axis
	_nose = fit.nose
	_tail = fit.tail
	_lob = fit.lob
	_stages = fit.stages
	_stage_tails = fit.stage_tails
	for part in _parts:
		part.visible = loaded
	_base.transform = Transform3D(Basis(Vector3.UP, yaw) * _base_rest.basis, _base_rest.origin)


# Fires if it can; whether it did.
func fire() -> bool:
	if not loaded or absf(_yaw_error()) > AIM_TOLERANCE:
		return false
	_launch()
	loaded = false
	# Classic: not loaded again until the rocket has gone off; see _explode.
	_reload_left = INF if btr.classic else RELOAD
	for part in _parts:
		part.visible = false
	return true


func step(delta: float) -> void:
	_traverse(delta)
	if not loaded:
		_reload_left -= delta
		if _reload_left <= 0.0:
			loaded = true
			for part in _parts:
				part.visible = true
	for rocket in _rockets.duplicate():
		_fly(rocket, delta)


# ----------------------------------------------------------------------------
# The mount

func _wanted_yaw() -> float:
	if aim_point == null:
		return 0.0 if absf(btr.speed) > 0.05 else yaw
	var to: Vector3 = aim_point - _base.global_position
	if Vector2(to.x, to.z).length() < 0.5:
		return yaw
	return wrapf(atan2(-to.z, to.x) - btr.heading, -PI, PI)


func _yaw_error() -> float:
	return wrapf(_wanted_yaw() - yaw, -PI, PI)


func _traverse(delta: float) -> void:
	var budget := (Level3DBtr.CLASSIC_TURRET_RATE if btr.classic else TRAVERSE_RATE) * delta
	yaw = wrapf(yaw + clampf(_yaw_error(), -budget, budget), -PI, PI)
	_base.transform = Transform3D(Basis(Vector3.UP, yaw) * _base_rest.basis, _base_rest.origin)


# ----------------------------------------------------------------------------
# Flight

func _launch() -> void:
	var frame := _pivot.global_transform
	var start := frame * _centre
	var heading := (frame.basis * _axis).normalized()
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	var classic := btr.classic
	var reach := RANGE
	if classic:
		reach = MISSILE_RANGE if has_missiles else GRENADE_RANGE
	elif aim_point != null:
		var to: Vector3 = aim_point - start
		reach = clampf(Vector2(to.x, to.z).length(), MIN_RANGE, RANGE)
	var target := start + flat * reach
	# Classic comes back to the height it left at, as the game's weapons fly
	# flat, and goes off on the ground under the end of it (_fly). Dropping on
	# to the ground instead, the nose met it a tenth of the distance short. A
	# bomb comes down on the ground either way: that is what a lob is.
	if _lob or not classic:
		target.y = ground.call(target.x, target.z).height

	# The model's parts, re-hung on a node of their own about the round's
	# middle, then turned from the mount's line on to the flight's.
	var rocket := Node3D.new()
	get_parent().add_child(rocket)
	var copies := {}
	for part in _parts:
		var copy := part.duplicate() as MeshInstance3D
		copy.visible = true
		copy.transform = Transform3D(Basis(), -_centre) * part.transform
		rocket.add_child(copy)
		copies[part] = copy
	var stages := []
	for own in _stages:
		stages.append(own.map(func(part): return copies[part]))
	var flame: MeshInstance3D = null
	if not _lob:
		flame = MeshInstance3D.new()
		flame.mesh = _flame_mesh
		flame.material_override = _materials.core
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rocket.add_child(flame)
		flame.position = _axis * (_tail - 0.12)
		_stretch_flame(flame, _axis, 0.18)

	var speed := LAUNCH_SPEED
	var rearm := 0.0
	if classic:
		speed = MISSILE_SPEED if has_missiles else GRENADE_SPEED
		rearm = TRAVELING_EXPLOSION_TIME if has_missiles and missile_power > 0 else EXPLOSION_TIME
	if _lob:
		speed = GRENADE_SPEED
	# Either leaves along its rails or its tube, whatever they point at -- the
	# mount's own elevation, and the hull's pitch and roll under it -- and
	# comes down on the target: the line to it with a hump over it (_arc),
	# as big as makes the slope at the start the rails'. A rocket's hump is
	# over by the end, so it arrives along that line; a bomb's is a
	# parabola's, and comes down as steeply as it went up. A round whose
	# rails point below the line would dip under it, into the ground; it
	# takes the line instead.
	var run := Vector2(target.x - start.x, target.z - start.z).length()
	var rise := heading.y / maxf(Vector2(heading.x, heading.z).length(), 0.01)
	var entry := {"node": rocket, "flame": flame, "direction": heading,
			"speed": speed, "smoke": 0.0, "age": 0.0, "grow": 1.0,
			"scale": frame.basis.get_scale().x, "classic": classic, "rearm": rearm,
			"axis": _axis, "nose": _nose, "tail": _tail, "lob": _lob,
			"stages": stages, "stage_tails": _stage_tails, "dropped": 0,
			"power": missile_power if has_missiles else 0,
			"from": start, "to": target, "run": run, "gone": 0.0,
			"hump": maxf(run * rise - (target.y - start.y), 0.0),
			"heading": heading, "basis": frame.basis}
	if _lob:
		for copy in copies.values():
			(copy as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		entry["blob"] = _instance(_crater_mesh, "blob")
		_mortar_blast(start + heading * _nose * entry.scale, heading)
	_place_on_arc(entry, 0.0)
	_rockets.append(entry)
	btr.recoil(heading, KICK)


func _fly(rocket: Dictionary, delta: float) -> void:
	rocket.age += delta
	var step: float = rocket.speed * delta
	if not rocket.lob and not rocket.classic:
		rocket.speed = minf(rocket.speed + THRUST * delta, TOP_SPEED)
		# A motor's speed is along the path; a round out of steep rails
		# covers little ground to begin with.
		step *= Vector2(rocket.direction.x, rocket.direction.z).length()
	if not _advance(rocket, minf(rocket.gone + step, rocket.run)):
		return
	var node: Node3D = rocket.node
	var direction: Vector3 = rocket.direction
	if not rocket.lob:
		# PlayerMissile.update: off on the tick it is over a solid or shield
		# tile.
		var over := Level3DMap.to_map(Vector2(node.global_position.x, node.global_position.z))
		if btr.map.is_missile_target(over.x, over.y):
			var at := node.global_position
			var top: Dictionary = surface.call(at.x, at.z)
			if top.hit:
				at.y = minf(at.y, top.height)
			_explode(rocket, at, -direction)
			return
		var flame: MeshInstance3D = rocket.flame
		_stretch_flame(flame, rocket.axis, _rng.randf_range(0.16, 0.3))
		rocket.smoke += delta
		while rocket.smoke >= SMOKE_EVERY:
			rocket.smoke -= SMOKE_EVERY
			_trail(node.global_position + direction * rocket.tail * _size(rocket))
		# A staged round burns its stages out in equal shares of the way.
		var stages: Array = rocket.stages
		while rocket.dropped < stages.size() - 1 \
				and rocket.gone >= rocket.run * (rocket.dropped + 1) / stages.size():
			_drop_stage(rocket)
	if rocket.gone >= rocket.run - 0.001:
		var there: Dictionary = ground.call(node.global_position.x, node.global_position.z)
		_explode(rocket, Vector3(node.global_position.x, there.height, node.global_position.z), Vector3.UP)


# Along its path to `gone`, metres over the ground, nose first, sweeping the
# chord its nose covers. False if that ran into something, which has set it
# off. A bomb's speed is over the ground, as a thrown thing's is, and so is
# the classic rocket's, which is what keeps its timing the game's.
func _advance(rocket: Dictionary, gone: float) -> bool:
	var node: Node3D = rocket.node
	var nose: Vector3 = node.global_position + rocket.direction * rocket.nose * _size(rocket)
	var next_nose: Vector3 = _arc(rocket, gone) + _arc_tangent(rocket, gone) * rocket.nose * _size(rocket)
	if _sweep(rocket, nose, next_nose + (next_nose - nose).normalized() * 0.05):
		return false
	_place_on_arc(rocket, gone)
	return true


# The path, `gone` metres over the ground from the start: the line to the
# target with the hump over it -- s(1 - s)^2 for a rocket, level again by the
# end, s(1 - s) for a bomb -- scaled so that at the start it rises as the
# rails did.
func _arc(rocket: Dictionary, gone: float) -> Vector3:
	var s: float = gone / rocket.run if rocket.run > 0.0 else 1.0
	var at: Vector3 = (rocket.from as Vector3).lerp(rocket.to, s)
	at.y += rocket.hump * s * (1.0 - s) * (1.0 if rocket.lob else 1.0 - s)
	return at


func _arc_tangent(rocket: Dictionary, gone: float) -> Vector3:
	var s: float = gone / rocket.run if rocket.run > 0.0 else 1.0
	var chord: Vector3 = rocket.to - rocket.from
	var slope: float = 1.0 - 2.0 * s if rocket.lob else (1.0 - s) * (1.0 - 3.0 * s)
	return (chord + Vector3.UP * rocket.hump * slope).normalized()


# The model's scale times how much the round has grown, for its lengths.
func _size(rocket: Dictionary) -> float:
	return rocket.scale * rocket.grow


# The round turned from the line it sat on to its path's, at its size for how
# far it has gone (BOMB_PEAK, ROCKET_GROWTH); a bomb nods as well, and has its
# spot on the ground.
func _place_on_arc(rocket: Dictionary, gone: float) -> void:
	if rocket.lob:
		var s: float = gone / rocket.run if rocket.run > 0.0 else 1.0
		rocket.grow = 1.0 + (BOMB_PEAK - 1.0) * 4.0 * s * (1.0 - s)
	else:
		rocket.grow = 1.0 + (ROCKET_GROWTH - 1.0) * smoothstep(0.0, ROCKET_GROW_TIME, rocket.age)
	var ahead := _arc_tangent(rocket, gone)
	var heading: Vector3 = rocket.heading
	var turn := Quaternion(heading, ahead) if heading.cross(ahead).length() > 1e-5 else Quaternion()
	var side := ahead.cross(Vector3.UP)
	if rocket.lob and side.length() > 1e-5:
		var nod := WOBBLE * sin(gone / rocket.speed * WOBBLE_RATE)
		turn = Quaternion(side.normalized(), nod) * turn
	var at := _arc(rocket, gone)
	(rocket.node as Node3D).global_transform = Transform3D(Basis(turn) * rocket.basis * rocket.grow, at)
	rocket.gone = gone
	rocket.direction = ahead
	if rocket.lob:
		_place_blob(rocket.blob, at)


# The spot under a bomb: on the ground below it, smaller the higher it is.
func _place_blob(blob: MeshInstance3D, at: Vector3) -> void:
	var there: Dictionary = ground.call(at.x, at.z)
	var height: float = there.height if there.hit else 0.0
	blob.material_override = _materials["blob_water" if there.hit and there.kind == "water" else "blob"]
	var size := maxf(BLOB_RADIUS / (1.0 + maxf(at.y - height, 0.0) * BLOB_SHRINK), BLOB_SMALLEST)
	blob.global_position = Vector3(at.x, height + BLOB_LIFT, at.z)
	blob.scale = Vector3(size, 1.0, size)


# The mortar going off: a flash at the tube's mouth and a cough of smoke thrown
# out along it, and nothing after.
func _mortar_blast(at: Vector3, along: Vector3) -> void:
	for layer in [["flash", 0.3, 0.1], ["core", 0.18, 0.07]]:
		var ball := _instance(_puff_mesh, layer[0])
		ball.global_position = at
		ball.scale = Vector3.ONE * 0.05
		var tween := ball.create_tween()
		tween.tween_property(ball, "scale", Vector3.ONE * float(layer[1]), float(layer[2]) * 0.3)
		tween.tween_property(ball, "scale", Vector3.ONE * 0.001, float(layer[2]) * 0.7)
		tween.tween_callback(ball.queue_free)
	for i in 6:
		var puff := _instance(_puff_mesh, "trail")
		var out := (along * _rng.randf_range(0.15, 0.6) + Vector3(_rng.randf_range(-1, 1),
				_rng.randf_range(-0.2, 0.6), _rng.randf_range(-1, 1)) * 0.18)
		puff.global_position = at
		puff.scale = Vector3.ONE * 0.05
		var size := _rng.randf_range(0.14, 0.24)
		var life := _rng.randf_range(0.6, 1.0)
		var tween := puff.create_tween()
		tween.set_parallel()
		tween.tween_property(puff, "scale", Vector3.ONE * size, life * 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "global_position", at + out + Vector3.UP * 0.3, life).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector3.ONE * 0.001, life * 0.7).set_delay(life * 0.3) 				.set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(puff.queue_free)


# Asks the segment a round's nose covers this step for an enemy in the way,
# and sets it off there; whether it did.
func _sweep(rocket: Dictionary, nose: Vector3, reach: Vector3) -> bool:
	var found: Dictionary = intercept.call(nose, reach) if intercept.is_valid() else {}
	if found.is_empty():
		return false
	struck.call(found)
	_explode(rocket, nose.lerp(reach, found.t), (nose - reach).normalized())
	return true


# The rearmost stage still on, burnt out: its parts fall away tumbling, and
# the flame and the trail move up to the next one's tail.
func _drop_stage(rocket: Dictionary) -> void:
	var node: Node3D = rocket.node
	var k: int = rocket.dropped
	var tails: Array = rocket.stage_tails
	var axis: Vector3 = rocket.axis
	var spent := Node3D.new()
	get_parent().add_child(spent)
	spent.global_transform = node.global_transform \
			* Transform3D(Basis(), axis * (tails[k] + tails[k + 1]) * 0.5)
	for copy in rocket.stages[k]:
		(copy as Node3D).reparent(spent)
	rocket.dropped = k + 1
	rocket.tail = tails[k + 1]
	(rocket.flame as Node3D).position = axis * (rocket.tail - 0.12)
	var joint: Vector3 = node.global_transform * (axis * rocket.tail)
	for i in 4:
		_trail(joint)
	var from := spent.global_transform
	var drift: Vector3 = rocket.direction * rocket.speed * 0.25
	var spin_axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1, 1)).normalized()
	var spin := _rng.randf_range(6.0, 10.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var tween := spent.create_tween()
	tween.tween_method(func(t: float):
		var at := from.origin + drift * t + Vector3.DOWN * 4.9 * t * t
		spent.global_transform = Transform3D(Basis(spin_axis, spin * t) * from.basis, at), 0.0, STAGE_FALL, STAGE_FALL)
	tween.tween_callback(spent.queue_free)


func _trail(at: Vector3) -> void:
	var puff := _instance(_puff_mesh, "trail")
	puff.global_position = at + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1),
			_rng.randf_range(-1, 1)) * 0.03
	var size := _rng.randf_range(0.08, 0.12)
	puff.scale = Vector3.ONE * size
	var life := _rng.randf_range(0.5, 0.8)
	var tween := puff.create_tween()
	tween.set_parallel()
	tween.tween_property(puff, "scale", Vector3.ONE * size * 2.2, life * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "global_position", puff.global_position + Vector3.UP * 0.25, life)
	tween.tween_property(puff, "scale", Vector3.ONE * 0.001, life * 0.6).set_delay(life * 0.4)
	tween.chain().tween_callback(puff.queue_free)


# ----------------------------------------------------------------------------
# The explosion

func _explode(rocket: Dictionary, at: Vector3, normal: Vector3) -> void:
	_rockets.erase(rocket)
	(rocket.node as Node3D).queue_free()
	if rocket.has("blob"):
		(rocket.blob as Node3D).queue_free()
	if rocket.classic and not loaded:
		_reload_left = rocket.rearm
	var there: Dictionary = ground.call(at.x, at.z)
	var on_water: bool = there.hit and there.kind == "water" and at.y <= there.height + 0.05
	# Asked first: a building that goes down brings its own soot, and a crater
	# of the rocket's on top of it is a second, darker scorch.
	var destroyed: bool = exploded.call(at) if exploded.is_valid() else false
	_fireball(at)
	_light(at)
	if on_water:
		_column(at)
	else:
		_smoke(at)
		_chips(at, normal)
		# Not on the water, even from a hit above it -- a boat's.
		if not destroyed and there.kind != "water" and at.y <= there.height + 0.2:
			_crater(Vector3(at.x, there.height, at.z))
	# PlayerMissile.update: an upgraded missile throws its blast sideways, and
	# the second upgrade vertically too.
	if rocket.power > 0:
		var ways: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT]
		if rocket.power == 2:
			ways.append_array([Vector2.UP, Vector2.DOWN])
		for way in ways:
			if traveled.is_valid():
				traveled.call(at, way)
			_travel(Vector3(at.x, there.height if there.hit else at.y, at.z), way)


# A TravelingExplosion as it is seen: a ball of fire running along the ground
# at the game's speed, as big as the game's box and shrinking with it -- the
# game's sprite is fire, then flash, then smoke, one to each of its periods --
# and leaving puffs behind it, spray over the water.
func _travel(at: Vector3, way: Vector2) -> void:
	# Fire is a flash round a hot core, which reads on the sand where the
	# flash's orange alone does not; smoke is the flash's ball in J_Smoke.
	var ball := _instance(_puff_mesh, "flash")
	var core := _instance(_puff_mesh, "core")
	var light := OmniLight3D.new()
	get_parent().add_child(light)
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 3.0
	light.omni_attenuation = 2.0
	var step := Vector3(way.x, 0.0, way.y) * TravelingExplosion.VELOCITY * Level3DMap.PX
	var life := TravelingExplosion.TRAVEL_TIME / 100.0
	var last := [-1, 0]     # the period shown, the tick of the last puff
	var tween := ball.create_tween()
	tween.tween_method(func(seconds: float):
		var t := mini(int(seconds * 100.0) + 1, TravelingExplosion.TRAVEL_TIME)
		var p := at + step * t
		var there: Dictionary = ground.call(p.x, p.z)
		var radius := Level3DGuns.traveling_margin(t) * Level3DMap.PX * 0.8
		p.y = (there.height if there.hit else at.y) + radius * 0.5
		ball.global_position = p
		ball.scale = Vector3.ONE * radius
		core.global_position = p + Vector3.UP * radius * 0.35
		core.scale = Vector3.ONE * radius * 0.6
		light.global_position = p + Vector3.UP * 0.5
		light.light_energy = 3.0 * (1.0 - float(t) / TravelingExplosion.TRAVEL_TIME)
		var period := 0 if t < TravelingExplosion.PERIOD0 else (1 if t < TravelingExplosion.PERIOD1 else 2)
		if period != last[0]:
			last[0] = period
			ball.material_override = _materials["smoke" if period == 2 else "flash"]
			core.visible = period < 2
		if t - last[1] >= 6:
			last[1] = t
			_puff(p, radius * 0.8, "splash" if there.hit and there.kind == "water" else "smoke"),
			0.0, life, life)
	tween.tween_property(ball, "scale", Vector3.ONE * 0.001, 0.12)
	tween.tween_callback(func():
		ball.queue_free()
		core.queue_free()
		light.queue_free())


# One puff that swells, rises and shrinks away.
func _puff(at: Vector3, size: float, material: String) -> void:
	var puff := _instance(_puff_mesh, material)
	puff.global_position = at
	puff.scale = Vector3.ONE * size * 0.3
	var life := _rng.randf_range(0.6, 0.9)
	var tween := puff.create_tween()
	tween.set_parallel()
	tween.tween_property(puff, "scale", Vector3.ONE * size, life * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "global_position", at + Vector3.UP * 0.6, life)
	tween.tween_property(puff, "scale", Vector3.ONE * 0.001, life * 0.7).set_delay(life * 0.3) \
			.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(puff.queue_free)


# Explosion as it is seen: the game draws its sprite `size` px across while the
# box that kills is 0.35 of that either side, so what it shows is what it hits.
# The ball is the same, on the same curve and clock as Level3DGuns' box --
# from EXPLOSION_START by GROW_RATE a tick until past EXPLOSION_END -- and
# stepped with the physics ticks, so the two do not drift apart. It used to
# swell to 0.9 m in a twelfth of a second and be gone in 0.28, when the box
# was a quarter of that and only half grown: an enemy inside the fire lived,
# and one walking in after it was out died of nothing to be seen. The hot core
# is there for the game's first two frames and goes on the third, from 80 px,
# where its fire breaks up into holes.
func _fireball(at: Vector3) -> void:
	var ball := _instance(_puff_mesh, "flash")
	var core := _instance(_puff_mesh, "core")
	var place := func(size: float):
		var radius := size * 0.5 * Level3DMap.PX
		ball.scale = Vector3.ONE * radius
		ball.global_position = at + Vector3.UP * 0.2
		core.visible = size < 80.0
		core.scale = Vector3.ONE * radius * 0.6
		# High enough to stand out of the flash's top, or from above it is not
		# there, and the flash's orange alone is lost on the sand.
		core.global_position = at + Vector3.UP * (0.2 + radius * 0.6)
	place.call(Level3DGuns.EXPLOSION_START)
	var life := EXPLOSION_TIME
	var tween := ball.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(seconds: float):
		var ticks := int(seconds * 100.0) + 1
		place.call(minf(Level3DGuns.EXPLOSION_START * pow(Explosion.GROW_RATE, ticks),
				Level3DGuns.EXPLOSION_END)),
		0.0, life, life)
	tween.tween_callback(core.queue_free)
	tween.tween_property(ball, "scale", Vector3.ONE * 0.001, 0.08)
	tween.tween_callback(ball.queue_free)


# Blast_Light's curve, shortened: the stage's destruction lights 700 W for a
# frame and fades over ten.
func _light(at: Vector3) -> void:
	var light := OmniLight3D.new()
	get_parent().add_child(light)
	light.global_position = at + Vector3.UP * 0.6
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 6.0
	light.omni_attenuation = 2.0
	light.light_energy = 0.0
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 6.0, 0.04)
	tween.tween_property(light, "light_energy", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(light.queue_free)


# What the fire leaves. It rises once the fireball is nearly done and from
# inside it: puffs starting at once and spread 0.45 m hid the fire and stood
# as far out as the old fireball did, the same lie about the reach.
func _smoke(at: Vector3) -> void:
	for i in 7:
		var puff := _instance(_puff_mesh, "smoke")
		var offset := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * 0.3
		puff.global_position = at + offset + Vector3.UP * 0.1
		puff.scale = Vector3.ONE * 0.001
		var size := _rng.randf_range(0.28, 0.42)
		var life := _rng.randf_range(0.9, 1.3)
		var delay := EXPLOSION_TIME * _rng.randf_range(0.7, 0.95)
		var tween := puff.create_tween()
		tween.set_parallel()
		tween.tween_property(puff, "scale", Vector3.ONE * size, life * 0.3).set_delay(delay).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "global_position", puff.global_position + Vector3.UP * 1.1 + offset * 0.6,
				life).set_delay(delay)
		tween.tween_property(puff, "scale", Vector3.ONE * 0.001, life * 0.7).set_delay(delay + life * 0.3) \
				.set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(puff.queue_free)


func _column(at: Vector3) -> void:
	for i in 6:
		var puff := _instance(_puff_mesh, "splash")
		var offset := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * 0.3
		puff.global_position = at + offset
		puff.scale = Vector3.ONE * 0.1
		var size := _rng.randf_range(0.22, 0.35)
		var rise := _rng.randf_range(0.6, 1.2)
		var life := _rng.randf_range(0.6, 0.9)
		var tween := puff.create_tween()
		tween.set_parallel()
		tween.tween_property(puff, "scale", Vector3.ONE * size, life * 0.3)
		tween.tween_property(puff, "global_position", puff.global_position + Vector3.UP * rise, life * 0.5) \
				.set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "global_position", puff.global_position, life * 0.5).set_delay(life * 0.5) \
				.set_ease(Tween.EASE_IN)
		tween.tween_property(puff, "scale", Vector3.ONE * 0.001, life * 0.5).set_delay(life * 0.5)
		tween.chain().tween_callback(puff.queue_free)


func _chips(at: Vector3, normal: Vector3) -> void:
	for i in 10:
		var chip := _instance(_chip_mesh, "chip")
		var size := _rng.randf_range(0.05, 0.1)
		chip.scale = Vector3(size, size * 0.6, size * 1.3)
		var out := (normal + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.3, 1.2),
				_rng.randf_range(-1, 1))).normalized()
		var velocity := out * _rng.randf_range(3.0, 6.0)
		var spin := Vector3(_rng.randf_range(-15, 15), _rng.randf_range(-15, 15), _rng.randf_range(-15, 15))
		var floor_y: float = ground.call(at.x, at.z).height
		var life := _rng.randf_range(0.5, 0.8)
		var tween := chip.create_tween()
		tween.tween_method(func(t: float):
			var p := at + velocity * t + Vector3.DOWN * 4.9 * t * t
			p.y = maxf(p.y, floor_y + 0.02)
			chip.global_position = p
			chip.rotation = spin * t, 0.0, life, life)
		tween.tween_property(chip, "scale", Vector3.ONE * 0.001, 0.3)
		tween.tween_callback(chip.queue_free)


# A scorch on the ground that stays, the stage's soot decal in miniature. The
# oldest goes when there are too many. It is a flat disc, so it is made no
# bigger than the surface it lies on: shrunk until its rim is all off the
# water and at the height of its centre -- or there is none, near a bridge's
# edge or the shore.
func _crater(at: Vector3) -> void:
	var size := _rng.randf_range(0.5, 0.65)
	while not _fits(at, size):
		size *= 0.85
		if size < CRATER_SMALLEST:
			return
	var crater := _instance(_crater_mesh, "soot")
	crater.global_position = at + Vector3.UP * 0.008
	crater.rotation.y = _rng.randf() * TAU
	crater.scale = Vector3(0.05, 1.0, 0.05)
	var tween := crater.create_tween()
	tween.tween_property(crater, "scale", Vector3(size, 1.0, size * 0.85), 0.2).set_ease(Tween.EASE_OUT)
	_craters.append(crater)
	while _craters.size() > CRATERS_KEPT:
		_craters.pop_front().queue_free()


# Whether a disc of radius `size` at `at` lies on something other than water
# all round, within CRATER_STEP of its height: sampled at eight points of the
# rim.
func _fits(at: Vector3, size: float) -> bool:
	for i in 8:
		var a := TAU * i / 8.0
		var there: Dictionary = ground.call(at.x + size * cos(a), at.z + size * sin(a))
		if not there.hit or there.kind == "water" or absf(there.height - at.y) > CRATER_STEP:
			return false
	return true


func clear_craters() -> void:
	for crater in _craters:
		crater.queue_free()
	_craters.clear()


# ----------------------------------------------------------------------------

func _instance(mesh: Mesh, material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _materials[material]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(node)
	return node


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


static func _lit(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material


# The exhaust, long along the rocket's axis whichever way the model runs.
static func _stretch_flame(flame: MeshInstance3D, axis: Vector3, length: float) -> void:
	var along := Basis(Quaternion(Vector3.RIGHT, axis)) if Vector3.RIGHT.cross(axis).length() > 1e-5 \
			else Basis.from_euler(Vector3(0, PI if axis.x < 0.0 else 0.0, 0))
	flame.basis = along * Basis.from_scale(Vector3(length, 0.1, 0.1))
