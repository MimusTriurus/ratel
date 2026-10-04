// The game over's grass and flowers in the wind (Level3DGameOver), lit
// softly as the rest of its cemetery is. Its tufts are one mesh, the glb's
// grass joined, so a tuft is not a node with a foot of its own as a tree is
// (level3d_wind.gdshaderinc): each vertex carries its height over the ground
// in UV2.x instead, worked out on load, and bends downwind by its square --
// the foot stays in the ground and the tip goes furthest. The gusts are the
// stage's wind's (wind_gust), the same wave from the same quarter, so that
// they run over the grass and through the trees together; the sway's phase
// comes from where the vertex is, slowly over the ground, so that a tuft's
// blades go together and the field moves in patches, with a faster flutter
// over it that each blade has a little of its own.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://src/game3d/shaders/level3d_wind.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
// The mesh's normal on both sides: a dome's or a crown's, which the back of
// a blade or a leaf is lit by as much as its front. Drawn both sides, the
// back's normal is otherwise turned round.
uniform bool keep_normal = false;

// Metres of bend per metre of height squared at a full gust: a 0.3 m tuft's
// tip goes some 7 cm. The share of it held rather than swaying, and how often
// it sways; the flutter's share and how often.
const float GRASS_BEND = 0.8;
const float GRASS_LEAN = 0.4;
const float GRASS_SWAY_HZ = 0.7;
const float GRASS_FLUTTER = 0.25;
const float GRASS_FLUTTER_HZ = 2.4;

void vertex() {
	float h = max(UV2.x, 0.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = wind_time();
	vec2 to = normalize(WIND_TO);
	float gust = wind_gust(world.xz, t);
	float phase = 1.7 * sin(world.x * 0.9 + world.z * 0.7) + 2.3 * sin(world.x * 0.31 - world.z * 0.53);
	float sway = GRASS_LEAN + (1.0 - GRASS_LEAN) * sin(TAU * GRASS_SWAY_HZ * t + phase);
	float flutter = GRASS_FLUTTER * sin(TAU * GRASS_FLUTTER_HZ * t + phase * 2.0 + world.y * 7.0);
	vec2 push = to * (sway + flutter) * gust * GRASS_BEND * wind_strength * h * h;
	// Bent, the tip comes down a little rather than stretching the blade.
	float drop = dot(push, push) * 0.5 / max(h, 0.05);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(push.x, -drop, push.y);
}

void fragment() {
	if (keep_normal && !FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
