// A ring of foam spreading on the water (Level3DFx.ripple): what a blast, a
// round or a travelling explosion leaves on the sea and the river. The water
// is a height field drawn per fragment and its mesh never moves
// (level3d_ocean.gdshader), so a flat ring laid a hair over it stays on it.
//
// The mesh is a square two units across about the ring's middle; the ring is
// what of it lies between `inner` and 1 from there, the rest discarded, so it
// is opaque, as the effects are. Its edges wander with a noise round the ring,
// `seed` its own, as far as a share of its width: foam, not a drawn circle.
// Two flat bands, cel-shaded as the stage is: white foam on the outside,
// where the wave breaks, and paler water behind it. `inner` 0 is a disc,
// the foam where the splash came down, which opens into the ring as it
// spreads.
//
// Unshaded, like the fire: the foam along the shore is the ocean shader's
// own and lit with it, but a ring the sun lit two-tone would be half grey.
// No contour: the water is left soft (docs/cel-shading.md), and a black line
// round every ripple would draw a target on it.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec4 foam : source_color = vec4(0.93, 0.98, 1.0, 1.0);
uniform vec4 wash : source_color = vec4(0.56, 0.86, 0.97, 1.0);

instance uniform float inner = 0.8;
instance uniform float seed = 0.0;

varying vec2 local;

// Value noise, 0 to 1.
float wander(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	local = VERTEX.xz;
}

void fragment() {
	float r = length(local);
	float band = 1.0 - inner;
	// Round the ring, not across it: the same wander all the way in and out.
	vec2 around = local / max(r, 1e-4);
	float d = r + (wander(around * 2.5 + vec2(seed)) - 0.5) * band * 0.8;
	if (d > 1.0 || d < inner) {
		discard;
	}
	ALBEDO = d > inner + band * 0.45 ? foam.rgb : wash.rgb;
}
