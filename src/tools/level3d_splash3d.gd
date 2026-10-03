# The title screen's splash made as a scene rather than a picture: the sunset
# of Level3DSplash (level3d_splash.gd), and the jeeps standing against it,
# made in 3D from nothing -- no picture in it -- and cel-shaded as the preview
# draws its units. A prototype, two steps of four in: the sky, the jeeps
# backlit and the ground; the haze, the palms in the wind, the mouse's gust
# and, under --splash-dust, the dust (HAZE_DISTANCE, PALM_WIND, GUST_SPEED,
# RUNNERS); the menu driving the jeeps is still to come. The title shows it in place of
# the picture under --splash-3d (docs/preview3d-options.md).
#
# Its own world in a SubViewport, so that neither the preview's sun nor its
# environment reaches it, and it runs on through the paused tree under the
# title. The SubViewport is drawn by this TextureRect, whose shader fades the
# frame's edges to black so that it sits on the title's black without a seam,
# as the picture's own edges did.
#
# The light is the point of it. The sun is on the horizon behind the jeeps,
# so the light comes straight at the camera, a shade upward: every face the
# camera sees is turned from it and takes the two-tone light's dark tone, and
# the jeeps are silhouettes, as in the picture; the faces turned to the sun,
# which the camera cannot see, are the lit tone. What does show of the light
# is the rim: the faces seen edge on, lit whole when the light is behind
# them -- the light wrapping round the outline, a stepped band as the two
# tones are stepped. Godot's own rim term (BaseMaterial3D.rim) was tried and
# is too thin to see: its width comes from the roughness, which the two-tone
# light holds at 0.02 for a hard edge between the tones. So the paints are
# TOON_SHADER, the two-tone light and the rim in one, the glb's colours
# carried over. The contour is the preview's (Level3DHull).
#
# The sky is SKY_SHADER, the picture's sunset worked out rather than copied:
# a round sun half set, yellow at its heart and orange at its edge, and a red
# glow round it that dies to black, both breathing as Level3DSplash's does. The ground is
# near rolling ground, flat ground out to the horizon, three of the stage's
# palms framing the sun and clumps of boulders off to the side of them, all
# gathered round the sun's edges, silhouettes on the glow.
#
# The camera stands low and looks up. The jeeps are silhouettes only while
# they stand against the sky, so the camera must be below their tops: raised,
# it would look down on them against the ground. Looking up instead puts the
# horizon low in the frame, and less of it is ground.
class_name Level3DSplash3D
extends TextureRect

const JEEP := "res://resources/3d/jackal_jeep.glb"
# The palms are the stage's: these meshes' first instances in its glb.
const STAGE := "res://resources/3d/jackal_stage1.glb"
const PALM_MESHES := ["Palm", "Palm_001", "Palm_002", "Palm_003"]
# The boulders: lumps of rock of their own, not the stage's -- its rocks are
# slabs, 1.1 x 0.4 m at the level's scale, and drawn up tall enough to stand
# above the horizon they were pyramids. Each is the effects' faceted ball
# (Level3DFx.ball) with its corners pushed in and out, ROCK_JITTER of its
# radius, squashed and sunk in the ground, lit as everything else is and
# drawn round as the preview's effects are (Level3DFx.CONTOUR_SHADER).
#
# All of them by hand, in clumps of a big one, a smaller one or two against
# it and stones round them, and all at the sun's edges -- the sun is what the frame is
# about, and what stands in it gathers round it -- but not at the palms'
# feet: just inside the disc's edge, which meets the horizon at x 0.37 of
# the distance, at 0.15 to 0.35, between the palms (0.29 and 0.43 on the
# left, 0.375 on the right) and the jeeps (inside 0.19), and nearer the
# camera than the palms, so that they stand low against the brightest of
# the disc, the tops of the big ones over the horizon. Round the palms' feet
# the two ran together into clumps of palm and rock; at 0.5 they were off at
# the frame's edges, nowhere near the sun. [position, radius at its widest,
# its seed, how squashed it is, its turn in degrees].
const ROCK_JITTER := 0.22
const ROCK_COLOUR := Color(0.2, 0.09, 0.06)
const ROCK_CONTOUR := 0.035
const ROCKS := [
	# Left, between the near palm and the jeep, the stones nearest it partly
	# behind it.
	[Vector3(-5.9, 0.0, -30.0), 1.2, 3, 0.75, 20.0],
	[Vector3(-7.0, 0.0, -31.2), 0.75, 7, 0.85, 140.0],
	[Vector3(-5.0, 0.0, -28.6), 0.45, 12, 0.8, 70.0],
	[Vector3(-7.5, 0.0, -29.3), 0.3, 21, 0.8, 10.0],
	[Vector3(-4.6, 0.0, -31.8), 0.28, 22, 0.9, 200.0],
	[Vector3(-8.2, 0.0, -32.6), 0.35, 23, 0.75, 90.0],
	[Vector3(-4.2, 0.0, -29.8), 0.22, 24, 0.85, 300.0],
	# Right, between the jeep and the palm.
	[Vector3(8.6, 0.0, -30.0), 1.25, 5, 0.7, 200.0],
	[Vector3(10.2, 0.0, -31.4), 0.75, 9, 0.9, 310.0],
	[Vector3(7.4, 0.0, -28.6), 0.45, 14, 0.8, 30.0],
	[Vector3(9.3, 0.0, -29.0), 0.3, 25, 0.85, 120.0],
	[Vector3(11.2, 0.0, -32.3), 0.33, 26, 0.75, 60.0],
	[Vector3(7.0, 0.0, -30.6), 0.25, 27, 0.9, 250.0],
	[Vector3(6.6, 0.0, -28.0), 0.2, 28, 0.8, 170.0],
]
# The stage's palms are 2.3 m tall at the level's scale, where the jeep is
# 0.375 of this scene's: 2.67 times that is a palm by the jeep as in the game,
# and they are drawn half again as tall, palms being taller than the game's.
const PALM_SCALE := 4.0
# Where they stand, by hand: two at the left edge of the sun and one at the
# right, where they frame it -- [position, which of PALM_MESHES, its turn in
# degrees, its scale over PALM_SCALE]. The disc's edge on the horizon is
# 20 degrees off the middle, x 0.37 of the distance. The far one on the left
# stands right by it, at 0.43; the near one inside it, against the sun, at
# 0.29. Their crowns -- 0.07 and 0.1 of their distance either side of the
# trunk -- would touch that close, so the far one is the shorter, its crown
# below the near one's fronds: at 0.37 and 0.375 the far one stood behind
# the near one.
const PALMS := [
	[Vector3(-12.8, 0.0, -44.0), 0, 20.0, 1.0],
	[Vector3(-24.0, 0.0, -56.0), 2, 140.0, 0.78],
	[Vector3(18.0, 0.0, -48.0), 1, 250.0, 1.05],
]
# The frame's width over its height: Level3DSplash's picture's, 1024 x 504,
# so that the two take the same place on the title.
const ASPECT := 1024.0 / 504.0

# The jeep's launcher fits (level3d_rocket.gd's FITS, and the spare ones in
# level3d_btr.gd): only the missiles' is shown, the picture's rocket pods.
const SHOWN_FIT := "LauncherBase"
const HIDDEN_FITS := ["MortarBase", "HeavyLauncherBase", "StageLauncherBase", "GradBase",
		"TubeLauncherBase"]

# Where everything stands, in metres; the jeeps are at the glb's own scale,
# 1:1, and face the camera, down +Z.
# Low, a metre up, and tilted up by CAMERA_TILT degrees, which puts the
# horizon some 70% of the way down the frame.
const CAMERA_AT := Vector3(0, 1.0, 0)
const CAMERA_TILT := 7.0
const CAMERA_FOV := 34.0
const JEEPS := [Vector3(-2.8, 0, -21), Vector3(2.8, 0, -21)]
# Each turned out from the middle by this much, degrees: straight at the
# camera their sides are edge on to nothing, and the rim has no side to run
# down.
const JEEP_TOE := 14.0
# The near ground runs from behind the camera this far, this wide; the far
# ground, flat, from there to FAR_GROUND, near enough the horizon.
const GROUND_SIZE := Vector2(140, 75)
const FAR_GROUND := 1500.0

# The sun's light: straight at the camera, raised this many degrees -- a
# negative elevation is light travelling upward, so that the tops of the
# jeeps, turned up, are turned from it too.
const SUN_ELEVATION := -1.5
const SUN_COLOUR := Color(1.0, 0.62, 0.32)
const SUN_ENERGY := 1.4
# The dark tone: what the ambient light makes of a face the sun misses.
const AMBIENT := Color(0.55, 0.22, 0.16)
const AMBIENT_ENERGY := 0.22
# The rim: how far round from edge on it reaches (1 - the cosine of the
# face's angle to the view), how bright, and how much of the paint's own
# colour it takes rather than the light's.
const RIM_WIDTH := 0.45
const RIM := 0.9
const RIM_TINT := 0.35
# A single plane's rim, the fronds' and the glass's: narrower and fainter.
const PLANE_RIM := 0.5
const PLANE_RIM_WIDTH := 0.12

# Dark, so that the faces the low sun catches are a glint and not a stripe.
const GROUND_COLOUR := Color(0.085, 0.036, 0.028)

# CULL is replaced: back for a solid, disabled for a single plane -- the
# palms' fronds, the jeep's glass. Godot turns a back face's normal round
# itself when nothing is culled; turned again here, it lit every pane and
# frond seen from behind.
const TOON_SHADER := """
shader_type spatial;
render_mode CULL;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_width = 0.3;
uniform float rim = 0.9;
uniform float rim_tint = 0.35;
void fragment() {
	ALBEDO = albedo.rgb;
}
void light() {
	// The two tones: lit or not, no shading between.
	DIFFUSE_LIGHT += step(0.0, dot(NORMAL, LIGHT)) * ATTENUATION * LIGHT_COLOR / PI;
	// The rim: seen edge on, with the light behind.
	float edge_on = step(1.0 - rim_width, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	float behind = clamp(-dot(LIGHT, VIEW), 0.0, 1.0);
	vec3 band = edge_on * behind * rim * ATTENUATION * LIGHT_COLOR / PI;
	// Diffuse is taken times the paint, specular is not: the tint between.
	DIFFUSE_LIGHT += band * rim_tint;
	SPECULAR_LIGHT += band * (1.0 - rim_tint);
}
"""

# The dust: clouds of it, raised by the wind -- off unless the preview is run
# with --splash-dust. RUNNERS gusts skim along the
# ground downwind, each a wheel nobody sees, and while a runner's gust is up
# (RUNNER_PULSE: it comes and goes) it raises a cloud every CLOUD_EVERY
# seconds, so that a gust leaves a few behind it, overlapping, and then none.
#
# A cloud is one body with a life of its own, CLOUD_LIFE seconds: born a
# small knot on the ground, it swells as it rises and drifts downwind, and
# then breaks up -- eaten away in holes that widen until nothing is left, the
# way cel-shaded smoke goes (DUST_SHADER). Its body is one ball, faceted
# (Level3DFx.ball), pushed out by a noise of its own into lobes, billows on
# billows, flattened, drawn out along the wind and half sunk in the ground;
# its normals are worked out from the pushed shape, smooth over each lobe, so
# that it is lit as the lobes it has. Pushed both in and out, it was a lumpy
# ball, a potato.
#
# This is the third go at it. A stream of small balls, one per DUST_STEP of
# a runner, as the preview's wheels raise theirs (Level3DPuffs), was a string
# of bubbles: every ball drew its own rim, and no cloud was ever one thing.
# Soft translucent spheres were blots, and big solid balls lumps that read
# as rocks.
#
# The runners cross the frame, not a box: at each depth they come in just
# past its upwind edge and leave past the other, VIEW_SLOPE of the depth
# either side of the middle -- the frame's half width over its distance. A
# box as wide as the far frame put most of them out of the near one.
const RUNNERS := 8
const DUST_DEPTH := 30.0               # z from DUST_NEAR away
const DUST_NEAR := 7.0
const VIEW_SLOPE := 0.66
const RUNNER_SPEED := Vector2(1.4, 2.2)
const RUNNER_PULSE := Vector2(6.0, 10.0) # seconds a gust takes to come and go
const CLOUD_EVERY := Vector2(0.7, 1.4)
const CLOUD_LIFE := Vector2(3.0, 5.0)
# A cloud's radius at its biggest, metres, a little more far off; how big it
# is born, as a share of that; how high it rises over its life, as a share of
# its radius; how much flatter than round it is, and how much longer along
# the wind -- low and long, hugging the ground. Grown with the distance to
# hold their size in the frame, and rising as far as their radius, they were
# boulders of dust taller than the jeeps.
const CLOUD_RADIUS := Vector2(0.45, 0.85)
const CLOUD_BORN := 0.2
const CLOUD_RISE := 0.12
const CLOUD_FLAT := 0.6
const CLOUD_LONG := 1.7
const CLOUD_POOL := 120
const WIND := Vector3(1.3, 0.0, 0.0)
# The preview's dust is sand (Level3DPuffs' "ground"). Lit as the solids
# are, it was dark against the sun and lost on the dark ground, its rim all
# that showed; dust lets the light through, so its two tones are its own
# (DUST_SHADER): the faces turned from the sun, which the camera sees, take
# the light that comes through, DUST_THROUGH of it, past a step; the rest
# are the dark tone; the edge has the rim -- one rim round the cloud.
const DUST_COLOUR := Color(0.93, 0.76, 0.48)
const DUST_THROUGH := 0.5
const DUST_STEP_AT := 0.3
# Narrower than a solid's: a cloud's lobes each have an edge.
const DUST_RIM_WIDTH := 0.25

# The cloud's body and its going (vertex and fragment): `lump` how far the
# noise pushes the surface in and out, as a share of the radius; the life
# share at which it starts to break up. INSTANCE_CUSTOM is the cloud's life,
# 0..1, and its seed.
const DUST_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float through = 0.5;
uniform float step_at = 0.3;
uniform float rim_width = 0.45;
uniform float rim = 0.9;
uniform float rim_tint = 0.35;
uniform float lump = 0.5;
uniform float break_up = 0.55;
varying vec3 dir;
varying float life;
varying float seed;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Billows: a few big round lobes bulging outward only, so that the outline
// is a run of them rather than a lumpy ball; they churn a little as the cloud
// lives. A second, finer octave of lobes on the lobes, each with its own
// line between the tones, mottled the cloud like marble.
vec3 billowed(vec3 d, float s, float l) {
	vec3 q = d * 2.0 + vec3(s, s * 0.7, l * 0.9);
	float lobe = smoothstep(0.25, 0.85, noise(q));
	return d * (1.0 - lump * 0.5 + lump * lobe * 1.4);
}

void vertex() {
	life = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y * 37.0;
	dir = normalize(VERTEX);
	VERTEX = billowed(dir, seed, life);
	// The normal of the billowed surface, from two points beside this one:
	// smooth over each lobe, so that the two tones part along its curve.
	// The ball's own were its facets', and the facets of the billows, lit
	// one by one, were shards.
	vec3 t1 = normalize(cross(dir, abs(dir.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 t2 = cross(dir, t1);
	vec3 a = billowed(normalize(dir + t1 * 0.03), seed, life) - VERTEX;
	vec3 b = billowed(normalize(dir + t2 * 0.03), seed, life) - VERTEX;
	vec3 n = normalize(cross(a, b));
	NORMAL = dot(n, dir) < 0.0 ? -n : n;
}

void fragment() {
	// Broken up: eaten away where a noise over its surface is under a level
	// that rises from nothing at break_up to all of it at the end.
	float e = noise(dir * 3.2 + seed * 1.7) * 0.7 + noise(dir * 7.0 + seed) * 0.3;
	if (e < smoothstep(break_up, 1.0, life) * 1.05) {
		discard;
	}
	ALBEDO = albedo.rgb;
}

void light() {
	// Lit through: turned from the light by more than step_at.
	DIFFUSE_LIGHT += step(step_at, -dot(NORMAL, LIGHT)) * through * ATTENUATION * LIGHT_COLOR / PI;
	float edge_on = step(1.0 - rim_width, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	float behind = clamp(-dot(LIGHT, VIEW), 0.0, 1.0);
	vec3 band = edge_on * behind * rim * ATTENUATION * LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += band * rim_tint;
	SPECULAR_LIGHT += band * (1.0 - rim_tint);
}
"""

# The palms sway as the preview's do (level3d_wind.gdshaderinc), gently.
const PALM_WIND := 0.6

# The haze, Level3DSplash's, here a picture of the frame bent where it runs
# through a sheet of warm air: a quad standing HAZE_DISTANCE away, behind the
# jeeps -- so that they, nearer, do not waver, the disc and the far ground
# and the far palms do -- and HAZE_REACH metres tall, strongest at the
# ground.
const HAZE_DISTANCE := 40.0
const HAZE_REACH := 10.0

# The mouse: a moving cursor is a gust where it points at the ground, the
# dust there blown away from it and along with it, the air over it stirred.
# As Level3DSplash's: the cursor's speed, in pixels a second of the frame,
# that blows at full strength, and how quickly a gust dies down (1/s); how
# far round it reaches, metres, and how hard it pushes, m/s^2.
const GUST_SPEED := 1500.0
const GUST_DECAY := 1.5
const GUST_RADIUS := 4.0
const GUST_PUSH := 16.0

const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float reach = 10.0;
// How far the air pushes a pixel at the ground, in pixels of a frame 406
// high, sideways and up or down; how fast it rises, m/s.
uniform vec2 push = vec2(2.5, 1.2);
uniform float rise = 0.7;
uniform vec2 mouse = vec2(-10.0);
uniform float gust = 0.0;
uniform float aspect = 0.4922;
varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = world.y;
	float strength = smoothstep(-0.3, 0.3, h) * (1.0 - smoothstep(0.0, reach, h));
	vec2 from_mouse = (SCREEN_UV - mouse) * vec2(1.0, aspect);
	strength *= 1.0 + 2.5 * gust * exp(-dot(from_mouse, from_mouse) / 0.008);
	// Two octaves, cells wider than they are tall: layers of warm air rising.
	vec2 p = vec2(world.x * 0.45, (world.y - TIME * rise) * 1.4);
	vec2 n = vec2(noise(p) * 0.65 + noise(p * 2.3 + 17.0) * 0.35,
			noise(p + 41.0) * 0.65 + noise(p * 2.3 + 59.0) * 0.35);
	vec2 offset = (n - 0.5) * 2.0 * push * strength / 406.0 * vec2(aspect, 1.0);
	ALBEDO = textureLod(screen, SCREEN_UV + offset, 0.0).rgb;
}
"""

const EDGE := """
shader_type canvas_item;
// The frame fades to black this far in from each edge, as a share of the
// width and the height: wider at the bottom, where the ground runs out.
uniform vec4 fade = vec4(0.12, 0.08, 0.12, 0.16); // left, top, right, bottom
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float f = smoothstep(0.0, fade.x, UV.x) * smoothstep(0.0, fade.z, 1.0 - UV.x)
			* smoothstep(0.0, fade.y, UV.y) * smoothstep(0.0, fade.w, 1.0 - UV.y);
	COLOR = vec4(c.rgb * f, 1.0);
}
"""

# The sky, measured off the picture. Its sun is round, and setting: a circle
# 335 px in radius whose centre is 157 px under the horizon, so that what
# shows is a segment of it, 590 px across and 178 high -- which reads, by its
# width and height alone, as an ellipse 1.6 times as wide as it is tall and
# centred on the horizon, and was drawn so once, squashed. The glow is round
# about the same centre, its brightness the same at the same distance from
# it all the way round.
#
# So here: the angle between the eye's direction and the sun's centre, which
# is `sink` radians under the horizon, in units of the sun's radius. The
# picture's 296 px of half width on the horizon is 0.353 rad, so that the
# sun is as much of the frame's width as the picture's is of its own, 57%;
# the radius is 1.132 of that and the sink 0.53 of it. The colours are
# interpolated in the picture's own sRGB, which is what the renderer takes
# (no conversion: Compatibility draws the sky's colour as it is), as read off
# it at these radii: the disc white-yellow up
# to half its radius (all of it under the horizon but its top) and orange at
# its edge; the glow outside a step darker, red dying to black by 1.75 radii.
# The breath is Level3DSplash's: once every `breath` seconds the sun a little
# bigger and brighter.
const SKY_SHADER := """
shader_type sky;
uniform float radius = 0.4;
uniform float sink = 0.187;
uniform float breath = 7.0;
uniform float swell = 0.012;
uniform float brighten = 0.05;
// sRGB, 0..1.
const vec3 HEART = vec3(253.0, 227.0, 6.0) / 255.0;
const vec3 EDGE = vec3(246.0, 58.0, 1.0) / 255.0;
const vec3 GROUND = vec3(5.0, 2.0, 1.0) / 255.0;
// The glow: radii and the picture's red and green there.
const float GLOW_R[7] = float[](1.0, 1.06, 1.13, 1.2, 1.36, 1.55, 1.75);
const float GLOW_RED[7] = float[](235.0, 209.0, 146.0, 91.0, 40.0, 8.0, 0.0);
const float GLOW_GREEN[7] = float[](36.0, 25.0, 8.0, 6.0, 2.0, 0.0, 0.0);

vec3 glow(float r) {
	for (int i = 0; i < 6; i++) {
		if (r < GLOW_R[i + 1]) {
			float t = (r - GLOW_R[i]) / (GLOW_R[i + 1] - GLOW_R[i]);
			return vec3(mix(GLOW_RED[i], GLOW_RED[i + 1], t), mix(GLOW_GREEN[i], GLOW_GREEN[i + 1], t), 0.0) / 255.0;
		}
	}
	return vec3(0.0);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(vec3(0.0, -sin(sink), -cos(sink)));
	float b = 0.5 - 0.5 * cos(TIME * TAU / breath);
	float r = acos(clamp(dot(d, sun), -1.0, 1.0)) / (radius * (1.0 + swell * b));
	vec3 c = r < 1.0 ? mix(HEART, EDGE, clamp((r - 0.47) / 0.53, 0.0, 1.0)) : glow(r);
	c *= 1.0 + brighten * b;
	// Below the horizon only past the far ground's edge: as dark as it.
	c = d.y < 0.0 ? GROUND : c;
	// The Compatibility renderer takes the sky's colour as sRGB as it is.
	COLOR = c;
}
"""

var viewport: SubViewport
var camera: Camera3D
var jeeps: Array[Node3D] = []

var _height: Callable        # the near ground's height at (x, z)
var _dust_mesh: MultiMeshInstance3D
var _haze_mesh: MeshInstance3D
var _runners: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _oldest := 0
var _wind_materials: Array[ShaderMaterial] = []
var _dust_rng := RandomNumberGenerator.new()
var _time := 0.0
var _gust := 0.0
var _last_mouse := Vector2.ZERO
var _mouse_ground = null     # Vector3 or null
var _mouse_velocity := Vector3.ZERO


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := Shader.new()
	edge.code = EDGE
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = edge

	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(viewport)
	texture = viewport.get_texture()
	_build()


# `width` wide at ASPECT, centred on `centre`, as Level3DSplash.place puts the
# picture; rendered at the size it is drawn.
func place(centre: Vector2, width: float) -> void:
	size = Vector2(width, width / ASPECT)
	position = centre - size * 0.5
	viewport.size = Vector2i(size.round())


func _build() -> void:
	var world := Node3D.new()
	viewport.add_child(world)

	var environment := Environment.new()
	var sky_shader := Shader.new()
	sky_shader.code = SKY_SHADER
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# The light is the sun's and the colour's below, not the sky's.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT
	environment.ambient_light_energy = AMBIENT_ENERGY
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.light_color = SUN_COLOUR
	sun.light_energy = SUN_ENERGY
	world.add_child(sun)
	# Pointing from the sky at the camera, the light's -Z its way.
	var travel := Vector3(0, sin(deg_to_rad(-SUN_ELEVATION)), cos(deg_to_rad(SUN_ELEVATION)))
	sun.basis = Basis.looking_at(travel, Vector3.UP)

	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.far = FAR_GROUND * 1.5
	world.add_child(camera)
	camera.position = CAMERA_AT
	camera.rotation.x = deg_to_rad(CAMERA_TILT)

	world.add_child(_ground())
	for at in JEEPS:
		var jeep := _jeep()
		world.add_child(jeep)
		jeep.position = at
		jeep.rotation.y = deg_to_rad(JEEP_TOE) * signf(at.x) * -1.0
		jeeps.append(jeep)
	_haze_mesh = _haze()
	world.add_child(_haze_mesh)
	# --splash-dust: the dust clouds, which are off unless asked for.
	if OS.get_cmdline_user_args().has("--splash-dust"):
		_dust_mesh = _dust()
		world.add_child(_dust_mesh)


# Gently rolling ground, faceted, out of a fixed seed so that the frame is
# the same every time, flat ground beyond it, and the rocks and palms where
# ROCKS and PALMS put them.
func _ground() -> Node3D:
	var root := Node3D.new()
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.08
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var cells := Vector2i(70, 40)
	var step := GROUND_SIZE / Vector2(cells)
	var origin := Vector2(-GROUND_SIZE.x * 0.5, 8.0)  # x, and z nearest the camera
	var height := func(x: float, z: float) -> float:
		# Flat round the jeeps, rolling towards the sides.
		# Low in front of the camera too, where a slope turned to the sun
		# would be a broad lit band across the frame.
		var side := clampf(absf(x) / 30.0, 0.0, 1.0)
		var far := clampf(-z / 25.0, 0.0, 1.0)
		return noise.get_noise_2d(x, z) * (0.2 + 1.4 * side * side * far)
	_height = height
	for j in cells.y:
		for i in cells.x:
			var x0 := origin.x + i * step.x
			var z0 := origin.y - j * step.y
			var x1 := x0 + step.x
			var z1 := z0 - step.y
			var a := Vector3(x0, height.call(x0, z0), z0)
			var b := Vector3(x1, height.call(x1, z0), z0)
			var c := Vector3(x1, height.call(x1, z1), z1)
			var d := Vector3(x0, height.call(x0, z1), z1)
			for v in [a, c, b, a, d, c]:
				st.add_vertex(v)
	st.generate_normals()
	var ground := MeshInstance3D.new()
	ground.mesh = st.commit()
	ground.material_override = _toon(GROUND_COLOUR, 0.0)
	root.add_child(ground)
	# Beyond, flat to the horizon, a little under the near ground so that the
	# two do not fight where they overlap.
	var far := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FAR_GROUND * 2.0, FAR_GROUND)
	far.mesh = plane
	far.material_override = ground.material_override
	far.position = Vector3(0, -0.3, -FAR_GROUND * 0.5)
	root.add_child(far)

	# The boulders, where ROCKS puts them.
	var rock_paint := _toon(ROCK_COLOUR, RIM)
	var line := ShaderMaterial.new()
	line.shader = Level3DFx.CONTOUR_SHADER
	line.set_shader_parameter("width", ROCK_CONTOUR)
	line.set_shader_parameter("extent", 1.0 + ROCK_JITTER)
	rock_paint.next_pass = line
	for entry in ROCKS:
		var at: Vector3 = entry[0]
		_rock(root, Vector3(at.x, height.call(at.x, at.z), at.z), entry[1], entry[2], entry[3], entry[4],
				rock_paint)

	var palm_meshes := _stage_meshes(PALM_MESHES)
	if palm_meshes.size() == PALM_MESHES.size():
		for entry in PALMS:
			var at: Vector3 = entry[0]
			var palm := MeshInstance3D.new()
			palm.mesh = palm_meshes[entry[1]]
			_dress(palm)
			_sway(palm)
			palm.scale = Vector3.ONE * PALM_SCALE * float(entry[3])
			palm.rotation.y = deg_to_rad(entry[2])
			palm.position = Vector3(at.x, height.call(at.x, at.z) - 0.05, at.z)
			root.add_child(palm)
	return root


# A boulder on the ground at `at`: `radius` at its widest, out of a ball of
# its own `seed`, squashed to `squash` of its width, turned `turn` degrees
# and sunk a third of its height.
func _rock(root: Node3D, at: Vector3, radius: float, seed: int, squash: float, turn: float,
		paint: Material) -> void:
	var rock := MeshInstance3D.new()
	rock.mesh = Level3DFx.ball(1, ROCK_JITTER, seed)
	rock.material_override = paint
	rock.scale = Vector3(1.0, squash, 0.9) * radius
	rock.rotation.y = deg_to_rad(turn)
	rock.position = at + Vector3.UP * radius * squash * 0.35
	root.add_child(rock)


# Meshes of the stage's, by the names of their first instances in
# jackal_stage1.glb, which the preview has loaded already when the title
# shows (the glb is 60 ms to load and 16 to instance when it has not).
func _stage_meshes(names: Array) -> Array[Mesh]:
	var meshes: Array[Mesh] = []
	var stage: Node3D = (load(STAGE) as PackedScene).instantiate()
	for name in names:
		var palm := stage.find_child(name, true, false) as MeshInstance3D
		if palm != null:
			meshes.append(palm.mesh)
	stage.free()
	return meshes


# A glb's mesh in this scene's light: the preview's contour, and its paints
# as TOON_SHADER.
func _dress(mesh_instance: MeshInstance3D) -> void:
	Level3DHull.apply(mesh_instance)
	for surface in mesh_instance.mesh.get_surface_count():
		var paint := mesh_instance.mesh.surface_get_material(surface)
		if paint == null or Level3DHull.is_hull(paint):
			continue
		# The glb's materials are shared with the preview's, so the rim goes
		# on copies of them. A palm the preview has put in the wind already
		# (Level3DWind) has its paints swapped for the wind's shader, which
		# keeps the colour as "albedo" and draws both sides.
		if paint is BaseMaterial3D:
			mesh_instance.set_surface_override_material(surface, _rimmed(paint))
		elif paint is ShaderMaterial and paint.get_shader_parameter("albedo") != null:
			var plane := String(paint.resource_name).contains("Frond")
			var m := _toon(paint.get_shader_parameter("albedo"), RIM * (PLANE_RIM if plane else 1.0), true)
			if plane:
				m.set_shader_parameter("rim_width", PLANE_RIM_WIDTH)
			mesh_instance.set_surface_override_material(surface, m)


func _jeep() -> Node3D:
	var jeep: Node3D = (load(JEEP) as PackedScene).instantiate()
	var prefix := "Jeep_"
	for fit in HIDDEN_FITS:
		var node := jeep.find_child(prefix + fit, true, false) as Node3D
		if node != null:
			node.visible = false
	var shown := jeep.find_child(prefix + SHOWN_FIT, true, false) as Node3D
	if shown != null:
		shown.visible = true
	for node in jeep.find_children("*", "MeshInstance3D", true, false):
		_dress(node as MeshInstance3D)
	# The model is modelled along +Z already, facing the camera.
	return jeep


var _toon_shaders := {}     # two-sided -> Shader
var _toon_copies := {}

# The glb's paint as TOON_SHADER, once a material; what glows is left as it is.
func _rimmed(paint: BaseMaterial3D) -> Material:
	if paint.emission_enabled:
		return paint
	if not _toon_copies.has(paint):
		var plane := paint.cull_mode == BaseMaterial3D.CULL_DISABLED
		_toon_copies[paint] = _toon(paint.albedo_color, RIM * (PLANE_RIM if plane else 1.0), plane)
		# A plane is seen nearly edge on over most of it -- a frond from below
		# -- and a rim as wide as a solid's lit it all.
		if plane:
			_toon_copies[paint].set_shader_parameter("rim_width", PLANE_RIM_WIDTH)
	return _toon_copies[paint]


func _toon(colour: Color, rim: float, two_sided := false) -> ShaderMaterial:
	if not _toon_shaders.has(two_sided):
		var shader := Shader.new()
		shader.code = TOON_SHADER.replace("CULL", "cull_disabled" if two_sided else "cull_back")
		_toon_shaders[two_sided] = shader
	var m := ShaderMaterial.new()
	m.shader = _toon_shaders[two_sided]
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("rim_width", RIM_WIDTH)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("rim_tint", RIM_TINT)
	return m


# The dust, one MultiMesh of CLOUD_POOL clouds that _process moves: a cloud
# slot not in use is scaled to nothing.
func _dust() -> MultiMeshInstance3D:
	var ball := Level3DFx.ball(3, 0.0, 11)
	var shader := Shader.new()
	shader.code = DUST_SHADER
	var paint := ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("albedo", DUST_COLOUR)
	paint.set_shader_parameter("through", DUST_THROUGH)
	paint.set_shader_parameter("step_at", DUST_STEP_AT)
	paint.set_shader_parameter("rim_width", DUST_RIM_WIDTH)
	paint.set_shader_parameter("rim", RIM)
	paint.set_shader_parameter("rim_tint", RIM_TINT)
	ball.surface_set_material(0, paint)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = ball
	multimesh.instance_count = CLOUD_POOL
	for i in CLOUD_POOL:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_dust_rng.seed = 5
	for r in RUNNERS:
		var runner := {}
		_place_runner(runner, true)
		_runners.append(runner)
	# Some already about when the title opens, at every age.
	for r in _runners:
		for k in 2:
			_raise_cloud(r.at + Vector3(-k * 2.5, 0.0, 0.0), 0.8)
			_clouds[-1].age = _dust_rng.randf() * float(_clouds[-1].life)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The clouds wander out of any box worked out once; never culled.
	instance.custom_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 40, 200))
	return instance


# A runner anywhere across the frame when the dust starts, and just past its
# upwind edge after that, as the wind brings it in.
func _place_runner(runner: Dictionary, anywhere: bool) -> void:
	var z := -DUST_NEAR - _dust_rng.randf() * DUST_DEPTH
	var half := -z * VIEW_SLOPE + 2.0
	var x := _dust_rng.randf_range(-half, half) if anywhere else -half
	runner.at = Vector3(x, 0.0, z)
	runner.speed = _dust_rng.randf_range(RUNNER_SPEED.x, RUNNER_SPEED.y)
	runner.pulse = _dust_rng.randf_range(RUNNER_PULSE.x, RUNNER_PULSE.y)
	runner.phase = _dust_rng.randf() * TAU
	runner.next = _dust_rng.randf_range(CLOUD_EVERY.x, CLOUD_EVERY.y)


# A cloud born where a runner is, `strength` 0..1 of its gust.
func _raise_cloud(at: Vector3, strength: float) -> void:
	at.y = _height.call(at.x, at.z)
	var cloud := {
		"at": at,
		"radius": _dust_rng.randf_range(CLOUD_RADIUS.x, CLOUD_RADIUS.y) * (0.6 + 0.4 * strength) * (1.0 - at.z / 120.0),
		"life": _dust_rng.randf_range(CLOUD_LIFE.x, CLOUD_LIFE.y),
		"age": 0.0,
		# Carried by the wind a little slower than it blows, and off sideways.
		"drift": WIND * _dust_rng.randf_range(0.6, 0.9) + Vector3(0.0, 0.0, _dust_rng.randf_range(-0.2, 0.2)),
		"push": Vector3.ZERO,     # what gusts of the cursor have blown it
		"turn": _dust_rng.randf() * TAU,
		"seed": _dust_rng.randf(),
	}
	if _clouds.size() < CLOUD_POOL:
		_clouds.append(cloud)
	else:
		# The pool is full: the oldest goes.
		_clouds[_oldest] = cloud
		_oldest = (_oldest + 1) % CLOUD_POOL


# The palms in the wind: each paint of theirs as TOON_SHADER moving its
# vertices as level3d_wind.gdshaderinc does, and the contour as the
# preview's moving hull (Level3DWind.HULL_SHADER), so that the line goes with
# the frond; the crown and its reach measured as the preview measures them.
func _sway(palm: MeshInstance3D) -> void:
	var crown := Level3DWind._crown(palm.mesh as ArrayMesh)
	if crown.is_empty():
		return
	palm.extra_cull_margin = Level3DWind.CULL_MARGIN * PALM_SCALE
	var blasts := PackedVector4Array()
	blasts.resize(Level3DWind.BLASTS)
	var sizes := PackedVector2Array()
	sizes.resize(Level3DWind.BLASTS)
	for surface in palm.mesh.get_surface_count():
		var source := palm.mesh.surface_get_material(surface)
		var m: ShaderMaterial
		if Level3DHull.is_hull(source):
			m = ShaderMaterial.new()
			m.shader = Level3DWind.HULL_SHADER
			m.set_shader_parameter("pixels", Level3DHull.PIXELS)
		else:
			var paint := palm.get_surface_override_material(surface) as ShaderMaterial
			if paint == null:
				continue
			m = paint.duplicate() as ShaderMaterial
			m.shader = _toon_wind_shader(paint.shader)
		m.set_shader_parameter("wind_crown", crown.at)
		m.set_shader_parameter("wind_radius", crown.reach)
		m.set_shader_parameter("wind_flap", 1.0 if crown.palm else 0.0)
		m.set_shader_parameter("wind_give", 1.0 if crown.palm else Level3DWind.TREE_GIVE)
		m.set_shader_parameter("wind_strength", PALM_WIND)
		m.set_shader_parameter("wind_blasts", blasts)
		m.set_shader_parameter("wind_blast_size", sizes)
		palm.set_surface_override_material(surface, m)
		_wind_materials.append(m)


var _wind_shaders := {}     # TOON_SHADER variant -> the same moved by the wind

func _toon_wind_shader(still: Shader) -> Shader:
	if not _wind_shaders.has(still):
		var shader := Shader.new()
		shader.code = still.code.replace("shader_type spatial;\n", "shader_type spatial;\n"
				+ "#include \"res://src/tools/level3d_wind.gdshaderinc\"\n").replace("void fragment() {",
				"void vertex() {\n\tVERTEX = wind_moved(VERTEX, MODEL_MATRIX);\n}\nvoid fragment() {")
		_wind_shaders[still] = shader
	return _wind_shaders[still]


func _haze() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(400, HAZE_REACH + 1.0)
	var shader := Shader.new()
	shader.code = HAZE_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("reach", HAZE_REACH)
	m.set_shader_parameter("aspect", 1.0 / ASPECT)
	quad.material = m
	var haze := MeshInstance3D.new()
	haze.mesh = quad
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	haze.position = Vector3(0, (HAZE_REACH + 1.0) * 0.5 - 0.5, -HAZE_DISTANCE)
	return haze


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_follow_mouse(delta)
	for m in _wind_materials:
		m.set_shader_parameter("wind_clock", _time)
	if _dust_mesh == null:
		return
	# The runners, each raising a cloud every CLOUD_EVERY while its gust is up.
	for runner in _runners:
		var phase: float = runner.phase
		var strength := maxf(sin(_time * TAU / float(runner.pulse) + phase), 0.0)
		runner.at += Vector3(float(runner.speed), 0.0, sin(_time * 0.4 + phase) * 0.5) * delta
		if runner.at.x > -float(runner.at.z) * VIEW_SLOPE + 2.0:
			_place_runner(runner, false)
			continue
		runner.next -= delta
		if runner.next <= 0.0:
			runner.next = _dust_rng.randf_range(CLOUD_EVERY.x, CLOUD_EVERY.y)
			if strength > 0.25:
				_raise_cloud(runner.at, strength)
	var multimesh := _dust_mesh.multimesh
	for i in CLOUD_POOL:
		if i >= _clouds.size():
			break
		var cloud: Dictionary = _clouds[i]
		cloud.age += delta
		var k: float = cloud.age / float(cloud.life)
		if k >= 1.0:
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		var push: Vector3 = cloud.push
		var radius: float = cloud.radius
		# Born small, swelling quickly and then slowly to its full size.
		var size := radius * lerpf(CLOUD_BORN, 1.0, 1.0 - pow(1.0 - k, 2.5))
		var base: Vector3 = cloud.at + cloud.drift * float(cloud.age) + push
		# The gust: away from where the cursor points, and along with it.
		if _gust > 0.01 and _mouse_ground != null:
			var away: Vector3 = base - _mouse_ground
			away.y = 0.0
			var r := away.length() - size
			if r < GUST_RADIUS:
				var g := 1.0 - maxf(r, 0.0) / GUST_RADIUS
				var shove := away.normalized() * g * g * GUST_PUSH + _mouse_velocity * g * 1.5
				push += shove * _gust * delta * delta * 6.0
				# A gust tears it apart sooner, too.
				cloud.age += delta * g * _gust * 1.5
		cloud.push = push
		# Half out of the ground at first, and more of it as it swells: low,
		# but standing up off the ground rather than lying in it, which,
		# flatter and sunk deeper, it did like a puddle.
		var lift := size * CLOUD_FLAT * lerpf(0.15, 0.5, k) + radius * CLOUD_RISE * k
		var p := Vector3(base.x, _height.call(base.x, base.z) + lift, base.z)
		# Spread along the ground more than it stands up: it rolls downwind.
		var basis := Basis(Vector3.UP, float(cloud.turn) * 0.3 + k * 0.3).scaled(Vector3(1.0, CLOUD_FLAT, 1.0) * size)
		basis = Basis.from_scale(Vector3(CLOUD_LONG, 1.0, 1.0)) * basis
		multimesh.set_instance_transform(i, Transform3D(basis, p))
		multimesh.set_instance_custom_data(i, Color(k, float(cloud.seed), 0, 0))


# Where the cursor points at the ground (or null, pointing over it), how fast
# that point moves, and the gust: as hard as the cursor is fast across the
# frame, dying down when it stops.
func _follow_mouse(delta: float) -> void:
	var at := get_local_mouse_position() / size
	var pixels := at * Vector2(viewport.size)
	var speed := (pixels - _last_mouse).length() / maxf(delta, 1e-4)
	_last_mouse = pixels
	_gust = maxf(_gust * exp(-GUST_DECAY * delta), minf(speed / GUST_SPEED, 1.0))
	var origin := camera.project_ray_origin(pixels)
	var ray := camera.project_ray_normal(pixels)
	var point = null
	if ray.y < -0.001:
		point = origin + ray * ((0.4 - origin.y) / ray.y)
	if point != null and _mouse_ground != null:
		_mouse_velocity = _mouse_velocity.lerp((point - _mouse_ground) / maxf(delta, 1e-4), 1.0 - exp(-10.0 * delta))
	elif point == null:
		_mouse_velocity = Vector3.ZERO
	_mouse_ground = point
	var haze := _haze_mesh.mesh.surface_get_material(0) as ShaderMaterial
	haze.set_shader_parameter("mouse", at)
	haze.set_shader_parameter("gust", _gust)
