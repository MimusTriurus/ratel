# The title screen's splash made as a scene rather than a picture: the sunset
# of Level3DSplash (level3d_splash.gd), and the jeeps standing against it,
# made in 3D from nothing -- no picture in it -- and cel-shaded as the preview
# draws its units. A prototype: the title's menu lights the jeeps and swings
# their turrets (show_menu), and a game picked drives them off (launch); the sky, the jeeps
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

# The jeeps are the preview's vehicle (Level3DBtr.chosen): the armoured
# pickup, or the jeep under --jeep. Not the BTR: under --btr they are the
# armoured pickup still.
const KINDS := ["armored", "jeep"]
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
# A game picked, the menu goes and the title brings the scene to the middle
# of the screen, FOCUS_ZOOM times as big (focus): in the title art's place,
# with nothing under it, it left the bottom half of the screen empty. And the
# frame opens out to the screen's edges as it comes: the sun rises as the
# jeeps go (RISE_*), and a disc 23 degrees in radius came up out of the top
# of a frame cut to the picture's proportions. So the scene is rendered the
# whole screen big throughout, SCREEN, as wide as a camera FOCUS_ZOOM times
# as close would see it all (place); on the title only the middle of it shows,
# the frame's (_region), which is the scene exactly as it was, drawn smaller,
# so that it is not blown up and soft once it is there and is not resized as
# it grows.
const FOCUS_ZOOM := 1.5
const SCREEN := Vector2(2048, 1152)

# The jeep's launcher fits (level3d_rocket.gd's FITS, and the spare ones in
# level3d_btr.gd): only the mortar's is shown, what a run starts with. It was
# the missiles', the picture's rocket pods, which stand taller than the
# Chinook's cabin and went through its roof on the way in.
const SHOWN_FIT := "MortarBase"
const HIDDEN_FITS := ["LauncherBase", "HeavyLauncherBase", "StageLauncherBase", "GradBase",
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

# The sunrise: once a game is picked (launch) the sun comes up over RISE_TIME
# -- the disc out of the horizon to RISEN_SINK, the shade to RISEN_AMBIENT,
# the ground lit (RISEN_GROUND, RISEN_GLOW) and the sky over the horizon
# (SKY_SHADER's `dawn`) -- so that the title fades out on a sun that has
# risen, into the stage's day, and not on one that has set. Its light stays
# where it was, SUN_ELEVATION, just under the horizon, so that everything
# stands against the disc as a silhouette still: raised with it, it crossed
# the slopes of the rolling ground's facets one by one between 0 and 2
# degrees, and the two-tone light (TOON_SHADER) turned each lit in a frame,
# angular patches of light jumping about the ground as the sun came up. The title has
# faded out about 11 s after the pick over the Chinook (measured), a little
# over RISE_TIME, so it fades on the risen sun; the frame has opened out to
# the screen's edges by then (focus), for the whole disc to be seen.
const RISE_TIME := 10.0
const SINK := 0.187              # SKY_SHADER's, the sun half set
const RISEN_SINK := -0.12
const RISEN_AMBIENT := 0.42
# And the ground lighter under it, a warm brown, all of it at once: its paint
# lighter, and a glow of its own, which no facet's slope turns on or off --
# and the sun going off it as the glow comes, since the camera follows the
# jeeps in over it (Level3DSplashLanding, CHASE_*) and the facets the sun just
# under the horizon catches were angular patches of light all over the
# ground near to. Burnt orange, towards the stage's sand (hue 35 degrees,
# which the title fades into) though a good deal darker, so that what stands
# on it is still a silhouette: some 27 degrees and 0.17 lightness at the
# end. A red brown (19 degrees, 0.09), it was the frame's one colour the
# stage has nothing of; at 32 degrees, that dark, it was olive.
const RISEN_GROUND := Color(0.5, 0.27, 0.08)
const RISEN_GLOW := Color(0.3, 0.155, 0.03)
const GROUND_SUN_OFF := 0.35   # of the rise, the sun off the ground by then

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
// What it gives off itself: the lamps, when they are on.
uniform vec3 glow : source_color = vec3(0.0);
// How much of the sun it takes: all of it, but for the ground as the sun
// rises (Level3DSplash3D._show_rise).
uniform float sun = 1.0;
void fragment() {
	// The paint's lightness only, not its colour: the splash is drawn in
	// the dark and the sun's colours, and whatever light falls on a face --
	// the sun on a jeep turned from the camera, a lamp on the jeep ahead or
	// into the Chinook -- shows that light's colour on it, not green.
	ALBEDO = vec3(dot(albedo.rgb, vec3(0.299, 0.587, 0.114)));
	EMISSION = glow;
}
void light() {
	// The two tones: lit or not, no shading between. A spot's falloff --
	// the lamps' -- is cut in bands too, full, half and none, so that the
	// pool it lights has edges; the sun's is 1 everywhere.
	float reach = ATTENUATION > 0.55 ? 1.0 : (ATTENUATION > 0.12 ? 0.5 : 0.0);
	reach *= LIGHT_IS_DIRECTIONAL ? sun : 1.0;
	DIFFUSE_LIGHT += step(0.0, dot(NORMAL, LIGHT)) * reach * LIGHT_COLOR / PI;
	// The rim: seen edge on, with the light behind.
	float edge_on = step(1.0 - rim_width, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	float behind = clamp(-dot(LIGHT, VIEW), 0.0, 1.0);
	vec3 band = edge_on * behind * rim * ATTENUATION * LIGHT_COLOR / PI;
	// Diffuse is taken times the paint, specular is not: the tint between.
	DIFFUSE_LIGHT += band * rim_tint;
	SPECULAR_LIGHT += band * (1.0 - rim_tint);
}
"""

# The title's menu drives the jeeps (show_menu): on "1 player" the left
# jeep's lamps come on and its engine is gunned, on "2 players" both jeeps',
# on anything else they go dark; on hard the turrets swing round on the
# camera, on normal they look out to either side.
#
# The lamps are the hull's LAMP_PAINTS surface, the pair of headlights at its
# nose, one either side (_lamps_at): their paint glows (TOON_SHADER's `glow`) and over each a flare and a
# spot light come up, the spot lighting a pool on the ground before the jeep
# that the two-tone light cuts in bands (TOON_SHADER, ATTENUATION). Coming on
# they flicker once, as a lamp catching does; going off they fade quickly.
const LAMP_PAINTS := {"jeep": "Jeep_White", "armored": "Armored_Lamp"}
const LAMP_COLOUR := Color(1.0, 0.9, 0.68)
const LAMP_GLOW := 2.4
const LAMP_ON := 0.25          # seconds to come up
const LAMP_OFF := 0.15         # seconds to go down
const FLARE_SIZE := 1.6        # metres across at full
const SPOT_ENERGY := 9.0
const SPOT_RANGE := 16.0
const SPOT_ANGLE := 24.0
const SPOT_DIP := 7.0          # degrees below level
# The spots light the ground and nothing else (its layers): on a jeep or the
# Chinook their near-white light, strong enough for a pool on the dark sand,
# burnt the paint out white, which is not one of the splash's colours -- the
# dark and the sun's.
const GROUND_LAYER := 2
# The engine: the hull shakes on its wheels, ENGINE_IDLE metres at a tick-
# over and ENGINE_RUN when the jeep's lamps are on, and not at all with the
# engine off; gunned, its nose kicks up ENGINE_KICK rad/s on a spring
# (ENGINE_SPRING: stiffness, damping) and settles -- the kick given over
# about KICK_TIME seconds (_kick), since all at once the nose jumped in a
# frame -- and CATCH_KICK of that as it catches.
const ENGINE_IDLE := 0.004
const ENGINE_RUN := 0.009
const ENGINE_KICK := 0.9
const KICK_TIME := 0.12
const CATCH_KICK := 0.5
const ENGINE_SPRING := Vector2(120.0, 9.0)
# And heard. A jeep the menu lights is started (ENGINE_START, from
# START_FROM, the silence before the key cut), catches START_CATCH seconds
# into the file -- its nose kicks then, not at the pick -- and runs on into
# the idle loop (ENGINE_LOOP) from IDLE_AT, where the start has come down to
# it, crossfaded over IDLE_IN. Put out, it runs on ENGINE_LINGER seconds, so
# that running down the menu is not a starter and a fade at every entry,
# and then dies away, its sound faded out over ENGINE_FADE and its shake
# with it. Lit again inside CATCH_AGAIN of that it picks up again with no
# starter, and put out before it has caught the starter just gives up,
# over STOP_IN. On the move the idle is
# pitched up with the speed, to REV_PITCH at REV_SPEED m/s, and gunned it
# revs, REV_BLIP up and down over REV_TIME. All at ENGINE_VOLUME, which is
# as loud as ENGINE_NEAR m off -- where the jeeps stand (JEEPS) -- louder
# nearer, up to ENGINE_LOUDEST, and flat, as the Chinook's rotor is
# (Level3DSplashLanding). Times in the files are from their own start.
const ENGINE_START := "jeep_start"
const ENGINE_LOOP := "jeep_idle"
const START_FROM := 0.12
const START_CATCH := 0.5
const IDLE_AT := 2.0
const IDLE_IN := 0.6
const STOP_IN := 0.2
const ENGINE_LINGER := 1.5
const CATCH_AGAIN := 1.0
const ENGINE_FADE := 1.5
const REV_PITCH := 1.5
const REV_SPEED := 16.0
const REV_BLIP := 0.25
const REV_TIME := 0.5
const ENGINE_VOLUME := 0.35
const ENGINE_NEAR := 21.0
const ENGINE_LOUDEST := 2.5
# The turrets: degrees out from the camera on normal, turning at TURRET_RATE
# degrees a second.
const TURRET_OUT := 40.0
const TURRET_RATE := 90.0

const FLARE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.9, 0.68);
uniform float level = 0.0;
void vertex() {
	// A billboard, keeping the instance's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float core = pow(max(1.0 - length(q), 0.0), 2.5);
	// A thin streak across, as a lens draws a lamp seen head on.
	float streak = pow(max(1.0 - abs(q.x), 0.0), 1.5) * pow(max(1.0 - abs(q.y) * 9.0, 0.0), 2.0) * 0.6;
	ALBEDO = colour * (core + streak) * level;
}
"""

# A game picked (launch): the jeeps it is for gun their engines for
# LAUNCH_REV seconds and go, LAUNCH_ACCEL m/s^2, squatting on their tails,
# their wheels turning, each out past its side of the camera -- to LAUNCH_PASS,
# x out from the middle and z behind the camera -- throwing dust off its rear
# wheels, a small short cloud (the wind's own, CLOUD_*, scaled by
# WHEEL_CLOUD) every WHEEL_DUST_STEP metres. The title fades to black over
# them LAUNCH_HOLD seconds in and starts the run (Level3DTitle).
const LAUNCH_HOLD := 1.3
const LAUNCH_REV := 0.25
const LAUNCH_ACCEL := 9.0
const LAUNCH_PASS := Vector2(4.5, 8.0)
const LAUNCH_SQUAT := -0.045      # rad, nose up
const WHEELS := ["Wheel_L1", "Wheel_L2", "Wheel_R1", "Wheel_R2"]   # without the prefix
const REAR_WHEELS := ["Wheel_L2", "Wheel_R2"]
const WHEEL_DUST_STEP := 0.6
const WHEEL_CLOUD := Vector2(0.7, 0.45)   # radius, life, as shares of a wind cloud's

# The dust: clouds of it, raised by the wind -- off unless the preview is run
# with --splash-dust. RUNNERS gusts skim along the
# ground downwind, each a wheel nobody sees, and while a runner's gust is up
# (RUNNER_PULSE: it comes and goes) it raises a cloud every CLOUD_EVERY
# seconds, so that a gust leaves a few behind it, overlapping, and then none.
#
# A cloud is one body with a life of its own, CLOUD_LIFE seconds: born a
# small knot on the ground, it swells as it rises and drifts downwind, and
# then goes -- its lobes shrinking away one by one and its edge fraying, and
# dithered out only by the frame's sides (DUST_SHADER).
#
# It is a cartoon puff on a card that faces the camera, a billboard turned
# about the vertical only: a cauliflower of round lobes (DUST_LOBES) drawn by
# the shader, each lit as a sphere would be and pushed towards the camera by
# as much as that sphere would stand out, into the depth buffer too, so that
# two clouds and a cloud and the ground meet in round seams. Against the sun,
# a lobe glows where it is thin -- out at its edges -- and the cloud's outline
# brightest, a rim round the whole of it and none between its lobes.
#
# This is the fourth go at it. A stream of small balls, one per DUST_STEP of
# a runner, as the preview's wheels raise theirs (Level3DPuffs), was a string
# of bubbles: every ball drew its own rim, and no cloud was ever one thing.
# Soft translucent spheres were blots, and big solid balls lumps that read
# as rocks. One ball pushed out into lobes by a noise, flattened and lit
# through, was the third: low and lit all over, a flat bright slab on the
# dark ground, its facets and the holes it went in showing as the camera
# came in after the jeeps (Level3DSplashLanding, CHASE_*).
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
# its radius; and its card's half height and half width, as shares of it --
# longer along the ground than it stands, rolling along it. Grown with the
# distance to hold their size in the frame, and rising as far as their
# radius, they were boulders of dust taller than the jeeps.
const CLOUD_RADIUS := Vector2(0.45, 0.85)
const CLOUD_BORN := 0.2
const CLOUD_RISE := 0.12
const CLOUD_TALL := 1.0
const CLOUD_LONG := 1.6
const CLOUD_POOL := 192
const WIND := Vector3(1.3, 0.0, 0.0)
# The preview's dust is sand (Level3DPuffs' "ground"), and its tones are the
# shader's own, not the lights': the body a little lighter than the ground,
# what the sun comes through and the rim against it; all lighter as the sun
# rises (_show_rise), as the ground is. Lit by the scene's lights, the body
# was the sun's colour all over, brighter than anything on the ground, and
# read as a thing rather than as air.
const DUST_BODY := Color(0.24, 0.11, 0.07)
const DUST_LIT := Color(0.72, 0.38, 0.16)
const DUST_RIM := Color(1.0, 0.8, 0.45)
const RISEN_DUST_BODY := Color(0.46, 0.25, 0.14)
const RISEN_DUST_LIT := Color(0.86, 0.56, 0.3)
const DUST_LOBES := 7
# The clouds' look. By default each source's puffs -- a jeep's wheels, the
# Chinook's wash, a gust -- are one cloud (Level3DCelCloud, a port of the
# tank bench's CelCloud): spheres flowed into one shape with one ink line
# round it, flowing into one within CEL_BLEND metres, eaten from the rim from
# CEL_ERODE_FROM of their life, inked CEL_INK metres or CEL_INK_PX pixels
# wide, whichever is wider, and popping up over the first CEL_POP of it.
# --splash-puffs draws each as a card of its own (DUST_SHADER), and
# --splash-motes as a handful of soft motes (MOTE_*).
const CEL_BLEND := 0.3
const CEL_ERODE_FROM := 0.25
const CEL_INK := 0.04
const CEL_INK_PX := 1.5
const CEL_POP := 0.06
# A cloud is one only where its puffs overlap: the tanks' grow four times as
# wide as the run between two. A jeep's every CEL_WHEEL_STEP metres, then,
# off one rear wheel and the other in turn, CEL_WHEEL times a wind cloud's
# size and life (some 0.35 m across at the most, under a second): at the
# cards' spacing and size they were balls in a row, and smaller, separate
# stones; at twice this size, too big for a jeep (the user halved it); off
# both wheels at once, each a cloud, two ropes along the ground, as the
# tanks' were before theirs grew.
const CEL_WHEEL_STEP := 0.3
const CEL_WHEEL := Vector2(0.5, 0.2)
# A puff thrown from where it is raised slows to a stop over THROW_TIME
# seconds; a wheel's back from the jeep and out from under it at WHEEL_THROW
# m/s, each out by its own share -- out alike, the puffs lay in one line, as
# the tanks' did.
const THROW_TIME := 0.3
const WHEEL_THROW := Vector2(2.4, 1.6)
# Under --splash-motes, a cloud is not one puff but
# a handful of motes: soft sheets of the veil's kind (VEIL_SHADER), small
# and thick, MOTES_PER_METRE of the cloud's radius of them (3 to 8), each
# blown off its way by up to MOTE_SPREAD m/s and rising MOTE_RISE, swelling
# from MOTE_BORN of its size and slowing (MOTE_DRAG) -- dust as particles.
const MOTES_PER_METRE := 9.0
const MOTE_SPREAD := Vector2(0.2, 0.7)
const MOTE_RISE := Vector2(0.15, 0.45)
const MOTE_SIZE := Vector2(1.0, 1.6)
const MOTE_BORN := 0.3
const MOTE_DRAG := 1.2
const MOTE_LONG := 1.3
const MOTE_OPACITY := 0.6
const MOTE_CHURN := 0.3

# The veil: dust in the air rather than in clouds -- a thin, soft haze low
# over the ground, which the clouds stand in and which says the air is full
# of it. Big soft cards facing the camera as the clouds' do, VEIL_OPACITY at
# their thickest, the colour of dust lit through, raised where a cloud is
# (_raise_veil: the Chinook's wash, Level3DSplashLanding), swelling out of
# VEIL_BORN of their size and thinning out over their life, blown out and
# slowing (VEIL_DRAG, a share of their way lost a second). They fade into the
# ground and into anything else behind them by how near it is (VEIL_SOFT
# metres, or their own height if less, off the depth buffer), so that no
# card shows its edge where it goes into the ground. Solid, they were the
# soft blots of the second go at the clouds; this thin and under the solid
# ones, they are the air. The pool is the motes' too (MOTE_*), each sheet
# with its own opacity and how ragged its edge is. The haze itself is off
# unless the preview is run with --splash-veil (_veil_on).
const VEIL_POOL := 360
const VEIL_OPACITY := 0.45
const VEIL_BORN := 0.35
const VEIL_DRAG := 0.6
const VEIL_SOFT := 1.2
const VEIL_COLOUR := Color(0.78, 0.45, 0.22)
const RISEN_VEIL_COLOUR := Color(0.9, 0.62, 0.36)
const VEIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform, depth_draw_never, blend_mix;
uniform vec3 colour : source_color = vec3(0.78, 0.45, 0.22);
// The middle, where it is thickest, this much darker than its thin edge --
// a little: more, and each mote was a ring, a soap bubble.
uniform float thick = 0.92;
uniform float soft = 1.2;
uniform float side_fade = 0.25;
uniform vec2 sides = vec2(0.0, 1.0);
uniform sampler2D depth : hint_depth_texture, filter_nearest;
varying float life;
varying float seed;
varying vec2 extent;
varying float opacity;
varying float ragged;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(dot(i, vec2(1.0, 57.0)));
	float b = hash(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
	float c = hash(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
	float d = hash(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	// Its life, 0..1, its seed, its opacity and how ragged its edge is.
	life = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y * 37.0;
	opacity = INSTANCE_CUSTOM.z;
	ragged = INSTANCE_CUSTOM.w;
	extent = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 toward = INV_VIEW_MATRIX[3].xyz - centre;
	toward.y = 0.0;
	toward = normalize(toward);
	vec3 across = normalize(cross(vec3(0.0, 1.0, 0.0), toward));
	vec3 world = centre + across * VERTEX.x * extent.x + vec3(0.0, 1.0, 0.0) * VERTEX.y * extent.y;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(toward, 0.0)).xyz);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	q.y = -q.y;
	// A soft heap, flatter on top, its edge wandering on a slow noise that
	// rolls as it lives.
	float churn = noise(q * vec2(1.6, 2.4) + vec2(seed + life * 1.2, seed * 0.5))
			+ 0.5 * noise(q * vec2(3.5, 5.0) + vec2(seed * 0.3 - life * 2.0, seed));
	float r = length(q * vec2(1.0, 1.25)) + (churn / 1.5 - 0.5) * ragged;
	float a = 1.0 - smoothstep(0.25, 1.0, r);
	a *= smoothstep(0.0, 0.2, life) * (1.0 - smoothstep(0.35, 1.0, life));
	float across = (SCREEN_UV.x - sides.x) / (sides.y - sides.x);
	a *= smoothstep(0.03, side_fade, min(across, 1.0 - across));
	// Into whatever is behind it by how near that is.
	float d = texture(depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	behind.xyz /= behind.w;
	a *= clamp((VERTEX.z - behind.z) / min(soft, extent.y), 0.0, 1.0);
	ALBEDO = colour * mix(thick, 1.0, smoothstep(0.0, 0.9, r));
	ALPHA = a * opacity;
}
"""

# The puff (vertex and fragment). INSTANCE_CUSTOM is the cloud's life, 0..1,
# and its seed; its transform's scale the card's half width and height.
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform vec3 body : source_color = vec3(0.24, 0.11, 0.07);
// A lobe's underside, turned down more than below_at: what parts one lobe
// from the next in front of it.
uniform float under = 0.7;
uniform float below_at = -0.3;
uniform vec3 lit : source_color = vec3(0.72, 0.38, 0.16);
uniform vec3 rim : source_color = vec3(1.0, 0.8, 0.45);
// Towards the sun, world space: a cloud against it glows, one off to the
// side less.
uniform vec3 sun_toward = vec3(0.0, 0.0, -1.0);
// A lobe is thin enough to glow where it faces the camera less than this.
uniform float thin_at = 0.55;
// The rim, as a share of the card's half height, in from the outline.
uniform float rim_width = 0.07;
uniform float break_up = 0.5;
uniform float side_fade = 0.25;
// The frame's sides in the render, SCREEN_UV.x (Level3DSplash3D._region).
uniform vec2 sides = vec2(0.0, 1.0);
varying float life;
varying float seed;
varying vec2 extent;
varying float behind;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(dot(i, vec2(1.0, 57.0)));
	float b = hash(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
	float c = hash(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
	float d = hash(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Ordered dither, 4 x 4: the share of the pixels a level keeps.
float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void vertex() {
	life = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y * 37.0;
	extent = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	// Turned to the camera about the vertical: its foot stays level on the
	// ground.
	vec3 toward = eye - centre;
	toward.y = 0.0;
	toward = normalize(toward);
	vec3 across = normalize(cross(vec3(0.0, 1.0, 0.0), toward));
	vec3 world = centre + across * VERTEX.x * extent.x + vec3(0.0, 1.0, 0.0) * VERTEX.y * extent.y;
	behind = pow(clamp(dot(normalize(centre - eye), normalize(sun_toward)), 0.0, 1.0), 4.0);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(toward, 0.0)).xyz);
}

void fragment() {
	// Card space: x across, y up, in half heights, the middle 0.
	vec2 q = (UV - 0.5) * 2.0;
	q.y = -q.y;
	float wide = extent.x / extent.y;
	q.x *= wide;
	// The lobes: a row along the ground, bigger and higher in the middle, the
	// middle ones nearer the camera; they roll up a little as it lives, and
	// shrink away one by one once it breaks up.
	float best = -1.0;
	vec3 n = vec3(0.0, 0.0, 1.0);
	float outline = 1e3;
	for (int i = 0; i < LOBES; i++) {
		float fi = float(i);
		float h1 = hash(seed + fi * 1.7);
		float h2 = hash(seed * 1.3 + fi * 3.1);
		float h3 = hash(seed * 0.7 + fi * 5.3);
		float u = ((fi + 0.5 + (h1 - 0.5) * 0.7) / float(LOBES)) * 2.0 - 1.0;
		float middle = 1.0 - u * u;
		float r = (0.3 + 0.16 * h2) * (0.55 + 0.6 * middle);
		vec2 c = vec2(u * (wide - 0.35), -0.62 + r + 0.3 * h3 * middle + life * 0.12 * h1);
		r *= 1.0 - smoothstep(break_up + (1.0 - break_up) * 0.7 * h2, 1.0, life);
		vec2 d = q - c;
		float dd = length(d);
		outline = min(outline, dd - r);
		if (dd < r) {
			float z = 0.25 * middle * h3 + sqrt(r * r - dd * dd);
			if (z > best) {
				best = z;
				n = vec3(d / r, sqrt(max(1.0 - dd * dd / (r * r), 0.0)));
			}
		}
	}
	// Its edge frayed, and more of it as it goes.
	float fray = (noise(q * 3.5 + seed) - 0.5) * (0.04 + 0.06 * life);
	if (best < 0.0 || outline + fray > 0.0) {
		discard;
	}
	// Dithered out towards the frame's sides -- all of it by the edge, so
	// that a cloud thrown out there goes as it would with age: lit, on the
	// black the sky has died to by then, the edge's own fade to black cut it
	// off in a line. Its age needs none: its lobes are gone by the end, and
	// dithered with it too it was a scatter of specks round every old cloud.
	float across = (SCREEN_UV.x - sides.x) / (sides.y - sides.x);
	float side = 1.0 - smoothstep(0.03, side_fade, min(across, 1.0 - across));
	float keep = 1.0 - side;
	if (keep < bayer(FRAGCOORD.xy)) {
		discard;
	}
	vec3 colour = n.y < below_at ? body * under : body;
	if (n.z < thin_at) {
		colour = mix(body, lit, 0.35 + 0.65 * behind);
	}
	if (outline + fray > -rim_width && n.y > -0.4) {
		colour = mix(colour, rim, behind);
	}
	ALBEDO = colour;
	// Out towards the camera by as far as the lobe stands out of the card.
	vec4 clip = PROJECTION_MATRIX * vec4(VERTEX + vec3(0.0, 0.0, best * extent.y), 1.0);
	float ndc = clip.z / clip.w;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	DEPTH = ndc * 0.5 + 0.5;
#else
	DEPTH = ndc;
#endif
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
// The render's size and the frame's focused size, pixels (Level3DSplash3D.
// place): the gust's reach and the push are measured in the focused frame's
// pixels, whatever of the render shows.
uniform vec2 pixels = vec2(1200.0, 591.0);
uniform vec2 focused = vec2(1200.0, 591.0);
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
	vec2 from_mouse = (SCREEN_UV - mouse) * pixels / focused.x;
	strength *= 1.0 + 2.5 * gust * exp(-dot(from_mouse, from_mouse) / 0.008);
	// Two octaves, cells wider than they are tall: layers of warm air rising.
	vec2 p = vec2(world.x * 0.45, (world.y - TIME * rise) * 1.4);
	vec2 n = vec2(noise(p) * 0.65 + noise(p * 2.3 + 17.0) * 0.35,
			noise(p + 41.0) * 0.65 + noise(p * 2.3 + 59.0) * 0.35);
	vec2 offset = (n - 0.5) * 2.0 * push * strength / 406.0 * focused.y / pixels;
	ALBEDO = textureLod(screen, SCREEN_UV + offset, 0.0).rgb;
}
"""

const EDGE := """
shader_type canvas_item;
// The frame fades to black this far in from each edge, as a share of the
// width and the height: wider at the bottom, where the ground runs out.
uniform vec4 fade = vec4(0.12, 0.08, 0.12, 0.16); // left, top, right, bottom
// What of the render the frame shows (Level3DSplash3D._region), and how far it
// has opened out to the screen's edges, where it fades no more.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float opened = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, mix(region.xy, region.zw, UV));
	vec4 edge = fade * (1.0 - opened);
	float f = smoothstep(-1e-4, edge.x, UV.x) * smoothstep(-1e-4, edge.z, 1.0 - UV.x)
			* smoothstep(-1e-4, edge.y, UV.y) * smoothstep(-1e-4, edge.w, 1.0 - UV.y);
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
// The sunrise (RISE_TIME), 0 to 1: the sky over the horizon lit, orange low
// and violet higher up, and the far ground with it; and the sun yellower as
// it climbs out of the thick of the air -- its heart to RISEN_HEART, its rim
// from red to orange (RISEN_EDGE), its glow golden rather than red and
// GLOW_SHRINK tighter -- yellow and orange rather than white, since it ends
// only some 7 degrees up (RISEN_SINK). Its setting colours all through, it
// came up as red as it had gone down.
uniform float dawn = 0.0;
const vec3 RISEN_HEART = vec3(255.0, 240.0, 150.0) / 255.0;
const vec3 RISEN_EDGE = vec3(252.0, 140.0, 20.0) / 255.0;
const float RISEN_GLOW_GREEN = 0.5;   // of the glow's red, risen
const float GLOW_SHRINK = 0.25;
const vec3 DAWN_LOW = vec3(0.62, 0.22, 0.07);
const vec3 DAWN_HIGH = vec3(0.20, 0.09, 0.16);
// And over the second half of it the morning's: gold over the horizon, a
// rose peach by MORNING_MID up and a pale blue from MORNING_TOP (of the way
// straight up) -- the sky of a sun some degrees up, and the stage's sand and
// sea, which the title fades into. Red low and violet high to the end, the
// sky was the night coming rather than the day.
const vec3 MORNING_LOW = vec3(0.86, 0.52, 0.22);
const vec3 MORNING_MID_COLOUR = vec3(0.74, 0.47, 0.42);
const vec3 MORNING_HIGH = vec3(0.40, 0.55, 0.74);
const float MORNING_MID = 0.22;
const float MORNING_TOP = 0.6;
const vec3 DAWN_GROUND = vec3(0.08, 0.04, 0.012);
// sRGB, 0..1.
const vec3 HEART = vec3(253.0, 227.0, 6.0) / 255.0;
const vec3 EDGE = vec3(246.0, 58.0, 1.0) / 255.0;
const vec3 GROUND = vec3(5.0, 2.0, 1.0) / 255.0;
// The glow: radii and the picture's red and green there.
const float GLOW_R[7] = float[](1.0, 1.06, 1.13, 1.2, 1.36, 1.55, 1.75);
const float GLOW_RED[7] = float[](235.0, 209.0, 146.0, 91.0, 40.0, 8.0, 0.0);
const float GLOW_GREEN[7] = float[](36.0, 25.0, 8.0, 6.0, 2.0, 0.0, 0.0);

vec3 glow(float r) {
	r = 1.0 + (r - 1.0) * (1.0 + GLOW_SHRINK * dawn);
	for (int i = 0; i < 6; i++) {
		if (r < GLOW_R[i + 1]) {
			float t = (r - GLOW_R[i]) / (GLOW_R[i + 1] - GLOW_R[i]);
			float red = mix(GLOW_RED[i], GLOW_RED[i + 1], t);
			float green = mix(mix(GLOW_GREEN[i], GLOW_GREEN[i + 1], t), red * RISEN_GLOW_GREEN, dawn);
			return vec3(red, green, 0.0) / 255.0;
		}
	}
	return vec3(0.0);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(vec3(0.0, -sin(sink), -cos(sink)));
	float b = 0.5 - 0.5 * cos(TIME * TAU / breath);
	float r = acos(clamp(dot(d, sun), -1.0, 1.0)) / (radius * (1.0 + swell * b));
	vec3 heart = mix(HEART, RISEN_HEART, dawn);
	vec3 edge = mix(EDGE, RISEN_EDGE, dawn);
	vec3 c = r < 1.0 ? mix(heart, edge, clamp((r - 0.47) / 0.53, 0.0, 1.0)) : glow(r);
	c *= 1.0 + brighten * b;
	vec3 early = mix(DAWN_LOW, DAWN_HIGH, clamp(d.y * 2.5, 0.0, 1.0));
	vec3 late = d.y < MORNING_MID ? mix(MORNING_LOW, MORNING_MID_COLOUR, max(d.y, 0.0) / MORNING_MID)
			: mix(MORNING_MID_COLOUR, MORNING_HIGH, clamp((d.y - MORNING_MID) / (MORNING_TOP - MORNING_MID), 0.0, 1.0));
	vec3 lit = mix(early, late, smoothstep(0.4, 1.0, dawn)) * dawn;
	// The disc over the sky, whole; the glow screened onto it, lightening it
	// in its own gold. The larger of the two, channel by channel, took the
	// sun's red and the morning's blue, the disc's rim and the glow round it
	// pink. On the black sky before the sunrise, the glow as it was.
	c = r < 1.0 ? c : 1.0 - (1.0 - clamp(c, 0.0, 1.0)) * (1.0 - lit);
	// Below the horizon only past the far ground's edge: as dark as it.
	c = d.y < 0.0 ? GROUND + DAWN_GROUND * dawn : c;
	// The Compatibility renderer takes the sky's colour as sRGB as it is.
	COLOR = c;
}
"""

var viewport: SubViewport
var camera: Camera3D
var jeeps: Array[Node3D] = []
# Which vehicle the jeeps are (KINDS), and its Level3DBtr.VEHICLES' entry:
# its glb, its parts' prefix, its wheels' radius.
var kind: String = "jeep" if Level3DBtr.chosen() == "jeep" else "armored"
var vehicle: Dictionary = Level3DBtr.VEHICLES[kind]

var _rigs: Array[Dictionary] = []    # per jeep, what the menu moves (_rig)
var _rest := Rect2()                 # where place put the frame
var _focus: Tween                    # the frame going to the middle (focus)
var _hard := false
var _launch_time := -1.0             # seconds since launch, -1 before it
var _rise := 0.0                     # the sunrise, 0 to 1 (RISE_TIME)
var _sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ShaderMaterial
var _ground_paint: ShaderMaterial
var _dust_paint: ShaderMaterial
# Screen pixels to a render pixel: 1 / FOCUS_ZOOM on the title, 1 focused.
var zoom := 1.0 / FOCUS_ZOOM
var _focused := Vector2.ONE              # the frame's size focused, place

var _height: Callable        # the near ground's height at (x, z)
var _rock_paint: Material    # the boulders' (_ground), for any put down later
var _palm_meshes: Array[Mesh] = []
var _dust_mesh: MultiMeshInstance3D
var _veil_mesh: MultiMeshInstance3D
var _veil_paint: ShaderMaterial
var _veils: Array[Dictionary] = []
var _oldest_veil := 0
var _dust_style := "cel"     # "cel", "puffs" (--splash-puffs) or "motes" (--splash-motes)
var _veil_on := false        # the wash's haze (VEIL_*), under --splash-veil
var _cel_clouds := {}        # lane -> Level3DCelCloud, one a source of dust
var _dust_tones: Array[Color] = [DUST_BODY, DUST_LIT]   # the puffs' now, as the sun rises
var _cel_pending := false    # the clouds' draw put off to the frame's end
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


# One of a jeep's engine's two players (ENGINE_*): its level, 0 to 1,
# going to `goal` at `rate` a second, and stopped once it is out.
class Voice:
	var sound: String
	var player := AudioStreamPlayer.new()
	var level := 0.0
	var goal := 0.0
	var rate := 0.0

	func _init(name: String, owner: Node) -> void:
		sound = name
		owner.add_child(player)

	# From `from` seconds into the file, coming up over `seconds`. The
	# stream is asked again each time, since the sound mode can change.
	func begin(from := 0.0, seconds := 0.0) -> void:
		var stream := Level3DAudio.stream(sound)
		player.stop()
		player.stream = stream
		player.bus = Level3DAudio.bus(sound)
		level = 0.0 if seconds > 0.0 else 1.0
		fade(1.0, seconds)
		if stream != null and player.is_inside_tree():
			player.play(from)

	func fade(to: float, seconds: float) -> void:
		goal = to
		rate = absf(to - level) / seconds if seconds > 0.0 else INF
		if is_inf(rate):
			level = to

	func step(delta: float, gain: float) -> void:
		level = move_toward(level, goal, rate * delta)
		if level <= 0.0 and goal <= 0.0:
			if player.playing:
				player.stop()
			return
		player.volume_db = Level3DAudio.volume_db(sound) + linear_to_db(maxf(level * gain, 0.0001))

	func silence() -> void:
		player.stop()
		level = 0.0
		goal = 0.0


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
# picture; rendered at the size focus makes it (FOCUS_ZOOM).
func place(centre: Vector2, width: float) -> void:
	size = Vector2(width, width / ASPECT)
	position = centre - size * 0.5
	_rest = Rect2(position, size)
	_focused = size * FOCUS_ZOOM
	# At the screen's pixels, not the frame's: blown up, the edges stepped
	# (Level3DPixels).
	viewport.size = Vector2i(SCREEN * Level3DPixels.scale(self))
	# CAMERA_FOV across the focused frame's height, and the render as much
	# wider and taller as SCREEN is than that frame.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(CAMERA_FOV) * 0.5) * ASPECT * SCREEN.x / _focused.x))
	var haze := _haze_mesh.mesh.surface_get_material(0) as ShaderMaterial
	haze.set_shader_parameter("pixels", SCREEN)
	haze.set_shader_parameter("focused", _focused)
	_show_frame()


# What of the render the frame shows, in its UV: as much as the frame is big
# at `zoom`, about the render's middle, where the camera looks.
func _region() -> Rect2:
	var seen := size / zoom / SCREEN
	return Rect2(Vector2(0.5, 0.5) - seen * 0.5, seen)


# The frame's region and how far it has opened, to the shaders that read them.
func _show_frame() -> void:
	var r := _region()
	var edge := material as ShaderMaterial
	edge.set_shader_parameter("region", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	edge.set_shader_parameter("opened", inverse_lerp(1.0 / FOCUS_ZOOM, 1.0, zoom))
	if _dust_paint != null:
		_dust_paint.set_shader_parameter("sides", Vector2(r.position.x, r.end.x))
	if _veil_paint != null:
		_veil_paint.set_shader_parameter("sides", Vector2(r.position.x, r.end.x))


# The scene to `centre`, FOCUS_ZOOM times as big, and the frame out to the
# screen's edges about it, over `seconds`, eased both ends -- the frame's
# growth and the zoom's in step, so that it never shows more than the render
# has; reset_launch puts it back.
func focus(centre: Vector2, seconds: float) -> void:
	if _focus != null:
		_focus.kill()
	_focus = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus.tween_property(self, "size", SCREEN, seconds)
	_focus.tween_property(self, "position", centre - SCREEN * 0.5, seconds)
	_focus.tween_property(self, "zoom", 1.0, seconds)


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
	_environment = environment
	_sky_material = sky_material

	_sun = DirectionalLight3D.new()
	_sun.light_color = SUN_COLOUR
	_sun.light_energy = SUN_ENERGY
	world.add_child(_sun)
	# Pointing from the sky at the camera, the light's -Z its way.
	var travel := Vector3(0, sin(deg_to_rad(-SUN_ELEVATION)), cos(deg_to_rad(SUN_ELEVATION)))
	_sun.basis = Basis.looking_at(travel, Vector3.UP)
	_show_rise()

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
		_rigs.append(_rig(jeep, signf(at.x)))
	_haze_mesh = _haze()
	world.add_child(_haze_mesh)
	# The clouds' pool is always there, for the wheels' dust when the jeeps
	# drive off; the wind raises clouds only under --splash-dust.
	var args := OS.get_cmdline_user_args()
	_dust_style = "puffs" if args.has("--splash-puffs") else ("motes" if args.has("--splash-motes") else "cel")
	_veil_on = args.has("--splash-veil")
	_dust_mesh = _dust(OS.get_cmdline_user_args().has("--splash-dust"))
	world.add_child(_dust_mesh)
	_veil_mesh = _veil()
	world.add_child(_veil_mesh)


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
	_ground_paint = ground.material_override
	ground.layers = 1 | GROUND_LAYER
	root.add_child(ground)
	# Beyond, flat to the horizon, a little under the near ground so that the
	# two do not fight where they overlap.
	var far := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FAR_GROUND * 2.0, FAR_GROUND)
	far.mesh = plane
	far.material_override = ground.material_override
	far.layers = ground.layers
	far.position = Vector3(0, -0.3, -FAR_GROUND * 0.5)
	root.add_child(far)

	# The boulders, where ROCKS puts them.
	var rock_paint := _toon(ROCK_COLOUR, RIM)
	var line := ShaderMaterial.new()
	line.shader = Level3DFx.CONTOUR_SHADER
	line.set_shader_parameter("width", ROCK_CONTOUR)
	line.set_shader_parameter("extent", 1.0 + ROCK_JITTER)
	rock_paint.next_pass = line
	_rock_paint = rock_paint
	for entry in ROCKS:
		var at: Vector3 = entry[0]
		_rock(root, Vector3(at.x, height.call(at.x, at.z), at.z), entry[1], entry[2], entry[3], entry[4],
				rock_paint)

	_palm_meshes = _stage_meshes(PALM_MESHES)
	for entry in PALMS:
		_palm(root, entry)
	return root


# A palm as PALMS has it, `entry` [position, which of PALM_MESHES, its turn
# in degrees, its scale over PALM_SCALE], on the ground under it -- none if
# the stage's glb has lost its palms.
func _palm(root: Node3D, entry: Array) -> void:
	if _palm_meshes.size() != PALM_MESHES.size():
		return
	var at: Vector3 = entry[0]
	var palm := MeshInstance3D.new()
	palm.mesh = _palm_meshes[entry[1]]
	_dress(palm)
	_sway(palm)
	palm.scale = Vector3.ONE * PALM_SCALE * float(entry[3])
	palm.rotation.y = deg_to_rad(entry[2])
	palm.position = Vector3(at.x, _ground_y(at.x, at.z) - 0.05, at.z)
	root.add_child(palm)


# The ground's height at (x, z): the near ground's, or the flat ground's
# beyond it (_ground).
func _ground_y(x: float, z: float) -> float:
	return _height.call(x, z) if z > 8.0 - GROUND_SIZE.y else -0.3


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
	var jeep: Node3D = (load(vehicle.path) as PackedScene).instantiate()
	var prefix: String = vehicle.prefix
	for fit in HIDDEN_FITS:
		var node := jeep.find_child(prefix + fit, true, false) as Node3D
		if node != null:
			node.visible = false
	var shown := jeep.find_child(prefix + SHOWN_FIT, true, false) as Node3D
	if shown != null:
		shown.visible = true
	Level3DBtr.hide_upgrades(jeep, prefix)
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
# slot not in use is scaled to nothing. `wind`: the runners raise clouds, as
# --splash-dust asks; without, only the wheels do.
func _dust(wind: bool) -> MultiMeshInstance3D:
	var card := QuadMesh.new()
	card.size = Vector2(2.0, 2.0)
	var shader := Shader.new()
	shader.code = DUST_SHADER.replace("LOBES", str(DUST_LOBES))
	var paint := ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("body", DUST_BODY)
	paint.set_shader_parameter("lit", DUST_LIT)
	paint.set_shader_parameter("rim", DUST_RIM)
	paint.set_shader_parameter("sun_toward", _sun.basis.z)
	card.material = paint
	_dust_paint = paint
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = card
	multimesh.instance_count = CLOUD_POOL
	for i in CLOUD_POOL:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_dust_rng.seed = 5
	for r in (RUNNERS if wind else 0):
		var runner := {"lane": "wind%d" % r}
		_place_runner(runner, true)
		_runners.append(runner)
	# Some already about when the title opens, at every age.
	for r in _runners:
		for k in 2:
			_raise_cloud(r.at + Vector3(-k * 2.5, 0.0, 0.0), 0.8, 1.0, 1.0, null, _dust_rng.randf(), r.lane)
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


# A cloud born where a runner is, `strength` 0..1 of its gust -- or a wheel,
# with `size` and `life` the shares of a wind cloud's it is. The cloud, for
# whoever raised it to carry off some other way than the wind's ("drift").
# A puff at `at`, `size` and `life` times a wind cloud's, blown `drift` m/s
# (the wind's, by default), `aged` of its life already, of the cloud named
# `lane` (one a source: Level3DCelCloud), and thrown `throw` m/s from where it
# is raised, slowing to a stop over `throw_time` seconds: one puff of that
# cloud, a card of its own under --splash-puffs, a handful of motes (MOTE_*)
# under --splash-motes.
# `kind` what else differs: "born", its size at birth as a share of its full
# size (CLOUD_BORN), and "grow_time", seconds -- growing as it is thrown out
# rather than as it ages (Level3DSplashLanding's wash).
func _raise_cloud(at: Vector3, strength: float, size := 1.0, life := 1.0, drift = null, aged := 0.0,
		lane := "wind", throw := Vector3.ZERO, throw_time := THROW_TIME, kind := {}) -> void:
	at.y = _height.call(at.x, at.z)
	var radius := _dust_rng.randf_range(CLOUD_RADIUS.x, CLOUD_RADIUS.y) * (0.6 + 0.4 * strength) * (1.0 - at.z / 120.0) * size
	var span := _dust_rng.randf_range(CLOUD_LIFE.x, CLOUD_LIFE.y) * life
	# Carried by the wind a little slower than it blows, and off sideways.
	var blown: Vector3 = drift if drift != null else \
			WIND * _dust_rng.randf_range(0.6, 0.9) + Vector3(0.0, 0.0, _dust_rng.randf_range(-0.2, 0.2))
	if _dust_style == "motes":
		_raise_motes(at, radius, span, blown + throw, aged)
		return
	var cloud := {
		"at": at,
		"radius": radius,
		"life": span,
		"age": aged * span,
		"drift": blown,
		"throw": throw,
		"throw_time": maxf(throw_time, 1e-3),
		"lane": lane,
		"born": CLOUD_BORN,
		"grow_time": 0.0,
		"push": Vector3.ZERO,     # what gusts of the cursor have blown it
		"turn": _dust_rng.randf() * TAU,
		"seed": _dust_rng.randf(),
	}
	cloud.merge(kind, true)
	if _clouds.size() < CLOUD_POOL:
		_clouds.append(cloud)
	else:
		# The pool is full: the oldest goes.
		_clouds[_oldest] = cloud
		_oldest = (_oldest + 1) % CLOUD_POOL


# A cloud as motes (MOTE_*): spread over its middle, low, each blown off its
# way and rising.
func _raise_motes(at: Vector3, radius: float, span: float, blown: Vector3, aged: float) -> void:
	var count := clampi(roundi(radius * MOTES_PER_METRE), 3, 8)
	for m in count:
		var angle := _dust_rng.randf() * TAU
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var from := at + out * radius * 0.5 * sqrt(_dust_rng.randf())
		from.y = _dust_rng.randf() * radius * 0.3
		var drift := blown + out * _dust_rng.randf_range(MOTE_SPREAD.x, MOTE_SPREAD.y) \
				+ Vector3.UP * _dust_rng.randf_range(MOTE_RISE.x, MOTE_RISE.y)
		var life := span * _dust_rng.randf_range(0.7, 1.2)
		_raise_veil(from, drift, radius * _dust_rng.randf_range(MOTE_SIZE.x, MOTE_SIZE.y), MOTE_LONG, life, {
			"born": MOTE_BORN, "drag": MOTE_DRAG, "lift": 0.6, "churn": MOTE_CHURN,
			"opacity": MOTE_OPACITY * _dust_rng.randf_range(0.7, 1.0), "age": aged * life,
		})


# The veil's pool (VEIL_*), one MultiMesh as the clouds' is.
func _veil() -> MultiMeshInstance3D:
	var card := QuadMesh.new()
	card.size = Vector2(2.0, 2.0)
	var shader := Shader.new()
	shader.code = VEIL_SHADER
	_veil_paint = ShaderMaterial.new()
	_veil_paint.shader = shader
	_veil_paint.set_shader_parameter("colour", VEIL_COLOUR)
	_veil_paint.set_shader_parameter("soft", VEIL_SOFT)
	card.material = _veil_paint
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = card
	multimesh.instance_count = VEIL_POOL
	for i in VEIL_POOL:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 40, 200))
	return instance


# A sheet of the veil at `at` -- its height over the ground in `at.y` --
# `size` metres high at its fullest and `long` times as wide, blown `drift`
# m/s, for `life` seconds; `kind` what differs for a mote (_raise_motes).
func _raise_veil(at: Vector3, drift: Vector3, size: float, long: float, life: float, kind := {}) -> void:
	var veil := {"at": at, "drift": drift, "size": size, "long": long, "life": life, "age": 0.0,
			"seed": _dust_rng.randf(), "born": VEIL_BORN, "drag": VEIL_DRAG, "lift": 0.35,
			"churn": 0.6, "opacity": VEIL_OPACITY}
	veil.merge(kind, true)
	if _veils.size() < VEIL_POOL:
		_veils.append(veil)
	else:
		_veils[_oldest_veil] = veil
		_oldest_veil = (_oldest_veil + 1) % VEIL_POOL


func _move_veils(delta: float) -> void:
	var multimesh := _veil_mesh.multimesh
	for i in _veils.size():
		var veil: Dictionary = _veils[i]
		veil.age += delta
		var k: float = veil.age / float(veil.life)
		if k >= 1.0:
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		veil.at += veil.drift * delta
		veil.drift *= exp(-float(veil.drag) * delta)
		var at: Vector3 = veil.at
		var tall: float = veil.size * lerpf(veil.born, 1.0, 1.0 - pow(1.0 - k, 2.0))
		# Its middle `lift` of its height up: a veil's a third under the
		# ground, where the depth fade takes it.
		var p := Vector3(at.x, _ground_y(at.x, at.z) + at.y + tall * float(veil.lift), at.z)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(tall * float(veil.long), tall, tall)), p))
		multimesh.set_instance_custom_data(i, Color(k, float(veil.seed), float(veil.opacity), float(veil.churn)))


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
			Level3DHull.track(m)
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
				+ "#include \"res://src/game3d/shaders/level3d_wind.gdshaderinc\"\n").replace("void fragment() {",
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
	quad.material = m
	var haze := MeshInstance3D.new()
	haze.mesh = quad
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	haze.position = Vector3(0, (HAZE_REACH + 1.0) * 0.5 - 0.5, -HAZE_DISTANCE)
	return haze


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_silence_engines()
		return
	# The settings' anti-aliasing (Level3DPixels), as it is now.
	viewport.msaa_3d = Level3DPixels.msaa
	_time += delta
	_show_frame()
	_follow_mouse(delta)
	for m in _wind_materials:
		m.set_shader_parameter("wind_clock", _time)
	if _launch_time >= 0.0:
		_launch_time += delta
		if _rise < 1.0:
			_rise = minf(_rise + delta / RISE_TIME, 1.0)
			_show_rise()
	_drive_rigs(delta)
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
				_raise_cloud(runner.at, strength, 1.0, 1.0, null, 0.0, runner.lane)
	_move_veils(delta)
	var cel := _dust_style == "cel"
	for lane in _cel_clouds:
		(_cel_clouds[lane] as Level3DCelCloud).clear()
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
		# Born small, swelling quickly and then slowly to its full size -- or
		# as it goes out, for one that grows with its throw.
		var grow_time: float = cloud.grow_time
		var grown := 1.0 - exp(-float(cloud.age) / grow_time) if grow_time > 0.0 else 1.0 - pow(1.0 - k, 2.5)
		var size := radius * lerpf(float(cloud.born), 1.0, grown)
		var tau: float = cloud.throw_time
		var base: Vector3 = cloud.at + cloud.drift * float(cloud.age) + push \
				+ cloud.throw * tau * (1.0 - exp(-float(cloud.age) / tau))
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
		if cel:
			# Popping up at once, grown with the puff's own easing, sat with
			# most of its body over the ground -- centred on it, the ground's
			# depth cut it in half -- and eaten from the rim as it ages.
			var r := size * smoothstep(0.0, CEL_POP, k)
			var middle := Vector3(base.x, _height.call(base.x, base.z) + 0.7 * r + radius * CLOUD_RISE * k, base.z)
			_cel_cloud(cloud.lane).add(middle, r * _thin(middle, r), smoothstep(CEL_ERODE_FROM, 1.0, k), k,
					float(cloud.seed))
			continue
		size *= _thin(base + Vector3.UP * size, size)
		# The card's foot on the ground -- its lobes' feet some 0.6 of its half
		# height under its middle -- and rising off it as it lives.
		var tall := size * CLOUD_TALL
		var lift := tall * 0.6 + radius * CLOUD_RISE * k
		var p := Vector3(base.x, _height.call(base.x, base.z) + lift, base.z)
		var basis := Basis.from_scale(Vector3(size * CLOUD_LONG, tall, size))
		multimesh.set_instance_transform(i, Transform3D(basis, p))
		multimesh.set_instance_custom_data(i, Color(k, float(cloud.seed), 0, 0))
	if cel and not _cel_pending:
		_cel_pending = true
		_draw_cel_clouds.call_deferred()


# The clouds (Level3DCelCloud) as the camera sees them at the end of the
# frame, once anything that moves it -- Level3DSplashLanding's chase -- has.
func _draw_cel_clouds() -> void:
	_cel_pending = false
	var r := _region()
	for lane in _cel_clouds:
		var cloud := _cel_clouds[lane] as Level3DCelCloud
		cloud.paint(_dust_tones[0], _dust_tones[1], DUST_RIM, Vector2(r.position.x, r.end.x))
		cloud.draw(camera, _sun.basis.z)


# How much of a puff of radius `r` at `at` is left by what it may not stand
# through: all of it here, where nothing stands in the dust's way;
# Level3DSplashLanding's Chinook does.
func _thin(_at: Vector3, _r: float) -> float:
	return 1.0


# A wheel's distance between puffs, `step` metres as the cards have it.
func _wheel_step(step: float) -> float:
	return CEL_WHEEL_STEP if _dust_style == "cel" else step


# The cloud named `lane` (Level3DCelCloud), made on its first puff.
func _cel_cloud(lane: String) -> Level3DCelCloud:
	if not _cel_clouds.has(lane):
		_cel_clouds[lane] = Level3DCelCloud.new(camera.get_parent(), CEL_BLEND, CEL_INK, CEL_INK_PX)
	return _cel_clouds[lane]


# A jeep's dust for a step of its way, `size` and `life` times a wind
# cloud's: a puff off each rear wheel, or, as one cloud (CEL_WHEEL), off one
# and the other in turn.
func _wheel_dust(rig: Dictionary, size: float, life: float) -> void:
	if _dust_style != "cel":
		for wheel in rig.rear:
			_raise_wheel_dust(rig, wheel, size, life)
		return
	if rig.rear.is_empty():
		return
	var turn: int = rig.get("dust_turn", 0)
	rig.dust_turn = turn + 1
	_raise_wheel_dust(rig, rig.rear[turn % rig.rear.size()], CEL_WHEEL.x, CEL_WHEEL.y)


# A puff off a jeep's rear `wheel`, `size` and `life` times a wind cloud's:
# on the ground under it, thrown back from the jeep and out from under it
# (WHEEL_THROW), a cloud to each jeep.
func _raise_wheel_dust(rig: Dictionary, wheel: Node3D, size: float, life: float) -> void:
	var jeep := rig.jeep as Node3D
	var ahead := jeep.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var out := Vector3(ahead.z, 0.0, -ahead.x)
	if out.dot(wheel.global_position - jeep.global_position) < 0.0:
		out = -out
	var under := wheel.global_position + out * _dust_rng.randf_range(-0.1, 0.1) + ahead * _dust_rng.randf_range(-0.2, 0.2)
	var throw := -ahead * WHEEL_THROW.x * _dust_rng.randf_range(0.7, 1.3) \
			+ out * WHEEL_THROW.y * 1.4 * _dust_rng.randf()
	_raise_cloud(under, 1.0, size, life, null, 0.0, "jeep%d" % int(rig.side), throw)


# Where the cursor points at the ground (or null, pointing over it), how fast
# that point moves, and the gust: as hard as the cursor is fast across the
# frame, dying down when it stops -- across the title, so that the frame
# moving under a still cursor (focus) is not a gust.
func _follow_mouse(delta: float) -> void:
	var r := _region()
	var at := r.position + get_local_mouse_position() / size * r.size
	var pixels := at * Vector2(viewport.size)
	var on_title := get_global_mouse_position()
	var speed := (on_title - _last_mouse).length() / maxf(delta, 1e-4)
	_last_mouse = on_title
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


# What the title's menu has picked: `lit` jeeps with their lamps on and their
# engines gunned -- 0, 1 (the left one) or 2 -- and whether it is on hard.
# Level3DTitle calls it when the pick or the difficulty changes; the picture
# splash (Level3DSplash) has no such method and is left alone.
func show_menu(lit: int, hard: bool) -> void:
	for i in _rigs.size():
		var rig: Dictionary = _rigs[i]
		var on := i < lit
		if on and not rig.on:
			rig.flicker = 0.0
			if _engine_on(rig):
				# Gunned: the nose kicks up.
				_kick(rig, ENGINE_KICK)
				rig.rev = 1.0
		elif rig.on and not on:
			_engine_off(rig)
		rig.on = on
	_hard = hard


# What moves on a jeep: its hull, its turret, its lamps' paint, flares and
# spots, and their state.
func _rig(jeep: Node3D, side: float) -> Dictionary:
	var prefix: String = vehicle.prefix
	var hull := jeep.find_child(prefix + "Hull", true, false) as MeshInstance3D
	var turret := jeep.find_child(prefix + "TurretPivot", true, false) as Node3D
	var rig := {
		"jeep": jeep, "jeep_rest": jeep.transform,
		"hull": hull, "rest": hull.transform, "turret": turret, "turret_rest": turret.transform,
		"side": side, "yaw": 0.0, "on": false, "level": 0.0, "flicker": 1.0,
		"pitch": 0.0, "pitch_speed": 0.0, "push": 0.0, "phase": side * 1.7,
		"lamp": null, "flares": [], "spots": [],
		"wheels": [], "wheel_rests": [], "rear": [],
		"going": false, "run": 0.0, "dust_run": 0.0, "speed": 0.0,
		# Its engine (ENGINE_*): "off", "starting", "running" or "stopping",
		# seconds in that, whether a start has caught, the seconds it runs on
		# for once put out, the rev's 0 to 1 and how hard it shakes, 0 to 1.
		"engine": "off", "engine_time": 0.0, "caught": false, "linger": INF, "rev": 0.0, "turning": 0.0,
		"start": Voice.new(ENGINE_START, self), "idle": Voice.new(ENGINE_LOOP, self),
	}
	for name in WHEELS:
		var wheel := jeep.find_child(prefix + name, true, false) as Node3D
		if wheel != null:
			rig.wheels.append(wheel)
			rig.wheel_rests.append(wheel.transform)
			if name in REAR_WHEELS:
				rig.rear.append(wheel)
	var lamps_at: Array[Vector3] = []
	for surface in hull.mesh.get_surface_count():
		var paint := hull.mesh.surface_get_material(surface)
		if paint != null and String(paint.resource_name) == LAMP_PAINTS[kind]:
			lamps_at = _lamps_at(hull.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			# A copy of its own, since each jeep's lamps glow on their own.
			var lamp := (hull.get_surface_override_material(surface) as ShaderMaterial).duplicate() as ShaderMaterial
			hull.set_surface_override_material(surface, lamp)
			rig.lamp = lamp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var shader := Shader.new()
	shader.code = FLARE_SHADER
	for at in lamps_at:
		var flare := MeshInstance3D.new()
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("colour", LAMP_COLOUR)
		flare.mesh = quad
		flare.material_override = m
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flare.position = at + Vector3(0, 0, 0.08)
		flare.scale = Vector3.ONE * FLARE_SIZE
		hull.add_child(flare)
		rig.flares.append(flare)
		var spot := SpotLight3D.new()
		spot.light_color = LAMP_COLOUR
		spot.light_energy = 0.0
		spot.spot_range = SPOT_RANGE
		spot.spot_angle = SPOT_ANGLE
		spot.shadow_enabled = false
		spot.light_cull_mask = GROUND_LAYER
		spot.position = at
		# Forward, down the jeep's +Z, dipped.
		spot.basis = Basis.looking_at(Vector3(0, -sin(deg_to_rad(SPOT_DIP)), 1.0), Vector3.UP)
		hull.add_child(spot)
		rig.spots.append(spot)
	return rig


# Where the lamps' flares and spots stand: the middle of the lamps' paint
# either side, at its front -- each vehicle's own headlights.
func _lamps_at(points: PackedVector3Array) -> Array[Vector3]:
	var at: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		var box := AABB()
		var first := true
		for point in points:
			if signf(point.x) != side:
				continue
			box = AABB(point, Vector3.ZERO) if first else box.expand(point)
			first = false
		if not first:
			at.append(Vector3(box.get_center().x, box.get_center().y, box.end.z))
	return at


func _drive_rigs(delta: float) -> void:
	for rig in _rigs:
		# The lamps: up, with a flicker as they catch, and down.
		var target := 1.0 if rig.on else 0.0
		var level: float = move_toward(rig.level, target, delta / (LAMP_ON if rig.on else LAMP_OFF))
		rig.level = level
		rig.flicker = minf(rig.flicker + delta, 1.0)
		var shown := level
		if rig.on and rig.flicker < 0.35:
			# Catching: on, off for a moment, on.
			shown *= 0.25 if rig.flicker > 0.08 and rig.flicker < 0.16 else 1.0
		if rig.lamp != null:
			(rig.lamp as ShaderMaterial).set_shader_parameter("glow", LAMP_COLOUR * LAMP_GLOW * shown)
		for flare in rig.flares:
			((flare as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("level", shown)
		for spot in rig.spots:
			(spot as SpotLight3D).light_energy = SPOT_ENERGY * shown
		# The engine: the nose's spring, and the shake.
		var pitch: float = rig.pitch
		var speed: float = rig.pitch_speed
		# The kicks still owed (_kick), a share of them a frame.
		var give: float = float(rig.push) * minf(delta / KICK_TIME, 1.0)
		speed -= give
		rig.push -= give
		# Squatting on its tail while it pulls away.
		var squat := LAUNCH_SQUAT if rig.going and _launch_time > LAUNCH_REV else 0.0
		speed += (-ENGINE_SPRING.x * (pitch - squat) - ENGINE_SPRING.y * speed) * delta
		pitch += speed * delta
		rig.pitch = pitch
		rig.pitch_speed = speed
		_drive_engine(rig, delta)
		var shake := lerpf(ENGINE_IDLE, ENGINE_RUN, level) * float(rig.turning) \
				* (sin(_time * 52.0 + float(rig.phase)) + 0.5 * sin(_time * 31.0 + float(rig.phase) * 2.3))
		var rest: Transform3D = rig.rest
		(rig.hull as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, pitch) * rest.basis,
				rest.origin + Vector3.UP * shake)
		# The turret: at the camera on hard, out to its side on normal -- the
		# jeep's own toe taken off, so that "at the camera" is at it.
		var toe := deg_to_rad(JEEP_TOE) * float(rig.side)
		var want := toe if _hard else toe + deg_to_rad(TURRET_OUT) * float(rig.side)
		rig.yaw = move_toward(rig.yaw, want, deg_to_rad(TURRET_RATE) * delta)
		var turret_rest: Transform3D = rig.turret_rest
		(rig.turret as Node3D).transform = Transform3D(Basis(Vector3.UP, rig.yaw) * turret_rest.basis,
				turret_rest.origin)
		if rig.going:
			_drive_off(rig, delta)


# A game for `count` players: that many jeeps, the left one first, light up
# and drive off past the camera (LAUNCH_*). Returns how long Level3DTitle is
# to wait before it fades out over them.
func launch(count: int) -> float:
	_launch_time = 0.0
	for i in _rigs.size():
		var rig: Dictionary = _rigs[i]
		if i < count:
			if not rig.on:
				rig.flicker = 0.0
			rig.on = true
			_engine_on(rig)
			rig.going = true
			# Gunned again as it goes.
			_kick(rig, ENGINE_KICK * 0.6)
			rig.rev = 1.0
	return LAUNCH_HOLD


# The engine lit (show_menu, launch): started, or kept running, or picked up
# again as it dies away (ENGINE_*). True when it was running already, to be
# gunned.
func _engine_on(rig: Dictionary) -> bool:
	rig.linger = INF
	match rig.engine:
		"running":
			return true
		"stopping":
			var idle := rig.idle as Voice
			if float(rig.engine_time) < CATCH_AGAIN:
				# Still turning: it catches again by itself, the idle coming back
				# from where it was, or in, if it went from the start.
				(rig.start as Voice).fade(0.0, STOP_IN)
				if idle.player.playing:
					idle.fade(1.0, STOP_IN)
				else:
					idle.begin(0.0, STOP_IN)
				rig.engine = "running"
				rig.engine_time = 0.0
				_kick(rig, ENGINE_KICK)
				rig.rev = 1.0
			else:
				_crank(rig)
		"off":
			_crank(rig)
	return false


# The nose kicked up by `amount` rad/s, given over about KICK_TIME.
func _kick(rig: Dictionary, amount: float) -> void:
	rig.push += amount


func _crank(rig: Dictionary) -> void:
	(rig.start as Voice).begin(START_FROM)
	rig.engine = "starting"
	rig.engine_time = 0.0
	rig.caught = false


# The engine put out: after ENGINE_LINGER, or `at_once`.
func _engine_off(rig: Dictionary, at_once := false) -> void:
	if not at_once:
		rig.linger = ENGINE_LINGER
		return
	rig.linger = INF
	if rig.engine == "starting" and not rig.caught:
		# The starter gives up.
		(rig.start as Voice).fade(0.0, STOP_IN)
		rig.engine = "off"
		return
	if rig.engine in ["starting", "running"]:
		(rig.start as Voice).fade(0.0, ENGINE_FADE)
		(rig.idle as Voice).fade(0.0, ENGINE_FADE)
		rig.engine = "stopping"
		rig.engine_time = 0.0


# A frame of the engine: the start into the idle, the fade dying away, the
# rev, the shake, and the players' levels, the idle's pitch with the speed.
func _drive_engine(rig: Dictionary, delta: float) -> void:
	rig.engine_time += delta
	if is_finite(float(rig.linger)):
		rig.linger -= delta
		if rig.linger <= 0.0:
			_engine_off(rig, true)
	var at := START_FROM + float(rig.engine_time)
	var turning := 0.0
	match rig.engine:
		"starting":
			if not rig.caught and at >= START_CATCH:
				rig.caught = true
				_kick(rig, ENGINE_KICK * CATCH_KICK)
			if at >= IDLE_AT:
				(rig.start as Voice).fade(0.0, IDLE_IN)
				(rig.idle as Voice).begin(0.0, IDLE_IN)
				rig.engine = "running"
			turning = 1.0 if rig.caught else 0.0
		"running":
			turning = 1.0
		"stopping":
			turning = clampf(1.0 - float(rig.engine_time) / ENGINE_FADE, 0.0, 1.0)
			if float(rig.engine_time) >= ENGINE_FADE:
				rig.engine = "off"
	rig.turning = move_toward(float(rig.turning), turning, delta / 0.2)
	rig.rev = move_toward(float(rig.rev), 0.0, delta / REV_TIME)
	var gain := ENGINE_VOLUME * _engine_gain(rig, delta)
	var idle := rig.idle as Voice
	idle.player.pitch_scale = 1.0 + (REV_PITCH - 1.0) * clampf(float(rig.speed) / REV_SPEED, 0.0, 1.0) \
			+ REV_BLIP * float(rig.rev)
	for name in ["start", "idle"]:
		(rig[name] as Voice).step(delta, gain)


# How loud a jeep's engine is for where it is: 1 where they stand, louder
# nearer the camera (ENGINE_NEAR, ENGINE_LOUDEST).
func _engine_gain(rig: Dictionary, _delta: float) -> float:
	var far := ((rig.jeep as Node3D).position - camera.position).length()
	return clampf(ENGINE_NEAR / maxf(far, 1.0), 0.0, ENGINE_LOUDEST)


# Every engine quiet and off at once: the title gone, or opened again.
func _silence_engines() -> void:
	for rig in _rigs:
		for name in ["start", "idle"]:
			(rig[name] as Voice).silence()
		rig.engine = "off"
		rig.linger = INF
		rig.turning = 0.0


# Back where they stood, dark and silent, and their dust gone: the title
# opened again, which lights them as its menu says (show_menu).
func reset_launch() -> void:
	_launch_time = -1.0
	_rise = 0.0
	_show_rise()
	if _focus != null:
		_focus.kill()
		_focus = null
	position = _rest.position
	size = _rest.size
	zoom = 1.0 / FOCUS_ZOOM
	_silence_engines()
	for rig in _rigs:
		rig.on = false
		rig.level = 0.0
		rig.going = false
		rig.run = 0.0
		rig.speed = 0.0
		rig.dust_run = 0.0
		(rig.jeep as Node3D).transform = rig.jeep_rest
		for k in rig.wheels.size():
			(rig.wheels[k] as Node3D).transform = rig.wheel_rests[k]
	_clouds.clear()
	_oldest = 0
	for i in CLOUD_POOL:
		_dust_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_veils.clear()
	_oldest_veil = 0
	for i in VEIL_POOL:
		_veil_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


# A launched jeep along its way: out of where it stood towards LAUNCH_PASS on
# its side, turning to it over the first few metres, its wheels rolling the
# ground it covers, dust off its rear wheels.
func _drive_off(rig: Dictionary, delta: float) -> void:
	var t := maxf(_launch_time - LAUNCH_REV, 0.0)
	var run := 0.5 * LAUNCH_ACCEL * t * t
	rig.speed = LAUNCH_ACCEL * t
	var step: float = run - float(rig.run)
	rig.run = run
	var rest: Transform3D = rig.jeep_rest
	var side: float = rig.side
	var to := Vector3(LAUNCH_PASS.x * side, 0.0, LAUNCH_PASS.y) - rest.origin
	to.y = 0.0
	var way := to.normalized()
	var at := rest.origin + way * run
	at.y = _height.call(at.x, at.z)
	var rest_yaw := rest.basis.get_euler().y
	var yaw := lerp_angle(rest_yaw, atan2(way.x, way.z), smoothstep(0.0, 3.0, run))
	(rig.jeep as Node3D).transform = Transform3D(Basis(Vector3.UP, yaw), at)
	for k in rig.wheels.size():
		var wheel_rest: Transform3D = rig.wheel_rests[k]
		(rig.wheels[k] as Node3D).transform = Transform3D(wheel_rest.basis * Basis(Vector3.RIGHT, run / float(vehicle.wheel_radius)),
				wheel_rest.origin)
	rig.dust_run += step
	var dust_step := _wheel_step(WHEEL_DUST_STEP)
	while rig.dust_run >= dust_step:
		rig.dust_run -= dust_step
		_wheel_dust(rig, WHEEL_CLOUD.x, WHEEL_CLOUD.y)


# The sun as far up as the rise has it (RISE_*), eased in and out.
func _show_rise() -> void:
	if _sun == null:
		return
	var t := smoothstep(0.0, 1.0, _rise)
	_environment.ambient_light_energy = lerpf(AMBIENT_ENERGY, RISEN_AMBIENT, t)
	_sky_material.set_shader_parameter("sink", lerpf(SINK, RISEN_SINK, t))
	_sky_material.set_shader_parameter("dawn", t)
	if _veil_paint != null:
		_veil_paint.set_shader_parameter("colour", VEIL_COLOUR.lerp(RISEN_VEIL_COLOUR, t))
	_dust_tones = [DUST_BODY.lerp(RISEN_DUST_BODY, t), DUST_LIT.lerp(RISEN_DUST_LIT, t)]
	if _dust_paint != null:
		_dust_paint.set_shader_parameter("body", DUST_BODY.lerp(RISEN_DUST_BODY, t))
		_dust_paint.set_shader_parameter("lit", DUST_LIT.lerp(RISEN_DUST_LIT, t))
	if _ground_paint != null:
		_ground_paint.set_shader_parameter("albedo", GROUND_COLOUR.lerp(RISEN_GROUND, t))
		_ground_paint.set_shader_parameter("glow", Color.BLACK.lerp(RISEN_GLOW, t))
		# Off sooner than the rest comes up: gone before the camera is near.
		_ground_paint.set_shader_parameter("sun", 1.0 - smoothstep(0.0, GROUND_SUN_OFF, _rise))
