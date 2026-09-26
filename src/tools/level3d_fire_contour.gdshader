// The contour of the fire (level3d_fire.gdshader): level3d_contour.gdshader,
// grown about the ball's middle, and going with the fire, hole for hole
// (level3d_fire.gdshaderinc). Without that a hole would show the contour's
// far side through it, black, where the ground should be.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

#include "res://src/tools/level3d_fire.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float width = 0.014;
uniform float extent = 1.0;

varying vec3 direction;
varying vec3 eye;

void vertex() {
	direction = VERTEX;
	eye = fire_eye(MODEL_MATRIX, CAMERA_POSITION_WORLD);
	vec3 s = max(vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
			length(MODEL_MATRIX[2].xyz)), vec3(1e-5));
	vec3 radius = extent * s;
	VERTEX *= 1.0 + min(vec3(width), radius / 3.0) / radius;
}

void fragment() {
	if (fire_gone(normalize(direction), normalize(eye), burn)) {
		discard;
	}
	ALBEDO = colour.rgb;
}
