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
// shows through, and between two oaks one in front of the other. The ink
// hazed as the scene is (`fog_colour`, the mask's green): drawn over the
// finished frame, it would be black at any distance, while the rocks' and
// the crosses' shells are fogged with everything else.
shader_type canvas_item;

uniform sampler2D mask : filter_nearest;
uniform float pixels = 3.0;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// The fog's colour as the environment has it, sRGB: mixed in linear light,
// as Godot fogs the scene's shells -- mixed as sRGB, the same haze left the
// oaks' line half as light as a cross's beside them.
uniform vec4 fog_colour = vec4(0.0, 0.0, 0.0, 1.0);

// Which oak a mask pixel is, 0 for none: red full, green no more than half
// (the haze), blue its number in sixteenths.
float oak_of(vec3 c) {
	if (c.r < 0.98 || c.g > 0.51) {
		return 0.0;
	}
	return floor(c.b * 16.0 + 0.5) + 1.0;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
	vec2 px = 1.0 / vec2(textureSize(mask, 0));
	vec3 here = texture(mask, UV).rgb;
	float own = oak_of(here);
	if (own > 0.0) {
		// `pixels` of a frame 1080 high, as the shells' are: the mask is
		// the screen's size (Level3DPixels), not the frame's.
		float reach = pixels * float(textureSize(mask, 0).y) / 1080.0;
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
			float haze = clamp(here.g * 2.0, 0.0, 1.0);
			COLOR = vec4(to_srgb(mix(to_linear(ink.rgb), to_linear(fog_colour.rgb), haze)), 1.0);
		}
	}
}
