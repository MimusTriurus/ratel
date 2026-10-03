# The title screen's splash (level3d_title.gd): the sunset in place of the
# 2D game's title art, alive rather than a still. The preview's own, with no
# counterpart in the original or the 2D game.
#
# The picture is assets/images/splash3d/sunset.png, its glow running out to
# black on every edge so that it sits on the title's black without a seam.
# Over it, one shader:
#
# - The air: the heat haze of a hot evening, the sky just above the horizon
#   wavering as it rises, sideways and a little up and down, strongest on the
#   horizon and gone a third of the picture above it; the ground under the
#   horizon stays still. Sideways alone hardly shows: the sky's gradient runs
#   up the picture, so it is the vertical push that ripples it.
# - The sun breathing: the glow swelling and settling once every BREATH
#   seconds, a little wider and a little brighter, the sky only, so that the
#   horizon's line does not slide.
# - Dust: thin drifts of it blowing along the ground, lit from behind by the
#   sun, so brightest under it; seen in perspective, finer and slower towards
#   the horizon.
# - The mouse: a moving cursor is a gust where it passes -- the dust under it
#   blown aside and the air over it stirred. The picture itself stays put.
#
# TIME and _process both run on through the paused tree under the title.
class_name Level3DSplash
extends TextureRect

const SUNSET := "res://assets/images/splash3d/sunset.png"
# The horizon's row in the picture, as a fraction of its height (380 of 504).
const HORIZON := 0.754
# A gust: the cursor's speed (pixels a second) that blows at full strength,
# and how quickly a gust dies down when the cursor stops (1/s).
const GUST_SPEED := 1500.0
const GUST_DECAY := 1.5

const SHADER := """
shader_type canvas_item;

uniform float horizon = 0.754;
// The haze: how far above the horizon it reaches, as a fraction of the
// height; how far the air pushes a pixel at the horizon, in texels, sideways
// and up or down; how fast the air rises, in picture heights a second.
uniform float reach = 0.33;
uniform vec2 push = vec2(3.0, 1.5);
uniform float rise = 0.05;
// The sun's breath: its period in seconds, how much wider the glow gets and
// how much brighter the sky.
uniform float breath = 7.0;
uniform float swell = 0.012;
uniform float glow = 0.05;
// The dust: how bright at most, its colour in the sun, how fast it blows.
uniform float dust = 0.4;
uniform vec3 dust_colour : source_color = vec3(1.0, 0.55, 0.25);
uniform float wind = 0.035;
// The mouse: the cursor in the picture's UV, and 0 to 1 how hard it blows.
uniform vec2 mouse = vec2(-10.0);
uniform float gust = 0.0;
// The picture's height over its width, to measure round distances in UV.
uniform float aspect = 0.4922;

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

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.1 + 13.0) * 0.3 + noise(p * 4.3 + 29.0) * 0.2;
}

void fragment() {
	vec2 uv = UV;
	float above = horizon - uv.y;
	// The gust, round the cursor: 1 on it, gone about a tenth of the
	// picture's width away.
	vec2 from_mouse = (uv - mouse) * vec2(1.0, aspect);
	float near_mouse = gust * exp(-dot(from_mouse, from_mouse) / 0.008);

	// The breath: the sky drawn in towards the sun's centre as it swells,
	// which widens the glow; nothing at the horizon, all of it a tenth above.
	float b = 0.5 - 0.5 * cos(TIME * TAU / breath);
	float sky = smoothstep(0.0, 0.1, above);
	vec2 sun = vec2(0.5, horizon);
	uv = sun + (uv - sun) / (1.0 + swell * b * sky);

	// The haze, stirred where the cursor passes.
	float strength = smoothstep(-0.004, 0.01, above) * (1.0 - smoothstep(0.0, reach, above));
	strength *= 1.0 + 2.5 * near_mouse;
	// Two octaves, cells wider than they are tall: layers of warm air rising.
	vec2 p = vec2(uv.x * 40.0, (uv.y + TIME * rise) * 90.0);
	vec2 n = vec2(noise(p) * 0.65 + noise(p * 2.3 + 17.0) * 0.35,
			noise(p + 41.0) * 0.65 + noise(p * 2.3 + 59.0) * 0.35);
	uv += (n - 0.5) * 2.0 * push * strength * TEXTURE_PIXEL_SIZE;

	vec4 c = texture(TEXTURE, uv);
	c.rgb *= 1.0 + glow * b * sky;

	// The dust, on the ground: its depth below the horizon stands in for
	// distance, so the drifts are finer and slower towards the horizon. Blown
	// aside by a gust: the noise looked up from where the gust pushes it from.
	float below = UV.y - horizon;
	float ground = smoothstep(-0.01, 0.015, below) * (1.0 - smoothstep(0.08, 0.24, below));
	if (ground > 0.0) {
		float depth = 0.03 + max(below, 0.0);
		vec2 blow = from_mouse / max(length(from_mouse), 1e-4) * near_mouse * 0.04;
		// The drift's speed is the same in the noise at every depth, so the rows
		// do not shear apart, and on the screen it grows with the depth.
		vec2 q = vec2((UV.x - 0.5 - blow.x) / depth * 0.45 - TIME * wind * 2.25,
				(below - blow.y) * 55.0);
		float drift = smoothstep(0.5, 0.85, fbm(q));
		float fine = smoothstep(0.62, 0.9, fbm(q * vec2(2.5, 1.6) + vec2(-TIME * 0.4, 7.0)));
		// Backlit: bright under the sun, faint out at the sides.
		float lit = 0.45 + 0.55 * exp(-pow((UV.x - 0.5) / 0.22, 2.0));
		c.rgb += dust_colour * (drift * 0.7 + fine * 0.5) * ground * lit * dust;
	}
	COLOR = c * COLOR;
}
"""

var _gust := 0.0
var _last_mouse := Vector2.ZERO


func _init() -> void:
	texture = load(SUNSET)
	# The expand mode first, or the size is held to the texture's.
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("horizon", HORIZON)
	m.set_shader_parameter("aspect", float(texture.get_height()) / texture.get_width())
	material = m


# The picture `width` wide in its own proportions, centred on `centre`.
func place(centre: Vector2, width: float) -> void:
	size = Vector2(width, width * texture.get_height() / texture.get_width())
	position = centre - size * 0.5


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var at := get_viewport().get_mouse_position()
	# The gust: as hard as the cursor is fast, dying down when it stops.
	var speed := (at - _last_mouse).length() / maxf(delta, 1e-4)
	_last_mouse = at
	_gust = maxf(_gust * exp(-GUST_DECAY * delta), minf(speed / GUST_SPEED, 1.0))
	var m := material as ShaderMaterial
	m.set_shader_parameter("mouse", get_local_mouse_position() / size)
	m.set_shader_parameter("gust", _gust)
