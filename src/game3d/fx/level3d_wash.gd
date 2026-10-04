# The dust a helicopter's rotors raise off the ground on the 3D stage 1
# preview: the Chinook's (Level3DChinook.wash) as it comes down with the BTR,
# stands with its ramp down and climbs away again. Nothing here is from the
# game, which draws none of it.
#
# It is the title's wash (Level3DSplashLanding's _raise_wash, _hull_edge and
# _thin, and Level3DSplash3D's clouds), but one cloud rolling out from the
# hull, as a helicopter's is, rather than the splash's puffs: thrown out
# along the ground, a ring of puffs spreads apart as it goes, the gaps
# growing with the way gone, so a puff grew with its age and the ring broke
# up into a scatter of lumps round the hull. Here a puff grows with the way
# it has gone instead -- as the ring's round does -- and there are enough of
# them, flowing into one wide enough, that the ring is one body.
#
#   * Below HEIGHT metres over the ground, up to RATE puffs a second, more the
#     lower it is. Not under it but at the edge of its hull, OUT metres out and
#     HOVER_OUT more for each metre it is up, where the air the rotors drive
#     down comes out along the ground from under it: BORN_RADIUS big there,
#     thrown away from the hull at SPEED m/s, slowing over THROW_TIME, and
#     GROW metres bigger for each metre gone.
#   * One cloud a helicopter (Level3DCelCloud): the puffs flowed into one
#     shape, inked once round it and eaten from the rim as they age. Drawn one
#     by one, as Level3DPuffs draws a wheel's, they were a heap of separate
#     balls. Lit by the stage's light as everything else is, in the colour of
#     the ground they came off (Level3DPuffs.COLOURS); none off the water.
#   * The hull thins any puff that comes back into it, as the tank bench's
#     CelSolids thins its by the tanks', rather than let it stand through it.
#
# The hull is the one drawn: in the top view the Chinook is drawn at the
# original's scale for its height, and the dust comes out from under what is
# seen. The puffs move by the tick, so that a --shot is the same shot every
# time, and are drawn at the frame's end, once the camera has moved.
class_name Level3DWash
extends Node3D

const HEIGHT := 2.6
const RATE := 45.0
const OUT := 0.08
const HOVER_OUT := 0.3
const SPEED := Vector2(0.45, 0.8)
const THROW_TIME := 0.8
# A puff's radius at the hull, level metres, and its life, seconds; its
# middle SIT of its radius over the ground -- on it, so that the cloud lies
# along the ground, its lower half drawn on the ground (Level3DCelCloud.
# set_ground), well under the hull: sat a third of its radius up and twice the
# size, it stood over the Chinook -- and rising RISE of it more over its life; carried
# downwind (Level3DPuffs.WIND) at DRIFT m/s. RATE times the mean life is
# about Level3DCelCloud.POOL, the most one cloud draws.
const BORN_RADIUS := Vector2(0.26, 0.36)
const GROW := 0.22
const LIFE := Vector2(1.6, 2.2)
const SIT := 0.0
const RISE := 0.12
const DRIFT := 0.25
# Level3DCelCloud's: flowing into one within BLEND metres, eaten from the rim
# from ERODE_FROM of their life -- the oldest, outermost, so that the
# cloud's front frays as it thins -- popping up over the first POP of it, inked
# INK metres (the effects' contour, Level3DFx.CONTOUR) or INK_PX pixels wide.
const BLEND := 0.26
const ERODE_FROM := 0.45
const POP := 0.06
const INK := Level3DFx.CONTOUR
const INK_PX := 2.0
# The light's edge, sharp: the blended normal turns slowly between two puffs,
# and at the stage's TOON_EDGE the shade's edge was a blur pixels wide.
const TOON := 0.002
# A puff that has moved this far since the ground under it was last asked
# asks again.
const RESAMPLE := 0.25

# `ground.call(x, z)` -> {"height", "kind", "hit"}, the preview's ground layer.
var ground: Callable
var sun: DirectionalLight3D
# Each is called once a tick and gives the wash now, or nothing:
#   {"key", "hull" (Transform3D, the hull drawn, model metres to level),
#    "boxes" (Array[AABB], the hull in its own metres, Level3DChinook.HULL_BOXES)}
var sources: Array[Callable] = []

var _rng := RandomNumberGenerator.new()
var _puffs: Array[Dictionary] = []
var _clouds := {}       # key -> Level3DCelCloud
var _owed := {}         # key -> puffs owed, a share of one
var _hulls := {}        # key -> the source this tick, for _thin
var _pending := false


func _ready() -> void:
	_rng.seed = 7


func reset() -> void:
	_puffs.clear()
	_owed.clear()
	_hulls.clear()
	for key in _clouds:
		(_clouds[key] as Level3DCelCloud).hide()


func tick() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	_hulls.clear()
	for source in sources:
		var wash: Dictionary = source.call()
		if not wash.is_empty():
			_hulls[wash.key] = wash
			_raise(wash, dt)
	for i in range(_puffs.size() - 1, -1, -1):
		var puff := _puffs[i]
		puff.age += dt
		if puff.age >= puff.life:
			_puffs.remove_at(i)
			continue
		var at := _where(puff)
		if Vector2(at.x - puff.asked.x, at.z - puff.asked.y).length() > RESAMPLE:
			var under: Dictionary = ground.call(at.x, at.z)
			if not under.hit or under.kind == "water":
				_puffs.remove_at(i)
				continue
			puff.floor = under.height
			puff.asked = Vector2(at.x, at.z)


# Drawn at the frame's end: put off from the tick, the draw ran before the
# camera had moved for the frame, and the cloud was cut off at its edge.
func _process(_delta: float) -> void:
	if not _pending:
		_pending = true
		_draw.call_deferred()


# Puffs round the hull, more the lower it is, as many as are owed this tick.
func _raise(wash: Dictionary, dt: float) -> void:
	var hull: Transform3D = wash.hull
	var under: Dictionary = ground.call(hull.origin.x, hull.origin.z)
	var height: float = hull.origin.y - under.height
	if not under.hit or height > HEIGHT:
		_owed.erase(wash.key)
		return
	var owed: float = _owed.get(wash.key, 0.0) + RATE * (1.0 - maxf(height, 0.0) / HEIGHT) * dt
	var out_by := OUT + HOVER_OUT * maxf(height, 0.0)
	while owed >= 1.0:
		owed -= 1.0
		var edge := _hull_edge(hull, wash.boxes, out_by)
		var at: Vector3 = edge[0]
		var below: Dictionary = ground.call(at.x, at.z)
		if not below.hit or below.kind == "water":
			continue
		_cloud(wash.key).tint(Level3DPuffs.COLOURS.get(below.kind, Level3DPuffs.COLOURS.ground), TOON)
		var way: Vector3 = edge[1]
		_puffs.append({
			"key": wash.key,
			"at": Vector3(at.x, below.height, at.z),
			"throw": way * _rng.randf_range(SPEED.x, SPEED.y) * 2.0,
			"drift": Level3DPuffs.WIND * DRIFT,
			"radius": _rng.randf_range(BORN_RADIUS.x, BORN_RADIUS.y),
			"life": _rng.randf_range(LIFE.x, LIFE.y),
			"age": 0.0,
			"seed": _rng.randf(),
			"floor": below.height,
			"asked": Vector2(at.x, at.z),
		})
	_owed[wash.key] = owed


# Where a puff is now on the ground: blown out from the hull, slowing, and
# carried off downwind.
static func _where(puff: Dictionary) -> Vector3:
	var age: float = puff.age
	return puff.at + puff.drift * age + puff.throw * THROW_TIME * (1.0 - exp(-age / THROW_TIME))


# A point at the edge of the hull on the ground, `out` metres outside it,
# and the way out from there, flat: on the outline of `boxes` seen from above
# -- the Chinook's cabin and sponsons -- by its length, the way out the
# side's own, turned a little from the middle at random so that the puffs off
# one side do not run in a row. Level3DSplashLanding._hull_edge.
func _hull_edge(hull: Transform3D, boxes: Array, out: float) -> Array:
	var basis := hull.basis
	for attempt in 16:
		var box: AABB = boxes[_rng.randi() % boxes.size()]
		var a := Vector2(box.position.x, box.position.z)
		var b := Vector2(box.end.x, box.end.z)
		var side := b - a
		var t := _rng.randf() * 2.0 * (side.x + side.y)
		var p: Vector2
		var n: Vector2
		if t < side.x:
			p = Vector2(a.x + t, a.y)
			n = Vector2(0.0, -1.0)
		elif t < side.x + side.y:
			p = Vector2(b.x, a.y + t - side.x)
			n = Vector2(1.0, 0.0)
		elif t < 2.0 * side.x + side.y:
			p = Vector2(b.x - (t - side.x - side.y), b.y)
			n = Vector2(0.0, 1.0)
		else:
			p = Vector2(a.x, b.y - (t - 2.0 * side.x - side.y))
			n = Vector2(-1.0, 0.0)
		# On the outline of the boxes together, not inside another one.
		var inside := false
		for other in boxes:
			if other != box and p.x > other.position.x + 0.01 and p.x < other.end.x - 0.01 \
					and p.y > other.position.z + 0.01 and p.y < other.end.z - 0.01:
				inside = true
		if inside:
			continue
		var at := hull * Vector3(p.x, 0.0, p.y)
		var way := basis * Vector3(n.x, 0.0, n.y)
		way.y = 0.0
		var spread := basis * Vector3(p.x, 0.0, p.y)
		spread.y = 0.0
		way = (way.normalized() * 0.75 + spread.normalized() * 0.25
				+ way.normalized().cross(Vector3.UP) * _rng.randf_range(-0.3, 0.3)).normalized()
		return [at + way * out, way]
	var away := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
	return [Vector3(hull.origin.x, 0.0, hull.origin.z) + away * out, away]


# How much of a puff of radius `r` at `at` its own hull leaves: whole while
# its middle is a quarter of its radius outside, none half its radius inside,
# smoothly between -- so that a puff thrown against the hull shrinks into it
# rather than stand through it. Level3DSplashLanding._thin.
func _thin(key: String, at: Vector3, r: float) -> float:
	if not _hulls.has(key):
		return 1.0
	var hull: Transform3D = _hulls[key].hull
	var p := hull.affine_inverse() * at
	var radius := r / hull.basis.get_scale().x
	var inside := INF
	for box: AABB in _hulls[key].boxes:
		var q := (p - box.get_center()).abs() - box.size * 0.5
		var out := Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length()
		inside = minf(inside, out + minf(maxf(q.x, maxf(q.y, q.z)), 0.0))
	return smoothstep(-0.5 * radius, 0.25 * radius, inside)


# The cloud a helicopter's puffs make, made with its first.
func _cloud(key: String) -> Level3DCelCloud:
	if not _clouds.has(key):
		_clouds[key] = Level3DCelCloud.new(self, BLEND, INK, INK_PX, true)
	return _clouds[key]


# The clouds as the camera sees them at the end of the frame. Popping up at
# once, grown with the way gone, sat with their middle over the ground --
# centred on it, the ground's depth cut them in half -- and eaten from the
# rim as they age (Level3DSplash3D's cel clouds).
func _draw() -> void:
	_pending = false
	var lowest := {}
	for key in _clouds:
		(_clouds[key] as Level3DCelCloud).clear()
	for puff in _puffs:
		lowest[puff.key] = minf(lowest.get(puff.key, INF), puff.floor)
		var k: float = puff.age / puff.life
		var gone: float = puff.throw.length() * THROW_TIME * (1.0 - exp(-float(puff.age) / THROW_TIME))
		var size: float = puff.radius + GROW * gone
		var r := size * smoothstep(0.0, POP, k)
		var at := _where(puff)
		var middle := Vector3(at.x, float(puff.floor) + SIT * r + size * RISE * k, at.z)
		_cloud(puff.key).add(middle, r * _thin(puff.key, middle, r), smoothstep(ERODE_FROM, 1.0, k), k,
				float(puff.seed))
	# The viewport's camera: the preview makes its own after this.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var toward := sun.global_transform.basis.z if sun != null else Vector3.UP
	for key in _clouds:
		# The ground under the cloud, which the stage's landing is flat on.
		(_clouds[key] as Level3DCelCloud).set_ground(lowest.get(key, -1e9))
		(_clouds[key] as Level3DCelCloud).draw(camera, toward)
