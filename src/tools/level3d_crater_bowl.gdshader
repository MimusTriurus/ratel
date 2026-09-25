// A crater's bowl (level3d_fx.gd, crater_mesh): below the ground, and seen
// through it wherever its opening marked the stencil
// (level3d_crater_mask.gdshader). Not depth-tested, or the sand over it
// would hide it; it does not need to be, since a bowl is convex and seen
// from above its opening no two of its inner faces overlap, once the ones
// facing away are culled.
//
// Lit two-tone as everything is (the preview's _toon, which this material,
// a ShaderMaterial, does not get): a stepped N.L, no specular. Coloured by
// its vertices, as the rim is, and taken as they come: converted here from
// sRGB as well, they came out twice as dark and nearly black -- measured,
// the bowl's wall at the rim's inner face's colour, lit and in shade.
shader_type spatial;
render_mode blend_mix, depth_test_disabled, depth_draw_never, cull_back, diffuse_toon, specular_disabled;
stencil_mode read, compare_equal, 1;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.02;
	ALPHA = 1.0;
}
