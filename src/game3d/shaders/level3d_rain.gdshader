// The game over's rain (Level3DRain), unlit, pale and see-through, by `kind`:
//
//   0  a drop: a thin streak along the way it falls, the quad's long side,
//      fading to nothing at its tail and across its width, so that a
//      thousand of them read as a veil rather than as sticks
//   1  where one lands: a crown, a fan of thin jets from the quad's bottom
//      middle, each with a bead at its tip -- standing on the ground, a few
//      centimetres, as the particle's scale grows it and its colour's alpha
//      takes it away
//   2  and round it a ring on the ground, the quad lying flat, growing and
//      fading the same way
//
// The splashes were round drops thrown up off the ground and falling back,
// once, and read as hail bouncing.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform vec4 colour : source_color = vec4(0.84, 0.88, 0.95, 0.55);
uniform int kind = 0;
// A crown's quad, width over height, so that its jets are round in metres.
uniform float aspect = 1.5;

// How near `p` is to the jet from the crown's foot at `angle` (radians from
// up), `reach` long, in the quad's heights: 1 on its line, 0 off it.
float jet(vec2 p, float angle, float reach) {
	vec2 way = vec2(sin(angle), cos(angle));
	float along = clamp(dot(p, way), 0.0, reach);
	float off = length(p - way * along);
	float width = mix(0.035, 0.015, along / reach);
	float line = 1.0 - smoothstep(width * 0.5, width, off);
	float bead = 1.0 - smoothstep(0.03, 0.05, length(p - way * (reach + 0.02)));
	return max(line * (0.5 + 0.5 * along / reach), bead);
}

void fragment() {
	float a;
	if (kind == 1) {
		// From the foot, up: x in heights.
		vec2 p = vec2((UV.x - 0.5) * aspect, 1.0 - UV.y);
		a = 0.0;
		a = max(a, jet(p, -1.0, 0.55));
		a = max(a, jet(p, -0.5, 0.8));
		a = max(a, jet(p, 0.0, 0.9));
		a = max(a, jet(p, 0.5, 0.8));
		a = max(a, jet(p, 1.0, 0.55));
	} else if (kind == 2) {
		float r = length(UV - vec2(0.5)) * 2.0;
		// Soft, a faint second ring inside it: wet grass, not a puddle.
		a = (1.0 - smoothstep(0.0, 0.18, abs(r - 0.8))) * 0.35
				+ (1.0 - smoothstep(0.0, 0.14, abs(r - 0.45))) * 0.15;
	} else {
		float across = 1.0 - abs(UV.x * 2.0 - 1.0);
		// The head, at the bottom, full; the tail, at the top, gone.
		a = across * smoothstep(0.0, 0.8, UV.y);
	}
	ALBEDO = colour.rgb;
	ALPHA = colour.a * a * COLOR.a;
}
