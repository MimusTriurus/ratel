# Smoke, as one cloud (level3d_cloud.gdshader): BlenderMCP's CelCloud
# (BlenderMCP/godot/scripts/CelCloud.cs). Puffs are handed in as discs, drawn
# on one quad facing the eye and flowed into one shape, with one line round
# it. A frame is `clear`, an `add` a puff, then `draw`; the puffs' motion is
# the owner's (Level3DBurn), this knows only where each is this frame.
class_name Level3DCloud
extends RefCounted

const SHADER := preload("res://src/game3d/shaders/level3d_cloud.gdshader")
const POOL := 64                # the shader's arrays
const TOON_EDGE := 0.02         # level3d_preview.gd's: the two tones' step

var _quad: MeshInstance3D
var _look: ShaderMaterial
var _where := PackedVector4Array()
var _looks := PackedVector4Array()
var _blend := 0.05
var _n := 0


# Under `parent`, named `node_name`: its puffs' grey taken in `tint`, two of
# them flowing into one within `blend` metres; its line `ink_px` pixels of a
# frame 1080 high, as the contour's (Level3DHull).
func _init(parent: Node, node_name: String, tint: Color, blend: float, ink_px: float) -> void:
	_blend = blend
	_where.resize(POOL)
	_looks.resize(POOL)
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	_look.set_shader_parameter("tint", tint)
	_look.set_shader_parameter("blend", blend)
	_look.set_shader_parameter("ink_px", ink_px)
	_look.set_shader_parameter("toon_edge", TOON_EDGE)
	_quad = MeshInstance3D.new()
	_quad.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	_quad.mesh = mesh
	_quad.material_override = _look
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.visible = false
	parent.add_child(_quad)


func clear() -> void:
	_n = 0


func hide() -> void:
	_n = 0
	_quad.visible = false


# A puff this frame: its middle in the world, its radius, metres, its grey, a
# seed for its lumps, how far it is eaten (0..1) and its age, a share of its
# life. Past POOL it is dropped.
func add(at: Vector3, r: float, tone: float, seed: float, erode: float, age: float) -> void:
	if _n >= POOL:
		return
	_where[_n] = Vector4(at.x, at.y, at.z, r)
	_looks[_n] = Vector4(tone, seed, erode, age)
	_n += 1


# The puffs added since `clear`, facing `eye` (the camera's basis): the quad
# over every puff, its lumps and the line, in front of them all (its own depth
# is not used: the shader writes the cloud's).
func draw(eye: Basis) -> void:
	if _n == 0:
		_quad.visible = false
		return
	var right := eye.x.normalized()
	var up := eye.y.normalized()
	var back := eye.z.normalized()
	var mid := Vector3.ZERO
	for i in _n:
		mid += Vector3(_where[i].x, _where[i].y, _where[i].z)
	mid /= _n
	var wide := 0.0
	var tall := 0.0
	var front := 0.0
	for i in _n:
		var at := Vector3(_where[i].x, _where[i].y, _where[i].z)
		var reach := _where[i].w * 1.4 + _blend * 2.0
		wide = maxf(wide, absf((at - mid).dot(right)) + reach)
		tall = maxf(tall, absf((at - mid).dot(up)) + reach)
		front = maxf(front, (at - mid).dot(back) + _where[i].w)
	_quad.global_transform = Transform3D(Basis(right * (2.0 * wide), up * (2.0 * tall), back), mid + back * front)
	_quad.visible = true
	_look.set_shader_parameter("puffs", _where)
	_look.set_shader_parameter("looks", _looks)
	_look.set_shader_parameter("count", _n)
