// The contour round every model in the 3D preview (level3d_hull.gd): the
// inverted hull of docs/cel-shading.md, section 3, grown here rather than by
// a Solidify in Blender (level3d_hull.gdshaderinc). Black whatever the light.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

#include "res://src/tools/level3d_hull.gdshaderinc"

void vertex() {
	vec3 corner = VERTEX;
	VERTEX = hull_grown(VERTEX, NORMAL, UV.x, MODEL_MATRIX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	POSITION = hull_position(corner, VERTEX, NORMAL, UV, MODEL_MATRIX, MODELVIEW_MATRIX, VIEW_MATRIX,
			PROJECTION_MATRIX);
}

void fragment() {
	ALBEDO = vec3(0.0);
}
