// A machine-gun round in the 3D preview, the player's and the enemies'
// (Level3DFx.take_round): a faceted ball, or a diamond drawn out along its
// flight (Level3DFx.ROUND_SHAPE), coloured as the game's EnemyBullet sprite
// is and as the blasts' fire is drawn (level3d_fire.gdshader) -- flat bands
// with hard edges, a white core in a ring of the round's colour, unlit, since
// what it shows is a hot round, not a lit one. Its rim is its contour, thick and in the sprite's rim colour, red
// or near black (level3d_contour.gdshader, the next pass).
//
// Which band a point is in is how squarely the round faces the camera there,
// taken off the sphere or the ellipsoid its corners lie on rather than off its
// facets, so that the core is in its middle from wherever it is seen and is
// not cut into triangles. It casts its shadow as the models do; it takes
// none, being hot.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// How squarely it faces the camera at the core's edge: the yellow round's
// core is a glint, the white one's most of it, or it reads as grey.
uniform float core_edge = 0.85;
uniform vec4 core : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 ring : source_color = vec4(1.0, 0.86, 0.12, 1.0);

varying vec3 round_normal;

void vertex() {
	// The corners lie on the unit sphere: its normal there, through the
	// node's stretch, is the ellipsoid's.
	round_normal = MODELVIEW_NORMAL_MATRIX * VERTEX;
}

void fragment() {
	float facing = clamp(dot(normalize(round_normal), VIEW), 0.0, 1.0);
	ALBEDO = facing > core_edge ? core.rgb : ring.rgb;
}
