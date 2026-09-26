// What the fire (level3d_fire.gdshader) and its contour
// (level3d_fire_contour.gdshader) share: a noise over the ball, and the part
// of it that has gone.
//
// A point of the ball is known by its direction from the middle, in the mesh's
// own space, and the contour is the same mesh grown about that middle, so a
// point of the fire and the point of the contour over it have the same
// direction and the same noise. That is what lets the two go together: where
// the fire has a hole the contour has one too, and the ground shows through
// rather than the black of the contour's far side. By point, not by facet: a
// facet all one colour drew every band and every hole in triangles.
//
// The node's own numbers are here too, pinned to the same slots: an instance
// uniform's slot is otherwise its order in each shader, and the contour, which
// has no use for `age`, would read the fire's `age` as its `burn`.
//   age     0 to 1 fire, white-hot to red; 1 to 2 smoke, as it cools to grey
//   burn    0 to 1, how much of it has gone (fire_gone)
//   warmth  added to its heat: the stem of a blast is hotter than its cap
instance uniform float age : instance_index(0) = 0.0;
instance uniform float burn : instance_index(1) = 0.0;
instance uniform float warmth : instance_index(2) = 0.0;

// Value noise, 0 to 1, smooth between whole numbers.
float fire_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n[8];
	for (int k = 0; k < 8; k++) {
		vec3 c = i + vec3(float(k & 1), float((k >> 1) & 1), float((k >> 2) & 1));
		n[k] = fract(sin(dot(c, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	}
	return mix(mix(mix(n[0], n[1], f.x), mix(n[2], n[3], f.x), f.y),
			mix(mix(n[4], n[5], f.x), mix(n[6], n[7], f.x), f.y), f.z);
}

// Whether the point in `direction` has gone, `share` 0 to 1 -- `burn`, as a
// rule -- with `eye` the camera's direction from the middle, both in the
// mesh's own space. A ball goes from the middle out, as seen: a ragged hole
// where it faces the camera, and the same one on its far side behind it, so
// that it is a hole right through, which widens until only a broken ring of
// its edge is left, and then that goes too. It is how the smoke of a cartoon
// blast thins away, and fire going out looks the same.
bool fire_gone(vec3 direction, vec3 eye, float share) {
	if (share <= 0.0) {
		return false;
	}
	// The middle opens first, and the edge breaks into pieces not long
	// after, by the noise, before the hole has thinned it to a line: with
	// the edge held to the end, every lobe went as a drawn circle, which is
	// the shell seen edge on.
	float middle = abs(dot(direction, eye));
	return middle * 0.5 + fire_noise(direction * 3.5 + vec3(41.0)) * 0.9 > 1.25 - share * 1.6;
}

// The camera, in the mesh's own space: its direction from the middle is `eye`.
vec3 fire_eye(mat4 model, vec3 camera) {
	return (inverse(model) * vec4(camera, 1.0)).xyz;
}
