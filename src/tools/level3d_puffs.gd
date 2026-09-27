# The exhaust and the dust of everything that drives on the 3D stage 1
# preview: the player's jeep or BTR (Level3DBtr.puffs), the brown tanks' and
# the boss's (their puffs), and the boats' outboards, which raise no dust on
# the water; and the smoke of what burns, the tanks' wrecks and the damage
# they take. Nothing here is from the game, which draws none of it.
#
# They were parts of the tanks' models once: three lumps to each exhaust and
# to each track, on bones of their own, looping in a clip of their own
# (jackal_tank.py). So they went where the tank went -- a trail of dust the
# same length whatever it did, swinging round with the hull as it turned on
# the spot -- the same three puffs every second on every tank, and the
# sand's colour on the helipad and in the forest. Here a puff is left in the
# air where it was made, and the vehicle drives on out of it: the models keep
# only the bones, Exhaust.L/R and Dust.L/R, to say where from.
#
# The exhaust goes by time: a puff out of each mouth every IDLE_EVERY seconds
# standing, every DRIVE_EVERY under way, bigger, rising less and blown back
# further. The dust goes by the ground covered: a puff every DUST_STEP metres
# a track's back end or a rear wheel moves over the ground -- so none while
# it stands, more the faster it goes, and a tank turning on the spot raises
# it too -- in the colour of that ground, as the gun's dust is
# (level3d_gun.gd): sand, the hard ground's concrete, the forest's earth.
# None off the water, nor off a wheel in the air.
#
# The smoke went the same way. A wreck's column, a hit tank's thinner one and
# the wisps out of the boss's breaches were five or two lumps to a source on
# bones of their own, looping in Burn, Smoke and Breached: the column leant
# the way the hull pointed, since it was in the hull's own frame, and came up
# the same five puffs a second on every wreck. Here a source says how often
# and how big, and the puffs rise from it and are blown downwind (WIND),
# whichever way the wreck lies.
#
# The puffs are the effects' faceted balls, low poly and opaque, cel-shaded
# and drawn round (level3d_fx.gd): a puff swells and shrinks away instead of
# fading, as every effect of the preview's does.
class_name Level3DPuffs
extends Node3D

const IDLE_EVERY := 0.42
const DRIVE_EVERY := 0.2
# How far off its time a puff may come, as a share of the interval: two
# exhausts that started together soon do not puff in step.
const JITTER := 0.35
# A puff's life, seconds; how high an exhaust puff rises and how far back it
# is blown over it, level metres, standing and under way; how big it grows
# under way, as a share of its size.
const EXHAUST_LIFE := Vector2(0.8, 1.05)
const EXHAUST_RISE := Vector2(0.28, 0.16)
const EXHAUST_BACK := Vector2(0.04, 0.14)
const EXHAUST_BIG := 1.35
# The smoke's wind, level x, z, as the sea's swell drifts (level3d_ocean.
# gdshader): a column is blown this way by SMOKE_BLOWN of the height it
# rises, as the models' leant 0.55 of theirs, and swayed by SMOKE_SWAY of a
# puff's size. How far a smoke puff may come off its time, as JITTER.
const WIND := Vector3(0.868, 0.0, 0.496)
const SMOKE_BLOWN := 0.5
const SMOKE_SWAY := 0.35
const SMOKE_JITTER := 0.2
# _grow's highest, which a smoke source's `size` is: its puffs at their
# biggest.
const GROW_PEAK := 0.76
const DUST_STEP := 0.28
const DUST_LIFE := Vector2(0.6, 0.85)
const CLOUD_LIFE := Vector2(0.9, 1.4)
# How much further a cloud's puffs are blown than a wheel's (DUST_DRIFT):
# puffed out from a line, they did not part and stood in one long lump.
const CLOUD_SPREAD := 2.2
# How far a dust puff drifts from where it was raised, and how high it lifts,
# as shares of its size.
const DUST_DRIFT := 1.4
const DUST_LIFT := 0.9
# A contact this far over the ground under it raises none.
const AIRBORNE := 0.08
# A dust contact that jumps further than this in a tick has been put
# somewhere else -- the player put back -- and raises none for it.
const BREAK := 0.6

# `ground.call(x, z)` -> {"height", "kind", "hit"}, the preview's ground layer.
var ground: Callable
# Each is called once a tick and gives what puffs now:
#   {"key", "kind": "exhaust", "at" (Vector3, the mouth), "back" (Vector3,
#    level, the way the vehicle's tail points), "size" (level metres, a
#    puff's radius standing), "working" (0 standing .. 1 under way)}
#   {"key", "kind": "dust", "at" (Vector3, where it touches the ground),
#    "size"}
#   {"key", "kind": "smoke", "at" (Vector3, where it rises from), "size"
#    (level metres, a puff's radius at its biggest), "every" (seconds
#    between puffs), "life" (seconds), "rise" (level metres over its life),
#    "colour" ("smoke", the wrecks' dark, or "exhaust", the wisps' grey)}
# A key that is missing is forgotten: its next puff starts afresh.
var sources: Array = []

var _rng := RandomNumberGenerator.new()
var _meshes: Array[ArrayMesh] = []
var _materials := {}
var _next := {}         # exhaust key -> seconds to its next puff
var _last := {}         # dust key -> [where it was, metres since its last puff]
var _seen := {}


func _ready() -> void:
	# Seeded, so that a --shot is the same shot every time.
	_rng.seed = 5
	for i in 3:
		_meshes.append(Level3DFx.ball(1, 0.12, 11 + i))
	_materials = {
		# The tanks' MT_Smoke, which their exhaust was.
		"exhaust": _lit(Color8(132, 130, 126)),
		# The tanks' MT_SmokeDark, which their wrecks' smoke was.
		"smoke": _lit(Color8(58, 56, 54)),
		"ground": _lit(Color(0.93, 0.76, 0.48)),
		"hard": _lit(Color(0.66, 0.65, 0.62)),
		"forest": _lit(Color(0.52, 0.42, 0.26)),
	}


func reset() -> void:
	_next.clear()
	_last.clear()
	for child in get_children():
		child.queue_free()


func tick() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	_seen.clear()
	for source in sources:
		for emitter in source.call():
			_seen[emitter.key] = true
			if emitter.kind == "exhaust":
				_exhaust(emitter, dt)
			elif emitter.kind == "smoke":
				_smoke(emitter, dt)
			else:
				_dust(emitter)
	for table in [_next, _last]:
		for key in table.keys():
			if not _seen.has(key):
				table.erase(key)


func _exhaust(e: Dictionary, dt: float) -> void:
	var working: float = e.working
	var every := lerpf(IDLE_EVERY, DRIVE_EVERY, working)
	var left: float = _next.get(e.key, _rng.randf() * every) - dt
	if left > 0.0:
		_next[e.key] = left
		return
	_next[e.key] = every * (1.0 + _rng.randf_range(-JITTER, JITTER))
	var at: Vector3 = e.at
	var back: Vector3 = e.back
	var size: float = e.size * lerpf(1.0, EXHAUST_BIG, working) * _rng.randf_range(0.85, 1.15)
	var rise := lerpf(EXHAUST_RISE.x, EXHAUST_RISE.y, working)
	var blown := back * lerpf(EXHAUST_BACK.x, EXHAUST_BACK.y, working)
	var sway := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * size * 0.6
	var life := _rng.randf_range(EXHAUST_LIFE.x, EXHAUST_LIFE.y)
	var puff := _puff("exhaust")
	var spin := _rng.randf() * TAU
	var drift := func(t: float):
		var k := t / life
		var p := at + blown * k + sway * k + Vector3.UP * rise * pow(k, 0.8)
		puff.global_transform = Transform3D(Basis(Vector3.UP, spin + k).scaled(Vector3.ONE * maxf(size * _grow(k), 0.001)), p)
	_start(puff, drift, life)


# Smoke goes by time, as the exhaust does, and rises from where it was made:
# the source goes on without it.
func _smoke(e: Dictionary, dt: float) -> void:
	var every: float = e.every
	var left: float = _next.get(e.key, _rng.randf() * every) - dt
	if left > 0.0:
		_next[e.key] = left
		return
	_next[e.key] = every * (1.0 + _rng.randf_range(-SMOKE_JITTER, SMOKE_JITTER))
	var at: Vector3 = e.at
	var size: float = e.size / GROW_PEAK * _rng.randf_range(0.85, 1.15)
	var rise: float = e.rise * _rng.randf_range(0.9, 1.1)
	var blown := WIND * rise * SMOKE_BLOWN
	var sway := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * size * GROW_PEAK * SMOKE_SWAY
	var life: float = e.life * _rng.randf_range(0.9, 1.1)
	var puff := _puff(e.colour)
	var spin := _rng.randf() * TAU
	var billow := func(t: float):
		var k := t / life
		# Up at once and slowing, blown over more the higher it is.
		var p := at + Vector3.UP * rise * pow(k, 0.8) + (blown + sway) * k * k
		puff.global_transform = Transform3D(Basis(Vector3.UP, spin + k).scaled(Vector3.ONE * maxf(size * _grow(k), 0.001)), p)
	_start(puff, billow, life)


func _dust(e: Dictionary) -> void:
	var at: Vector3 = e.at
	var under: Dictionary = ground.call(at.x, at.z)
	if not under.hit or under.kind == "water" or at.y - under.height > AIRBORNE:
		_last.erase(e.key)
		return
	at.y = under.height
	var last: Array = _last.get(e.key, [at, _rng.randf() * DUST_STEP])
	var run := Vector2(at.x - last[0].x, at.z - last[0].z).length()
	if run > BREAK:
		run = 0.0
	var gone: float = last[1] + run
	_last[e.key] = [at, fmod(gone, DUST_STEP)]
	if gone < DUST_STEP:
		return
	var size: float = e.size * _rng.randf_range(0.8, 1.2)
	var way := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
	_dust_puff(at, size, way * size * DUST_DRIFT * _rng.randf_range(0.5, 1.0), _ground_material(under),
			_rng.randf_range(DUST_LIFE.x, DUST_LIFE.y))


# A cloud thrown up off a line on the ground at once -- the Chinook's ramp
# coming down on the sand (Level3DChinook) -- `count` puffs `size` big from
# `at` - `across` to `at` + `across`, blown out along `out` and away to either
# end, and living CLOUD_LIFE, longer than a wheel's. None off the water.
func cloud(at: Vector3, across: Vector3, out: Vector3, size: float, count: int) -> void:
	for i in count:
		var k := float(i) / maxf(count - 1, 1) * 2.0 - 1.0
		var p := at + across * k
		var under: Dictionary = ground.call(p.x, p.z)
		if not under.hit or under.kind == "water":
			continue
		p.y = under.height
		var s := size * _rng.randf_range(0.6, 1.3)
		var drift := (out * _rng.randf_range(0.4, 1.3) + across.normalized() * k * _rng.randf_range(0.5, 1.2)) \
				* s * DUST_DRIFT * CLOUD_SPREAD
		_dust_puff(p, s, drift, _ground_material(under), _rng.randf_range(CLOUD_LIFE.x, CLOUD_LIFE.y))


func _ground_material(under: Dictionary) -> String:
	return under.kind if under.kind in ["hard", "forest"] else "ground"


# One puff of dust on the ground at `at`, drifting `drift` over its life.
func _dust_puff(at: Vector3, size: float, drift: Vector3, material: String, life: float) -> void:
	var puff := _puff(material)
	var spin := _rng.randf() * TAU
	var settle := func(t: float):
		var k := t / life
		# Swells in the first fifth, then shrinks away, low over the ground
		# and flattened, as dust that does not rise as smoke does.
		var r := size * (1.0 - pow(1.0 - minf(k * 5.0, 1.0), 3.0)) * (1.0 - pow(maxf(k - 0.2, 0.0) / 0.8, 2.0))
		var p := at + drift * (1.0 - pow(1.0 - k, 2.0)) + Vector3.UP * (r * 0.4 + size * DUST_LIFT * k * 0.3)
		puff.global_transform = Transform3D(Basis(Vector3.UP, spin).scaled(Vector3(1.0, 0.7, 1.0) * maxf(r, 0.001)), p)
	_start(puff, settle, life)


# A puff's size over its life, k 0..1: out of nothing, swelling, and thinning
# to nothing again -- the curve the tanks' clips grew theirs by.
static func _grow(k: float) -> float:
	return pow(sin(PI * k), 0.7) * (0.45 + 0.55 * k)


func _puff(material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _meshes[_rng.randi() % _meshes.size()]
	node.material_override = _materials[material]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _start(node: Node3D, move: Callable, life: float) -> void:
	move.call(0.0)
	var tween := node.create_tween()
	tween.tween_method(move, 0.0, life, life)
	tween.tween_callback(node.queue_free)


static func _lit(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return Level3DFx.contour(material)
