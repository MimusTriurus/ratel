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
# at the ground under the cursor, no further than its reach: the game's, or
# RANGE with the long reach (Level3DSettings.Reach).
#
# From the tank bench (BlenderMCP/godot, docs/combat.md): an explosion shakes
# the camera -- the one shake the bench leaves on, because without it a blast
# reads as a picture of one -- as a decaying sum of sines on two axes with a
# (1 - t/T)^2 envelope, in screen pixels rather than metres so that zoom does
# not change it. The preview owns the camera; `exploded` hands it the point.
#
# Effects are low poly and opaque, as the gun's are and the stage's
# destruction is. The fire is the game's Explosion sprite cel-shaded -- white,
# yellow, orange and red bands on a faceted ball, drawn round, burning away at
# the end (level3d_fire.gdshader) -- and so are the embers it throws; the
# smoke is J_Smoke's colour, the dust the blast throws out over the ground
# the colour of the ground, and the crater is its own (Level3DFx.crater_mesh).
# On the water it is a splash instead of smoke and dust: a column, a crown of
# drops and rings of foam spreading from it (_splash).
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
# The launch's light (_launch_light): energy, metres round, seconds going out,
# and how far over the round's middle.
const LAUNCH_LIGHT_ENERGY := 1.6
const LAUNCH_LIGHT_REACH := 6.0
const LAUNCH_LIGHT_TIME := 0.18
const LAUNCH_LIGHT_LIFT := 0.2
const SMOKE_EVERY := 0.012
const CRATERS_KEPT := 40
# A crater smaller than this is not worth drawing; its rim may stand this far
# off the height at its centre and still lie flat enough.
const CRATER_SMALLEST := 0.2
# Hit again and again, a crater grows to this and no bigger (_crater).
const CRATER_BIGGEST := 1.1
const CRATER_STEP := 0.06
# _scorch: how many are kept -- level3d_scorch.gdshaderinc's SCORCHES -- and
# how big one is, from and to.
const SCORCHES_KEPT := 32
const SCORCH_RADIUS := Vector2(0.35, 0.5)
# What a rocket leaves on a wall or a building it strikes, where the ground would
# take a crater: soot on it (Level3DMarks) this many metres round, smaller than
# a scorch -- a wall is half a metre thick; RUBBLE bits of it knocked off, which
# fall at its foot and stay, the last RUBBLE_KEPT of them; and a thin smoke
# from the soot, a puff every SMOULDER_EVERY seconds for SMOULDER_TIME.
const SOOT_RADIUS := Vector2(0.3, 0.4)
const RUBBLE := Vector2i(4, 6)
const RUBBLE_KEPT := 48
const RUBBLE_SIZE := Vector2(0.035, 0.07)
const SMOULDER_TIME := 2.5
const SMOULDER_EVERY := 0.14
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
# How long a travelling explosion's fire takes to burn away once it is over
# (level3d_fire.gdshader's `burn`), and the embers a blast throws.
const BURN_TIME := 0.12
const EMBERS := 7
# A blast's fire once the game's explosion is over (_fireball): how much of
# its heat it has spent at its peak, how long it then takes to cool to the
# edge of smoke, and how long the smoke lasts.
const PEAK_AGE := 0.7
const COOL_TIME := 0.25
const SMOKE_TIME := 1.2
# A destruction's blast (blast): how long its mushroom takes to grow, on a
# curve of its own rather than the game's box.
const BLAST_GROW := 0.4
# What every mushroom, a round's or a destruction's, does to the palms and the
# trees round it (Level3DWind): it reaches PLANT_REACH times its radius at
# its peak -- a round's is 0.94 m, a building's up to 2 -- and throws a crown
# two metres up PLANT_THROW times it, at most PLANT_THROW_MAX.
const PLANT_REACH := 5.0
const PLANT_THROW := 0.4
const PLANT_THROW_MAX := 0.55
# The mushroom's lobes (_fireball), in the game ball's radius: [part, how
# many, how far out, how big, stretch, height, warmth]. The height is a
# share of the cap's -- 0 on the ground, 1 the cap -- or, over 1, the cap's
# and that much more of a radius. How far out and how big together stay
# inside 1, so that seen from above the fire covers no more ground than the
# game's box does.
const LOBES := [
	["base", 5, 0.52, 0.42, Vector3(1.0, 0.6, 1.0), 0.0, 0.05],
	["stem", 2, 0.05, 0.28, Vector3(0.8, 1.7, 0.8), 0.45, 0.3],
	["cap", 6, 0.44, 0.44, Vector3(1.0, 0.8, 1.0), 1.0, 0.0],
	["cap", 1, 0.08, 0.55, Vector3(1.0, 0.85, 1.0), 1.35, 0.12],
]
# _dust_ring: how many puffs, how far out they run from the middle, in metres.
const DUST_PUFFS := 20
const DUST_REACH := Vector2(0.7, 1.5)
# A bomb has no motor, and Grenade draws no trail: it goes at the grenade's
# speed in either mode, 5 px a tick over the ground, and leaves nothing behind
# it. What it has is at the tube, a flash and a cough of smoke as it goes
# (_mortar_blast), and on the ground its shadow, which it climbs away from and
# comes back down to -- the arc seen from above, which the game's Grenade
# shows by swelling as it rises, as the bomb here does too (BOMB_PEAK). It
# noses up and down a little as it flies, for the game's spinning sprite: a
# bomb steadied by fins does not spin.
#
# Both cast a real shadow, or with Level3DFx.real_shadows off (the preview's
# H, --spots) have a spot on the ground under them instead: a rocket's arc
# takes it six metres up, and its shadow lies three or four off it with the
# sun where it is. The spot's size, as Level3DFx.place_spot has it.
const BLOB_RADIUS := 0.2
const BLOB_SHRINK := 0.7        # per metre above the ground
const BLOB_SMALLEST := 0.12
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
# A rocket's back-blast (_back_blast): fire out of the rails' tail, under the
# launcher, and smoke thrown out over the hull from it. By weapon level, a
# share of BACK_BLAST_RADIUS -- the mortar has none, its bomb goes out of the
# tube's mouth (_mortar_blast) -- and bigger as the missile is.
const BACK_BLAST := [0.0, 1.0, 1.3, 1.6]
const BACK_BLAST_RADIUS := 0.2
const BACK_BLAST_TIME := 0.25
const BACK_BLAST_PUFFS := 9

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
# `strike.call(at, travel)`: the face a rocket that went off at `at` is seen to
# strike, and what it is -- level3d_preview.gd's _strike_at.
var strike: Callable
var btr: Level3DBtr
var aim_point = null        # Vector3 or null
var at_cursor := false      # aim_point is the cursor, as Level3DGun's
var unlimited := false      # the preview's unlimited reach, see _launch
var long_reach := false     # RANGE rather than the game's, see _launch
# The preview's rate cheat (Level3DSettings.launcher_rate): the reload that
# many times faster, see fire.
var rate := 1.0
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
# Where its craters, scorches and rubble go: the launcher whose lists the
# ground is told of (_push_ground, ground_materials), and the one the vehicles
# feel them through (crater_height). Null, this one. The second player's
# launcher in co-op has the first's, so that two players' rounds dig one
# ground.
var marks: Level3DLauncher

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
var _craters := []              # see _crater, oldest first
var _scorches: Array[Vector4] = []   # see _scorch, oldest first
var _rubble_bits: Array[Node3D] = []   # see _rubble, oldest first
var _crater_meshes: Array[Dictionary] = []   # Level3DFx.crater_mesh, a few of them
var _rng := RandomNumberGenerator.new()
var _puff_mesh: ArrayMesh
var _chip_mesh: ArrayMesh
var _flame_mesh: SphereMesh
var _fire_mesh: ArrayMesh
var _materials := {}


func _ready() -> void:
	_rng.seed = 2
	for entry in FITS:
		_mounts.append(_read_fit(entry))
	_refit()

	_puff_mesh = Level3DFx.ball(1, 0.12, 3)
	_chip_mesh = Level3DFx.ball(0, 0.25, 4)
	_fire_mesh = Level3DFx.ball(2, 0.06, 5)
	_flame_mesh = SphereMesh.new()
	_flame_mesh.radial_segments = 5
	_flame_mesh.rings = 2
	_flame_mesh.radius = 1.0
	_flame_mesh.height = 2.0
	for i in 4:
		_crater_meshes.append(Level3DFx.crater_mesh(10 + i))
	_materials = {
		"flash": _unshaded(Color(1.0, 0.62, 0.2)),
		"core": _unshaded(Color(1.0, 0.92, 0.6)),
		"fire": Level3DFx.fire(),
		# The Blender materials' base colours are linear; a material's albedo
		# here is sRGB, and taken as it is J_Soot came out black.
		"smoke": _lit(Color(0.33, 0.31, 0.29).linear_to_srgb()),
		"trail": _lit(Color(0.78, 0.78, 0.76)),
		# The gun's dust, level3d_gun.gd's, by the ground it is thrown off:
		# sand, the hard ground's concrete, the forest's earth.
		"dust": _lit(Color(0.93, 0.76, 0.48)),
		"dust_hard": _lit(Color(0.66, 0.65, 0.62)),
		"dust_forest": _lit(Color(0.52, 0.42, 0.26)),
		"splash": _lit(Color(0.92, 0.97, 1.0)),
		# The splash's paler water, under its white.
		"spray": _lit(Color(0.6, 0.87, 0.97)),
		"rim": _painted(true),
		"bowl": _painted(false),
		# Darker than the sand, or only their lines show on it.
		"rim_clod": _lit(Level3DFx.RIM_SAND.lerp(Level3DFx.RIM_SCORCHED, 0.6)),
		"chip": _lit(Color(0.25, 0.2, 0.15)),
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
	# Under the preview's rate cheat, classic reloads on the clock instead, so
	# that more than one can be in the air: the game's cycle, the whole flight
	# and the explosion after it, that many times faster or slower.
	if not btr.classic:
		_reload_left = RELOAD / rate
	elif rate == 1.0:
		_reload_left = INF
	else:
		var flight := MISSILE_RANGE / MISSILE_SPEED if has_missiles else GRENADE_RANGE / GRENADE_SPEED
		var rearm := TRAVELING_EXPLOSION_TIME if has_missiles and missile_power > 0 else EXPLOSION_TIME
		_reload_left = (flight + rearm) / rate
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
	# Where it goes is the game's: along the hull's heading, turned by the
	# mount's yaw, which is what the aim turns it by. Not along the rails as
	# they lie: a hull tipped up on a ruin or a rock tips them too, and rails
	# raised for the lob, rolled with the hull, point off to the side -- the
	# round went off wherever the ground had rocked the jeep. How steeply it
	# rises is the rails' elevation on the hull, for the same reason.
	# A rocket's launch runs on into its flight, and is taken back when it
	# goes off first (_explode); the original mode's is the original's, played out.
	var launch_sound: AudioStreamPlayer = null
	if has_missiles and not Level3DAudio.as_original():
		launch_sound = Level3DAudio.hold("rocket_launch")
	else:
		Level3DAudio.play("rocket_launch" if has_missiles else "grenade_launch", start)
	var bearing := btr.heading + yaw
	var flat := Vector3(cos(bearing), 0.0, -sin(bearing))
	var hull_up := (_base.get_parent() as Node3D).global_basis.y.normalized()
	var elevation := asin(clampf(heading.dot(hull_up), -1.0, 1.0))
	var launch := flat * cos(elevation) + Vector3.UP * sin(elevation)
	var classic := btr.classic
	# The reach is the setting's, however the BTR drives (Level3DSettings.Reach);
	# the cursor only brings it in.
	var most := RANGE if long_reach else (MISSILE_RANGE if has_missiles else GRENADE_RANGE)
	var reach := most
	if not classic and aim_point != null:
		var to: Vector3 = aim_point - start
		reach = clampf(Vector2(to.x, to.z).length(), minf(MIN_RANGE, most), most)
	# Unlimited (Level3DGun.UNLIMITED_RANGE): aimed at the cursor it goes off
	# on it, however far that is and however the BTR drives -- on it, not
	# that far along the mount's line, which the round leaves off to one side
	# of the line the mount was turned along; otherwise it flies until it
	# strikes.
	var target := start + flat * reach
	if unlimited:
		target = start + flat * Level3DGun.UNLIMITED_RANGE
		if at_cursor and aim_point != null:
			var to: Vector3 = aim_point - start
			if Vector2(to.x, to.z).length() >= MIN_RANGE:
				target = Vector3(aim_point.x, start.y, aim_point.z)
			else:
				target = start + flat * MIN_RANGE
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
	# Either leaves at its rails' or its tube's elevation on the hull, along
	# `launch`, and comes down on the target: the line to it with a hump over
	# it (_arc), as big as makes the slope at the start the rails'. The model
	# is turned off the rails as they lie on to that at once (_place_on_arc). A rocket's hump is
	# over by the end, so it arrives along that line; a bomb's is a
	# parabola's, and comes down as steeply as it went up. A round whose
	# rails point below the line would dip under it, into the ground; it
	# takes the line instead.
	var run := Vector2(target.x - start.x, target.z - start.z).length()
	var rise := launch.y / maxf(Vector2(launch.x, launch.z).length(), 0.01)
	var entry := {"node": rocket, "flame": flame, "direction": launch,
			"speed": speed, "smoke": 0.0, "age": 0.0, "grow": 1.0,
			"scale": frame.basis.get_scale().x, "classic": classic, "rearm": rearm,
			"axis": _axis, "nose": _nose, "tail": _tail, "lob": _lob,
			"stages": stages, "stage_tails": _stage_tails, "dropped": 0,
			"power": missile_power if has_missiles else 0, "missile": has_missiles,
			"from": start, "to": target, "run": run, "gone": 0.0,
			"hump": maxf(run * rise - (target.y - start.y), 0.0),
			"heading": heading, "basis": frame.basis, "launch_sound": launch_sound}
	for copy in copies.values():
		(copy as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				if Level3DFx.real_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entry["blob"] = Level3DFx.spot(get_parent())
	if _lob:
		_mortar_blast(start + heading * _nose * entry.scale, heading)
	else:
		_back_blast(frame * (_centre + _axis * _tail), -heading, BACK_BLAST[weapon_level()])
	_launch_light(start)
	_place_on_arc(entry, 0.0)
	if not _lob:
		Level3DAudio.attach_loop(FLIGHT_SOUND, rocket)
		_pitch_flight(entry)
	_rockets.append(entry)
	btr.recoil(launch, KICK)


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
		_pitch_flight(rocket)
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
# far it has gone (BOMB_PEAK, ROCKET_GROWTH), and its spot on the ground; a
# bomb nods as well.
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
	# On whatever is under it, a bunker's roof or a rock as well as the ground.
	var there: Dictionary = surface.call(at.x, at.z)
	Level3DFx.place_spot(rocket.blob, at, there.height if there.hit else 0.0, there.hit and there.kind == "water",
			BLOB_RADIUS, BLOB_SHRINK, BLOB_SMALLEST)


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


# A rocket leaving its rails: out of their tail, `at`, along `back`, a ball of
# fire that swells and cools from white to red and burns away in
# BACK_BLAST_TIME, with a star of flame thrown back in it (Level3DFx.flash),
# and under them smoke blown out low over the hull and past it. The fire rides
# on the vehicle -- it is gone before the vehicle has gone far -- and the
# smoke is left behind. From above the rails stand steep, so what is seen of
# the blast is the ball round their foot and the smoke spreading from it; the
# star, along the rails, is mostly end on. `size` is BACK_BLAST's.
func _back_blast(at: Vector3, back: Vector3, size: float) -> void:
	if size <= 0.0:
		return
	var radius := BACK_BLAST_RADIUS * size
	var holder := Node3D.new()
	btr.add_child(holder)
	holder.global_position = at
	var ball := MeshInstance3D.new()
	ball.mesh = _fire_mesh
	ball.material_override = _materials.fire
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ball)
	var spin := Basis(Vector3.UP, _rng.randf() * TAU)
	var forward := back.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length() < 1e-3:
		side = Vector3.RIGHT
	var star := Node3D.new()
	holder.add_child(star)
	star.global_basis = Basis(forward, side.cross(forward).normalized(), side.normalized()) \
			* Basis(Vector3.RIGHT, _rng.randf_range(-Level3DFx.FLASH_ROCK, Level3DFx.FLASH_ROCK))
	var flames := Level3DFx.flash(star, _fire_mesh, _materials.fire, radius * 3.0, radius * 1.2)
	var burn := func(t: float):
		var k := t / BACK_BLAST_TIME
		ball.transform = Transform3D(spin.scaled(Vector3.ONE * radius * (0.35 + 0.65 * sqrt(k))),
				holder.global_basis.inverse() * forward * radius * 0.4 * k)
		ball.set_instance_shader_parameter("age", k)
		ball.set_instance_shader_parameter("burn", clampf((k - 0.55) / 0.45, 0.0, 1.0))
		Level3DFx.set_fire(flames, minf(k * 1.4, 1.0), clampf((k - 0.6) / 0.4, 0.0, 1.0))
	burn.call(0.0)
	var tween := holder.create_tween()
	tween.tween_method(burn, 0.0, BACK_BLAST_TIME, BACK_BLAST_TIME)
	tween.tween_callback(holder.queue_free)
	# The smoke, low and out: back along the blast's run over the ground and
	# to either side of it, as it spreads off the hull. Out of the fire's edge
	# once it has flared, and no bigger than half of it: out of its middle at
	# once, it covered the fire before it was seen.
	var flat := Vector3(forward.x, 0.0, forward.z)
	for i in BACK_BLAST_PUFFS:
		var out := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
		if flat.length() > 0.1:
			out = (out + flat.normalized() * 0.8).normalized()
		var puff := _instance(_puff_mesh, "trail")
		var from := at + out * radius * 0.8
		puff.global_position = from
		puff.scale = Vector3.ONE * 0.001
		var reach := _rng.randf_range(0.6, 1.2) * radius * 3.0
		var puff_size := _rng.randf_range(0.3, 0.5) * radius
		var life := _rng.randf_range(0.5, 0.8)
		var wait := BACK_BLAST_TIME * _rng.randf_range(0.35, 0.6)
		var smoke := puff.create_tween()
		smoke.set_parallel()
		smoke.tween_property(puff, "scale", Vector3.ONE * puff_size, life * 0.3).set_delay(wait) \
				.set_ease(Tween.EASE_OUT)
		smoke.tween_property(puff, "global_position", from + out * reach + Vector3.UP * radius * 0.8, life) \
				.set_delay(wait).set_ease(Tween.EASE_OUT)
		smoke.tween_property(puff, "scale", Vector3.ONE * 0.001, life * 0.7).set_delay(wait + life * 0.3) \
				.set_ease(Tween.EASE_IN)
		smoke.chain().tween_callback(puff.queue_free)


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


# The motor's pitch with its speed, from FLIGHT_PITCH's first at the launch
# to its second at TOP_SPEED: the rocket is heard speeding up. Classic
# firing flies at one speed, and is heard at the middle of it.
const FLIGHT_SOUND := "rocket_flight"
const FLIGHT_PITCH := Vector2(0.85, 1.2)

func _pitch_flight(rocket: Dictionary) -> void:
	var flight := Level3DAudio.loop_on(rocket.node, FLIGHT_SOUND)
	if flight == null:
		return
	var fast := 0.5 if rocket.classic else inverse_lerp(LAUNCH_SPEED, TOP_SPEED, rocket.speed)
	flight.pitch_scale = lerpf(FLIGHT_PITCH.x, FLIGHT_PITCH.y, clampf(fast, 0.0, 1.0))


# ----------------------------------------------------------------------------
# The explosion

# How fast the motor and the launch die away when the rocket goes off: under
# its blast, quick enough that nothing of it is heard after.
const BLAST_CUT := 0.06

func _explode(rocket: Dictionary, at: Vector3, normal: Vector3) -> void:
	_rockets.erase(rocket)
	# The motor and what is left of the launch die away under the blast
	# rather than stop dead: the rocket is hidden, and freed when they have.
	var node: Node3D = rocket.node
	var launch_sound = rocket.launch_sound
	if is_instance_valid(launch_sound):
		Level3DAudio.fade_out(launch_sound, Callable(), BLAST_CUT)
	var flight := Level3DAudio.loop_on(node, FLIGHT_SOUND)
	if flight != null:
		node.visible = false
		Level3DAudio.fade_out(flight, node.queue_free, BLAST_CUT)
	else:
		node.queue_free()
	(rocket.blob as Node3D).queue_free()
	if rocket.classic and not loaded and rate == 1.0:
		_reload_left = rocket.rearm
	var there: Dictionary = ground.call(at.x, at.z)
	var on_water: bool = there.hit and there.kind == "water" and at.y <= there.height + 0.05
	# The weapon's blast wherever it goes off, and on the water the splash
	# over it (blast_water), so that a missile and a bomb still sound like
	# themselves there and one splash does for both. Modern only: the
	# original knew no water, and played explode3 for a missile and
	# explode2 for a grenade wherever they went off.
	Level3DAudio.play("blast_missile" if rocket.missile else "blast_small", at)
	if on_water and not Level3DAudio.as_original():
		Level3DAudio.play("blast_water", at)
	# Asked first: a building that goes down brings its own soot, and a crater
	# of the rocket's on top of it is a second, darker scorch.
	var destroyed: bool = exploded.call(at) if exploded.is_valid() else false
	_fireball(at)
	_light(at)
	if on_water:
		_splash(Vector3(at.x, there.height, at.z))
	else:
		_embers(at)
		_chips(at, normal)
		# On a wall or a building, what it leaves is on that: soot, rubble at
		# its foot and smoke, and nothing on the ground. A wall's top is ground
		# to the hull, and took a crater dug into it.
		var hit: Dictionary = strike.call(at, -normal) if strike.is_valid() else {"hit": false}
		if hit.hit and hit.kind in Level3DMarks.KINDS:
			Level3DMarks.soot(hit.position, _rng.randf_range(SOOT_RADIUS.x, SOOT_RADIUS.y))
			_marks()._rubble(hit.position, hit.normal, hit.colour)
			_smoulder(hit.position + hit.normal * 0.05)
		elif there.hit and there.kind != "wall" and at.y <= there.height + 0.2:
			_dust_ring(Vector3(at.x, there.height, at.z), there.kind)
			# Not on the water, even from a hit above it -- a boat's. A crater
			# where the ground can be dug and there is room for one, a scorch
			# where not.
			if not destroyed and there.kind != "water":
				var on_ground := Vector3(at.x, there.height, at.z)
				if not (there.kind != "hard" and _marks()._crater(on_ground)):
					_marks()._scorch(on_ground)
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


func _marks() -> Level3DLauncher:
	return self if marks == null else marks


# A TravelingExplosion as it is seen: a ball of fire running along the ground
# at the game's speed, as big as the game's box and shrinking with it, and
# leaving flames behind it that burn out where they are (_cinder), spray over
# the water. It used to leave puffs of smoke, which stood in a grey cross
# long after the fire had gone and was all anyone saw of it. The game's sprite is fire in
# all three of its periods, cooling from the big blast's second frame through
# its first to the small red ring of the fourth, and so is the ball: its `age`
# runs from hot to cold over the whole run, then it burns away.
func _travel(at: Vector3, way: Vector2) -> void:
	var ball := _instance(_fire_mesh, "fire")
	var light := OmniLight3D.new()
	get_parent().add_child(light)
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 3.0
	light.omni_attenuation = 2.0
	var step := Vector3(way.x, 0.0, way.y) * TravelingExplosion.VELOCITY * Level3DMap.PX
	var life := TravelingExplosion.TRAVEL_TIME / 100.0
	var last := [0]     # the tick of the last puff
	var run := func(seconds: float):
		var t := mini(int(seconds * 100.0) + 1, TravelingExplosion.TRAVEL_TIME)
		var p := at + step * t
		var there: Dictionary = ground.call(p.x, p.z)
		var radius := Level3DGuns.traveling_margin(t) * Level3DMap.PX * 0.8
		p.y = (there.height if there.hit else at.y) + radius * 0.5
		ball.global_position = p
		ball.scale = Vector3.ONE * radius
		ball.set_instance_shader_parameter("age", float(t) / TravelingExplosion.TRAVEL_TIME)
		light.global_position = p + Vector3.UP * 0.5
		light.light_energy = 3.0 * (1.0 - float(t) / TravelingExplosion.TRAVEL_TIME)
		if t - last[0] >= 6:
			last[0] = t
			if there.hit and there.kind == "water":
				_puff(p, radius * 0.8, "splash")
				Level3DFx.ripple(get_parent(), Vector3(p.x, there.height, p.z), radius * 3.0,
						0.8, 0.0, _rng.randf() * 100.0)
			else:
				_cinder(p, radius * 0.6, float(t) / TravelingExplosion.TRAVEL_TIME)
	# Placed now, not on the tween's first step, the next frame: until then
	# the ball would be a metre across at the middle of the map.
	run.call(0.0)
	var tween := ball.create_tween()
	tween.tween_method(run, 0.0, life, life)
	tween.tween_callback(light.queue_free)
	tween.tween_method(func(k: float): ball.set_instance_shader_parameter("burn", k), 0.0, 1.0, BURN_TIME)
	tween.tween_callback(ball.queue_free)


# A flame left on the ground, as hot as the fire that left it was (`age`), which
# cools where it is, rising a little, and burns away.
func _cinder(at: Vector3, size: float, age: float) -> void:
	var flame := _instance(_chip_mesh, "fire")
	var life := _rng.randf_range(0.25, 0.4)
	var spin := Basis(Vector3.UP, _rng.randf() * TAU)
	var burn := func(t: float):
		var k := t / life
		flame.global_transform = Transform3D(spin.scaled(Vector3.ONE * size * (1.0 - 0.3 * k)),
				at + Vector3.UP * 0.15 * k)
		flame.set_instance_shader_parameter("age", lerpf(age, 1.0, k))
		flame.set_instance_shader_parameter("burn", clampf((k - 0.5) / 0.5, 0.0, 1.0))
	burn.call(0.0)
	var tween := flame.create_tween()
	tween.tween_method(burn, 0.0, life, life)
	tween.tween_callback(flame.queue_free)


# The blasts' smoke and flames, for what burns after them: the player's wreck
# (Level3DWreck).
func wreck_smoke(at: Vector3, size: float) -> void:
	_puff(at, size, "smoke")


func wreck_flame(at: Vector3, size: float, age: float) -> void:
	_cinder(at, size, age)


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
# The fire is the same, on the same curve and clock as Level3DGuns' box --
# from EXPLOSION_START by GROW_RATE a tick until past EXPLOSION_END -- and
# stepped with the physics ticks, so the two do not drift apart. It used to
# swell to 0.9 m in a twelfth of a second and be gone in 0.28, when the box
# was a quarter of that and only half grown: an enemy inside the fire lived,
# and one walking in after it was out died of nothing to be seen.
#
# It is a cartoon's mushroom of fire, made of lobes (LOBES): billows on the
# ground, a stem, hotter than the rest, and a cap that climbs as it grows.
# Seen from above it covers the ground the game's ball does and no more --
# the lobes are placed within its radius -- and it can stand as tall as it
# likes. It cools as it grows, over the same clock (level3d_fire.gdshader's
# `age`): white-hot at first, as the sprite's first frame is, and going red.
#
# When the box is gone it cools on, over COOL_TIME, and then over SMOKE_TIME
# the same lobes turn to smoke, the edges grey first and the hearts last, as
# a cartoon blast's do: the cap goes on climbing and billowing out, the stem
# thins away beneath it, the billows on the ground spread and go first, and
# then each lobe thins from the middle out to a broken ring of its edge and
# is gone (`burn`). It used to shrink away in a quarter of a second and leave
# puffs of smoke of its own; before that, burn away in holes at its full size
# in a frame. The game's sprite is simply gone on the tick its box is: all
# of this is after it, when nothing is hit.
#
# Each blast is its own -- the lobes' sizes and places a little off, the cap
# leaning, every lobe drifting its own way -- and each lobe is turned at
# random, so that the fire's noise, the same in every ball, is not.
func _fireball(at: Vector3) -> void:
	_mushroom(at, func(seconds: float) -> float:
		var ticks := int(seconds * 100.0) + 1
		return minf(Level3DGuns.EXPLOSION_START * pow(Explosion.GROW_RATE, ticks),
				Level3DGuns.EXPLOSION_END) * 0.5 * Level3DMap.PX, EXPLOSION_TIME, 0.0)


# A destruction's blast, which the preview sets off (level3d_preview.gd): a
# unit's, the BTR's, a building's. The same mushroom, embers and light as a
# round's, `radius` metres over the ground at its peak, standing on the ground
# under `at`, `delay` seconds from now -- a round's blast that brings a
# building down goes off first, and the building's after it, a chain. It is
# not the game's Explosion, whose box is the round's if a round set it off,
# so it grows on a curve of its own, over BLAST_GROW. The destructions' own
# flash and smoke, baked in Blender, are hidden: they were a flat white
# glow and grey lumps, beside fire and smoke drawn as these are.
func blast(at: Vector3, radius: float, delay := 0.0) -> void:
	var there: Dictionary = ground.call(at.x, at.z)
	var foot := Vector3(at.x, there.height if there.hit else at.y, at.z)
	_mushroom(foot, func(seconds: float) -> float:
		return radius * (0.3 + 0.7 * (1.0 - pow(1.0 - minf(seconds / BLAST_GROW, 1.0), 2.0))),
		BLAST_GROW, delay)
	var go := func():
		_light(foot)
		_embers(foot)
	if delay > 0.0:
		get_tree().create_timer(delay, false, true).timeout.connect(go)
	else:
		go.call()


# The mushroom itself: `radius_at.call(seconds)` its radius over the ground
# while it grows, for `grow_time`; then it cools and turns to smoke.
func _mushroom(at: Vector3, radius_at: Callable, grow_time: float, delay: float) -> void:
	var lobes: Array[Dictionary] = []
	for group in LOBES:
		for i in int(group[1]):
			var node := _instance(_fire_mesh, "fire")
			node.set_instance_shader_parameter("warmth", float(group[6]))
			var size: float = group[3] * _rng.randf_range(0.88, 1.12)
			var reach: float = group[2] * _rng.randf_range(0.85, 1.15)
			var angle := TAU * (i + _rng.randf_range(-0.3, 0.3)) / float(group[1])
			var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
			lobes.append({"node": node, "part": group[0], "size": size,
					"out": Vector3(cos(angle), 0.0, sin(angle)) * minf(reach, 0.95 - size),
					"stretch": group[4], "height": group[5],
					"spin": Basis(axis.normalized() if axis.length() > 0.01 else Vector3.UP, _rng.randf() * TAU),
					"drift": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.0, 0.5), _rng.randf_range(-1, 1)) * 0.2})
	var lean := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).limit_length(1.0) * 0.04
	var peak: float = radius_at.call(grow_time)
	Level3DWind.blast(at, minf(peak * PLANT_THROW, PLANT_THROW_MAX), peak * PLANT_REACH, delay)
	var life := grow_time + COOL_TIME + SMOKE_TIME
	# `seconds` from the blast. The radius grows until `grow_time` -- for a
	# round's, the game ball's until its box is gone -- then is the peak's;
	# `after` is the time since.
	var place := func(seconds: float):
		var radius := peak
		var after := seconds - grow_time
		var rise := 1.0
		if after < 0.0:
			radius = radius_at.call(seconds)
			rise = seconds / grow_time
			after = 0.0
		var spent := after / (COOL_TIME + SMOKE_TIME)
		# The cap: from half a radius up to a radius and a half while the
		# fire grows, then on up and slowing.
		var cap := radius * (0.5 + 1.1 * rise) + 0.7 * (1.0 - pow(1.0 - spent, 2.0))
		for lobe in lobes:
			var node: MeshInstance3D = lobe.node
			var out: Vector3 = lobe.out
			var grow := 1.0
			var height: float = lobe.height
			var y := 0.0
			var smoke_time := SMOKE_TIME
			match lobe.part:
				"base":
					out *= 1.0 + 0.6 * spent
					grow = 1.0 - 0.5 * spent
					smoke_time *= 0.7
				"stem":
					grow = clampf(1.0 - after / 0.35, 0.0, 1.0)
				"cap":
					out = out * (1.0 + 0.35 * spent) + lean * (1.0 + 3.0 * spent)
					grow = 1.0 + 0.35 * spent
			var size: float = lobe.size * radius * grow
			if height > 1.0:
				y = cap + (height - 1.0) * radius
			elif height > 0.0:
				y = cap * height
			else:
				y = size * 0.35
			var age := rise * PEAK_AGE
			if after > 0.0:
				age = lerpf(PEAK_AGE, 1.0, minf(after / COOL_TIME, 1.0)) \
						+ clampf((after - COOL_TIME) / smoke_time, 0.0, 1.0)
			var smoke := clampf(age - 1.0, 0.0, 1.0)
			node.visible = size > 0.001
			node.global_transform = Transform3D(
					(lobe.spin as Basis).scaled(lobe.stretch * maxf(size, 0.001)),
					at + out * radius + Vector3.UP * y + lobe.drift * after)
			node.set_instance_shader_parameter("age", age)
			node.set_instance_shader_parameter("burn", clampf((smoke - 0.4) / 0.6, 0.0, 1.0))
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if delay > 0.0:
		for lobe in lobes:
			(lobe.node as Node3D).visible = false
		tween.tween_interval(delay)
	else:
		place.call(0.0)
	tween.tween_method(place, 0.0, life, life)
	tween.tween_callback(func():
		for lobe in lobes:
			(lobe.node as Node).queue_free())


# Sparks of the fire thrown out of it, which cool from white to red as they
# fly, on the fire's own bands, and burn away before they are down. They are
# not the blast's reach -- they are past the box's edge in a blink -- any more
# than the chips are.
func _embers(at: Vector3) -> void:
	# No higher than the blast: one in the side of a wall is under its top,
	# which is ground to a downward ray.
	var floor_y: float = minf(ground.call(at.x, at.z).height, at.y)
	for i in EMBERS:
		var ember := _instance(_chip_mesh, "fire")
		var out := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.4, 1.2), _rng.randf_range(-1, 1)).normalized()
		var velocity := out * _rng.randf_range(2.5, 4.5)
		var start := at + Vector3.UP * 0.25 + out * 0.15
		var size := _rng.randf_range(0.04, 0.07)
		var life := _rng.randf_range(0.35, 0.6)
		var fly := func(t: float):
			var k := t / life
			var p := start + velocity * t + Vector3.DOWN * 3.0 * t * t
			p.y = maxf(p.y, floor_y + size)
			ember.global_position = p
			ember.scale = Vector3.ONE * size * (1.0 - 0.4 * k)
			ember.set_instance_shader_parameter("age", k)
			ember.set_instance_shader_parameter("burn", clampf((k - 0.7) / 0.3, 0.0, 1.0))
		_start(ember, fly, life)


# The launch's light on the hull (Level3DFx.flash_light), as the
# machine gun's flash lights it (Level3DGun.FLASH_ENERGY) but bigger and
# longer, the back blast's or the bomb's charge: up in a flash, out over
# LAUNCH_LIGHT_TIME. Over the mount, so that it takes the hull's top.
func _launch_light(at: Vector3) -> void:
	var light := Level3DFx.flash_light(get_parent(), LAUNCH_LIGHT_REACH)
	light.global_position = at + Vector3.UP * LAUNCH_LIGHT_LIFT
	light.light_energy = 0.0
	light.visible = true
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", LAUNCH_LIGHT_ENERGY, 0.02)
	tween.tween_property(light, "light_energy", 0.0, LAUNCH_LIGHT_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(light.queue_free)


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


# The blast on the ground throws the ground out from under it: a ring of dust
# that runs out low over it on every side, swelling as it goes, and settles
# back down, shrinking, where it stopped. Past the fire, which smoke may not
# go -- smoke standing out there reads as the fire's reach -- but dust is the
# ground's colour and lies flat on it, so it reads as what the blast pushed,
# not what it burnt. On the ground only: a hit on a building or a boat, or
# over the water, throws none.
func _dust_ring(at: Vector3, kind: String) -> void:
	var material: String = {"hard": "dust_hard", "forest": "dust_forest"}.get(kind, "dust")
	var turn := _rng.randf() * TAU
	for i in DUST_PUFFS:
		var puff := _instance(_puff_mesh, material)
		var way := Vector3.RIGHT.rotated(Vector3.UP, turn + TAU * (i + _rng.randf_range(-0.4, 0.4)) / DUST_PUFFS)
		var from := _rng.randf_range(0.2, 0.4)
		var reach := _rng.randf_range(DUST_REACH.x, DUST_REACH.y)
		# The ones that go further are the smaller: the ring's edge frays
		# rather than ending in a row of balls.
		var peak := lerpf(0.36, 0.2, inverse_lerp(DUST_REACH.x, DUST_REACH.y, reach)) * _rng.randf_range(0.85, 1.15)
		var life := _rng.randf_range(0.9, 1.3)
		var delay := _rng.randf_range(0.0, 0.06)
		# Long along the way it goes, swept rather than blown up.
		var spin := Basis(way.cross(Vector3.UP), Vector3.UP, way).scaled(Vector3(1.0, 0.55, 1.4))
		var roll := func(t: float):
			var k := clampf((t - delay) / life, 0.0, 1.0)
			# Out fast and slowing, as a push does; swells in the first
			# quarter, then shrinks as it settles.
			var r := lerpf(from, reach, 1.0 - pow(1.0 - k, 3.0))
			var size := peak * (1.0 - pow(1.0 - minf(k * 4.0, 1.0), 2.0)) \
					* (1.0 - pow(maxf(k - 0.25, 0.0) / 0.75, 2.0))
			size = maxf(size, 0.001)
			puff.global_transform = Transform3D(spin.scaled(Vector3.ONE * size),
					at + way * r + Vector3.UP * size * 0.4)
		roll.call(0.0)
		var tween := puff.create_tween()
		tween.tween_method(roll, 0.0, life + delay, life + delay)
		tween.tween_callback(puff.queue_free)


# The blast on the water, `at` its surface: a column thrown straight up that
# falls back into itself, white over the paler water under it, higher than
# the fire and slower, so that it stands out of it and comes down once the
# fire has burnt away; a crown of drops thrown out and up all round, which
# fall back in; three rings of foam spreading from it one after another, and
# a patch of foam where the column comes down (Level3DFx.ripple). The fire over it is the game's -- its
# Explosion is the same on the water -- and so is its reach; the rings are
# only the water's.
func _splash(at: Vector3) -> void:
	var gravity := Vector3.DOWN * 9.8
	for i in 6:
		var puff := _instance(_puff_mesh, "splash" if i % 2 == 0 else "spray")
		var offset := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * 0.12
		var height := _rng.randf_range(1.6, 2.4) * (1.0 - i * 0.1)
		var width := _rng.randf_range(0.18, 0.28)
		var life := _rng.randf_range(1.0, 1.3)
		var spin := Basis(Vector3.UP, _rng.randf() * TAU)
		var throw := func(t: float):
			var k := t / life
			# Up and back down on a parabola, and thinning as it falls:
			# tall while it rises, a heap as it lands.
			var y := height * 4.0 * k * (1.0 - k)
			var size := maxf(width * (1.0 - pow(k, 3.0)), 0.001)
			var tall := lerpf(2.0, 1.0, k)
			puff.global_transform = Transform3D(spin.scaled(Vector3(size, size * tall, size)),
					at + offset * (1.0 + k) + Vector3.UP * y)
		_start(puff, throw, life)
	for i in 16:
		var drop := _instance(_chip_mesh, "splash")
		var out := Vector3.RIGHT.rotated(Vector3.UP, TAU * (i + _rng.randf_range(-0.3, 0.3)) / 16.0)
		var velocity := out * _rng.randf_range(1.2, 2.2) + Vector3.UP * _rng.randf_range(2.5, 4.0)
		var start := at + out * 0.15
		var size := _rng.randf_range(0.03, 0.05)
		# Until it is back down on the water.
		var life := 2.0 * velocity.y / -gravity.y
		var fly := func(t: float):
			var v := velocity + gravity * t
			var along := v.normalized()
			var side := along.cross(Vector3.UP if absf(along.y) < 0.99 else Vector3.RIGHT).normalized()
			# Long along the way it flies, a drop and not a pebble.
			drop.global_transform = Transform3D(
					Basis(side, along, side.cross(along)).scaled(Vector3(1.0, 1.8, 1.0) * size),
					start + velocity * t + gravity * 0.5 * t * t)
		_start(drop, fly, life)
	# Reach, life, delay: the rings, then the foam where the column lands.
	# The first goes furthest, as a ripple's does -- one that set off later
	# and went further would cross it.
	for ring in [[2.8, 1.8, 0.0], [2.1, 1.6, 0.25], [1.4, 1.4, 0.5], [0.8, 0.9, 1.0]]:
		Level3DFx.ripple(get_parent(), at, ring[0], ring[1], ring[2], _rng.randf() * 100.0)


# Runs `move` over `life` seconds, then frees the node -- and once now: a
# tween's first step is the next frame, and until then the node would be drawn
# as it was made, at the middle of the map (level3d_gun.gd's).
func _start(node: Node3D, move: Callable, life: float) -> void:
	move.call(0.0)
	var tween := node.create_tween()
	tween.tween_method(move, 0.0, life, life)
	tween.tween_callback(node.queue_free)


func _chips(at: Vector3, normal: Vector3) -> void:
	for i in 10:
		var chip := _instance(_chip_mesh, "chip")
		# Half a unit box's 0.05 to 0.1: the chip is a ball of radius 1.
		var size := _rng.randf_range(0.025, 0.05)
		chip.scale = Vector3(size, size * 0.6, size * 1.3)
		var out := (normal + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.3, 1.2),
				_rng.randf_range(-1, 1))).normalized()
		var velocity := out * _rng.randf_range(3.0, 6.0)
		var spin := Vector3(_rng.randf_range(-15, 15), _rng.randf_range(-15, 15), _rng.randf_range(-15, 15))
		var floor_y: float = minf(ground.call(at.x, at.z).height, at.y)
		var life := _rng.randf_range(0.5, 0.8)
		var fly := func(t: float):
			var p := at + velocity * t + Vector3.DOWN * 4.9 * t * t
			p.y = maxf(p.y, floor_y + 0.02)
			chip.global_position = p
			chip.rotation = spin * t
		# Placed now, not at the middle of the map until the next frame.
		fly.call(0.0)
		var tween := chip.create_tween()
		tween.tween_method(fly, 0.0, life, life)
		tween.tween_property(chip, "scale", Vector3.ONE * 0.001, 0.3)
		tween.tween_callback(chip.queue_free)


# A crater that stays: a ring of thrown-up sand round a scorched hole, clods
# beyond it (Level3DFx.crater_mesh), and a shape the vehicles feel (crater_height).
# The oldest goes when there are too many. It lies on flat ground, so it is
# made no bigger than the ground it lies on: shrunk until its rim is all off
# the water and the hard ground and at the height of its centre -- or there is
# none, near a bridge's edge or the shore, and a scorch instead (_scorch).
#
# Nor does one lie over another. Two that overlapped showed each rim standing
# over the other's hole, and each bowl through the other's rim. A round that
# lands in a crater makes that one bigger instead, up to CRATER_BIGGEST, its
# middle drawn a little
# towards the new hit; one that lands beside a crater makes a smaller one, no
# further out than the other's foot -- or, too small for that, the other
# bigger. The craters a building leaves (add_ruin_crater) are fixed: a round
# that lands in one, or too close to have room, leaves none of its own.
#
# A crater is {"node", "centre", "radii", "angle", "height", "ruin"}: centre
# in x, z; radii its outer foot's along its own x and z, which are the same
# but for a ruin's; angle its turn about y; height its scale up; ruin the
# building it belongs to, or "" for a round's.
#
# False when there is no room for one, and the round should leave a scorch
# instead (_scorch); true when it dug one, grew one, or landed in one.
func _crater(at: Vector3) -> bool:
	var centre := Vector2(at.x, at.z)
	var size := _rng.randf_range(0.6, 0.8)
	var grown := -1         # the crater this one replaces
	var nearest := -1
	for i in _craters.size():
		var gap: float = centre.distance_to(_craters[i].centre) - _foot(_craters[i], centre)
		if gap < 0.0:
			if _craters[i].ruin != "":
				return true
			grown = i
			break
		if gap < size:
			size = gap
			nearest = i
	if grown < 0 and size < CRATER_SMALLEST and nearest >= 0:
		if _craters[nearest].ruin != "":
			return false
		grown = nearest
	var start := size * 0.1
	if grown >= 0:
		var old: Dictionary = _craters[grown]
		centre = old.centre.lerp(centre, 0.3)
		start = old.height
		size = minf(old.height * 1.15, CRATER_BIGGEST)
		# Clear of the others still, now that its middle has moved.
		for i in _craters.size():
			if i != grown:
				size = minf(size, centre.distance_to(_craters[i].centre) - _foot(_craters[i], centre))
		if size <= old.height:
			return true
		var there: Dictionary = ground.call(centre.x, centre.y)
		at = Vector3(centre.x, there.height, centre.y)
	while not _fits(at, size):
		size *= 0.85
		if size < CRATER_SMALLEST or (grown >= 0 and size <= start):
			return grown >= 0
	if grown >= 0:
		(_craters[grown].node as Node3D).queue_free()
		_craters.remove_at(grown)
	var crater := make_crater(get_parent())
	crater.global_position = at + Vector3.UP * 0.006
	crater.rotation.y = _rng.randf() * TAU
	# Clods thrown clear of it, and not into the next one's hole.
	for i in _rng.randi_range(4, 6):
		var a := _rng.randf() * TAU
		var way := Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(1.05, 1.5)
		var lands := centre + Vector2(way.x, way.z).rotated(-crater.rotation.y) * size
		if _craters.any(func(other): return _spread(other, lands) < 1.0):
			continue
		var clod := _part(crater, _chip_mesh, "rim_clod")
		var radius := _rng.randf_range(0.05, 0.08)
		# Sunk a little way, not so far that only its line shows.
		clod.position = way + Vector3.UP * radius * 0.4
		clod.scale = Vector3.ONE * radius
		clod.rotation = Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * TAU
	crater.scale = Vector3.ONE * start
	var tween := crater.create_tween()
	tween.tween_property(crater, "scale", Vector3.ONE * size, 0.2).set_ease(Tween.EASE_OUT)
	_craters.append({"node": crater, "centre": centre, "radii": Vector2(size, size),
			"angle": crater.rotation.y, "height": size, "ruin": ""})
	var rounds := _craters.filter(func(c): return c.ruin == "")
	if rounds.size() > CRATERS_KEPT:
		(rounds[0].node as Node3D).queue_free()
		_craters.erase(rounds[0])
	return true


# What a rocket leaves where it digs no crater: on the hard ground -- the
# bridge, the helipad, a hangar's pad, the gate's sill -- or on ground with
# no room for a crater, by the hard ground's edge or the water's. A ragged
# black blotch, painted by the ground's shaders on whatever it lies across
# (level3d_scorch.gdshaderinc); the vehicles do not feel it. SCORCHES_KEPT of
# them, the oldest going first.
func _scorch(at: Vector3) -> void:
	_scorches.append(Vector4(at.x, at.z, _rng.randf_range(SCORCH_RADIUS.x, SCORCH_RADIUS.y),
			_rng.randf_range(0.0, 100.0)))
	if _scorches.size() > SCORCHES_KEPT:
		_scorches.remove_at(0)
	_scorches_told = false


# A unit crater's parts under `parent`: its opening, its bowl and its rim
# (Level3DFx.crater_mesh), one of a few of them, picked at random.
func make_crater(parent: Node) -> Node3D:
	var crater := Node3D.new()
	parent.add_child(crater)
	var meshes: Dictionary = _crater_meshes[_rng.randi() % _crater_meshes.size()]
	_part(crater, meshes.bowl, "bowl")
	# The rim casts, so that its shadow falls into the hole.
	_part(crater, meshes.rim, "rim").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return crater


# The materials the craters' holes go through (level3d_holes.gdshaderinc) --
# the ground's, the hard ground's, the tyre marks', the lines painted on the
# ground -- which the preview hands over; the ground's paint the scorches as
# well (level3d_scorch.gdshaderinc). The holes are told every frame, from the
# craters' nodes as they are then: a round's crater growing in, a building's
# shrunk to nothing until the destruction shows it. The scorches when there is
# one more or none.
var ground_materials: Array[ShaderMaterial] = []
var _holes_told := PackedFloat32Array()
var _scorches_told := false
const HOLES := 64                # level3d_holes.gdshaderinc's


func _process(_delta: float) -> void:
	_push_ground()


func _push_ground() -> void:
	if not _scorches_told:
		_scorches_told = true
		var scorches := PackedVector4Array(_scorches)
		scorches.resize(SCORCHES_KEPT)
		for material in ground_materials:
			material.set_shader_parameter("scorch_count", _scorches.size())
			material.set_shader_parameter("scorch_place", scorches)
	var places := PackedVector4Array()
	var sizes := PackedVector2Array()
	var told := PackedFloat32Array()
	for crater in _craters:
		var node: Node3D = crater.node
		if places.size() == HOLES or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var axes := node.global_transform.basis
		var across := axes.x.length()
		var along := axes.z.length()
		if across < 1e-3 or along < 1e-3:
			continue
		var origin := node.global_transform.origin
		# Its turn about y, as its local x lies in the world.
		var place := Vector4(origin.x, origin.z, axes.x.x / across, -axes.x.z / across)
		places.append(place)
		sizes.append(Vector2(across, along))
		told.append_array([place.x, place.y, place.z, place.w, across, along])
	if told == _holes_told:
		return
	_holes_told = told
	var count := places.size()
	places.resize(HOLES)
	sizes.resize(HOLES)
	for material in ground_materials:
		material.set_shader_parameter("crater_count", count)
		material.set_shader_parameter("crater_place", places)
		material.set_shader_parameter("crater_size", sizes)


# A building's crater, which the preview makes where its blast scorched the
# ground: it stays until the building is put back (remove_ruin_craters), no
# round grows it, and the rounds' craters it lands over are gone.
func add_ruin_crater(ruin: String, node: Node3D, centre: Vector2, radii: Vector2, angle: float,
		height: float) -> void:
	var crater := {"node": node, "centre": centre, "radii": radii, "angle": angle,
			"height": height, "ruin": ruin}
	for other in _craters.duplicate():
		if other.ruin == "" and centre.distance_to(other.centre) < other.radii.x + _foot(crater, other.centre):
			(other.node as Node3D).queue_free()
			_craters.erase(other)
	_craters.append(crater)


func remove_ruin_craters(ruin: String) -> void:
	_craters = _craters.filter(func(c): return c.ruin != ruin)


# A crater's part: the material on first, for the preview's _toon.
func _part(crater: Node3D, mesh: Mesh, material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _materials[material]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crater.add_child(node)
	return node


# How far out from its middle `at` is, in the crater's radii: 1 on its outer
# foot, whichever way.
static func _spread(crater: Dictionary, at: Vector2) -> float:
	var local: Vector2 = (at - crater.centre).rotated(crater.angle) / crater.radii
	return local.length()


# How far the crater's outer foot is from its middle, the way `towards` lies.
static func _foot(crater: Dictionary, towards: Vector2) -> float:
	var way: Vector2 = (towards - crater.centre).rotated(crater.angle)
	if way.length_squared() < 1e-8:
		return minf(crater.radii.x, crater.radii.y)
	way = way.normalized() / crater.radii
	return 1.0 / way.length()


# How much the craters raise or lower the ground at x, z, for what goes over
# them: their rims and the bowls inside (Level3DFx.crater_profile).
func crater_height(x: float, z: float) -> float:
	var at := Vector2(x, z)
	var height := 0.0
	for crater in _craters:
		height += Level3DFx.crater_profile(_spread(crater, at)) * crater.height
	return height


# Whether a disc of radius `size` at `at` lies on ground that can be dug --
# not the water, not the hard ground -- all round, within CRATER_STEP of its
# height: sampled at eight points of the rim.
func _fits(at: Vector3, size: float) -> bool:
	for i in 8:
		var a := TAU * i / 8.0
		var there: Dictionary = ground.call(at.x + size * cos(a), at.z + size * sin(a))
		if not there.hit or there.kind in ["water", "hard"] or absf(there.height - at.y) > CRATER_STEP:
			return false
	return true


# The rounds' craters and scorches; a building's craters go when it is put back.
func clear_craters() -> void:
	for crater in _craters:
		if crater.ruin == "":
			(crater.node as Node3D).queue_free()
	_craters = _craters.filter(func(c): return c.ruin != "")
	_scorches.clear()
	_scorches_told = false
	for bit in _rubble_bits:
		bit.queue_free()
	_rubble_bits.clear()


# What a rocket knocks off a wall or a building (_explode): bits of it, in its
# colour a shade darker so they read against it, thrown out off the face and
# falling to whatever is under them -- the ground at its foot, mostly, or the
# top of a wall -- where they stay. `surface` is asked as they fall, so that
# one over a bunker lands on it rather than in it.
func _rubble(at: Vector3, normal: Vector3, colour: Color) -> void:
	var key := "rubble_%s" % colour.to_html(false)
	if not _materials.has(key):
		_materials[key] = _lit(colour.darkened(0.2))
	var out_flat := Vector3(normal.x, 0.0, normal.z)
	for i in _rng.randi_range(RUBBLE.x, RUBBLE.y):
		var bit := _instance(_chip_mesh, key)
		var size := _rng.randf_range(RUBBLE_SIZE.x, RUBBLE_SIZE.y)
		var shape := Vector3(size * _rng.randf_range(0.8, 1.3), size * _rng.randf_range(0.5, 0.8),
				size * _rng.randf_range(0.8, 1.3))
		bit.scale = shape
		var velocity := (out_flat * 1.2 + Vector3(_rng.randf_range(-0.7, 0.7), _rng.randf_range(0.3, 0.9),
				_rng.randf_range(-0.7, 0.7))).normalized() * _rng.randf_range(1.2, 2.6)
		var from := at + normal * 0.05
		# Where it comes down, stepped along its fall.
		var land := 1.5
		var t := 0.02
		while t < 1.5:
			var p := from + velocity * t + Vector3.DOWN * 4.9 * t * t
			var under: Dictionary = surface.call(p.x, p.z)
			if velocity.y - 9.8 * t < 0.0 and (not under.hit or p.y <= under.height + shape.y * 0.5):
				land = t
				break
			t += 0.02
		var spin := Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
		var rest := Vector3(0.0, _rng.randf() * TAU, 0.0)
		var fly := func(s: float):
			var p := from + velocity * s + Vector3.DOWN * 4.9 * s * s
			if s >= land:
				var under: Dictionary = surface.call(p.x, p.z)
				p.y = (under.height if under.hit else p.y) + shape.y * 0.5
			bit.global_position = p
			bit.rotation = rest if s >= land else spin * s
		fly.call(0.0)
		var tween := bit.create_tween()
		tween.tween_method(fly, 0.0, land, land)
		_rubble_bits.append(bit)
	while _rubble_bits.size() > RUBBLE_KEPT:
		_rubble_bits.pop_front().queue_free()


# A thin smoke going up from a rocket's soot for a while after the blast.
func _smoulder(at: Vector3) -> void:
	var tween := create_tween()
	var puffs := int(SMOULDER_TIME / SMOULDER_EVERY)
	tween.tween_interval(EXPLOSION_TIME)
	for i in puffs:
		var left := 1.0 - float(i) / puffs
		tween.tween_callback(func():
			_puff(at + Vector3(_rng.randf_range(-0.05, 0.05), 0.0, _rng.randf_range(-0.05, 0.05)),
					lerpf(0.08, 0.2, left) * _rng.randf_range(0.8, 1.2), "smoke"))
		tween.tween_interval(SMOULDER_EVERY)


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


# Coloured by its mesh's vertices, the crater's rim and bowl; the rim is
# drawn round, the bowl is seen through the ground and is not.
static func _painted(outlined: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	return Level3DFx.contour(material) if outlined else material


static func _lit(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	# What is lit is drawn round, as the models are; what glows is not.
	return Level3DFx.contour(material)


# The exhaust, long along the rocket's axis whichever way the model runs.
static func _stretch_flame(flame: MeshInstance3D, axis: Vector3, length: float) -> void:
	var along := Basis(Quaternion(Vector3.RIGHT, axis)) if Vector3.RIGHT.cross(axis).length() > 1e-5 \
			else Basis.from_euler(Vector3(0, PI if axis.x < 0.0 else 0.0, 0))
	flame.basis = along * Basis.from_scale(Vector3(length, 0.1, 0.1))
