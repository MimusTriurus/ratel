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
//
// Two things the width is made good for, which left the line broken or thin
// where it was drawn at all:
//   - it is only as wide on the screen as the growth is across the ray to the
//     eye, and the normals, averaged over a corner, lean towards the camera
//     -- half of one along the edge of a roof, a bunker's raked side nearly
//     all -- so the line went down to a hairline there, and to nothing where
//     a rock's silhouette passed a vertex whose normal faced the eye. The
//     growth is stretched by what the lean takes off, up to STRETCH;
//   - where a thing stands on the ground, what shows past its foot is its
//     underside's hull, grown down into the ground, which hid it: no building
//     had a line along its foot. Round a mesh's foot -- FOOT of its lowest
//     point, which the hull's UV.y gives each corner -- what is grown below
//     the corner it was grown from is drawn nearer the eye, along the ray,
//     which moves nothing on the screen: as far as brings it back up to that
//     corner's height, and LIFT over, to come clear of the ground. Only
//     there: pulled everywhere, the hull came through whatever lay a line's
//     width over it -- a barracks' walls and the roof's own underside through
//     its roof, 3 cm thick (jackal_cel.py, SHEET), and the palms' fronds,
//     which have no thickness at all, in black patches.
uniform float pixels = 3.0;

const float STRETCH = 2.5;
const float LIFT = 0.015;
const float FOOT = 0.1;


// A frame's height at the vertex is 2 w / projection[1][1], w the clip w:
// the depth for the tilted camera's perspective, 1 for the top view's
// orthographic. Its size: the projection is flipped upside down when the
// frame is drawn to a texture, and the hull, grown by a negative width, went
// in, and out through the far side of every small part in black.
float hull_metres(vec3 vertex, mat4 modelview, mat4 projection) {
	float w = (projection * modelview * vec4(vertex, 1.0)).w;
	return pixels / 1080.0 * 2.0 * w / abs(projection[1][1]);
}


vec3 hull_scale(mat4 model) {
	return max(vec3(length(model[0].xyz), length(model[1].xyz), length(model[2].xyz)), vec3(1e-6));
}


// Towards the eye from a point in view space: along the ray for the tilted
// camera's perspective, straight back for the top view's orthographic.
vec3 hull_to_eye(vec3 at, mat4 projection) {
	return projection[3][3] == 1.0 ? vec3(0.0, 0.0, 1.0) : -normalize(at);
}


vec3 hull_grown(vec3 vertex, vec3 normal, float reach, mat4 model, mat4 modelview, mat4 projection) {
	if (IN_SHADOW_PASS) {
		return vec3(0.0);
	}
	vec3 s = hull_scale(model);
	vec3 across = mat3(modelview) * (normal / s);
	float stretch = 1.0;
	if (dot(across, across) > 1e-12) {
		vec3 eye = hull_to_eye((modelview * vec4(vertex, 1.0)).xyz, projection);
		float along = dot(normalize(across), eye);
		stretch = 1.0 / max(sqrt(max(1.0 - along * along, 0.0)), 1.0 / STRETCH);
	}
	float metres = hull_metres(vertex, modelview, projection);
	return vertex + normal * min(vec3(metres) / s, vec3(reach)) * stretch;
}


// Where the grown vertex is drawn: pulled towards the eye, as far as the
// part's own reach allows, so that a part shrinking to nothing, by its
// node's scale or its bone's, does not end in its hull drawn over it.
vec4 hull_position(vec3 vertex, vec3 grown, vec3 normal, vec2 reach_foot, mat4 model, mat4 modelview,
		mat4 view, mat4 projection) {
	vec3 at = (modelview * vec4(grown, 1.0)).xyz;
	vec3 s = hull_scale(model);
	if (IN_SHADOW_PASS || reach_foot.y * s.y > FOOT) {
		return projection * vec4(at, 1.0);
	}
	vec3 up = normalize(view[1].xyz);
	float sunk = -dot(at - (modelview * vec4(vertex, 1.0)).xyz, up);
	if (sunk <= 0.0) {
		return projection * vec4(at, 1.0);
	}
	vec3 eye = hull_to_eye(at, projection);
	float reach = reach_foot.x;
	float held = reach * min(s.x, min(s.y, s.z)) * min(length(normal), 1.0);
	float pull = min(sunk / max(dot(eye, up), 0.25) + LIFT, held);
	return projection * vec4(at + eye * pull, 1.0);
}
