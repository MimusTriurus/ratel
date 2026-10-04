// An oak's crown in the game over's cemetery (Level3DGameOver, _plant_oaks):
// its leaves, open planes cut out of their texture, and the cores of its
// puffs, in the wind (level3d_wind.gdshaderinc) and lit softly, as the rest
// of the cemetery is.
//
// The oaks are BlenderMCP's (resources/3d/oaks/, made by its
// pipeline/tree_gen.py), and are lit as its board lights them: by the
// normals the file gives -- each leaf's and core's the ellipsoid of its puff
// mixed with the whole crown's, so that the crown is lit as one volume rather
// than as a ripple of planes -- on both sides of a leaf, and with no shadow
// from the sun on it: a crown shadowing itself leaf by leaf comes out speckled
// with dark triangles (BlenderMCP's docs/props.md, "Tree3D"). It still casts
// one on the ground.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, shadows_disabled;

#include "res://src/game3d/shaders/level3d_wind.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
// The leaf's shape and colour; a core has none, and is white under its albedo.
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform float scissor = 0.5;
// The colour turned to the cemetery's: the oaks' palette was picked for
// BlenderMCP's board light, and under this warm low sun came out olive-brown,
// a crown of the grass's colour. Linear, per channel.
uniform vec3 tint = vec3(1.0);

void vertex() {
	VERTEX = wind_moved(VERTEX, MODEL_MATRIX);
}

void fragment() {
	// The file's normal on the back of a leaf too: drawn both sides, the
	// back's is otherwise turned round.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec4 leaf = texture(albedo_tex, UV);
	ALBEDO = albedo.rgb * leaf.rgb * tint;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
