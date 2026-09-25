// The contour of the hard ground a building's crater can reach -- a hangar's
// pad (level3d_preview.gd, _holed_ground) -- holed with it, as the ground is
// (level3d_ground.gdshader). The glb's J_Contour, written
// out: a shell of flipped faces, one-sided, black whatever the light. Left
// whole, the shell's underside would show through the hole as a black floor.
shader_type spatial;
render_mode cull_back, unshaded;

#include "res://src/tools/level3d_holes.gdshaderinc"

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (in_crater_hole(world.xz)) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
