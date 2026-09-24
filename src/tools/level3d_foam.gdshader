// The foam round the green boats of the 3D stage 1 preview (level3d_boats.gd):
// the white water at the hull and the wake it leaves. Both are flat, on the
// water, and drawn after it -- the water reads the screen, so it is in the
// transparent pass, and this has a higher render priority than it.
//
// Two uses, `mode`:
//   0  the hull's: a quad round the boat, a child of it, so its vertices are
//      in the model's own metres (bow +z). The foam is a patch the boat sits
//      in: all of a superellipse the shape of the hull's waterline, fuller aft
//      than at the pointed bow, and a band round it, widened at the bow by
//      `speed` -- the bow wave of a boat under way. What is under the hull is
//      hidden by it, so no edge is fitted to its side.
//   1  the wake's: a ribbon behind the stern, UV.x across it 0..1 and UV.y its
//      age 0..1. A churned line down the middle, where the screws are, and the
//      two arms of the wave at its edges, both breaking up and thinning as it
//      ages.
// The noise is the ocean shader's (level3d_ocean.gdshader), in world metres, so
// the foam does not slide with the boat.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform int mode = 0;
uniform vec3 foam_colour : source_color = vec3(0.95, 0.97, 1.0);
// How much of the foam there is, 0..1: the hull's fades when the boat is gone.
uniform float strength = 1.0;
// 0 at rest, 1 under way.
uniform float speed = 0.0;
// 0..1: the water boiling round a boat going down -- a wider band all round,
// broken up.
uniform float churn = 0.0;
// The hull's waterline, model metres: half-width, half-length, and where its
// middle is along the hull.
uniform vec3 waterline = vec3(1.5, 4.5, 0.1);
// The band's width out from the hull, model metres, at rest and at the bow
// under way.
uniform float band = 0.8;
uniform float bow_wave = 0.5;

varying vec3 world;
varying vec3 local;

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

float crumple(vec2 p, float t) {
	vec2 drift = vec2(0.21, -0.13) * t;
	return (vnoise(p + drift) - 0.5) * 1.30
			+ (vnoise(p * 2.17 - drift * 1.40) - 0.5) * 0.60;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX;
}

// The hull's: 0..1 foam at a point `p` of the quad, model metres.
float hull_foam(vec2 p, float n) {
	vec2 q = vec2(p.x / waterline.x, (p.y - waterline.z) / waterline.y);
	// Pointed forward (+y is the bow), full aft, where the transom is.
	float e = q.y > 0.0 ? 2.0 : 4.0;
	float r = pow(pow(abs(q.x), e) + pow(abs(q.y), e), 1.0 / e);
	// Metres off the waterline: r over its gradient, so the band is as wide
	// ahead of the bow as it is abeam, not stretched by the hull's length.
	vec2 grad = pow(abs(q), vec2(e - 1.0)) / pow(r, e - 1.0) / waterline.xy;
	float off = (r - 1.0) / max(length(grad), 1e-4);
	float bow = smoothstep(-0.2, 0.9, q.y);
	float width = band * (0.6 + 0.4 * speed) + bow_wave * speed * bow + 1.4 * churn;
	// Lapping at rest, as the ring comes and goes; a steady wave under way.
	float edge = width * (0.75 + 0.5 * n);
	// From just under the hull's side, so that no water shows between them.
	return 1.0 - smoothstep(edge * 0.6, edge, off);
}

// The wake's: across -1..1, age 0..1.
float wake_foam(float across, float age, float n) {
	float fade = 1.0 - age;
	float centre = exp(-pow(across / (0.16 + 0.22 * age), 2.0)) * pow(fade, 1.4);
	float arms = exp(-pow((abs(across) - 0.84) / 0.09, 2.0)) * fade;
	float head = smoothstep(0.0, 0.06, age);
	return max(centre, arms) * head;
}

void fragment() {
	float t = TIME;
	float n = crumple(world.xz * 3.2, t * 1.6);
	float body;
	if (mode == 0) {
		body = hull_foam(local.xz, n);
	} else {
		body = wake_foam(UV.x * 2.0 - 1.0, UV.y, n);
	}
	// An edge pushed about by noise rather than a band dimmed by it: foam is
	// there or it is not, with a soft rim. At rest the noise breaks the ring
	// into lapping patches; under way it holds together. Only where there is
	// foam to break: noise on open water would be specks all over the quad.
	float foam = smoothstep(0.35, 0.55, body + n * (mix(0.75, 0.45, speed) + 0.4 * churn))
			* smoothstep(0.02, 0.2, body);
	ALBEDO = foam_colour;
	// COLOR.a is the wake's tail fading out; the hull's quad has none, white.
	ALPHA = foam * strength * 0.85 * COLOR.a;
}
