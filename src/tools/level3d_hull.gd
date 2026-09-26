class_name Level3DHull
extends RefCounted

# The contour round every model in the 3D preview, made in the engine rather
# than in Blender (docs/cel-shading.md, sections 3 and 5). The preview runs
# every mesh added to the tree through here (level3d_preview.gd,
# _engine_contour), the level's and every unit's.
#
# The glbs still carry the contour as a surface of every mesh, the Solidify's
# shell, in a `*Contour` material. That surface is dropped and a hull made in
# its place out of the mesh's own triangles, all its surfaces together, which
# level3d_hull.gdshader grows and draws from behind only -- the same inverted
# hull, grown on the GPU, one width for every model: PIXELS on the screen,
# near or far, zoomed in or out (level3d_hull.gdshaderinc). The glbs' was
# baked in metres for the scale each was built to stand at in the preview,
# which has drifted since -- the jeep's for 0.31, and it stands at 0.375 --
# and was 1.4 cm or so, which the camera, far up, drew a pixel wide.
# --baked-contour draws the glbs' own, to compare.
#
# The normals it is grown along are not the mesh's: the models are flat, so
# every corner is a vertex per face, each with its face's normal, and grown
# along those the faces part at every edge and the hull shows cracks. Each
# position gets the average of the faces round it, weighted by their angle
# there, as Blender's vertex normals are, which are what the Solidify grew
# along. A skinned mesh's hull keeps its vertices' bones and weights, and
# goes with them.
#
# Not every part has a line (docs/cel-shading.md, section 9): what glows, the
# fire, the flashes, the tanks' paint -- stripes and panels, each of which
# would be framed in black. The builds leave those out with a vertex group
# that holds the Solidify's thickness to nothing there, so in the glb the
# shell lies on the part instead of round it, vertex on vertex. That is what
# says a vertex is bare: it is not grown, and a face bare at all three
# corners is not in the hull at all. When the Solidify goes from the builds,
# this will want saying some other way -- a vertex colour, say.
#
# Made once a mesh: the level's 6000 meshes are 291, and every glb there is
# takes 0.4 s all told.

# The hull's material's name ends as the glbs' did, so that what passes the
# contour by -- the two-tone light (_toon), the tanks' charring -- still does.
const HULL_NAME := "Hull_Contour"
const SHADER := preload("res://src/tools/level3d_hull.gdshader")
# How far a part's line may reach, as a share of the part's size: a part
# shrinking to nothing takes its line with it (level3d_hull.gdshaderinc).
const REACH := 1.0 / 6.0
# The line, in pixels of a frame 1080 high (level3d_hull.gdshaderinc): thick,
# as Chinatown Wars draws its cars and people.
const PIXELS := 3.0
# A position whose faces' normals, summed, come to less than this share of
# what they would pointing one way has no normal (_smooth_normals).
const DEGENERATE := 0.25

# A prototype, --engine-creases: the lines along the sharp edges too
# (Level3DCreases).
static var creases := false

static var _material: ShaderMaterial
static var _made := {}  # a glb's Mesh -> the same with the engine's hull


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.resource_name = HULL_NAME
		_material.shader = SHADER
		_material.set_shader_parameter("pixels", PIXELS)
	return _material


static func is_hull(material: Material) -> bool:
	return material != null and material.resource_name == HULL_NAME


# Gives `instance` the engine's hull in place of its baked one, if it has one.
static func apply(instance: MeshInstance3D) -> void:
	var mesh := instance.mesh as ArrayMesh
	if mesh == null:
		return
	if not _made.has(mesh):
		_made[mesh] = _rebuild(mesh)
	instance.mesh = _made[mesh]


static func _rebuild(mesh: ArrayMesh) -> ArrayMesh:
	var baked := -1
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		# Made here already -- a copy of a node that had it, the ground's
		# shadow casters (_holed_ground) -- and the hull is no baked shell.
		if is_hull(material):
			return mesh
		if material != null and material.resource_name.ends_with("Contour"):
			baked = surface
	if baked < 0 or mesh.get_blend_shape_count() > 0:
		return mesh  # nothing baked to replace; no model has blend shapes
	# Where the shell lies on the part rather than round it: what is bare.
	var kept_in := {}
	for p in mesh.surface_get_arrays(baked)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		kept_in[_key(p)] = true
	var out := mesh.duplicate() as ArrayMesh
	out.surface_remove(baked)
	var positions := PackedVector3Array()
	var flat := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var black := PackedByteArray()  # per face: in a black paint, a chamfer's
	var skinned := false
	for surface in out.get_surface_count():
		if out.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := out.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var base := positions.size()
		var faces_before := indices.size() / 3
		positions.append_array(vertices)
		flat.append_array(arrays[Mesh.ARRAY_NORMAL])
		if arrays[Mesh.ARRAY_BONES] != null:
			skinned = true
			bones.append_array(arrays[Mesh.ARRAY_BONES])
			weights.append_array(arrays[Mesh.ARRAY_WEIGHTS])
		else:
			for i in vertices.size():
				bones.append_array([0, 0, 0, 0])
				weights.append_array([1.0, 0.0, 0.0, 0.0])
		if arrays[Mesh.ARRAY_INDEX] != null:
			for i in arrays[Mesh.ARRAY_INDEX] as PackedInt32Array:
				indices.append(base + i)
		else:
			for i in vertices.size():
				indices.append(base + i)
		var paint := out.surface_get_material(surface)
		var is_black := 1 if paint != null and paint.resource_name.ends_with("Black") else 0
		for f in indices.size() / 3 - faces_before:
			black.append(is_black)
	if indices.is_empty():
		return out
	var aabb := AABB(positions[0], Vector3.ZERO)
	for p in positions:
		aabb = aabb.expand(p)
	# The normals over every face, as Blender's are; the hull without the
	# faces that are bare all round, which would lie on the part and be culled.
	# A position with no normal to speak of is bare too: grown along a normal
	# that is next to nothing, the hull of a frond went every way, across its
	# face, and the palm came out black.
	var normals := _smooth_normals(positions, flat, indices)
	var reach := PackedVector2Array()
	reach.resize(positions.size())
	var bare := PackedByteArray()
	bare.resize(positions.size())
	for i in positions.size():
		bare[i] = 1 if kept_in.has(_key(positions[i])) or normals[i] == Vector3.ZERO else 0
		if normals[i] == Vector3.ZERO:
			normals[i] = flat[i]
		reach[i] = Vector2(0.0 if bare[i] else aabb.get_longest_axis_size() * REACH, 0.0)
	var lined := PackedInt32Array()
	for t in range(0, indices.size() - 2, 3):
		if not (bare[indices[t]] and bare[indices[t + 1]] and bare[indices[t + 2]]):
			lined.append_array([indices[t], indices[t + 1], indices[t + 2]])
	if lined.is_empty():
		return out
	var hull := []
	hull.resize(Mesh.ARRAY_MAX)
	hull[Mesh.ARRAY_VERTEX] = positions
	hull[Mesh.ARRAY_NORMAL] = normals
	hull[Mesh.ARRAY_TEX_UV] = reach
	hull[Mesh.ARRAY_INDEX] = lined
	if skinned:
		hull[Mesh.ARRAY_BONES] = bones
		hull[Mesh.ARRAY_WEIGHTS] = weights
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, hull)
	out.surface_set_material(out.get_surface_count() - 1, material())
	if creases:
		Level3DCreases.add_to(out, positions, flat, indices, black, bare,
				aabb.get_longest_axis_size() * REACH, bones if skinned else PackedInt32Array(), weights)
	return out


# A position to a tenth of a millimetre: which vertices are one corner.
static func _key(p: Vector3) -> Vector3i:
	return Vector3i((p * 1e4).round())


# The angle-weighted normal of each position, whichever vertices share it.
# Which way a face points is its vertices' own normals' to say, not its
# winding's. Zero where the faces round a position point every which way and
# all but cancel (DEGENERATE): a sheet with both its sides, a palm's frond.
static func _smooth_normals(positions: PackedVector3Array, flat: PackedVector3Array,
		indices: PackedInt32Array) -> PackedVector3Array:
	var key_of := PackedInt32Array()
	key_of.resize(positions.size())
	var keys := {}
	for i in positions.size():
		var key := _key(positions[i])
		if not keys.has(key):
			keys[key] = keys.size()
		key_of[i] = keys[key]
	var sums := PackedVector3Array()
	sums.resize(keys.size())
	var angles := PackedFloat32Array()
	angles.resize(keys.size())
	for t in range(0, indices.size() - 2, 3):
		var a := positions[indices[t]]
		var b := positions[indices[t + 1]]
		var c := positions[indices[t + 2]]
		var face := (b - a).cross(c - a)
		if face.length_squared() < 1e-20:
			continue
		face = face.normalized()
		if face.dot(flat[indices[t]]) < 0.0:
			face = -face
		var corners := [[a, b, c], [b, c, a], [c, a, b]]
		for k in 3:
			var p: Vector3 = corners[k][0]
			var angle: float = (corners[k][1] - p).angle_to(corners[k][2] - p)
			sums[key_of[indices[t + k]]] += face * angle
			angles[key_of[indices[t + k]]] += angle
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	for i in positions.size():
		var sum := sums[key_of[i]]
		normals[i] = sum.normalized() if sum.length() > DEGENERATE * angles[key_of[i]] else Vector3.ZERO
	return normals
