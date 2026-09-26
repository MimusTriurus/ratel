// A machine-gun round in the 3D preview, the player's and the enemies'
// (Level3DFx.take_round): a faceted ball, or a diamond drawn out along its
// flight (Level3DFx.ROUND_SHAPE), coloured as the game's EnemyBullet sprite
// is and as the blasts' fire is drawn (level3d_fire.gdshader) -- flat bands
// with hard edges, unlit, since what it shows is a hot round, not a lit one:
// a white core, a ring of the round's colour, and a thick rim, red.
//
// Which band a point is in is how far out from the round's middle it is seen,
// `spread` 0 in the middle to 1 on the silhouette -- the sine of the angle between
// the view and the normal, taken off the sphere or the ellipsoid the corners
// lie on rather than off the facets, so that the bands are rings from wherever
// it is seen and are not cut into triangles.
//
// Over everything, as the game draws its rounds (Level3DFx.ROUND_PRIORITY):
// at the height a round flies it went into a ruined bunker's wreck or a
// palm's crown it passed over, and the height does not decide what it hits.
// So the rim is a band of this pass rather than a contour of its own: drawn
// with no depth test, a contour's shell, the next pass, lay over the round.
// It casts its shadow as the models do; it takes none, being hot.
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, shadows_disabled;

uniform vec4 core : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 ring : source_color = vec4(1.0, 0.86, 0.12, 1.0);
uniform vec4 rim : source_color = vec4(0.6, 0.06, 0.02, 1.0);
// Where the core and the ring end, in `spread`: the yellow round's core is a
// glint, the white one's most of it, or it reads as grey.
uniform float core_edge = 0.4;
uniform float rim_edge = 0.75;

varying vec3 round_normal;

void vertex() {
	// The corners lie on the unit sphere: its normal there, through the
	// node's stretch, is the ellipsoid's.
	round_normal = MODELVIEW_NORMAL_MATRIX * VERTEX;
}

void fragment() {
	float facing = clamp(dot(normalize(round_normal), VIEW), 0.0, 1.0);
	float spread = sqrt(1.0 - facing * facing);
	ALBEDO = spread < core_edge ? core.rgb : (spread < rim_edge ? ring.rgb : rim.rgb);
}
