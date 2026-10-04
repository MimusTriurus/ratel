// An oak's double in the game over's outline mask (Level3DGameOver,
// _outline_oaks): its leaves cut out as the crown's are and its trunk, in the
// wind as they are (level3d_wind.gdshaderinc), flat in the oak's own mask
// colour -- red full, blue its number -- which level3d_oak_ink.gdshader
// looks for in the mask render; and in green, halved, how much of the haze
// is between it and the camera, by the formula Godot fogs the scene with
// (`fog_density`, the environment's), so that the oak's ink is hazed as the
// shell round a rock is.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

#include "res://src/game3d/shaders/level3d_wind.gdshaderinc"

uniform vec4 mask_colour : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform float scissor = 0.5;
uniform float fog_density = 0.0;

void vertex() {
	VERTEX = wind_moved(VERTEX, MODEL_MATRIX);
}

void fragment() {
	float haze = 1.0 - exp(min(0.0, -length(VERTEX) * fog_density));
	ALBEDO = vec3(mask_colour.r, haze * 0.5, mask_colour.b);
	ALPHA = texture(albedo_tex, UV).a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
