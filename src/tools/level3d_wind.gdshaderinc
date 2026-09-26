// The wind in the palms of the 3D preview (level3d_wind.gd): what the palms'
// own material (level3d_wind.gdshader) and their contour
// (level3d_hull_wind.gdshader) share, so that the line goes where the frond
// goes. Nothing here is from the game, whose palms are tiles.
//
// Moved in the vertex shader, not by bones or a clip: there are 150 palms on
// the stage, instances of four meshes, and a skeleton and a player each would
// cost more than the rest of the stage's scenery, and sway in step unless
// every one were set off by hand. Here each palm takes its phase from where
// it stands, and the gusts are a wave running downwind over the map, so that
// neighbours lean together and a row does not.
//
// Three things move:
//   - the trunk bends downwind, by the square of the height, so that the foot
//     stays where it is and the crown goes furthest -- part of it held, the
//     lean, and part of it swaying;
//   - each frond flaps, by the square of how far out from the crown the
//     vertex is (wind_radius, the crown's reach), so that the stalk stays on
//     the crown and the tip goes furthest: up and down, which the tilted
//     camera sees, and round the crown, which the top view does. The phase
//     goes by the frond's bearing from the crown, so neighbours are out of
//     step and a frond, narrow, goes as one;
//   - the gusts scale both.
//
// Everything is worked out from the vertex as the mesh has it, so no weights
// are painted on the models: the height is the mesh's y, its origin at the
// foot, and the crown and its reach are measured once a mesh (level3d_wind.gd).
//
// wind_fps above 0 steps the time, that many frames a second, the way a
// cartoon is drawn on twos -- held poses, which go with the flat colours and
// the line; 0 is smooth.

uniform vec3 wind_crown = vec3(0.0, 1.8, 0.0);
uniform float wind_radius = 1.0;
uniform float wind_fps = 0.0;
uniform float wind_strength = 1.0;

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


float wind_time() {
	return wind_fps > 0.0 ? floor(TIME * wind_fps) / wind_fps : TIME;
}


vec3 wind_moved(vec3 vertex, mat4 model) {
	float t = wind_time();
	vec3 origin = model[3].xyz;
	vec2 to = normalize(WIND_TO);
	float along = dot(origin.xz, to);
	float across = dot(origin.xz, vec2(-to.y, to.x));
	float wave = sin(TAU * (along - t * WIND_GUST_SPEED) / WIND_GUST_LENGTH);
	float gust = (1.0 - WIND_LULL) + WIND_LULL * wave * (0.7 + 0.3 * sin(across * 0.09 + t * 0.21));
	// A palm's own phase, from where it stands.
	float phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * TAU;

	float h = max(vertex.y, 0.0);
	float sway = WIND_LEAN + (1.0 - WIND_LEAN) * sin(TAU * WIND_SWAY_HZ * t + phase);
	vec3 bend = vec3(to.x, 0.0, to.y) * WIND_BEND * h * h * sway * gust;
	// Level metres to the mesh's own: the palms stand scaled and turned.
	bend = inverse(mat3(model)) * bend;

	vec2 off = vertex.xz - wind_crown.xz;
	float out_of = length(off);
	float w = clamp(out_of / wind_radius, 0.0, 1.0);
	w *= w;
	vec2 radial = off / max(out_of, 1e-4);
	float bearing = atan(off.y, off.x);
	float flap = TAU * WIND_FLAP_HZ * t + bearing * 3.0 + phase;
	vec3 frond = (vec3(0.0, WIND_LIFT * sin(flap), 0.0)
			+ vec3(-radial.y, 0.0, radial.x) * WIND_SWING * sin(flap * 0.7 + 1.3)) * w * gust;

	return vertex + (bend + frond) * wind_strength;
}
