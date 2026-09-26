// A palm's or a tree's trunk and crown in the wind (level3d_wind.gdshaderinc),
// lit as every other material of the preview's is (level3d_preview.gd, _toon): two
// tones, no specular, no reflection. The glb's material was a
// StandardMaterial3D, which cannot move its vertices; this takes its colour.
// Both sides drawn, as the glb's were: a palm's fronds are single planes.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

#include "res://src/tools/level3d_wind.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
// _toon's TOON_EDGE: the step between the two tones, as sharp as it goes.
uniform float roughness = 0.02;

void vertex() {
	VERTEX = wind_moved(VERTEX, MODEL_MATRIX);
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
