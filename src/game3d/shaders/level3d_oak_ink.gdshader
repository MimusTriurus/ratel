// The oaks' outline in the game over's cemetery (Level3DGameOver,
// _outline_oaks), drawn over its frame rather than grown round a mesh: a
// leaf is an open plane, which Level3DHull's shell cannot ring -- BlenderMCP,
// whose oaks they are, found the same and outlines its crowns this way.
//
// `mask` is the scene again from the same camera, every oak in its own flat
// colour (level3d_oak_mask.gdshader) and everything else as it is, so that
// what stands in front of an oak hides it there too. A pixel of an oak gets
// the ink when within `pixels` of it the mask is not that oak: inside the
// silhouette, round every leaf on the crown's edge and every gap the sky
// shows through, and between two oaks one in front of the other.
shader_type canvas_item;

uniform sampler2D mask : filter_nearest;
uniform float pixels = 3.0;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Which oak a mask pixel is, 0 for none: red full, green none, blue its
// number in sixteenths.
float oak_of(vec3 c) {
	if (c.r < 0.98 || c.g > 0.02) {
		return 0.0;
	}
	return floor(c.b * 16.0 + 0.5) + 1.0;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
	vec2 px = 1.0 / vec2(textureSize(mask, 0));
	float own = oak_of(texture(mask, UV).rgb);
	if (own > 0.0) {
		float reach = pixels;
		bool edge = false;
		// A disc of `pixels`, by eight directions and the rings between.
		for (float r = 1.0; r <= reach && !edge; r += 1.0) {
			for (int i = 0; i < 12; i++) {
				float a = float(i) * TAU / 12.0;
				vec2 at = UV + vec2(cos(a), sin(a)) * r * px;
				if (oak_of(texture(mask, at).rgb) != own) {
					edge = true;
					break;
				}
			}
		}
		if (edge) {
			COLOR = vec4(ink.rgb, 1.0);
		}
	}
}
