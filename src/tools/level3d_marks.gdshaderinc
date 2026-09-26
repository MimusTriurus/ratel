// What the rockets and the rounds leave on the walls and the buildings
// (Level3DMarks): a rocket's soot, a round's pock. Painted by the shaders of
// what they lie on (level3d_marked.gdshader), in the world rather than on a
// quad, so that one lies over a wall's top, its side and the edge between as
// paint would -- the way the rockets' scorches lie on the hard ground
// (level3d_scorch.gdshaderinc), and faceted as those are.
//
// Set by Level3DMarks:
//   mark_place  x, y, z of its middle; its radius, negative for a pock
// A mark is a ball: a face it cuts is marked as far across as the ball cuts
// it, a ragged polygon on the face's plane -- laid out on the two world axes
// the face is nearest to lying along, so that a wall's top takes the same
// shape a scorch on the ground would. Soot is two of them, an outer band and
// a heart darker still, as a scorch is. A pock is smaller and in other tones:
// a ring of the surface paler, chipped to what is under the paint, round a
// dark hole -- the one reads on a face in the shade, the other in the sun, and
// soot's brown on a shaded grey face read as nothing.
const int MARKS = 64;
const int MARK_SIDES = 12;
const int POCK_SIDES = 6;
const float MARK_BAND = 0.55;
const float MARK_HEART = 0.9;
const float POCK_CHIP = 0.35;
const float POCK_HEART = 0.8;
const vec3 POCK_HOLE = vec3(0.04);

uniform int mark_count = 0;
uniform vec4 mark_place[64];
// Level3DMarks.SOOT.
uniform vec4 soot : source_color = vec4(0.16, 0.156, 0.147, 1.0);

float mark_hash(float seed, float k) {
	return fract(sin(seed * 12.9898 + k * 78.233) * 43758.5453);
}

// Whether `d`, on the face from the mark's middle, is inside the polygon of
// `sides` whose corner k lies at `radius` * (low + (1 - low) * a hash of k).
bool in_mark_polygon(vec2 d, float radius, float low, float seed, int sides) {
	if (dot(d, d) >= radius * radius) {
		return false;
	}
	float wedge = 6.28318530718 / float(sides);
	float a = atan(d.y, d.x);
	float k = floor((a < 0.0 ? a + 6.28318530718 : a) / wedge);
	float k1 = mod(k + 1.0, float(sides));
	vec2 p0 = radius * (low + (1.0 - low) * mark_hash(seed, k)) * vec2(cos(k * wedge), sin(k * wedge));
	vec2 p1 = radius * (low + (1.0 - low) * mark_hash(seed, k1))
			* vec2(cos((k + 1.0) * wedge), sin((k + 1.0) * wedge));
	vec2 e = p1 - p0;
	vec2 q = d - p0;
	return e.x * q.y - e.y * q.x >= 0.0;
}

// `colour` at `world`, on a face turned to `normal` (unit length), as the
// marks have left it.
vec3 marked(vec3 world, vec3 normal, vec3 colour) {
	vec3 facing = abs(normal);
	float tone = 0.0;
	int pock = 0;   // 1 the chipped ring, 2 the hole
	for (int i = 0; i < MARKS; i++) {
		if (i >= mark_count) {
			break;
		}
		vec4 m = mark_place[i];
		float r = abs(m.w);
		vec3 d = world - m.xyz;
		if (dot(d, d) >= r * r) {
			continue;
		}
		float off = dot(d, normal);
		float across = sqrt(max(r * r - off * off, 0.0));
		vec2 p = facing.y >= max(facing.x, facing.z) ? d.xz : (facing.x >= facing.z ? d.zy : d.xy);
		float seed = fract(sin(dot(m.xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 100.0;
		if (m.w < 0.0) {
			if (pock < 2 && in_mark_polygon(p, across, 0.6, seed, POCK_SIDES)) {
				pock = in_mark_polygon(p, across * 0.5, 0.6, seed + 7.0, POCK_SIDES) ? 2 : 1;
			}
		} else if (in_mark_polygon(p, across, 0.7, seed, MARK_SIDES)) {
			tone = max(tone, in_mark_polygon(p, across * 0.5, 0.6, seed + 7.0, MARK_SIDES)
					? MARK_HEART : MARK_BAND);
		}
	}
	vec3 c = mix(colour, soot.rgb, tone);
	if (pock == 1) {
		c = mix(c, vec3(1.0), POCK_CHIP);
	} else if (pock == 2) {
		c = mix(c, POCK_HOLE, POCK_HEART);
	}
	return c;
}
