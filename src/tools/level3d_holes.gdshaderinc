// The craters' holes in the ground (level3d_fx.gd, crater_mesh), for what
// lies on the ground and has to let them through: the ground itself
// (level3d_ground.gdshader), the tyre and track marks, the lines painted on
// it. The ground cannot be cut, and Compatibility has no decals, so the hole
// is these shaders not drawing there: the crater's bowl, below, is then
// simply seen, depth and all -- a soldier in it, rubble lying in it.
//
// Set by Level3DLauncher._push_holes from the craters' own nodes, every
// frame, so that a hole is as big as its crater is at that moment -- one
// growing in, a building's shown when the destruction shows it:
//   crater_place  x, z of its middle; cos and sin of its turn about y
//   crater_size   its unit radius along its own x and z, in metres
// A hole is the rim's inner foot, a regular HOLE_SIDES-gon of radius HOLE_IN
// in the unit crater, turned with it -- Level3DFx.RIM_SEGMENTS and RIM_IN,
// which must stay the same. A hair smaller, so that its edge tucks under the
// rim's inner wall rather than showing a sliver of nothing along it.
const int HOLES = 64;
const int HOLE_SIDES = 11;
const float HOLE_IN = 0.5 * 0.995;

uniform int crater_count = 0;
uniform vec4 crater_place[64];
uniform vec2 crater_size[64];

bool in_crater_hole(vec2 xz) {
	float wedge = 6.28318530718 / float(HOLE_SIDES);
	for (int i = 0; i < HOLES; i++) {
		if (i >= crater_count) {
			break;
		}
		vec4 place = crater_place[i];
		vec2 d = xz - place.xy;
		// Into the crater's own axes: turned by its angle, as Godot's
		// Vector2.rotated, then in its radii.
		vec2 local = vec2(d.x * place.z - d.y * place.w, d.x * place.w + d.y * place.z) / crater_size[i];
		float r = length(local);
		if (r >= HOLE_IN) {
			continue;
		}
		float a = atan(local.y, local.x);
		float off = mod(a, wedge) - 0.5 * wedge;
		if (r < HOLE_IN * cos(0.5 * wedge) / cos(off)) {
			return true;
		}
	}
	return false;
}
