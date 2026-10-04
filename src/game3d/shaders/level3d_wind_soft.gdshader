// A tree's or a bush's crown in the wind (level3d_wind.gdshaderinc), lit
// softly as the game over's cemetery is (Level3DGameOver): Lambert's
// diffuse, no specular -- the soft copies' look, which level3d_wind.gdshader,
// the stage's, has in two tones. Both sides drawn, as the glb's were.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://src/game3d/shaders/level3d_wind.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
// The mesh's normal on both sides: a dome's or a crown's, which the back of
// a blade or a leaf is lit by as much as its front. Drawn both sides, the
// back's normal is otherwise turned round.
uniform bool keep_normal = false;

void vertex() {
	VERTEX = wind_moved(VERTEX, MODEL_MATRIX);
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
