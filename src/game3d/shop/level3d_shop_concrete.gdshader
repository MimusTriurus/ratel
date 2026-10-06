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

varying vec2 world;

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
	ALBEDO = base * (1.0 + (g - 0.5) * contrast);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
