// Fire in the 3D preview, and the smoke it cools into: the explosions' lobes,
// the embers they throw, the muzzles' flashes (level3d_rocket.gd,
// level3d_gun.gd, level3d_guns.gd). Explosion's sprite, cel-shaded: the game
// draws a blast in three colours with hard edges, white at the heart, yellow
// round it and a dark red rim, and that is what this is, with an orange
// between the yellow and the red -- four flat bands, their edges hard but
// curved, as the sprite's blobs are.
//
// Which band is a point's heat: how squarely the ball faces the camera there,
// so that the heart is in the middle of the ball from wherever it is seen and
// the rim at its edge, as the sprite's is; ragged by a noise over the ball
// (level3d_fire.gdshaderinc), drawn afresh FRAMES times over each unit of
// `age`, so that the fire boils in steps as the sprite's frames do; more for
// a ball's own `warmth`; and less the older the fire is, `age` 0 to 1, so the
// white goes first and the red is left.
//
// Past 1 it is smoke, as a cartoon blast's fire is by the end: its coolest
// part, the edge, turns grey first and the grey spreads in until by 2 there
// is no fire left in it, the heart last. The grey is two tones, lit from
// `sun` or not. Then it goes, from the middle out (`burn`, fire_gone).
//
// Taken off the round ball the facets stand for -- its direction from the
// middle, and the normal that would be there -- not off the facets: taken off
// them, each facet was all one band, and the bands and holes were cut in
// triangles. The facets still show at the edge, which is the models' look.
//
// Both sides are drawn, the inside in the red or the dark grey, for what
// shows through a hole. Unshaded, as a light is: fire is not lit by the sun,
// and the smoke's two tones are its own.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://src/game3d/shaders/level3d_fire.gdshaderinc"

const float FRAMES = 14.0;

uniform vec4 white : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 yellow : source_color = vec4(1.0, 0.86, 0.12, 1.0);
uniform vec4 orange : source_color = vec4(0.97, 0.36, 0.04, 1.0);
uniform vec4 red : source_color = vec4(0.6, 0.06, 0.02, 1.0);
// J_Smoke's grey, lit and not.
uniform vec4 smoke_lit : source_color = vec4(0.66, 0.64, 0.62, 1.0);
uniform vec4 smoke_dark : source_color = vec4(0.42, 0.4, 0.39, 1.0);
// From the top left of the frame, as the stage's sun is.
uniform vec3 sun = vec3(-0.45, 1.0, -0.45);

varying vec3 direction;
varying vec3 round_normal;
varying vec3 world_normal;
varying vec3 eye;

void vertex() {
	direction = VERTEX;
	round_normal = mat3(MODELVIEW_MATRIX) * VERTEX;
	world_normal = mat3(MODEL_MATRIX) * VERTEX;
	eye = fire_eye(MODEL_MATRIX, CAMERA_POSITION_WORLD);
}

void fragment() {
	vec3 d = normalize(direction);
	if (fire_gone(d, normalize(eye), burn)) {
		discard;
	}
	float smoke = clamp(age - 1.0, 0.0, 1.0);
	vec3 grey = dot(normalize(world_normal), normalize(sun)) > 0.25 ? smoke_lit.rgb : smoke_dark.rgb;
	vec3 colour = smoke > 0.0 ? smoke_dark.rgb : red.rgb;
	if (FRONT_FACING) {
		float facing = clamp(dot(normalize(round_normal), VIEW), 0.0, 1.0);
		float frame = floor(min(age, 1.999) * FRAMES);
		float heat = facing + (fire_noise(d * 2.4 + frame * vec3(3.1, 1.7, 2.3)) - 0.5) * 0.7
				+ 0.12 + warmth - min(age, 1.0) * 0.6;
		colour = red.rgb;
		if (heat > 0.72) {
			colour = white.rgb;
		} else if (heat > 0.5) {
			colour = yellow.rgb;
		} else if (heat > 0.3) {
			colour = orange.rgb;
		}
		if (smoke > 0.0 && heat < mix(0.12, 1.2, smoke)) {
			colour = grey;
		}
	}
	ALBEDO = colour;
}
