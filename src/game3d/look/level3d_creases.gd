class_name Level3DCreases
extends RefCounted

# A prototype, --engine-creases: the lines along a model's sharp edges made in
# the engine, as its contour is (Level3DHull), rather than by outline()'s
# chamfers in Blender (docs/cel-shading.md, section 2).
#
# An edge is sharp where the faces either side of it meet at more than ANGLE,
# as outline() has it. Along each, a strip folded over the edge: one half on
# each face, from the edge in, which is how a chamfer looks from wherever it
# is seen. level3d_crease.gdshader gives the halves their width, WIDTH in the
# world whatever the node's scale, and lifts them off their faces by LIFT so
# that they do not fight them for the depth.
#
# Nor on a narrow face, where the shader leaves its half out: the facets of
# something round -- a tube, a missile's nose -- which outline() takes at 50
# degrees for that, would be striped along every one. How wide a face is,
# across from the edge, goes to the shader, which knows the node's scale and
# so the width in the world (FACE, in lines).
#
# Not every edge: not one beside a black face, which is a chamfer the build
# already made (or black paint, where a black line would not show), so that
# a model with chamfers keeps them and gets nothing twice; not one bare at
# both ends, the parts that have no lines at all (Level3DHull); not an open
# edge, nor one shared by more than two faces.

const SHADER := preload("res://src/game3d/shaders/level3d_crease.gdshader")
const ANGLE := deg_to_rad(40.0)
const WIDTH := 0.011  # OUTLINE, docs/cel-shading.md, section 6
const LIFT := 0.002
const FACE := 3.0

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.resource_name = "Crease_Contour"
		_material.shader = SHADER
		_material.set_shader_parameter("width", WIDTH)
		_material.set_shader_parameter("lift", LIFT)
		_material.set_shader_parameter("face", FACE)
	return _material


# Adds the creases of the triangles `indices` over `positions` to `mesh` as a
# surface of their own, if it has any. `black` is per face, `bare` per vertex;
# `bones` empty for a mesh that is not skinned.
static func add_to(mesh: ArrayMesh, positions: PackedVector3Array, flat: PackedVector3Array,
		indices: PackedInt32Array, black: PackedByteArray, bare: PackedByteArray, reach: float,
		bones: PackedInt32Array, weights: PackedFloat32Array) -> void:
	var faces := indices.size() / 3
	var normals := PackedVector3Array()
	normals.resize(faces)
	var corner_of := {}  # position -> an index of its own, which vertices share
	var corner := PackedInt32Array()
	corner.resize(positions.size())
	for i in positions.size():
		var key := Level3DHull._key(positions[i])
		if not corner_of.has(key):
			corner_of[key] = corner_of.size()
		corner[i] = corner_of[key]
	# Every edge by its two corners: the faces on it, each with the edge's
	# two vertices as that face has them.
	var edges := {}
	for f in faces:
		var a := positions[indices[f * 3]]
		var n := (positions[indices[f * 3 + 1]] - a).cross(positions[indices[f * 3 + 2]] - a)
		if n.length_squared() < 1e-20:
			continue
		n = n.normalized()
		if n.dot(flat[indices[f * 3]]) < 0.0:
			n = -n
		normals[f] = n
		for k in 3:
			var i := indices[f * 3 + k]
			var j := indices[f * 3 + (k + 1) % 3]
			var key := Vector2i(mini(corner[i], corner[j]), maxi(corner[i], corner[j]))
			if key.x == key.y:
				continue
			if not edges.has(key):
				edges[key] = []
			edges[key].append([f, i, j, indices[f * 3 + (k + 2) % 3]])
	var cos_angle := cos(ANGLE)
	var out_positions := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_tangents := PackedFloat32Array()
	var out_uvs := PackedVector2Array()
	var out_uv2s := PackedVector2Array()
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	var out_indices := PackedInt32Array()
	for key in edges:
		var sides: Array = edges[key]
		if sides.size() != 2:
			continue
		var f1: int = sides[0][0]
		var f2: int = sides[1][0]
		if black[f1] or black[f2]:
			continue
		if bare[sides[0][1]] and bare[sides[0][2]]:
			continue
		if normals[f1].dot(normals[f2]) > cos_angle:
			continue
		for side in sides:
			var f: int = side[0]
			var i: int = side[1]
			var j: int = side[2]
			var pa := positions[i]
			var pb := positions[j]
			var along := (pb - pa).normalized()
			var to_third := positions[side[3]] - pa
			var across := to_third - along * to_third.dot(along)
			var inward := across.normalized()
			var base := out_positions.size()
			# The edge's two ends, then the same two again, which the shader
			# moves in across the face.
			for k in 4:
				var v: int = i if k == 0 or k == 3 else j
				out_positions.append(positions[v])
				out_normals.append(inward)
				out_tangents.append_array([normals[f].x, normals[f].y, normals[f].z, 1.0])
				out_uvs.append(Vector2(reach, 0.0 if k < 2 else 1.0))
				out_uv2s.append(Vector2(across.length(), 0.0))
				if not bones.is_empty():
					for b in 4:
						out_bones.append(bones[v * 4 + b])
						out_weights.append(weights[v * 4 + b])
			out_indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	if out_indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_positions
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_TANGENT] = out_tangents
	arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	arrays[Mesh.ARRAY_TEX_UV2] = out_uv2s
	arrays[Mesh.ARRAY_INDEX] = out_indices
	if not bones.is_empty():
		arrays[Mesh.ARRAY_BONES] = out_bones
		arrays[Mesh.ARRAY_WEIGHTS] = out_weights
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material())
