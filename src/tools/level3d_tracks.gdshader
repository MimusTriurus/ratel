// The marks tyres and tracks leave on the 3D stage 1 preview
// (level3d_tracks.gd). A mark darkens whatever it lies on, sand or concrete,
// lit or in shadow, by multiplying it: blend_mul, unshaded. It is at its
// darkest for `hold` seconds and gone `fade` seconds after that, by the
// birth time each vertex carries -- nothing is rebuilt as it fades.
//
//   UV.x   0 to 1 across the mark
//   UV.y   along it, in tread pitches: the pattern repeats every 1
//   UV2.x  when it was laid, on the clock `now` runs on
//   UV2.y  1 for a track's pads, 0 for a tyre's lugs
shader_type spatial;
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float now = 0.0;
uniform float hold = 1.667;
uniform float fade = 5.0;
// What the ground is multiplied by where a mark is at its deepest: sand
// pressed down, in its own shade.
uniform vec3 tint : source_color = vec3(0.62, 0.5, 0.4);

varying float age;
varying float tread;

void vertex() {
	age = now - UV2.x;
	tread = UV2.y;
}

void fragment() {
	float life = 1.0 - clamp((age - hold) / fade, 0.0, 1.0);
	float across = abs(UV.x * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.75, 1.0, across);
	float pattern;
	if (tread > 0.5) {
		// Pads: a bar across the whole track, a gap, a bar.
		pattern = mix(0.4, 1.0, step(0.45, fract(UV.y)));
	} else {
		// Lugs: chevrons, pointing the way the tyre rolled.
		pattern = mix(0.6, 1.0, step(0.5, fract(UV.y + across * 0.6)));
	}
	ALBEDO = mix(vec3(1.0), tint, life * edge * pattern);
}
