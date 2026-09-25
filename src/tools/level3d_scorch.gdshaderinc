// The scorch a rocket leaves where it cannot dig a crater -- on the bridge,
// the helipad, a hangar's pad, the gate's sill, or too near one of them or
// the water for a crater to lie flat (Level3DLauncher._scorch). Painted by
// the shaders of what it lies on (level3d_ground.gdshader), so that it lies
// on every plate, kerb and gap of the bridge the way paint would, where a
// flat mark would float over the gaps or sink under the plates.
//
// Set by Level3DLauncher._push_ground with the craters' holes:
//   scorch_place  x, z of its middle; its radius; a seed for its shape
// A scorch is two ragged SCORCH_SIDES-gons, faceted as the craters are: an
// outer band, the ground darkened towards SOOT, and a heart darker still.
const int SCORCHES = 32;
const int SCORCH_SIDES = 12;
const float SCORCH_BAND = 0.55;
const float SCORCH_HEART = 0.9;

uniform int scorch_count = 0;
uniform vec4 scorch_place[32];
// Level3DFx.SOOT.
uniform vec4 soot : source_color = vec4(0.2, 0.13, 0.07, 1.0);

float scorch_hash(float seed, float k) {
	return fract(sin(seed * 12.9898 + k * 78.233) * 43758.5453);
}

// Whether `d`, from the scorch's middle, is inside the polygon whose corner k
// lies at `radius` * (low + (1 - low) * a hash of k) -- the triangle of the
// middle and the two corners either side of its angle.
bool in_scorch_polygon(vec2 d, float radius, float low, float seed) {
	float wedge = 6.28318530718 / float(SCORCH_SIDES);
	float a = atan(d.y, d.x);
	float k = floor((a < 0.0 ? a + 6.28318530718 : a) / wedge);
	float k1 = mod(k + 1.0, float(SCORCH_SIDES));
	vec2 p0 = radius * (low + (1.0 - low) * scorch_hash(seed, k)) * vec2(cos(k * wedge), sin(k * wedge));
	vec2 p1 = radius * (low + (1.0 - low) * scorch_hash(seed, k1))
			* vec2(cos((k + 1.0) * wedge), sin((k + 1.0) * wedge));
	vec2 e = p1 - p0;
	vec2 q = d - p0;
	return e.x * q.y - e.y * q.x >= 0.0;
}

// `colour` as the scorches have left it at `xz`.
vec3 scorched(vec2 xz, vec3 colour) {
	int tone = 0;
	for (int i = 0; i < SCORCHES; i++) {
		if (i >= scorch_count || tone == 2) {
			break;
		}
		vec4 s = scorch_place[i];
		vec2 d = xz - s.xy;
		if (dot(d, d) >= s.z * s.z || !in_scorch_polygon(d, s.z, 0.7, s.w)) {
			continue;
		}
		tone = in_scorch_polygon(d, s.z * 0.5, 0.6, s.w + 7.0) ? 2 : 1;
	}
	if (tone == 0) {
		return colour;
	}
	return mix(colour, soot.rgb, tone == 2 ? SCORCH_HEART : SCORCH_BAND);
}
