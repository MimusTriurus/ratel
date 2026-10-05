// The game over's cemetery as an old print (Level3DGameOver, `film`), over
// its frame once the oaks' ink is on it: black and white, a grain, the
// corners darkened and soft. What it is for is to hide the game's models up close,
// which the title hides with its light. The soft edge goes by the place on the
// screen, not by depth: Compatibility has no depth of field.
//
// The players' helmets and wreaths on their graves keep their colours: in
// `mask` (the oaks' mask render, level3d_oak_mask.gdshader) they are blue,
// green their material's number in eighths (_key_kept), and there the frame
// takes that material's own colour (`kept_colours`, sRGB) at the brightness
// the render gave it -- not the render's colour, which the warm light and
// the haze leave olive and khaki beside the grey.
//
// And the rain on the lens (`drops`, 0 for none): drops a few pixels across
// that land here and there, stand a few seconds and dry, and larger ones
// that run down the glass by fits and starts, wandering a little and leaving
// a cleared trail behind them. Each a small lens of its own -- the frame through it upside down, a dark rim and
// a light on its upper side. Each kind in cells of the screen's height that
// a drop may be in, each at its own time -- tall ones for those that run;
// the print is made of what they show.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D mask : filter_nearest;
uniform float time = 0.0;
uniform vec3 kept_colours[7];
// How much of the colour goes to the two tones, 0 to 1 -- all of it, and the
// tones a grey's -- and how much what is kept is lifted, in the shadow of the
// light behind it.
uniform float fade = 1.0;
uniform float kept_lift = 1.3;
uniform vec3 shadow_tone = vec3(0.06, 0.06, 0.06);
uniform vec3 paper_tone = vec3(0.93, 0.93, 0.91);
uniform float grain = 0.07;
// How dark the corners are, and how blurred (mip levels).
uniform float vignette = 0.6;
uniform float blur = 2.5;
// The drops: all of them (0 to 1), how many of the cells have one that
// stands, how far a drop turns the frame (screen heights), how long one
// stands (s); how long one runs the height of its cell, and how many of the
// tall cells have one.
uniform float drops = 1.0;
uniform float stands = 0.1;
uniform float drop_refraction = 0.05;
uniform float drop_life = 6.0;
uniform float run_life = 7.0;
uniform float runs = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// A drop's lens at `p` (screen heights) in a layer of cells `scale` to the
// screen's height: xy where in the drop, -1 to 1, z how much of it there is
// (0 outside, fading at its rim and as it dries); `share` of the cells
// with one, each standing `life` seconds, `size` times the size it might be
// in its cell.
vec3 drop_at(vec2 p, float scale, float seed, float share, float life_time, float size) {
	vec2 cell = floor(p * scale);
	vec2 in_cell = fract(p * scale) - 0.5;
	// A fresh draw each time round -- whether there is a drop, where and how
	// large -- or the same cells would hold one for ever, wherever they fell.
	float turn = time / life_time + hash(cell + seed + 4.1);
	float life = fract(turn);
	vec2 key = cell + seed + vec2(13.7, 5.3) * mod(floor(turn), 97.0);
	if (hash(key) > drops * share) {
		return vec3(0.0);
	}
	vec2 centre = (vec2(hash(key + 1.3), hash(key + 2.7)) - 0.5) * 0.45;
	float radius = mix(0.12, 0.27, hash(key + 5.9)) * size;
	// It lands at once, a little larger than it stands, and dries smaller.
	radius *= smoothstep(0.0, 0.01, life) * (1.0 + 0.15 * (1.0 - smoothstep(0.0, 0.04, life)));
	radius *= mix(1.0, 0.6, smoothstep(0.55, 0.85, life));
	float there = 1.0 - smoothstep(0.7, 0.85, life);
	if (radius <= 0.0 || there <= 0.0) {
		return vec3(0.0);
	}
	// A drop sags a little under its weight.
	vec2 d = (in_cell - centre) / radius * vec2(1.0, 0.88);
	float r = length(d);
	if (r >= 1.0) {
		return vec3(0.0);
	}
	return vec3(d, there * smoothstep(1.0, 0.8, r));
}

// A running drop's lens at `p`, as drop_at's, in cells `scale` to the
// screen's height across and four times as tall: the drop from the cell's
// top to its bottom over its run, quick and slow by turns, its way
// wandering. As on a window: a drop heavy and round below, narrowing above
// into its trail, which is near as wide as it is -- a way it has cleared,
// the standing drops swept off it (they are not drawn where the trail is),
// a film of water with faint edges and a bead left on it here and there,
// drying slowly from its far end. A bead turns the frame less than the drop.
vec3 run_at(vec2 p, float scale, float seed) {
	const float TALL = 4.0;
	const float BEADS = 0.28;
	vec2 cell = floor(p * vec2(scale, scale / TALL));
	vec2 q = (fract(p * vec2(scale, scale / TALL)) - 0.5) * vec2(1.0, TALL);
	// A fresh draw each time round -- whether there is a drop, where and how
	// large -- or the same cells would hold one for ever, wherever they fell.
	float turn = time / run_life + hash(cell + seed + 4.1);
	float life = fract(turn);
	vec2 key = cell + seed + vec2(13.7, 5.3) * mod(floor(turn), 97.0);
	if (hash(key) > drops * runs) {
		return vec3(0.0);
	}
	float run = life - 0.022 * sin(life * TAU * 5.0);
	float top = -TALL * 0.45;
	float y = mix(top, TALL * 0.45, run);
	float wander = hash(key + 7.7) * TAU;
	float base_x = (hash(key + 1.3) - 0.5) * 0.3;
	float path = base_x + 0.08 * sin(q.y * 2.3 + wander);
	float there = smoothstep(0.0, 0.04, life) * (1.0 - smoothstep(0.92, 1.0, life));
	float radius = mix(0.05, 0.075, hash(key + 5.9));
	float trail = radius * 0.62;
	float behind = y - q.y;
	// Below its middle, round.
	if (behind <= 0.0) {
		vec2 d = vec2(q.x - path, -behind) / radius;
		float r = length(d);
		if (r >= 1.0) {
			return vec3(0.0);
		}
		return vec3(d * 0.7, there * smoothstep(1.0, 0.8, r));
	}
	// Above it, narrowing over NECK radii from its own width to the trail's.
	const float NECK = 2.2;
	if (behind < radius * NECK) {
		float k = behind / (radius * NECK);
		float half_width = mix(radius, trail, smoothstep(0.0, 1.0, k));
		vec2 d = vec2((q.x - path) / half_width, -k);
		float r = length(d);
		if (r < 1.0) {
			return vec3(d * 0.7, there * smoothstep(1.0, 0.8, r));
		}
	}
	if (q.y < top) {
		return vec3(0.0);
	}
	// The trail: a film, the more dried the further back.
	float wet = 1.0 - smoothstep(0.4, TALL * 0.9, behind);
	float half_width = trail * mix(0.75, 1.0, wet);
	float across = (q.x - path) / half_width;
	if (wet <= 0.0 || abs(across) >= 1.0) {
		return vec3(0.0);
	}
	// A bead left on it, now and then.
	float at = (floor(q.y / BEADS) + 0.5) * BEADS;
	if (y - at > radius * NECK && hash(key + at) > 0.55) {
		float small = trail * mix(0.35, 0.6, hash(key + at + 0.5)) * mix(0.5, 1.0, wet);
		vec2 bead = vec2(q.x - path - (hash(key + at + 0.9) - 0.5) * trail * 0.6, q.y - at) / small;
		float bead_r = length(bead);
		if (bead_r < 1.0) {
			return vec3(bead * 0.5, there * smoothstep(1.0, 0.8, bead_r));
		}
	}
	// A film: flat across, the frame through it as it is, but at its edges,
	// which bend it a little and take the rim's shade.
	float edge = sign(across) * pow(abs(across), 6.0);
	return vec3(edge, 0.0, there * wet * 0.45);
}

// Which kept material a mask pixel is, -1 for none.
int kept(vec3 c) {
	if (c.r > 0.05 || c.b < 0.95 || c.g < 0.06) {
		return -1;
	}
	return int(floor(c.g * 8.0 + 0.5)) - 1;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = (uv - 0.5) * vec2(1.4, 1.0);
	float edge = dot(c, c);
	float lod = smoothstep(0.12, 0.4, edge) * blur;
	vec3 drop = vec3(0.0);
	if (drops > 0.0) {
		vec2 p = uv * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
		// Where one drop is, no other: a running one's trail is clear of
		// the standing ones.
		float bend = 1.0;
		drop = run_at(p, 5.0, 31.0);
		// The standing ones, 3 to 7 pixels at 1080: one turns the frame
		// no further than it is across, or it would read as noise.
		if (drop.z <= 0.0) {
			drop = drop_at(p, 7.0, 0.0, stands, drop_life, 0.175);
			bend = 0.2;
		}
		if (drop.z <= 0.0) {
			drop = drop_at(p + 0.37, 13.0, 17.0, stands, drop_life, 0.325);
		}
		// Through a drop, the frame round it turned over; sharp in it.
		uv -= drop.xy * drop.z * drop_refraction * bend * vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0);
		lod = mix(lod, 0.0, drop.z);
	}
	vec3 colour = textureLod(screen, uv, lod).rgb;
	float l = dot(colour, vec3(0.299, 0.587, 0.114));
	int which = kept(texture(mask, uv).rgb);
	if (which >= 0) {
		vec3 own = kept_colours[min(which, 6)];
		colour = own * l / max(dot(own, vec3(0.299, 0.587, 0.114)), 0.05) * kept_lift;
	} else {
		l = smoothstep(0.04, 0.92, l);
		colour = mix(colour, mix(shadow_tone, paper_tone, l), fade);
	}
	if (drop.z > 0.0) {
		float r = length(drop.xy);
		colour *= 1.0 - 0.2 * smoothstep(0.7, 0.98, r) * drop.z;
		colour += 0.22 * smoothstep(0.2, 0.05, length(drop.xy - vec2(-0.3, -0.45))) * drop.z;
	}
	colour += (hash(floor(FRAGCOORD.xy / 1.6) + fract(time) * 97.0) - 0.5) * grain;
	colour *= 1.0 - smoothstep(0.15, 0.6, edge) * vignette;
	COLOR = vec4(colour, 1.0);
}
