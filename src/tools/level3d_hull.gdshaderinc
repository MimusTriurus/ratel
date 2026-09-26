// The models' contour, grown in the engine (level3d_hull.gd): what the hull
// (level3d_hull.gdshader) and the holed hull of the hard ground
// (level3d_ground_contour.gdshader) share.
//
// The hull is the model's own triangles again, with their normals averaged
// over each corner, grown along those by `width` in the world whatever the
// node's scale, and drawn from behind only: the rim past the silhouette.
//
// Two ways a part is hidden, and neither may leave a black dot the width of
// the line where it was:
//   - by its node's scale, which the destructions animate to nothing: the
//     growth is held to `reach`, a sixth of the part's longest side in its
//     own units (the hull's UV.x), so it goes to nothing with the part;
//   - by its bone's scale, the tanks' flashes, the smoke's puffs: the
//     skinning scales NORMAL with the bone, and it is used as it comes, not
//     normalized, so the growth goes with the part here too.
//
// And it casts no shadow, collapsed to a point in the shadow pass: a line is
// not a thing that stands in the sun. Cast, it shadowed what it lies over --
// a palm's frond, a single plane with its hull 1.4 cm above it, went dark
// all over wherever the sun was on the hull's side.
uniform float width = 0.014;

vec3 hull_grown(vec3 vertex, vec3 normal, float reach, mat4 model) {
	if (IN_SHADOW_PASS) {
		return vec3(0.0);
	}
	vec3 s = max(vec3(length(model[0].xyz), length(model[1].xyz), length(model[2].xyz)), vec3(1e-6));
	return vertex + normal * min(vec3(width) / s, vec3(reach));
}
