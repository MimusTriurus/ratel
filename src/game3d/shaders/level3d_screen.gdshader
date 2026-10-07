// The 3D preview's look, drawn over the finished frame by ColorRects on
// CanvasLayers of their own (level3d_preview.gd, _screen_pass): mode 2 the
// pixels (Level3DSettings.Look.PIXELS), mode 1 a CRT monitor
// (Level3DSettings.crt), which goes over either look. The modern look is no
// rect at all. Mode 3, under both, is the light preset's grade
// (Level3DLighting): the stage only, under the HUD.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform sampler2D screen_nearest : hint_screen_texture, filter_nearest;
uniform int mode = 1;
// CRT: how far the glass bulges (Level3DSettings.crt_curve, Graphics ->
// Screen curvature), and how many scanlines the frame is tall --
// 270 is a quarter of 1080, a line to every four pixels of a full HD screen.
uniform float curve = 0.08;
uniform float lines = 270.0;
// Pixels: how many the frame is wide, and the levels each channel is cut to.
// The port's frame is 512 of the NES's pixels across (2048 at 4x); 640 is a
// little finer than that, and 24 levels keep the water's and the shadows'
// shades from banding the way a palette would.
uniform float columns = 640.0;
uniform float levels = 24.0;
// Grade: the shade's hue and the light's, and how far towards each, in
// OKLab's a and b. Only the hue moves: OKLab's lightness is left as it is, so
// what is told apart by brightness -- a unit from the ground, the sun from the
// shade -- is told apart as well as before, and as the eye judges it (a shift
// held to a luminance sum moves blue for free, since it weighs so little, and
// the sea came out electric). Nor does a colour come out more saturated than
// it was or than `chroma`, whichever is the more: what is vivid already, the
// sea, the hangars' green, only turns. The sand is the reason it exists: its
// orange is at the edge of what a screen shows, red full and blue none, so no
// colour of light moves it, and a shadow of it can never turn cool.
uniform vec3 shade_tint = vec3(0.55, 0.45, 0.9);
uniform vec3 light_tint = vec3(1.0, 0.75, 0.45);
uniform float shade_amount = 0.0;
uniform float light_amount = 0.0;
// Where the shade ends and the light begins, in OKLab lightness: the sand's
// shadow is 0.53 and its lit face 0.77, a lit grey wall 0.7.
uniform vec2 split = vec2(0.55, 0.72);
uniform float chroma = 0.12;

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

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

// Björn Ottosson's, linear sRGB in and out.
vec3 to_oklab(vec3 c) {
	vec3 lms = vec3(
			0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b,
			0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b,
			0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
	lms = sign(lms) * pow(abs(lms), vec3(1.0 / 3.0));
	return vec3(
			0.2104542553 * lms.x + 0.7936177850 * lms.y - 0.0040720468 * lms.z,
			1.9779984951 * lms.x - 2.4285922050 * lms.y + 0.4505937099 * lms.z,
			0.0259040371 * lms.x + 0.7827717662 * lms.y - 0.8086757660 * lms.z);
}

vec3 from_oklab(vec3 lab) {
	vec3 lms = vec3(
			lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z,
			lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z,
			lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z);
	lms = lms * lms * lms;
	return vec3(
			4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
			-1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
			-0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z);
}

// Which way a tint lies in a and b, a unit long.
vec2 hue(vec3 tint) {
	vec2 ab = to_oklab(to_linear(tint)).yz;
	return ab / max(length(ab), 1e-5);
}

vec3 grade(vec2 uv) {
	vec3 lab = to_oklab(to_linear(texture(screen, uv).rgb));
	float lit = smoothstep(split.x, split.y, lab.x);
	// Not the black: the contour round everything is what reads in the
	// shade, and a tinted line is a weaker one.
	float ink = smoothstep(0.1, 0.25, lab.x);
	vec2 ab = lab.yz + (hue(shade_tint) * shade_amount * (1.0 - lit)
			+ hue(light_tint) * light_amount * lit) * ink;
	float most = max(length(lab.yz), chroma);
	ab *= min(1.0, most / max(length(ab), 1e-5));
	return to_srgb(clamp(from_oklab(vec3(lab.x, ab)), 0.0, 1.0));
}

void fragment() {
	if (mode == 3) {
		COLOR = vec4(grade(SCREEN_UV), 1.0);
	} else if (mode == 1) {
		COLOR = vec4(crt(SCREEN_UV, FRAGCOORD.xy, SCREEN_PIXEL_SIZE), 1.0);
	} else if (mode == 2) {
		COLOR = vec4(pixels(SCREEN_UV, SCREEN_PIXEL_SIZE), 1.0);
	} else {
		COLOR = texture(screen, SCREEN_UV);
	}
}
