# A burning wreck's fire and smoke, drawn in the models' own look: BlenderMCP's
# CelBurn (BlenderMCP/godot/scripts/CelBurn.cs) and its column, on the
# preview's world and light. The mission's end (Level3DVictory) burns the
# boss's wrecks with it.
#
#   * The flames: one quad over the fire's ports, facing the eye and upright
#     in the world, stretched by 1 / cos of the camera's pitch so that it
#     stands as tall on the screen; its tongues one field
#     (level3d_flame.gdshader). The quad's foot is under the ports, so the
#     deck in front hides it.
#   * The smoke: one cloud (Level3DCloud) of `puffs` puffs rising off the top
#     of the fire, swelling, blown downwind as they climb, eaten from the rim
#     from ERODE_FROM of their life. Closed form, as CelBurn's: every puff is
#     arithmetic on its index and the clock, its age a share of its own loop,
#     so the column has no first frame and a shot repeats to the pixel. Its
#     puffs are born evenly, a little shaken, and each is a share of the
#     column's height and of its width at the top.
#   * The fire's light: an omni light over the ports, flickering on three
#     sines, with no falloff but its range's -- the two tones step it into a
#     warm band on the deck and the smoke's foot, which seats the fire.
#
# Lengths are shares of `hull`, the wreck's length in metres, as CelBurn's are
# of the hull's on its board. What CelBurn has and this has not, yet: the fire
# coming up and going (here it burns, as a wreck at the mission's end has for
# a while), the scorch painted round the ports, the turret's stencil, the
# douse.
class_name Level3DBurn
extends Node3D

const FLAME_SHADER := preload("res://src/game3d/shaders/level3d_flame.gdshader")
const TONGUES := 4
const MAX_PORTS := 4

# The flames, hull lengths: a tongue's life, s; its width and height at birth;
# how far it rises over its life; how far round a port the tongues are born.
const TONGUE_LIFE := 0.9
const TONGUE := Vector2(0.23, 0.35)
const TONGUE_RISE := 0.20
const PORT_SPREAD := 0.06
# The fire's light: colour, energy, reach in hull lengths.
const GLOW_COLOUR := Color(1.0, 0.52, 0.22)
const GLOW_ENERGY := 0.9
const GLOW_REACH := 0.75
# The column: a puff's life, s; its width at birth and at the top, as a share
# of the hull and of the column's height; where it is born over the ports,
# hull lengths -- at the fire's top, out of it: born at the deck, a dark puff
# sat in the flame like a hole in it; when it starts to be eaten, a share of
# its life; its grey, burning; how far apart two puffs still flow into one,
# hull lengths, and the colour their grey is taken in.
const PUFF_LIFE := 3.2
const PUFF_BORN := 0.15
const PUFF_TOP := 0.32
const SMOKE_SEAT := 0.30
const ERODE_FROM := 0.6
const SOOT_TONE := 0.26
const BLEND := 0.03
const TINT := Color(0.96, 0.95, 1.0)

# Set before `build`: the wreck's length, metres; the ports, world; each
# port's tongues against TONGUE (an open turret ring burns bigger than a
# grille, CelBurn's RingFire 1.3); the column's height, metres, and its puffs;
# where the wind takes its top, per metre of height, world.
var hull := 1.36
var ports: Array[Vector3] = []
var sizes: Array[float] = []
var column := 2.0
var puffs := 34
var drift := Vector3(0.45, 0.0, -0.2)
# Whether there is fire, or smoke alone; a seed, so that two columns are not
# one column twice.
var flames := true
var seed := 0

var _clock := 0.0
var _flame: MeshInstance3D
var _flame_look: ShaderMaterial
var _cloud: Level3DCloud
var _glow: OmniLight3D


func build() -> void:
	if flames:
		_flame_look = ShaderMaterial.new()
		_flame_look.shader = FLAME_SHADER
		_flame = MeshInstance3D.new()
		_flame.name = "Tongues"
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		quad.center_offset = Vector3(0.0, 0.5, 0.0)
		_flame.mesh = quad
		_flame.material_override = _flame_look
		_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_flame)
		_glow = OmniLight3D.new()
		_glow.name = "Glow"
		_glow.light_color = GLOW_COLOUR
		_glow.omni_range = GLOW_REACH * hull
		# No falloff but the range's window, and no shadow: under
		# Compatibility an omni light's shadow washed what it did not light out
		# pale (CelBurn's note).
		_glow.omni_attenuation = 0.0
		_glow.shadow_enabled = false
		add_child(_glow)
	var ink := Level3DHull.pixels(Level3DHull.Kind.STAGE)
	_cloud = Level3DCloud.new(self, "Smoke", TINT, BLEND * hull, ink)
	# The column's puffs already up, as on a wreck that has burnt a while.
	_clock = 50.0 + seed * 7.3


# A frame: the clock on by `delta`, every tongue and puff put where it is,
# facing `eye`, the camera's basis.
func tick(delta: float, eye: Basis) -> void:
	_clock += delta
	if ports.is_empty():
		return
	var mid := Vector3.ZERO
	for p in ports:
		mid += p
	mid /= ports.size()
	if flames:
		_tongues(eye)
		var flick := 0.78 + 0.12 * sin(_clock * 7.3) + 0.07 * sin(_clock * 13.1 + 1.7) + 0.05 * sin(_clock * 23.0 + 0.4)
		_glow.global_position = mid + Vector3.UP * (0.16 * hull)
		_glow.light_energy = GLOW_ENERGY * flick
	_column(mid + Vector3.UP * ((SMOKE_SEAT if flames else 0.05) * hull), eye)


# The flames' quad: over the ports, facing the eye, upright, its foot under
# them; the ports handed to the shader in hull lengths from its foot, and how
# far each stands in front of it along the eye's ray.
func _tongues(eye: Basis) -> void:
	var right := eye.x.normalized()
	var up := eye.y.normalized()
	var n := mini(ports.size(), MAX_PORTS)
	var mid := Vector3.ZERO
	for i in n:
		mid += ports[i]
	mid /= n
	var lo := 0.0
	var hi := 0.0
	for i in n:
		var y := (ports[i] - mid).dot(up)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	mid += up * lo
	var big := 1.0
	for i in n:
		big = maxf(big, _size(i))
	# Under the ports: a tongue's foot reaches 0.4 of its height below its
	# base, and its height is up to 1.69 of TONGUE's.
	var foot := 0.4 * 1.69 * TONGUE.y * big
	var origin := mid - up * (foot * hull)
	var at := PackedVector2Array()
	at.resize(MAX_PORTS)
	var wide := 0.0
	for i in n:
		var rel := ports[i] - origin
		at[i] = Vector2(rel.dot(right), rel.dot(up)) / hull
		wide = maxf(wide, absf(at[i].x))
	# Room for the widest tongue either side and the tallest over its rise.
	var w := 2.0 * (wide + PORT_SPREAD + TONGUE.x * big * 1.3 * (0.96 + 0.4))
	var h := foot + (hi - lo) / hull + TONGUE_RISE + TONGUE.y * big * 1.69
	# Upright in the world, stretched by 1 / cos so that it spans the same
	# screen height: in the screen's plane it leant away from the eye.
	var c := maxf(Vector3.UP.dot(up), 0.2)
	var facing := right.cross(Vector3.UP).normalized()
	var seat := mid - Vector3.UP * (foot * hull / c)
	_flame.global_transform = Transform3D(Basis(right * (w * hull), Vector3.UP * (h * hull / c), -facing), seat)
	var back := eye.z.normalized()
	var across := back.dot(facing)
	if absf(across) < 1e-3:
		across = 1e-3
	var near := PackedFloat32Array()
	near.resize(MAX_PORTS)
	var size := PackedFloat32Array()
	size.resize(MAX_PORTS)
	for i in n:
		near[i] = (ports[i] - seat).dot(facing) / across
		size[i] = _size(i)
	_flame_look.set_shader_parameter("size", Vector2(w, h))
	_flame_look.set_shader_parameter("ports", at)
	_flame_look.set_shader_parameter("count", n)
	_flame_look.set_shader_parameter("time", _clock)
	_flame_look.set_shader_parameter("heat", 1.0)
	_flame_look.set_shader_parameter("life", TONGUE_LIFE)
	_flame_look.set_shader_parameter("tongue", TONGUE)
	_flame_look.set_shader_parameter("rise", TONGUE_RISE)
	_flame_look.set_shader_parameter("spread", PORT_SPREAD)
	_flame_look.set_shader_parameter("port_near", near)
	_flame_look.set_shader_parameter("port_size", size)
	_flame_look.set_shader_parameter("hull", hull)


func _size(i: int) -> float:
	return sizes[i] if i < sizes.size() else 1.0


# The column off `seat`: each puff up fast off the fire and slowing, bent by
# the wind as it climbs, swaying as wide as it is, swelling from PUFF_BORN of
# the hull to PUFF_TOP of the column, eaten from ERODE_FROM of its life.
func _column(seat: Vector3, eye: Basis) -> void:
	_cloud.clear()
	var count := mini(puffs, Level3DCloud.POOL)
	for k in count:
		var loop := _clock / PUFF_LIFE + (k + 0.35 * _hash(k, 17 + seed)) / count
		var a := loop - floorf(loop)
		var lap := int(floorf(loop))
		var h1 := _hash(k * 97 + lap, 19 + seed)
		var h2 := _hash(k * 97 + lap, 23 + seed)
		var rise := 1.0 - pow(1.0 - a, 2.2)
		var bend := pow(a, 1.4)
		var wob := 0.20 * hull * sqrt(a)
		var at := seat + Vector3.UP * (column * rise) + drift * (column * bend) \
				+ Vector3(cos(h1 * TAU), 0.0, sin(h1 * TAU)) * wob
		var pop := smoothstep(0.0, 0.07, a)
		var d := lerpf(PUFF_BORN * hull, PUFF_TOP * column, a) * (0.6 + 0.8 * h2) * pop
		var erode := smoothstep(ERODE_FROM, 1.0, a)
		if d <= 0.0:
			continue
		_cloud.add(at, 0.5 * d, SOOT_TONE, h2, minf(erode, 1.0), a)
	_cloud.draw(eye)


# CelPuff.Hash: a puff's seed off its index and lap, the same every run.
static func _hash(k: int, salt: int) -> float:
	var h := ((k * 73856093) ^ (salt * 19349663) ^ 0x9E3779B9) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFFFF) / 16777215.0
