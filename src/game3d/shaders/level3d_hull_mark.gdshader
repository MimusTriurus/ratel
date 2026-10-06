// The shop's mark round a part on a jeep (Level3DShop.Bay): the contour's
// hull (level3d_hull.gdshaderinc), grown from every face of the part
// (Level3DHull.mark_hull), in a colour, round the part's outline only.
//
// The part's own faces write 1 to the stencil as they are drawn, and this is
// drawn where they did not: the bores, the rings and every small part inside
// the outline are left without one. Drawn after them, in the transparent
// pass, as the part on trial is see-through and drawn there too.
//
// Both its sides drawn, not only the far one as the contour's: the armour's
// plates are sheets with no far side, and their hull, grown towards the eye,
// faces it all over. Inside the outline the stencil keeps it out either way.
//
// Pulled `bias` metres towards the eye, along the ray, which moves nothing on
// the screen: a part lying flush on the body -- the armour's plates, the
// aerial's foot -- has its hull's far side under the body, which hid it.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
stencil_mode read, compare_not_equal, 1;

#include "res://src/game3d/shaders/level3d_hull.gdshaderinc"

uniform vec3 colour : source_color = vec3(1.0, 0.6, 0.1);
uniform float bias = 0.06;

void vertex() {
	VERTEX = hull_grown(VERTEX, NORMAL, UV.x, MODEL_MATRIX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	vec3 at = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(at + hull_to_eye(at, PROJECTION_MATRIX) * bias, 1.0);
}

void fragment() {
	ALBEDO = colour;
	ALPHA = 1.0;
}
