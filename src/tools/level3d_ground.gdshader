// The stage's ground in the 3D preview -- sand, the beach's bands, the forest
// floor, the earth under it all -- with the craters' holes in it
// (level3d_holes.gdshaderinc). The glb's materials are flat colours, lit
// two-tone by the preview's _toon; this is the same light, written out:
// DIFFUSE_TOON stepped at TOON_EDGE, no specular, no metal. Both sides, as
// Blender exported them: some of the ground's pieces face down.
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

#include "res://src/tools/level3d_holes.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (in_crater_hole(world.xz)) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.02;
	METALLIC = 0.0;
}
