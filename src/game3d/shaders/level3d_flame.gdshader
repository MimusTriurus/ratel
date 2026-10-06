// Flames out of a wreck (Level3DBurn): BlenderMCP's CelBurn tongues
// (BlenderMCP/godot/scripts/CelBurn.cs, FlameShader), in the preview's world.
//
// One quad over the fire's ports, facing the eye and upright in the world,
// and on it one field: every tongue of every port a teardrop -- round foot,
// full sides, a soft point -- bent sideways by a noise that climbs it, the
// field their smooth union, and the bands cut on the union once: yellow
// core, orange, red, a dark red rim. A tongue banded on its own laid its rim
// over another's core where they crossed: a row of striped candles. The first
// tongue of a port is its body, always there, breathing on slow noises; the
// rest live `life` seconds each, out of nothing and back to it. One noise
// climbs through the whole fire, biting the top first.
//
// Each pixel stands at the depth of the nearest port whose tongues cover it,
// and nearer by up to half the body's width along its middle: a tongue is a
// body, not a sheet, and the deck in front of a port hides its foot.
//
// What differs from CelBurn: no turret's stencil -- a wreck here has nothing
// standing over its fire that the depth does not settle -- and opaque, there
// being no stencil to be drawn after; metres, not board pixels.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

#include "res://src/game3d/shaders/level3d_noise.gdshaderinc"

const int TONGUES = 4;
uniform vec3 core : source_color = vec3(1.0, 0.93, 0.55);
uniform vec3 body : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 edge : source_color = vec3(0.90, 0.24, 0.06);
uniform vec3 rim : source_color = vec3(0.32, 0.06, 0.03);
uniform vec2 size = vec2(1.0);          // the quad, hull lengths
uniform vec2 ports[4];                  // each port, hull lengths from the quad's foot
uniform int count = 1;
uniform float time = 0.0;
uniform float heat = 1.0;
uniform float life = 0.9;
uniform vec2 tongue = vec2(0.23, 0.35);
uniform float rise = 0.2;
uniform float spread = 0.06;
uniform float port_near[4];             // each port in front of the quad, metres along the eye's ray
uniform float port_size[4];
uniform float hull = 1.0;               // metres

float hash1(float x) { return fract(sin(x * 12.9898 + 4.1414) * 43758.5453); }

// 1 on a tongue's middle line, 0 at its edge, below 0 outside: drawn in to a
// point at the foot, full sides, a soft point.
float drop(vec2 q) {
	if (q.y < -0.4 || q.y > 1.0) return -1.0;
	float in_foot = smoothstep(-0.45, 0.25, q.y);
	float half_w = 0.96 * pow(max(1.0 - q.y, 0.0), 0.55) * in_foot;
	return 1.0 - abs(q.x) / max(half_w, 1e-3);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * size.x, (1.0 - UV.y) * size.y);
	float f = -1.0;
	float near = 0.0;
	float cover = -1e9;
	for (int i = 0; i < 4; i++) {
		if (i >= count) break;
		for (int j = 0; j < TONGUES; j++) {
			float k = float(i * 8 + j);
			float a, h1, h2, s;
			if (j == 0) {
				// The body: bigger, always there, with no life of its own.
				float br = noise3(vec3(time * 0.9, k, 5.0));
				a = 0.22;
				h1 = 0.20 + 0.40 * br;
				h2 = noise3(vec3(time * 0.6, k, 9.0));
				s = 1.1 * (0.85 + 0.20 * br);
			} else {
				float loop = time / life + (float(j) + hash1(k * 7.1) * 0.5) / float(TONGUES);
				a = fract(loop);
				float lap = floor(loop);
				h1 = hash1(k * 13.3 + lap * 1.7);
				h2 = hash1(k * 5.9 + lap * 3.1);
				// The others go out as the fire falls, shrinking, not cut.
				float keep = clamp((0.25 + 0.75 * heat - h2) / 0.15, 0.0, 1.0);
				if (keep <= 0.0) continue;
				// In from nothing and out to nothing.
				s = (0.5 + 0.45 * h1) * smoothstep(0.0, 0.3, a) * (1.0 - smoothstep(0.5, 1.0, a)) * keep;
			}
			s *= pow(heat, 0.6) * port_size[i];
			if (s < 1e-3) continue;
			vec2 base = ports[i] + vec2((h2 - 0.5) * 2.0 * spread * (j == 0 ? 0.3 : 1.0), rise * a * a);
			vec2 q = (p - base) / (tongue * vec2(s, s * (0.8 + 0.5 * h1)));
			// It licks: bent sideways, more the higher up.
			q.x -= (noise3(vec3(q.y * 1.6 - time * 1.3, k, 0.0)) - 0.5) * 0.8 * q.y * q.y;
			float d = drop(q) - a * 0.3;
			if (d > f)
				near = port_near[i];
			if (d > 0.0)
				cover = max(cover, port_near[i]);
			// A smooth union: one sliding over another does not notch it.
			float m = clamp(0.5 + 0.5 * (d - f) / 0.06, 0.0, 1.0);
			f = mix(f, d, m) + 0.06 * m * (1.0 - m);
		}
	}
	near = max(near, cover);
	float thick = 0.5 * tongue.x * 1.1 * pow(heat, 0.6) * hull * sqrt(clamp(f, 0.0, 1.0));
	vec4 clip = PROJECTION_MATRIX * vec4(VERTEX.xy, VERTEX.z + near + thick, 1.0);
	DEPTH = clip.z / clip.w * 0.5 + 0.5;
	// One noise climbing through the whole fire, biting the top first.
	float n = noise3(vec3(p * vec2(7.0, 5.0) - vec2(0.0, time * 2.8), 3.0));
	f -= (n - 0.4) * 0.35 * clamp(p.y / tongue.y, 0.0, 1.5);
	if (f < 0.0) discard;
	vec3 c = rim;
	if (f > 0.10) c = edge;
	if (f > 0.30) c = body;
	if (f > 0.55) c = core;
	ALBEDO = c;
}
