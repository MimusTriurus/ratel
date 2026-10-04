class_name Level3DLighting
extends RefCounted
# The 3D preview's light, as presets: the day it has always had, which is
# Blender's (level3d_preview.gd, _add_lights), and the low warm sun of the
# title's splash (level3d_splash3d.gd) brought to the stage. Not the splash's
# light itself: its sun is on the horizon in front of the camera, which makes
# everything a silhouette -- the point of a title, and the end of a stage
# that has to be read. What is kept is the mood: a warm sun lower in the sky,
# long shadows, a cool shade and the sea's glint in the sun's colour.
#
# Readability is the constraint, so a preset moves hue and not brightness:
#
# - The light's colour is a hue only. Its energy is scaled so that a grey face
#   is as bright as by day, lit and in shade (keep): the walls, the bunkers,
#   the rocks. A unit stands apart from the ground by brightness, and that
#   step does not change. SUNRISE makes up only part of its sun's colour
#   (`hold`): the sand redder and darker, as the splash's ground is, at a
#   cost measured (below) and no worse than DUSK's.
# - The sand cannot be moved by light at all. Its orange is at the edge of
#   what a screen shows, red full and blue none: a warm sun only finds red
#   that is already full, and a cool shade finds no blue to show. So the grade
#   (level3d_screen.gdshader, mode 3) does it, over the finished frame and
#   under the HUD: it turns hue, cool in the shade and warm in the light, and
#   leaves OKLab's lightness, and the black contour, as they were.
# - The sun stays in the top left of the frame, where the art was drawn to be
#   lit from (level3d_fire.gdshader's smoke, the craters, the HUD icons), and
#   goes no lower than 30 degrees. The two-tone light (_toon) lights every
#   face turned to the sun in full however low it is, so a low sun does not
#   darken the ground; what it does is lengthen the shadows, 1.9 times as long
#   at 30 degrees as at the day's 48, and a soldier in a palm's shadow is a
#   soldier read against the shade. Measured (a lightness step round each
#   unit, against the same frame by day): a unit in the sun or in the shade
#   reads as it did, but more of them stand in shade, the soldiers under the
#   base's south wall down to 0.6 of their step in the sun at 25 degrees.
# - So the shade is lighter as the sun is lower (`shade`, the ambient), as it
#   is at evening, when the sky lights the shadows and the sun has weakened:
#   the dark units on it stand out the more. The sun gives up what that adds
#   to a lit face, so a lit grey is where it was by day.
# - The fill: a second sun, from the other side and a little under the
#   horizon, casting nothing. Flat ground faces away from it and takes none;
#   what stands up -- the units' sides, the trunks, the walls -- takes it on
#   the side the sun leaves in shade, and takes it in a cast shadow too. It is
#   what keeps a unit apart from the shadow it stands in.
# - `exposure` is the one change of brightness, and it is the same for
#   everything, so it keeps every ratio; the flashes, the rounds and the fire
#   glow, and stand out the more for it.
#
# The water is lit smoothly, not in two tones; it is given the sun's height
# back and otherwise left to the light: under a warm sun the sea darkens, as
# it does at evening, which is also what a boat on it is read against.

enum Preset { DAY, GOLDEN, DUSK, SUNRISE }

const NAMES := ["day", "golden", "dusk", "sunrise"]
const LABELS := ["Day", "Golden hour", "Dusk", "Sunrise"]

# The grey a light's energy is held on (keep).
const GREY := Color(0.5, 0.5, 0.5)

# Per preset. `elevation`, degrees, is the sun's height; null keeps the day's
# direction exactly, and any other keeps its bearing. Colours are sRGB, and
# the light's are only hues: the energy is worked out (see above). `sky` is the
# ambient the water adds to itself (level3d_ocean.gdshader), linear. The
# day's background and sky are null: the preview's own, worked out off
# Blender's world. `hold` is how much of a light's colour is made up for in
# its energy (keep): 1 holds a grey where it was by day, 0 lets the colour take
# what it takes -- a sun as orange as the splash's, held on a grey, is more
# than twice as strong in red and burns the sand to full. `shade` is the
# ambient's strength, level3d_preview.gd's
# SHADE by day. `fill` is the fill's energy against the day's sun, 0 for none.
# The grade's tints and amounts (OKLab a and b) are level3d_screen.gdshader's,
# 0 for none.
const PRESETS := [
	{   # DAY: Blender's, as it has always been.
		"elevation": null,
		"sun": Color(1, 1, 1),
		"ambient": Color(1, 1, 1),
		"exposure": 1.0,
		"hold": 1.0,
		"shade": 0.3,
		"background": null,
		"sky": null,
		"fill": 0.0,
		"fill_colour": Color(1, 1, 1),
		"shade_tint": Color(1, 1, 1),
		"shade_amount": 0.0,
		"light_tint": Color(1, 1, 1),
		"light_amount": 0.0,
	},
	{   # GOLDEN: late afternoon, the sun's yellow before it reddens.
		"elevation": 36.0,
		"sun": Color(1.0, 0.88, 0.70),
		"ambient": Color(0.92, 0.94, 1.0),
		"exposure": 1.0,
		"hold": 1.0,
		"shade": 0.4,
		"background": Color(0.62, 0.50, 0.48),
		"sky": Vector3(0.07, 0.06, 0.08),
		"fill": 0.2,
		"fill_colour": Color(0.75, 0.82, 1.0),
		"shade_tint": Color(0.50, 0.50, 0.90),
		"shade_amount": 0.035,
		"light_tint": Color(1.0, 0.85, 0.55),
		"light_amount": 0.025,
	},
	{   # DUSK: the splash's own orange, the shade gone violet.
		"elevation": 30.0,
		"sun": Color(1.0, 0.74, 0.50),
		"ambient": Color(0.86, 0.84, 1.0),
		"exposure": 0.92,
		"hold": 1.0,
		"shade": 0.4,
		"background": Color(0.45, 0.26, 0.30),
		"sky": Vector3(0.09, 0.05, 0.07),
		"fill": 0.3,
		"fill_colour": Color(0.66, 0.66, 1.0),
		"shade_tint": Color(0.60, 0.40, 0.95),
		"shade_amount": 0.06,
		"light_tint": Color(1.0, 0.70, 0.45),
		"light_amount": 0.04,
	},
	{   # SUNRISE: the title's splash (level3d_splash3d.gd) as far as a stage
		# can be read in it -- its sun's colour as it is, SUN_COLOUR, its sky's
		# reds in the shade and the background, its yellow in the light.
		"elevation": 30.0,
		"sun": Color(1.0, 0.62, 0.32),
		"ambient": Color(0.92, 0.78, 0.84),
		"exposure": 0.9,
		"hold": 0.6,
		"shade": 0.4,
		"background": Color(0.36, 0.12, 0.06),
		"sky": Vector3(0.10, 0.045, 0.05),
		"fill": 0.3,
		"fill_colour": Color(0.80, 0.62, 0.86),
		"shade_tint": Color(0.75, 0.30, 0.45),
		"shade_amount": 0.055,
		"light_tint": Color(1.0, 0.80, 0.30),
		"light_amount": 0.04,
	},
]

# How far under the horizon the fill comes from, degrees: enough that the
# flat ground is past TOON_EDGE's band and takes none of it.
const FILL_UNDER := 4.0


static func from_name(name: String) -> Preset:
	var i := NAMES.find(name.to_lower())
	if i < 0:
		push_warning("No light preset %s; one of %s" % [name, ", ".join(NAMES)])
		return Preset.DAY
	return i as Preset


static func spec(preset: Preset) -> Dictionary:
	return PRESETS[preset]


# The sun's way, Blender axes (as level3d_preview.gd's SUN_DIRECTION_BLENDER):
# the day's, or the day's bearing at the spec's height.
static func sun_direction(spec: Dictionary, day: Vector3) -> Vector3:
	var elevation = spec["elevation"]
	if elevation == null:
		return day
	var across := Vector2(day.x, day.y).normalized()
	var e := deg_to_rad(float(elevation))
	return Vector3(across.x * cos(e), across.y * cos(e), -sin(e))


# The fill's, Blender axes: back the other way along the sun's bearing, and
# rising, from FILL_UNDER under the horizon.
static func fill_direction(day: Vector3) -> Vector3:
	var across := -Vector2(day.x, day.y).normalized()
	var e := deg_to_rad(FILL_UNDER)
	return Vector3(across.x * cos(e), across.y * cos(e), sin(e))


# How much stronger a light of this colour must be for `albedo` to be as
# bright under it as under white: luminance, linear, both sRGB in.
static func keep(light: Color, albedo := GREY, hold := 1.0) -> float:
	var a := albedo.srgb_to_linear()
	var l := light.srgb_to_linear()
	var lit := _luminance(Color(a.r * l.r, a.g * l.g, a.b * l.b))
	return pow(_luminance(a) / maxf(lit, 1e-6), hold)


static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
