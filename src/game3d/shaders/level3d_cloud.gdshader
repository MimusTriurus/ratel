// Smoke as one cloud (Level3DCloud): BlenderMCP's CelCloud
// (BlenderMCP/godot/scripts/CelCloud.cs), in the preview's world and light.
//
// Every puff a disc on one quad facing the eye, and the discs flowed into one
// shape -- a smooth union of their distances, `blend` metres wide -- with one
// line round it: drawn one by one as balls, each with its own line
// (Level3DPuffs), the same puffs were a heap of them. Each disc's rim is made
// lumpy by a noise in its own frame, so the lumps go with the puff, and it is
// eaten as it ages, from the rim in. Its light is the stage's two tones
// (diffuse_toon, the preview's _toon) on a normal blended from the puffs'
// spheres with the union's weights, so the sun lights one side of the whole
// column; its depth is the blended front of the same spheres, so what stands
// in the smoke cuts it where it should.
//
// What differs from CelCloud: the world is metres seen in perspective, so the
// line's width is screen pixels at each pixel's depth (`ink_px`, the
// contour's, Level3DHull); the light is the scene's own rather than a ramp
// of three tones, and the line is black, as the contour is.
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled, shadows_disabled;

#include "res://src/game3d/shaders/level3d_noise.gdshaderinc"

const int POOL = 64;
uniform vec4 puffs[POOL];       // xyz the middle, world; w the radius, metres
uniform vec4 looks[POOL];       // x its grey, y a seed, z how far eaten 0..1, w its age 0..1
uniform int count = 0;
uniform float blend = 0.05;
uniform vec3 tint : source_color = vec3(0.96, 0.95, 1.0);
uniform float ink_px = 3.0;
uniform float toon_edge = 0.02;

void fragment() {
	vec2 p = VERTEX.xy;
	// A pixel's size at the quad's depth, metres: the line is screen pixels.
	float px = -VERTEX.z * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	// ink_px is pixels of a frame 1080 high, as the contour's.
	float ink = ink_px * VIEWPORT_SIZE.y / 1080.0 * px;
	float sd = 1e9;
	float wsum = 0.0;
	float zsum = 0.0;
	float tsum = 0.0;
	vec3 nsum = vec3(0.0);
	for (int i = 0; i < POOL; i++) {
		if (i >= count) break;
		vec3 c = (VIEW_MATRIX * vec4(puffs[i].xyz, 1.0)).xyz;
		float r = max(puffs[i].w, 1e-3);
		vec4 lk = looks[i];
		vec2 q = p - c.xy;
		float len = length(q);
		vec2 u = q / max(len, 1e-4);
		// Eaten as it ages, from the rim in, by a noise round it, of what is
		// left of it rather than of the whole puff.
		float bite = noise3(vec3(u * 2.2 + lk.y * 31.0, lk.w * 1.2));
		float left = r * (1.0 - lk.z) * (1.0 + 0.3 * (bite - 0.5));
		// Gone, rather than a dot of ink.
		if (left < 2.0 * ink) continue;
		// Lumps round the rim, in the puff's own frame.
		float bump = noise3(vec3(u * 1.4 + lk.y * 17.0, lk.w * 1.5)) - 0.5;
		float di = len - left * (1.0 + 0.35 * bump);
		// Round in the middle: the noises are of the way round, which has none
		// at the centre.
		float plain = r * (1.0 - lk.z);
		di = mix(len - plain, di, smoothstep(0.2, 0.7, len / max(plain, 1e-3)));
		float h = sqrt(max(0.0, 1.0 - len * len / (r * r)));
		float w = exp(-clamp(di, -r, 3.0 * blend) / blend);
		nsum += normalize(vec3(q / r, max(h, 0.2))) * w;
		zsum += (c.z + r * h) * w;
		tsum += lk.x * w;
		wsum += w;
		float k = clamp(0.5 + 0.5 * (di - sd) / blend, 0.0, 1.0);
		sd = mix(di, sd, k) - blend * k * (1.0 - k);
	}
	if (sd > 0.0 || wsum <= 0.0) discard;
	vec4 clip = PROJECTION_MATRIX * vec4(p, zsum / wsum, 1.0);
	DEPTH = clip.z / clip.w * 0.5 + 0.5;
	ROUGHNESS = toon_edge;
	if (sd > -ink) {
		// The line: black whatever the light, as the contour is.
		ALBEDO = vec3(0.0);
		NORMAL = vec3(0.0, 0.0, 1.0);
	} else {
		ALBEDO = vec3(tsum / wsum) * tint;
		NORMAL = normalize(nsum);
	}
}
