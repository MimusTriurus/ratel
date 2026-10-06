shader_type spatial;

// The shop's concrete: the slabs (Level3DShop.Bay._slabs, `slabs` m to a
// tile) and over them, sharp, the concrete's own grain (`grain`, one per
// slab, a quarter turn per slab so that its repeat does not show).
uniform vec4 albedo : source_color = vec4(0.5);
uniform sampler2D slabs : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D grain : filter_linear_mipmap_anisotropic;
uniform float tile = 16.0;
uniform float slab = 4.0;
uniform float contrast = 0.5;
// The slabs laid along the first landing spot: a slab's corner on its
// square's (`origin`, the ground's x and z), turned as it is (`angle`, about
// y); the second's half (x > 0, `mirror`) its mirror image.
uniform vec2 origin = vec2(0.0);
uniform float angle = 0.0;
uniform bool mirror = false;
// The wear, in the first's half (the second's mirrored with it): tyre
// tracks into his jeep (`jeep`, nose along `way`) from behind, as he drove
// in, its own wheels' `gauge` and `tyre` apart and wide; an older pair beside
// them, oil under the jeep's engine and the helicopter (`heli`) and
// here and there. How dark: `track`, `oil`.
uniform vec2 jeep = vec2(0.0);
uniform vec2 way = vec2(0.0, 1.0);
uniform vec2 heli = vec2(0.0);
uniform float track = 0.3;
uniform float oil = 0.5;
uniform float gauge = 0.32;
uniform float tyre = 0.21;
uniform float nose = 0.6;
// The new pair's bend, to the left as it comes, its radius in metres; 0
// straight. Two players: round the helicopter behind the jeep.
uniform float bend = 0.0;

varying vec2 world;

// The grain as a noise: `at` in metres, `size` m to a repeat.
float noise(vec2 at, float size) {
	return texture(grain, at / size).r;
}

// A pair of tyre tracks ending at `to` (and `nose` m on, under the front
// wheels), come along `along`, `reach` m long behind, bent left round
// `radius` m (0 straight); how dark at `p`.
float tracks(vec2 p, vec2 to, vec2 along, float reach, float radius) {
	vec2 d = p - to;
	vec2 left = vec2(-along.y, along.x);
	float t = -dot(d, along);
	float s = abs(dot(d, left));
	if (radius > 0.0 && t > 0.0) {
		vec2 c = to + left * radius;
		vec2 r = p - c;
		float a = atan(dot(r, -along), dot(r, -left));
		t = a < 0.0 ? -1.0 - reach : radius * a;
		s = abs(length(r) - radius);
	}
	float wheel = 1.0 - smoothstep(tyre * 0.4, tyre * 0.55, abs(s - gauge));
	float fade = smoothstep(-nose, -nose + 0.3, t) * (1.0 - smoothstep(reach * 0.4, reach, t));
	return wheel * fade * smoothstep(0.25, 0.6, noise(p, 3.0));
}

// An oil stain about `at`, `size` m across, its edge ragged.
float stain(vec2 p, vec2 at, float size) {
	float r = length(p - at) / (size * 0.5);
	r += (noise(p + at * 7.0, 1.5) - 0.5) * 0.8;
	return 1.0 - smoothstep(0.6, 1.0, r);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = world;
	if (mirror) {
		p.x = -abs(p.x);
	}
	vec2 d = p - origin;
	vec2 ground = vec2(dot(d, vec2(cos(angle), -sin(angle))), dot(d, vec2(sin(angle), cos(angle))));
	vec2 cell = floor(ground / slab);
	vec2 at = fract(ground / slab);
	int turn = int(mod(cell.x * 3.0 + cell.y * 5.0, 4.0));
	if (turn == 1) at = vec2(at.y, 1.0 - at.x);
	else if (turn == 2) at = 1.0 - at;
	else if (turn == 3) at = vec2(1.0 - at.y, at.x);
	float g = textureGrad(grain, at, dFdx(ground / slab), dFdy(ground / slab)).r;
	vec3 base = albedo.rgb * texture(slabs, ground / tile).rgb;
	vec3 colour = base * (1.0 + (g - 0.5) * contrast);
	vec2 side = vec2(-way.y, way.x);
	float worn = tracks(p, jeep, way, 9.0, bend) * track;
	worn = max(worn, tracks(p, jeep + side * 1.3 + way * 1.5, normalize(way - side * 0.08), 12.0, 0.0) * track * 0.6);
	float spilt = stain(p, jeep + way * 0.8, 0.7);
	spilt = max(spilt, stain(p, heli + vec2(0.3, -0.2), 0.9) * 0.8);
	spilt = max(spilt, stain(p, mix(jeep, heli, 0.45) + way * 0.4, 0.45) * 0.7);
	spilt = max(spilt, stain(p, jeep + side * 1.6 - way * 1.4, 0.6) * 0.6);
	colour *= (1.0 - worn) * (1.0 - spilt * oil);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
