// The wind in the palms and the forest of the 3D preview (level3d_wind.gd),
// and what the blasts and the rounds do to them: what the plants' own
// material (level3d_wind.gdshader) and their contour
// (level3d_hull_wind.gdshader) share, so that the line goes where the frond
// goes. Nothing here is from the game, whose trees are tiles.
//
// Moved in the vertex shader, not by bones or a clip: there are 150 palms and
// 5000 trees on the stage, instances of fourteen meshes, and a skeleton and a
// player each would cost more than the rest of the stage's scenery, and sway
// in step unless every one were set off by hand. Here each plant takes its
// phase from where it stands, and the gusts are a wave running downwind over
// the map, so that neighbours lean together and a row does not.
//
// What moves:
//   - the trunk bends downwind, by the square of the height, so that the foot
//     stays where it is and the crown goes furthest -- part of it held, the
//     lean, and part of it swaying; a tree less than a palm (wind_give);
//   - each frond of a palm flaps (wind_flap), by the square of how far out
//     from the crown the vertex is (wind_radius, the crown's reach), so that
//     the stalk stays on the crown and the tip goes furthest: up and down,
//     which the tilted camera sees, and round the crown, which the top view
//     does. The phase goes by the frond's bearing from the crown, so
//     neighbours are out of step and a frond, narrow, goes as one. A tree's
//     crown is a ball or a cone, all of a piece, and does not;
//   - the gusts scale both;
//   - a blast throws the plant away from it, the shock reaching it later the
//     further off it stands, and it springs back, swinging to rest; a round
//     in a trunk or in the forest is a blast too, small and close. Each shakes
//     the crown as well, fast, and flaps the fronds harder, for as long as the
//     swinging lasts -- the rustle.
//
// Everything is worked out from the vertex as the mesh has it, so no weights
// are painted on the models: the height is the mesh's y, its origin at the
// foot, and the crown and its reach are measured once a mesh (level3d_wind.gd).
// Where the plant stands is the node's, so it moves as one.
//
// The time is the preview's (wind_clock), not the shader's TIME: a blast is
// set down at a moment of it, which TIME, rolling over every hour, cannot be
// matched to. wind_fps above 0 steps it, that many frames a second, the way
// a cartoon is drawn on twos -- held poses, which go with the flat colours
// and the line, and the blasts' swinging goes in them too; 0 is smooth.

uniform vec3 wind_crown = vec3(0.0, 1.8, 0.0);
uniform float wind_radius = 1.0;
uniform float wind_flap = 1.0;
uniform float wind_give = 1.0;
uniform float wind_clock = 0.0;
uniform float wind_fps = 0.0;
uniform float wind_strength = 1.0;

#define WIND_BLASTS 8
// xyz where, level; w when, on wind_clock.
uniform vec4 wind_blasts[WIND_BLASTS];
// x how far it throws a crown WIND_BLAST_UP metres up, y how far it reaches,
// metres; a slot with no reach is empty.
uniform vec2 wind_blast_size[WIND_BLASTS];

// The way the wind blows, level x and z: from the south-west, up the screen
// and across it, so both the top view and the tilted one see it.
const vec2 WIND_TO = vec2(0.8, -0.6);
// The trunk: metres of bend per metre of height squared, at a full gust; the
// share of it held rather than swaying; how often it sways.
const float WIND_BEND = 0.03;
const float WIND_LEAN = 0.45;
const float WIND_SWAY_HZ = 0.32;
// A frond's tip: how far it goes up and down and round the crown, metres at
// a full gust; how often it flaps.
const float WIND_LIFT = 0.1;
const float WIND_SWING = 0.13;
const float WIND_FLAP_HZ = 0.9;
// The gusts: a wave this long, metres, running downwind this fast, m/s, and
// how far the wind drops between them, as a share of a full gust.
const float WIND_GUST_LENGTH = 14.0;
const float WIND_GUST_SPEED = 4.0;
const float WIND_LULL = 0.45;
// A blast: how fast its shock runs over the ground, m/s; how often a plant
// swings back and forth after it, and how fast the swinging dies (1/s); how
// long it is followed at all, seconds; the height its throw is given for.
const float WIND_BLAST_SPEED = 30.0;
const float WIND_BLAST_HZ = 1.3;
const float WIND_BLAST_DAMP = 3.0;
const float WIND_BLAST_LIFE = 1.8;
const float WIND_BLAST_UP = 2.0;
// The rustle: how often the crown shakes and the fronds beat, and how far,
// as a share of the throw for the crown and metres for a frond's tip.
const float WIND_RUSTLE_HZ = 5.5;
const float WIND_RUSTLE_SHAKE = 0.3;
const float WIND_RUSTLE_LIFT = 0.14;
const float WIND_RUSTLE_SWING = 0.1;


float wind_time() {
	return wind_fps > 0.0 ? floor(wind_clock * wind_fps) / wind_fps : wind_clock;
}


vec3 wind_moved(vec3 vertex, mat4 model) {
	float t = wind_time();
	vec3 origin = model[3].xyz;
	vec2 to = normalize(WIND_TO);
	float along = dot(origin.xz, to);
	float across = dot(origin.xz, vec2(-to.y, to.x));
	float wave = sin(TAU * (along - t * WIND_GUST_SPEED) / WIND_GUST_LENGTH);
	float gust = (1.0 - WIND_LULL) + WIND_LULL * wave * (0.7 + 0.3 * sin(across * 0.09 + t * 0.21));
	// A plant's own phase, from where it stands.
	float phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * TAU;

	// The blasts: a throw, level, for a crown WIND_BLAST_UP up, and the rustle,
	// 0 still .. 1 at a full throw's strength.
	vec2 thrown = vec2(0.0);
	float rustle = 0.0;
	for (int i = 0; i < WIND_BLASTS; i++) {
		vec2 size = wind_blast_size[i];
		if (size.y <= 0.0) {
			continue;
		}
		vec2 from = origin.xz - wind_blasts[i].xz;
		float apart = length(from);
		float age = t - wind_blasts[i].w - apart / WIND_BLAST_SPEED;
		if (apart >= size.y || age <= 0.0 || age >= WIND_BLAST_LIFE) {
			continue;
		}
		float near = 1.0 - apart / size.y;
		near *= near;
		float dying = exp(-WIND_BLAST_DAMP * age);
		vec2 away = apart > 1e-3 ? from / apart : vec2(1.0, 0.0);
		thrown += away * size.x * near * dying * sin(TAU * WIND_BLAST_HZ * age);
		rustle += min(size.x * near * dying / 0.1, 1.0);
	}
	rustle = min(rustle, 1.0);

	float h = max(vertex.y, 0.0);
	float sway = WIND_LEAN + (1.0 - WIND_LEAN) * sin(TAU * WIND_SWAY_HZ * t + phase);
	vec2 push = to * WIND_BEND * sway * gust * wind_give * wind_strength
			+ thrown / (WIND_BLAST_UP * WIND_BLAST_UP);
	float shake = sin(TAU * WIND_RUSTLE_HZ * t + phase);
	push += vec2(-to.y, to.x) * shake * length(thrown) * WIND_RUSTLE_SHAKE / (WIND_BLAST_UP * WIND_BLAST_UP);
	// Level metres to the mesh's own: the plants stand scaled and turned.
	vec3 bend = inverse(mat3(model)) * (vec3(push.x, 0.0, push.y) * h * h);

	vec2 off = vertex.xz - wind_crown.xz;
	float out_of = length(off);
	float w = clamp(out_of / wind_radius, 0.0, 1.0);
	w *= w;
	vec2 radial = off / max(out_of, 1e-4);
	vec3 about = vec3(-radial.y, 0.0, radial.x);
	float bearing = atan(off.y, off.x);
	float flap = TAU * WIND_FLAP_HZ * t + bearing * 3.0 + phase;
	float beat = TAU * WIND_RUSTLE_HZ * t + bearing * 5.0 + phase;
	vec3 frond = (vec3(0.0, WIND_LIFT * sin(flap), 0.0) + about * WIND_SWING * sin(flap * 0.7 + 1.3))
			* gust * wind_strength
			+ (vec3(0.0, WIND_RUSTLE_LIFT * sin(beat), 0.0) + about * WIND_RUSTLE_SWING * sin(beat * 0.8 + 2.1))
			* rustle;

	return vertex + bend + frond * w * wind_flap;
}
