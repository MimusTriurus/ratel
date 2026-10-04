// A wall's or a building's surface with the rockets' soot and the rounds'
// pocks on it (level3d_marks.gdshaderinc), lit as every other material of the
// preview's is (level3d_preview.gd, _toon): two tones, no specular, no
// reflection. The glb's material was a StandardMaterial3D; this takes its
// colour. Both sides drawn, as the glb's were.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

#include "res://src/game3d/shaders/level3d_marks.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
// _toon's TOON_EDGE: the step between the two tones, as sharp as it goes.
uniform float roughness = 0.02;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	ALBEDO = marked(world_position, normalize(world_normal), albedo.rgb);
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
