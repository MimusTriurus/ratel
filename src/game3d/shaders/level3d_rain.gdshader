// A raindrop of the game over's rain (Level3DRain): a thin streak along the
// way it falls, the quad's long side, unlit, pale and see-through -- fading
// to nothing at its tail and across its width, so that a thousand of them
// read as a veil rather than as sticks. A splash is the same with
// `splash` on: a round drop, full in the middle.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform vec4 colour : source_color = vec4(0.84, 0.88, 0.95, 0.55);
uniform bool splash = false;

void fragment() {
	float a;
	if (splash) {
		a = 1.0 - smoothstep(0.2, 0.5, length(UV - vec2(0.5)));
	} else {
		float across = 1.0 - abs(UV.x * 2.0 - 1.0);
		// The head, at the bottom, full; the tail, at the top, gone.
		a = across * smoothstep(0.0, 0.8, UV.y);
	}
	ALBEDO = colour.rgb;
	ALPHA = colour.a * a * COLOR.a;
}
