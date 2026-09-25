# The marks tyres and tracks leave on the 3D stage 1 preview, fading away:
# the player's rear wheels (Level3DBtr.wheel_tracks), and the brown tanks' and
# the boss's tracks (their track_contacts). Nothing here is from the game,
# which leaves no marks.
#
# Each wheel or track is a trail: a strip on the ground, a quad every STEP it
# moves, each quad starting on the edge the last one ended on, so a trail
# bends without seams. The edge at a point is mitred, across the bisector of
# the way in and the way out, so a quad is written a step behind the wheel,
# once the way out is known; an edge cut square to the way in twisted the
# quad on the inside of a sharp turn into a dark bow tie. Its width is the
# tyre's or the track's; each edge sits LIFT over the ground under it. A trail ends where its wheel leaves the
# ground -- up a ramp over a ruin, on the Chinook's ramp -- or jumps further
# than BREAK, as the player does when it is put back.
#
# The fading is level3d_tracks.gdshader's, off the time each vertex was laid,
# so a quad is written once and never touched again. Quads go into meshes of
# CHUNK; only the newest one is rebuilt, when it grows, and a mesh is freed
# when the newest quad in it has faded.
#
# Decals would be the other way to do it, and the Compatibility renderer the
# project uses has none; a mark map the ground's shaders read would mean
# replacing every material the level's glb brings.
class_name Level3DTracks
extends Node3D

const SHADER := preload("res://src/tools/level3d_tracks.gdshader")
const STEP := 0.08
const BREAK := 0.6
const LIFT := 0.012
# A contact this far over the ground under it is off it.
const AIRBORNE := 0.08
const HOLD := 5.0 / 3.0
const FADE := 5.0
const CHUNK := 256

# `ground.call(x, z)` -> {"height", "hit", ...}, the preview's ground layer.
var ground: Callable
# Each is called once a tick and gives the contacts on the ground now, one
# for every wheel or track that leaves a mark: {"key", "at" (Vector3, the
# middle of where it touches), "width", "pitch" (metres a tread repeats in),
# "tread" (1 a track, 0 a tyre)}. A key that is missing ends its trail.
var sources: Array = []

var _material: ShaderMaterial
var _clock := 0.0
var _trails := {}       # key -> Trail
var _chunks: Array[Chunk] = []


class Trail:
	var at: Vector3             # the wheel's last point
	var back: Vector3           # the one before, where the next quad starts
	var has_back := false
	var left := Vector3.ZERO    # the edge at `back`, once there is one
	var right := Vector3.ZERO
	var across := Vector3.ZERO  # half the width, pointing left
	var along := 0.0            # metres from where it began to `back`
	var seen := false


class Chunk:
	var node: MeshInstance3D
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var births := PackedVector2Array()
	var quads := 0
	var newest := 0.0
	var dirty := false


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("hold", HOLD)
	_material.set_shader_parameter("fade", FADE)


# The one material every chunk draws with, for what tells it where the
# craters' holes are (Level3DLauncher.ground_materials).
func material() -> ShaderMaterial:
	return _material


func reset() -> void:
	_trails.clear()
	for c in _chunks:
		c.node.queue_free()
	_chunks.clear()


func tick() -> void:
	_clock += 1.0 / Engine.physics_ticks_per_second
	for trail in _trails.values():
		trail.seen = false
	for source in sources:
		for contact in source.call():
			_follow(contact)
	for key in _trails.keys():
		if not _trails[key].seen:
			_trails.erase(key)
	for i in range(_chunks.size() - 1, -1, -1):
		if _chunks[i].newest + HOLD + FADE < _clock:
			_chunks[i].node.queue_free()
			_chunks.remove_at(i)


func _process(_delta: float) -> void:
	_material.set_shader_parameter("now", _clock)
	for c in _chunks:
		if c.dirty:
			_build(c)


func _follow(contact: Dictionary) -> void:
	var at: Vector3 = contact.at
	var under: Dictionary = ground.call(at.x, at.z)
	if not under.hit or at.y - under.height > AIRBORNE:
		return
	at.y = under.height
	var trail: Trail = _trails.get(contact.key)
	if trail == null or Vector2(at.x - trail.at.x, at.z - trail.at.z).length() > BREAK:
		trail = Trail.new()
		trail.at = at
		_trails[contact.key] = trail
	trail.seen = true
	var run := Vector3(at.x - trail.at.x, 0.0, at.z - trail.at.z)
	var length := run.length()
	if length < STEP:
		return
	var half: float = contact.width * 0.5
	var way_out := run / length
	if not trail.has_back:
		# The first step: the edge where it began is square to it.
		trail.back = trail.at
		trail.has_back = true
		trail.across = Vector3.UP.cross(way_out) * half
		trail.left = _on_ground(trail.back + trail.across)
		trail.right = _on_ground(trail.back - trail.across)
		trail.at = at
		return
	var way_in := Vector3(trail.at.x - trail.back.x, 0.0, trail.at.z - trail.back.z)
	var into := way_in.length()
	way_in /= into
	# The mitre, as long as the turn needs to keep the width, up to twice it;
	# past a turn of 120 degrees -- a wheel backing the way it came -- the
	# last edge's way across, which folds the strip rather than twisting it.
	var bisector := way_in + way_out
	var across := trail.across
	if bisector.length_squared() > 1e-4:
		bisector = bisector.normalized()
		var cosine := bisector.dot(way_out)
		if cosine >= 0.5:
			across = Vector3.UP.cross(bisector) * (half / cosine)
	var left := _on_ground(trail.at + across)
	var right := _on_ground(trail.at - across)
	var pitch: float = contact.pitch
	_add_quad(trail.left, trail.right, right, left,
			trail.along / pitch, (trail.along + into) / pitch, contact.tread)
	trail.left = left
	trail.right = right
	trail.across = across
	trail.back = trail.at
	trail.along += into
	trail.at = at


func _on_ground(p: Vector3) -> Vector3:
	var under: Dictionary = ground.call(p.x, p.z)
	return Vector3(p.x, under.height + LIFT, p.z)


# Two triangles, left and right being the trail's sides looking the way it
# goes: UV.x 0 on the left, 1 on the right.
func _add_quad(l0: Vector3, r0: Vector3, r1: Vector3, l1: Vector3, v0: float, v1: float,
		tread: float) -> void:
	var c: Chunk = _chunks.back() if not _chunks.is_empty() else null
	if c == null or c.quads == CHUNK:
		c = Chunk.new()
		c.node = MeshInstance3D.new()
		c.node.mesh = c.mesh
		c.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.node.material_override = _material
		add_child(c.node)
		_chunks.append(c)
	var birth := Vector2(_clock, tread)
	for corner in [[l0, 0.0, v0], [r0, 1.0, v0], [r1, 1.0, v1],
			[l0, 0.0, v0], [r1, 1.0, v1], [l1, 0.0, v1]]:
		c.vertices.append(corner[0])
		c.uvs.append(Vector2(corner[1], corner[2]))
		c.births.append(birth)
	c.quads += 1
	c.newest = _clock
	c.dirty = true


func _build(c: Chunk) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = c.vertices
	arrays[Mesh.ARRAY_TEX_UV] = c.uvs
	arrays[Mesh.ARRAY_TEX_UV2] = c.births
	c.mesh.clear_surfaces()
	c.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	c.dirty = false
