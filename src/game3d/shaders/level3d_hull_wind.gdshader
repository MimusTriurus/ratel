// The contour of what moves in the wind (level3d_wind.gd): the models' hull
// (level3d_hull.gdshader), moved first as the mesh it is grown round is
// (level3d_wind.gdshaderinc), or the frond would flap out of its line.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

#include "res://src/game3d/shaders/level3d_wind.gdshaderinc"
#include "res://src/game3d/shaders/level3d_hull.gdshaderinc"

void vertex() {
	VERTEX = wind_moved(VERTEX, MODEL_MATRIX);
	vec3 corner = VERTEX;
	VERTEX = hull_grown(VERTEX, NORMAL, UV.x, MODEL_MATRIX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	POSITION = hull_position(corner, VERTEX, NORMAL, UV, MODEL_MATRIX, MODELVIEW_MATRIX, VIEW_MATRIX,
			PROJECTION_MATRIX);
}

void fragment() {
	ALBEDO = vec3(0.0);
}
