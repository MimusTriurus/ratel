// The lines along a model's sharp edges (level3d_creases.gd): a strip folded
// over each edge, half on each face. Its vertices come in pairs, on the edge
// (UV.y 0) and the same point again (UV.y 1), which is moved in across its
// face -- NORMAL, the way in -- by `width` in the world whatever the node's
// scale. All of it is lifted off the face -- TANGENT, the face's normal -- by
// `lift`, so as not to fight the face for the depth.
//
// Hidden as the hull is (level3d_hull.gdshaderinc): held to a share of the
// part's size, UV.x, where its node's scale hides it; scaled with NORMAL and
// TANGENT, which the skinning scales, where its bone's does. No shadow.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float width = 0.011;
uniform float lift = 0.002;
// A face narrower than this many widths, across from the edge in the world
// (UV2.x in the mesh's units), has no half of the strip: a round thing's.
uniform float face = 3.0;

void vertex() {
	float across = length((MODEL_MATRIX * vec4(NORMAL * UV2.x, 0.0)).xyz);
	if (IN_SHADOW_PASS || across < face * width) {
		VERTEX = vec3(0.0);
	} else {
		vec3 s = max(vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
				length(MODEL_MATRIX[2].xyz)), vec3(1e-6));
		vec3 reach = vec3(UV.x);
		VERTEX += NORMAL * UV.y * min(vec3(width) / s, reach) + TANGENT * min(vec3(lift) / s, reach);
	}
}

void fragment() {
	ALBEDO = vec3(0.0);
}
