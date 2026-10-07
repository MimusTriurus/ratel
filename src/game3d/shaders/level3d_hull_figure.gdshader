// The engine's hull (level3d_hull.gdshader) for the shop's figures, the two
// talking by the helicopter (Level3DShop.Bay._line): drawn `push` line widths
// further from the eye, along the ray, which moves nothing on the screen. A
// figure there is small and its line thick, and the hull of a part grown that
// far came out in front of the part beside it -- a hand's, an arm's where it
// meets the chest -- in black triangles over him; pushed back, it is hidden
// by him and shows only past his silhouette. No pull round the foot, as the
// stage's has: they stand on the concrete, and the line along their boots'
// soles is not missed.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

#include "res://src/game3d/shaders/level3d_hull.gdshaderinc"

uniform float push = 0.8;

void vertex() {
	vec3 corner = VERTEX;
	VERTEX = hull_grown(VERTEX, NORMAL, UV.x, MODEL_MATRIX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	vec3 at = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float metres = hull_metres(corner, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	POSITION = PROJECTION_MATRIX * vec4(at - hull_to_eye(at, PROJECTION_MATRIX) * metres * push, 1.0);
}

void fragment() {
	ALBEDO = vec3(0.0);
}
