// The 3D preview's look, drawn over the finished frame by ColorRects on
// CanvasLayers of their own (level3d_preview.gd, _screen_pass): mode 2 the
// pixels (Level3DSettings.Look.PIXELS), mode 1 a CRT monitor
// (Level3DSettings.crt), which goes over either look. The modern look is no
// rect at all.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform sampler2D screen_nearest : hint_screen_texture, filter_nearest;
uniform int mode = 1;
// CRT: how far the glass bulges, and how many scanlines the frame is tall --
// 270 is a quarter of 1080, a line to every four pixels of a full HD screen.
uniform float curve = 0.08;
uniform float lines = 270.0;
// Pixels: how many the frame is wide, and the levels each channel is cut to.
// The port's frame is 512 of the NES's pixels across (2048 at 4x); 640 is a
// little finer than that, and 24 levels keep the water's and the shadows'
// shades from banding the way a palette would.
uniform float columns = 640.0;
uniform float levels = 24.0;

vec2 bulge(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curve * dot(c.yx, c.yx);
	return c * 0.5 + 0.5;
}

vec3 crt(vec2 uv, vec2 frag, vec2 px) {
	vec2 at = bulge(uv);
	if (at.x < 0.0 || at.x > 1.0 || at.y < 0.0 || at.y > 1.0) {
		return vec3(0.0);
	}
	// The beams do not land on one spot: red and blue a little either side.
	float spread = 1.2 * px.x;
	vec3 colour;
	colour.r = texture(screen, at + vec2(spread, 0.0)).r;
	colour.g = texture(screen, at).g;
	colour.b = texture(screen, at - vec2(spread, 0.0)).b;
	// And they bleed: a little of the neighbours' light.
	vec3 glow = texture(screen, at + vec2(2.0 * px.x, 0.0)).rgb
			+ texture(screen, at - vec2(2.0 * px.x, 0.0)).rgb;
	colour = colour * 0.85 + glow * 0.15;
	// Scanlines, a dark gap between each line, less so where it is bright.
	float line = 0.5 + 0.5 * cos(at.y * lines * 6.2831853);
	float bright = dot(colour, vec3(0.3, 0.59, 0.11));
	colour *= mix(1.0, 0.55 + 0.45 * line, 1.0 - bright * 0.5);
	// The aperture grille: every third column of pixels a phosphor of one colour.
	int column = int(mod(frag.x, 3.0));
	vec3 mask = column == 0 ? vec3(1.0, 0.8, 0.8) : column == 1 ? vec3(0.8, 1.0, 0.8) : vec3(0.8, 0.8, 1.0);
	colour *= mask * 1.2;
	// The tube's corners are darker than its middle.
	vec2 edge = at * (1.0 - at);
	colour *= pow(clamp(edge.x * edge.y * 40.0, 0.0, 1.0), 0.25);
	return colour;
}

vec3 pixels(vec2 uv, vec2 px) {
	float size = 1.0 / (px.x * columns);
	vec2 cells = 1.0 / (px * size);
	vec2 at = (floor(uv * cells) + 0.5) / cells;
	vec3 colour = texture(screen_nearest, at).rgb;
	return floor(colour * levels + 0.5) / levels;
}

void fragment() {
	if (mode == 1) {
		COLOR = vec4(crt(SCREEN_UV, FRAGCOORD.xy, SCREEN_PIXEL_SIZE), 1.0);
	} else if (mode == 2) {
		COLOR = vec4(pixels(SCREEN_UV, SCREEN_PIXEL_SIZE), 1.0);
	} else {
		COLOR = texture(screen, SCREEN_UV);
	}
}
