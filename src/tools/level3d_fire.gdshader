// Fire in the 3D preview: the explosions' balls, and the embers they throw
// (level3d_rocket.gd). Explosion's sprite, cel-shaded: the game draws a blast
// in three colours with hard edges, white at the heart, yellow round it and a
// dark red rim, and that is what this is, with an orange between the yellow
// and the red -- four flat bands, their edges hard but curved, as the
// sprite's blobs are.
//
// Which band is a point's heat: how squarely the ball faces the camera there,
// so that the heart is in the middle of the ball from wherever it is seen and
// the rim at its edge, as the sprite's is; ragged by a noise over the ball
// (level3d_fire.gdshaderinc), drawn afresh FRAMES times over the fire's life,
// so that the fire boils in steps as the sprite's frames do; and less the
// older the fire is, `age` 0 to 1, so the white goes first and the red is
// left. Then the ball burns away in holes, `burn` 0 to 1.
//
// Both are taken off the round ball the facets stand for -- its direction
// from the middle, and the normal that would be there -- not off the facets:
// taken off them, each facet was all one band, and the bands and holes were
// cut in triangles. The facets still show at the edge, which is the models'
// look.
//
// Both sides are drawn, the inside in the red, for what shows through a hole.
// Unshaded, as a light is: fire is not lit by the sun.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://src/tools/level3d_fire.gdshaderinc"

const float FRAMES = 8.0;

uniform vec4 white : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 yellow : source_color = vec4(1.0, 0.86, 0.12, 1.0);
uniform vec4 orange : source_color = vec4(0.97, 0.36, 0.04, 1.0);
uniform vec4 red : source_color = vec4(0.6, 0.06, 0.02, 1.0);

varying vec3 direction;
varying vec3 round_normal;

void vertex() {
	direction = VERTEX;
	round_normal = mat3(MODELVIEW_MATRIX) * VERTEX;
}

void fragment() {
	vec3 d = normalize(direction);
	if (fire_burnt(d, burn)) {
		discard;
	}
	vec3 colour = red.rgb;
	if (FRONT_FACING) {
		float facing = clamp(dot(normalize(round_normal), VIEW), 0.0, 1.0);
		float frame = floor(min(age, 0.999) * FRAMES);
		float heat = facing + (fire_noise(d * 2.4 + frame * vec3(3.1, 1.7, 2.3)) - 0.5) * 0.7
				+ 0.12 - age * 0.6;
		if (heat > 0.72) {
			colour = white.rgb;
		} else if (heat > 0.5) {
			colour = yellow.rgb;
		} else if (heat > 0.3) {
			colour = orange.rgb;
		}
	}
	ALBEDO = colour;
}
