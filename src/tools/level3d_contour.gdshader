// The contour of the 3D preview's procedural effects (level3d_fx.gd): the
// models' inverted hull (docs/cel-shading.md), made in the shader instead of
// by a Solidify, since these meshes are built at run time. It is a material's
// next_pass, so the same mesh is drawn again, grown by `width` in the world
// whatever the node's scale, with its front faces culled: only the rim past
// the silhouette shows, black.
//
// Grown about the origin when `extent` is given, the mesh's radius there --
// for the balls and boxes the effects are made of, which have a centre and
// whose flat faces, grown along their normals, would part at the edges; along
// the normals otherwise, which wants smooth normals. Grown about the origin, a
// shrinking effect keeps its line in proportion, no more than a third of its
// radius, rather than ending as a black dot.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float width = 0.014;
uniform float extent = 0.0;

void vertex() {
	vec3 s = max(vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
			length(MODEL_MATRIX[2].xyz)), vec3(1e-5));
	if (extent > 0.0) {
		vec3 radius = extent * s;
		VERTEX *= 1.0 + min(vec3(width), radius / 3.0) / radius;
	} else {
		VERTEX += NORMAL * width / s;
	}
}

void fragment() {
	ALBEDO = colour.rgb;
}
