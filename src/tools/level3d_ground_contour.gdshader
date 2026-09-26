// The contour of the hard ground a building's crater can reach -- a hangar's
// pad (level3d_preview.gd, _holed_ground) -- holed with it, as the ground is
// (level3d_ground.gdshader). The models' hull (level3d_hull.gdshader), and
// discarding where the crater is: left whole, the hull's underside would show
// through the hole as a black floor.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

#include "res://src/tools/level3d_holes.gdshaderinc"
#include "res://src/tools/level3d_hull.gdshaderinc"

varying vec3 world;

void vertex() {
	VERTEX = hull_grown(VERTEX, NORMAL, UV.x, MODEL_MATRIX);
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (in_crater_hole(world.xz)) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
