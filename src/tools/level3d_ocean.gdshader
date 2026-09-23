// The sea and the river of the 3D stage 1 preview (level3d_preview.gd).
//
// Adapted from DeepShader in the BlenderMCP Godot bench (scripts/Stage3D.cs):
// the surface is a height field evaluated per fragment -- the mesh never moves
// -- with the swell's folded noise for the body of the waves and a finer chop
// for the sun to catch, and foam is an edge pushed about by noise rather than a
// band dimmed by it. What is not carried over is everything that bench needs
// for its tanks and hexagons.
//
// Where the water is shallow comes from Blender, not from the depth buffer. The
// sea has no floor under it, so the thickness DeepShader reads there would be
// the far plane everywhere; instead the Blender material's own input, the
// shore_dist attribute its geometry nodes compute, is baked into the vertex
// colour on export: R is the distance to the shore / 8 m, G is 1 on the open
// sea and 0 on the river. The colour ramp is the Blender one, stop for stop.
//
// Lit rather than unshaded, unlike DeepShader: the rest of this scene is lit by
// a real sun, and a lit surface takes that sun's highlight, the palms' shadows
// and the per-renderer gain the preview calibrates without a second copy of any
// of it. The bottom seen through the shallows is already lit, so it goes in as
// emission and not as albedo, which would light it twice.
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D zbuf : hint_depth_texture, filter_linear;

// Blender's ramp over shore_dist mapped from 0.15..5 m.
uniform vec3 shore_colour : source_color = vec3(0.169, 0.722, 0.769);
uniform vec3 mid_colour : source_color = vec3(0.075, 0.439, 0.659);
uniform vec3 deep_colour : source_color = vec3(0.0, 0.094, 0.353);
uniform float ramp_near = 0.15;
uniform float ramp_far = 5.0;
// The vertex colour stores distance / this.
uniform float shore_scale = 8.0;

uniform float wave_scale = 0.55;
uniform float wave_speed = 0.6;
uniform float relief = 0.14;
uniform float fine = 3.4;
uniform float sparkle = 0.10;
// The river is sheltered water: its waves are this share of the sea's.
uniform float river_calm = 0.35;
uniform float roughness_open = 0.4;
uniform float roughness_foam = 0.7;

// The surf line: how far from the shore it reaches, in metres, and how far the
// crumple pushes that edge, as a share of the band.
uniform float foam_width = 0.45;
uniform vec2 edge_crumple = vec2(0.9, 0.6);
// A second line further out that runs in towards the shore and fades, so the
// surf is seen arriving rather than painted on.
uniform float surge_reach = 2.2;
uniform float surge_period = 5.0;
uniform vec3 foam_colour : source_color = vec3(0.95, 0.97, 1.0);

// How far light gets into the shallows, in metres of water along the view ray,
// before the bottom is lost under the body colour; and how far the surface bends
// what is seen through it, in pixels.
uniform float clarity = 0.15;
uniform float refraction = 14.0;

varying vec3 world;
varying float shore;
varying float open_sea;

float hash12(vec2 p) {
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334677u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334677u;
	return float(n) * (1.0 / 4294967295.0);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x),
			u.y);
}

// Signed, roughly -1..1, and not folded: a fold makes creases, and a crease in
// an edge is a spike. An edge wants lobes.
float crumple(vec2 p, float t) {
	vec2 drift = vec2(0.21, -0.13) * t;
	return (vnoise(p + drift) - 0.5) * 1.30
			+ (vnoise(p * 2.17 - drift * 1.40) - 0.5) * 0.60;
}

// The swell: two folded octaves drifting apart. The fold is what separates
// water from cloud -- a surface held by its own tension has creases between
// its hills -- and the per-octave drift stops the field sliding as one sheet.
float height(vec2 p, float t) {
	float h = 0.0;
	float a = 1.0;
	float f = 1.0;
	vec2 drift = vec2(0.35, 0.20) * t;
	for (int i = 0; i < 2; i++) {
		float n = vnoise(p * f + drift);
		h += a * (1.0 - abs(2.0 * n - 1.0));
		a *= 0.5;
		f *= 2.03;
		drift = vec2(-drift.y, drift.x) * 1.7;
	}
	return h;
}

// The chop on top: finer, quicker, unfolded. This is what the sun catches.
float chop(vec2 p, float t) {
	float h = 0.0;
	float a = 1.0;
	float f = 1.0;
	vec2 drift = vec2(-0.22, 0.31) * t;
	for (int i = 0; i < 2; i++) {
		h += a * (vnoise(p * f + drift) - 0.5);
		a *= 0.5;
		f *= 2.7;
		drift = vec2(drift.y, -drift.x) * 2.1;
	}
	return h;
}

// Tears foam into patches, so a band is never a solid stripe. Looser than
// DeepShader's 0.30..0.80: seen from straight above at this scale its patches
// came out as speckle rather than as a surf line.
float shred(vec2 xz, float t) {
	return smoothstep(0.15, 0.55, height(xz * wave_scale * 2.0, t) / 1.75);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore = COLOR.r * shore_scale;
	open_sea = COLOR.g;
}

void fragment() {
	float t = TIME * wave_speed;
	float calm = mix(river_calm, 1.0, open_sea);

	// Central differences, in the height field's own units, as DeepShader.
	vec2 p = world.xz * wave_scale;
	float e = 0.35;
	float h = height(p, t);
	float hx = height(p + vec2(e, 0.0), t) - h;
	float hz = height(p + vec2(0.0, e), t) - h;
	vec2 cp = p * fine;
	vec2 ce = vec2(0.12, 0.0);
	float c = chop(cp, t);
	float cx = chop(cp + ce, t) - c;
	float cz = chop(cp + ce.yx, t) - c;
	vec3 n = normalize(vec3(-(hx * relief + cx * sparkle) * calm, e,
			-(hz * relief + cz * sparkle) * calm));

	// Blender's ramp, stop for stop: 0 -> shore, 0.12 -> mid, 0.55 -> deep.
	float r = clamp((shore - ramp_near) / (ramp_far - ramp_near), 0.0, 1.0);
	vec3 body = r < 0.12 ? mix(shore_colour, mid_colour, r / 0.12)
			: mix(mid_colour, deep_colour, clamp((r - 0.12) / 0.43, 0.0, 1.0));

	// The bottom, where there is one. Near the beach the land runs on under the
	// water and the depth buffer has it; out at sea it holds the far plane, and
	// the thickness is then large enough that none of it shows.
	// Compatibility's clip space is OpenGL's, -1..1 in depth; the others' is 0..1.
	float raw = texture(zbuf, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	raw = raw * 2.0 - 1.0;
#endif
	vec4 floor_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float floor_z = -floor_view.z / floor_view.w;
	float thick = max(floor_z - (-VERTEX.z), 0.0);
	float seen = exp(-thick / max(clarity, 0.001));
	vec2 bend = n.xz * refraction * (1.0 - seen) / vec2(textureSize(screen, 0));
	vec3 bottom = textureLod(screen, SCREEN_UV + bend, 0.0).rgb;

	// Foam: the surf line at the shore, its edge pushed by the crumple read on
	// the shore side of the band so the band keeps its width; and the surge,
	// a thinner line walking in from surge_reach and fading as it arrives.
	float push = crumple(world.xz * edge_crumple.x, t) * edge_crumple.y;
	float surf = 1.0 - smoothstep(0.0, foam_width, shore + push * foam_width);
	float phase = fract(TIME / surge_period);
	float line_at = mix(surge_reach, foam_width * 0.6, phase);
	float surge = (1.0 - smoothstep(0.0, foam_width * 0.35,
			abs(shore + push * foam_width * 0.5 - line_at)))
			* sin(phase * PI) * open_sea;
	// Broken twice: into patches by the swell, and into flecks by a finer noise,
	// which is what Blender's surf is -- a dotted line along the bank rather than
	// a stroke drawn round it.
	vec2 drift = vec2(0.11, -0.07) * t;
	float flecks = smoothstep(0.35, 0.6, vnoise(world.xz * 5.0 + drift) * 0.65
			+ vnoise(world.xz * 11.0 - drift) * 0.35);
	float foam = clamp(max(surf, surge * 0.8), 0.0, 1.0) * shred(world.xz, t)
			* mix(flecks, 1.0, 0.25);

	ALBEDO = mix(body * (1.0 - seen), foam_colour, foam);
	EMISSION = bottom * seen * (1.0 - foam);
	ROUGHNESS = mix(roughness_open, roughness_foam, foam);
	SPECULAR = 0.3;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
