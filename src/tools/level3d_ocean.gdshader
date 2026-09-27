// The sea and the river of the 3D stage 1 preview (level3d_preview.gd).
//
// Adapted from DeepShader in the BlenderMCP Godot bench (scripts/Stage3D.cs):
// the surface is a height field evaluated per fragment -- the mesh never moves
// -- with the swell's folded noise for the body of the waves and a finer chop
// for the sun to catch, the sun's spark in light(), and foam that is an edge
// pushed about by noise rather than a band dimmed by it. What is not carried
// over is everything that bench needs for its tanks and hexagons -- and its
// lap, the waterline run up the bank by hand against the depth buffer. Every
// waterline on this stage is on J_Cliff, the sea's wall and the river's
// banks alike, and on a face that steep a tenth of a metre of lap moved the
// line three to eight centimetres: a pixel or two at the game's zoom, bought
// by taking the depth test off the whole sea. The surf laps instead.
//
// Where the water is shallow comes from Blender, not from the depth buffer. The
// sea has no floor under it, so the thickness DeepShader reads there would be
// the far plane everywhere; instead the Blender material's own input, the
// shore_dist attribute its geometry nodes compute, is baked into the vertex
// colour on export: R is the distance to the shore / 8 m, G is Blender's
// `open`, clamp((d - 1) / 6) squared of that distance -- 0 on the river, and 0
// within a metre or two of every shore, the sea's too, rising to 1 seven
// metres out. The colour ramp is the Blender one, stop for stop.
//
// Which water a shore belongs to is the one thing neither says, since `open`
// is nought at both, and the surf wants it: it comes in off the sea, not down
// the river. sea_mask says it, grown out of `open` by the preview.
//
// Lit rather than unshaded, unlike DeepShader: the rest of this scene is lit by
// a real sun, and a lit surface takes that sun's highlight, the palms' shadows
// and the per-renderer gain the preview calibrates without a second copy of any
// of it. The bottom seen through the shallows is already lit, so it goes in as
// emission and not as albedo, which would light it twice.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, ambient_light_disabled;

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
// Where this had 0.14 and 0.10: at those the surface hardly ever tilted as far
// as the half vector, 15 to 25 degrees off the vertical here (see gloss), and
// there was nothing for a spark to land on. The relief is DeepShader's; the
// chop is under its 0.55, at which the sea glittered all over and read as
// noise.
uniform float relief = 0.30;
uniform float fine = 3.4;
uniform float sparkle = 0.40;
// The river is sheltered water: its waves are this share of the sea's.
uniform float river_calm = 0.35;
// What the diffuse is taken at (Burley's retro-reflection reads it); the glint
// does not use it.
uniform float roughness_open = 0.4;
uniform float roughness_foam = 0.7;

// The sun's glint: DeepShader's spark, a tight lobe on the whole normal, chop
// and all, because being small and moving is its whole job. Worked out in
// light(), so that the palms' shadows put it out as they put out the diffuse.
// What this had was Godot's one GGX lobe at roughness 0.4, and on the swell's
// creases it drew marble -- the failure DeepShader's notes describe, of a
// broad lobe tracking the fold.
//
// Far tighter than DeepShader's 210, and dimmer: this camera looks down, so the
// half vector is 15 to 25 degrees off the vertical, near the normals the swell
// tilts to, and at 210 the tilted view was glitter from edge to edge; at 400,
// with the chop at 0.55, it was still a speckle over the whole sea. At 1200
// only the wave faces turned right at the sun glint, and thinly. Nor is its
// second lobe here, the broad sheen on a flattened normal. Looking down, that
// normal is within a few degrees of vertical everywhere, so the lobe is one
// value over the whole sea, and it laid a grey veil on it at any setting tried.
//
// Strength is of the sun's colour at full, whatever the sun's energy: each
// renderer's gain is calibrated for the sand, and a glint is not diffuse.
uniform float gloss = 1200.0;
uniform float glint = 0.7;

// The surf line: how far from the shore it reaches, in metres, and how far the
// crumple pushes that edge, as a share of the band.
uniform float foam_width = 0.45;
uniform vec2 edge_crumple = vec2(0.9, 0.6);
// A second line further out that runs in towards the shore and fades, so the
// surf is seen arriving rather than painted on.
uniform float surge_reach = 2.2;
uniform float surge_period = 5.0;
// And what it does when it gets there, which is what water does at a wall:
// it cannot run up it, so it is the white that moves. The sea's surf widens by
// surf_swell as each surge breaks and draws in by surf_ebb as it goes back.
// On both waters it laps as well, by surf_lap, in lobes along the bank
// lap_scale per metre, so that the whole shore does not breathe as one.
uniform float surf_swell = 0.8;
uniform float surf_ebb = 0.3;
uniform float surf_lap = 0.35;
uniform float lap_scale = 0.35;
uniform vec3 foam_colour : source_color = vec3(0.95, 0.97, 1.0);

// Whitecaps: the open sea breaking here and there, one to a cell cap_cell
// metres across, each on its own cycle -- it breaks, spreads and tears, and is
// gone for the rest of it -- and somewhere else in its cell the next time
// round. Not keyed off the height field: foam on the swell's crests was
// DeepShader's first cut and read as scratches, the fold drawing lines rather
// than patches. cap_size is the radius a cap breaks at, metres; cap_share the
// part of its cycle it lives; cap_drift the pace they ride the swell at. They
// are where `open` passes cap_open, whole or not at all: scaled by it, as the
// rest of the sea's weather is, the ones coming in towards the shore faded
// into pale ghosts of themselves.
uniform float cap_cell = 4.0;
uniform float cap_size = 0.35;
uniform float cap_period = 7.0;
uniform float cap_share = 0.3;
uniform float cap_open = 0.45;
uniform float cap_drift = 0.25;

// 1 on the sea, shore and all, and 0 on the river, over sea_box in world XZ
// (corner, size): level3d_preview.gd, _mark_sea. Its cells are a metre across
// and read filtered, so its edge, in the river's mouth, is a metre soft.
// Unset, it is white, and all of the water is the sea.
uniform sampler2D sea_mask : filter_linear, repeat_disable, hint_default_white;
uniform vec4 sea_box = vec4(0.0, 0.0, 1.0, 1.0);

// How far light gets into the shallows, in metres of water along the view ray,
// before the bottom is lost under the body colour; and how far the surface bends
// what is seen through it, in pixels.
uniform float clarity = 0.15;
uniform float refraction = 14.0;

// The water is lit as it always was, by Burley, while every material round it
// is two-tone and the sun weakened to match (level3d_preview.gd, _toon); this
// gives the water the sun it had back.
uniform float sun_gain = 1.0;
// Nor does it take the scene's ambient, a grey raised for the two-tone
// shadows (SHADE there), but the Blender world's blue it always had: added
// here, as the ambient would have been, to what the sun lights.
uniform vec3 sky = vec3(0.041, 0.066, 0.12);

varying vec3 world;
varying float shore;
varying float open_sea;
// Handed on to light(): how much of the fragment is bare water for the sun to
// glint on.
varying float bare;

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

// vnoise with a quintic fade rather than the cubic one, so that its slope has
// no kink along the lattice. The spark is a normal within a few degrees of
// one direction, so it draws the slope's own contours, and the cubic's kinks
// made those rectangles and L's standing square to the screen.
float vnoise_smooth(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x),
			u.y);
}

// The chop on top: finer, quicker, unfolded. This is what the sun catches.
// Each octave on its own axes, turned 40 degrees from the last, for the same
// reason: two lattices lined up with each other and with the screen add up
// to a grid.
float chop(vec2 p, float t) {
	float h = 0.0;
	float a = 1.0;
	float f = 1.0;
	vec2 drift = vec2(-0.22, 0.31) * t;
	mat2 turn = mat2(vec2(0.766, 0.643), vec2(-0.643, 0.766));
	for (int i = 0; i < 2; i++) {
		p = turn * p;
		h += a * (vnoise_smooth(p * f + drift) - 0.5);
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

// The whitecaps at a point, 0..1, torn as they age along `speck`, a noise
// 0..1 before any threshold. Each cell's cap is looked for in the cell and its
// eight neighbours, since a cap near a cell's edge reaches over it.
float whitecap(vec2 xz, float t, float speck) {
	// Carried with the swell, which drifts this way, and drawn long across
	// it, as a crest breaks along its length.
	vec2 wind = normalize(vec2(0.35, 0.20));
	vec2 q = (xz - wind * TIME * cap_drift) / cap_cell;
	vec2 home = floor(q);
	float cap = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = home + vec2(float(i), float(j));
			float period = cap_period * (0.7 + 0.6 * hash12(c + vec2(4099.0, 0.0)));
			float run = TIME / period + hash12(c);
			float life = fract(run) / cap_share;
			if (life >= 1.0) {
				continue;
			}
			// Somewhere new in the cell each time round, never at its edge.
			float round_no = floor(run);
			vec2 at = c + 0.15 + 0.7 * vec2(hash12(c + vec2(round_no * 7.0, 101.0)),
					hash12(c + vec2(211.0, round_no * 13.0)));
			vec2 off = (q - at) * cap_cell;
			vec2 d = vec2(dot(off, wind), dot(off, vec2(-wind.y, wind.x)) * 0.45);
			// Breaks to its size in the first fifth of its life, and goes on
			// spreading as it fades, the same foam over more of the water.
			float size = cap_size * (0.6 + 0.8 * hash12(c + vec2(round_no, 307.0)))
					* (0.4 + 0.6 * smoothstep(0.0, 0.2, life) + 0.5 * life);
			// Its edge is pushed by the crumple, read in its own frame so that it
			// keeps its shape as it drifts, and pushed hard: a cap is a ragged
			// thing, and at a fraction of this it came out an oval.
			float edge = length(d) + crumple(off * 3.5 + c * 5.3, t) * size * 0.8;
			float body = 1.0 - smoothstep(size * 0.75, size, edge);
			// Solid white where it breaks, lace once it has: the speck cuts it
			// at a threshold that rises with its age, so that it goes as holes
			// opening in it. Fading it evenly left a pale ghost of the whole cap
			// for the last half of its life, and so did cutting the surf's
			// flecks, which are already thresholded and lie at 1 over a third
			// of the water, where no rising cut can reach.
			float cut = 0.75 * smoothstep(0.05, 1.0, life);
			cap = max(cap, body * smoothstep(cut, cut + 0.12, speck)
					* (1.0 - life * life) * smoothstep(0.0, 0.05, life));
		}
	}
	return cap;
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
	// the thickness is then large enough that none of it shows. The slab under
	// the north, Land_Base_North, is sunk to 1.12 m under the surface so that it
	// is lost too: at 0.28 m a sixth of its earth came through, and it ends at
	// z = -15 and x = -15, which drew both as edges across the river's mouth.
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

	float sea = texture(sea_mask, (world.xz - sea_box.xy) / sea_box.zw).r;

	// The surge's cycle: the line arrives at the end of it, and then the swash,
	// out from the wall fast and back slowly -- at its widest a tenth of the
	// way through, at its narrowest at 0.6, and back as it was when the next
	// one arrives.
	float phase = fract(TIME / surge_period);
	float swash = sin(TAU * pow(phase, 0.6));
	float reach = 1.0 + swash * (swash > 0.0 ? surf_swell : surf_ebb) * sea
			+ crumple(world.xz * lap_scale, t) * surf_lap;

	// Foam: the surf line at the shore, its edge pushed by the crumple read on
	// the shore side of the band so the band keeps its width, and lapping as
	// above; and the surge, a thinner line walking in from surge_reach and
	// fading as it arrives. The surge was scaled by `open`, which over the
	// whole of its walk in is 0.04 at most, and it was never seen.
	float push = crumple(world.xz * edge_crumple.x, t) * edge_crumple.y;
	float surf_width = foam_width * max(reach, 0.3);
	float surf = 1.0 - smoothstep(0.0, surf_width, shore + push * surf_width);
	float line_at = mix(surge_reach, foam_width * 0.6, phase);
	float surge = (1.0 - smoothstep(0.0, foam_width * 0.35,
			abs(shore + push * foam_width * 0.5 - line_at)))
			* sin(phase * PI) * sea;
	// Broken twice: into patches by the swell, and into flecks by a finer noise,
	// which is what Blender's surf is -- a dotted line along the bank rather than
	// a stroke drawn round it.
	vec2 drift = vec2(0.11, -0.07) * t;
	float speck = vnoise(world.xz * 5.0 + drift) * 0.65 + vnoise(world.xz * 11.0 - drift) * 0.35;
	float flecks = smoothstep(0.35, 0.6, speck);
	float foam = clamp(max(surf, surge * 0.8), 0.0, 1.0) * shred(world.xz, t)
			* mix(flecks, 1.0, 0.25);
	float caps = whitecap(world.xz, t, speck)
			* smoothstep(cap_open - 0.1, cap_open + 0.1, open_sea);
	foam = max(foam, caps);
	bare = 1.0 - foam;

	vec3 albedo = mix(body * (1.0 - seen), foam_colour, foam);
	ALBEDO = albedo * sun_gain;
	EMISSION = bottom * seen * (1.0 - foam) + albedo * sky;
	ROUGHNESS = mix(roughness_open, roughness_foam, foam);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}

void light() {
	// Godot's own diffuse, Burley, term for term as both renderers' light_compute
	// has it: a light() of one's own replaces all of the built-in lighting, not
	// just its specular, and this is what sun_gain was measured under.
	float cndl = max(min(dot(NORMAL, LIGHT), 1.0), 0.0);
	float cndv = max(dot(NORMAL, VIEW), 1e-4);
	vec3 half_v = normalize(VIEW + LIGHT);
	float cldh = clamp(dot(LIGHT, half_v), 0.0, 1.0);
	float fd90_minus_1 = 2.0 * cldh * cldh * ROUGHNESS - 0.5;
	float fdv = 1.0 + fd90_minus_1 * pow(1.0 - cndv, 5.0);
	float fdl = 1.0 + fd90_minus_1 * pow(1.0 - cndl, 5.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * (fdv * fdl * cndl / PI) * ATTENUATION;

	float spark = pow(max(dot(NORMAL, half_v), 0.0), gloss) * glint;
	vec3 hue = LIGHT_COLOR / max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), max(LIGHT_COLOR.b, 1e-4));
	SPECULAR_LIGHT += hue * spark * ATTENUATION * bare;
}
