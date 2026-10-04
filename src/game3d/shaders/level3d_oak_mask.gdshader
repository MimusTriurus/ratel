// An oak's double in the game over's outline mask (Level3DGameOver,
// _outline_oaks): its leaves cut out as the crown's are and its trunk, in the
// wind as they are (level3d_wind.gdshaderinc), flat in the oak's own mask
// colour -- red full, green none, blue its number -- which
// level3d_oak_ink.gdshader looks for in the mask render.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

#include "res://src/game3d/shaders/level3d_wind.gdshaderinc"

uniform vec4 mask_colour : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform float scissor = 0.5;

void vertex() {
	VERTEX = wind_moved(VERTEX, MODEL_MATRIX);
}

void fragment() {
	ALBEDO = mask_colour.rgb;
	ALPHA = texture(albedo_tex, UV).a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
