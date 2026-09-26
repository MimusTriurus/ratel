// The models' contour, grown in the engine (level3d_hull.gd): what the hull
// (level3d_hull.gdshader) and the holed hull of the hard ground
// (level3d_ground_contour.gdshader) share.
//
// The hull is the model's own triangles again, with their normals averaged
// over each corner, grown along those whatever the node's scale, and drawn
// from behind only: the rim past the silhouette. Grown by `pixels` of a frame
// 1080 high -- as many metres as that is where the vertex is, so the same on
// the screen near or far, zoomed in or out, as a cartoon's ink is, and thick
// as Chinatown Wars draws its cars and people. It was 1.4 cm in the world,
// which the camera, far up, drew a pixel wide.
//
// Grown in the world, along the normal, not moved across the screen at its
// own depth: that was tried, and where a thing stands on the ground the rim
// past its silhouette is the hull of its underside, which the ground in
// front of it hid -- the jeep lost its line altogether.
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
// a palm's frond, a single plane with its hull above it, went dark all over
// wherever the sun was on the hull's side. It is VERTEX that goes to the
// point: the shadow pass goes by it.
uniform float pixels = 3.0;

vec3 hull_grown(vec3 vertex, vec3 normal, float reach, mat4 model, mat4 modelview, mat4 projection) {
	if (IN_SHADOW_PASS) {
		return vec3(0.0);
	}
	// A frame's height at the vertex is 2 w / projection[1][1], w the clip w:
	// the depth for the tilted camera's perspective, 1 for the top view's
	// orthographic. Its size: the projection is flipped upside down when the
	// frame is drawn to a texture, and the hull, grown by a negative width,
	// went in, and out through the far side of every small part in black.
	float w = (projection * modelview * vec4(vertex, 1.0)).w;
	float metres = pixels / 1080.0 * 2.0 * w / abs(projection[1][1]);
	vec3 s = max(vec3(length(model[0].xyz), length(model[1].xyz), length(model[2].xyz)), vec3(1e-6));
	return vertex + normal * min(vec3(metres) / s, vec3(reach));
}
