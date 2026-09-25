// A crater's opening (level3d_fx.gd, crater_mesh): the rim's inner foot,
// flat on the ground, drawn only into the stencil buffer. What it marks is
// where the ground is not -- where the bowl below it may show
// (level3d_crater_bowl.gdshader). Depth-tested, so a vehicle or a puff over
// the opening keeps it unmarked, and the bowl is not drawn over them.
// Invisible: in the transparent pass, where the bowl has to be to read the
// stencil, with nothing written but the stencil.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
stencil_mode write, compare_always, 1;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
