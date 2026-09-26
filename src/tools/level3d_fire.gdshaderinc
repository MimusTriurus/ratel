// What the fire (level3d_fire.gdshader) and its contour
// (level3d_fire_contour.gdshader) share: a noise over the ball, and the part
// of it that has burnt away.
//
// A point of the ball is known by its direction from the middle, in the mesh's
// own space, and the contour is the same mesh grown about that middle, so a
// point of the fire and the point of the contour over it have the same
// direction and the same noise. That is what lets the two burn away together:
// where the fire has a hole the contour has one too, and the ground shows
// through rather than the black of the contour's far side. By point, not by
// facet: a facet all one colour drew every band and every hole in triangles.
//
// The node's own two numbers are here too, pinned to the same slots: an
// instance uniform's slot is otherwise its order in each shader, and the
// contour, which has no use for `age`, would read the fire's `age` as its
// `burn`.
instance uniform float age : instance_index(0) = 0.0;
instance uniform float burn : instance_index(1) = 0.0;

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

// `share` 0 to 1 -- `burn`, as a rule: that much of the ball gone, in holes
// that open and grow, the same ones in either shader. Stretched a little past
// the noise's ends, so that a hole opens as soon as there is any burn and
// nothing is left at 1.
bool fire_burnt(vec3 direction, float share) {
	return share > 0.0 && fire_noise(direction * 3.0 + vec3(41.0)) < share * 1.1 - 0.05;
}
