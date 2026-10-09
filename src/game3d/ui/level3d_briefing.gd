# The intro, the briefing table (docs/story/frames.md, "Вступление"): the
# R.A.T.E.L. hangar at night, the map on the table, the telephone ringing,
# the dossier's cards falling on to it one by one, each with its caption;
# then the camera leaves the table, goes out of the hangar's door into the
# dawn and comes to the title's own shot -- the jeeps, the rocks and the
# palms against the sun -- where the title takes over without a cut.
#
# So it is played in the title's world (Level3DSplash3D.play_briefing), in
# its SubViewport, which is what is beyond the door: the hangar stands
# behind the title's camera (Level3DSplash3D.HANGAR_DOOR), the sky goes
# from the night to the title's dawn (set_daylight), and its last frame is
# the title's camera's.
#
# All of it is built in Blender and exported (tools/blender/story_frames.py,
# export_intro): the table, the hangar and the cards as a glb, the cards'
# falls and captions its one animation; and beside it a track, the camera's
# place, turn and field of view and the daylight frame by frame, baked
# there. Played here by the clock: the animation sought to it, the track
# read at it -- so a slow frame is a jump rather than the intro going slow.
#
# The glb's paints are plain colours and pictures; the look is the
# preview's, given here: two tones, lit or in shade (SHADER), and the
# engine's contour round everything but what is printed on paper.
#
# The cards and captions are stand-ins (photos 4 and 8 grey, the marker a
# font that pops up whole); docs/story/frames.md, "Аниматик", has what is
# still to come.
class_name Level3DBriefing
extends Node3D

## The camera is on the title's own shot to stay (the track's `arrive`).
signal arrived

const SCENE := "res://resources/3d/story/briefing_intro.glb"
const TRACK := "res://resources/3d/story/briefing_intro.json"
const CLIP := "Intro_01_3D"
# The map's sheet: the print and the team's pencil over it, from the files
# sahrun_map.py prints (the glb leaves them out: 6000 px each).
const PRINT := "res://resources/3d/story/sahrun_print.png"
const MARKS := "res://resources/3d/story/sahrun_marks.png"
# The second player's token, on the map only with two (story_frames.py's
# PLAYERS); the intro is before there are any, so it shows one.
const SECOND_TOKEN := "SF1P_Token2"

# The two tones: lit -- the paint as it is, times the light's colour and
# strength, no more than the paint -- or in shade, `shade` times the paint
# (SHADE, the blend's: toon()'s, 70 62 70, sRGB), whatever lights the world
# round it (so not the title's red ambient); a spot's reach cut where its
# ATTENUATION falls under REACH, the blend's step, a hard-edged pool. What
# is `flat` glows its colour, lit or not: the lamp's bulb, the pins' red,
# the labels; the loupe's glass glows its tint, see-through (`glass`, its
# ALPHA). A `photo`, a painted frame, goes to grey, as the press
# photographs it stands in for; the `sheet` lays the pencil over the print.
# LIGHT_COLOR is the light's colour times its energy times PI.
#
# The Compatibility renderer adds the lights up, one pass a light with
# shadows, so a face two of them light is lit twice over -- the map went
# white where the lamp over the table and the fill on its near edge met.
# So the fill's pass -- told by its light coming from fill_at -- and the
# light in at the door's (Level3DSplash3D.door_light, the hangar's one
# parallel light) leave alone what the lamp's cone (lamp_*) reaches and
# faces it (`lamped`,
# reckoned without the lamp's shadows): the fill lights the fronts the lamp
# cannot, the telephone's, the mug's, and casts their shadows back across
# the map.
#
# Two shades, not one: a face turned from the light is in its own shade,
# `shade`, dark, which holds the shapes; a face turned to the lamp, in its
# cone, that something stands between it and the lamp is in a cast shadow
# -- the paper under a flag, a mug -- CAST_SHADE of the lit tone, since a
# room's walls and the paper itself throw light back into it. Both in the
# one shade, the shadows on the map were as black as the lines, and a
# flag's read as a black thing lying by it. The lamp's pass is told as the
# fill's is, by where its light comes from (lamp_at); and only on the
# table, CAST_RANGE from the lamp -- the walls and the floor its cone
# reaches past the shade and the table keep the one shade, or the hangar
# had a pale arc on its far wall.
#
# Both sides drawn: Blender draws a face from behind, and some of the
# blend's are turned in -- the telephone's dial, whose hull showed through
# it black. But for the glass: seen through, its faces behind laid their
# tint on its front's, and it was milk.
const SHADE := Color(0.061, 0.048, 0.061)
const CAST_SHADE := 0.45
# While the camera is over the table there is nothing round it: the hangar
# -- its floor in the lamp's pool, the table's legs, the walls, the
# emblems, the door's light -- is dark (`shown` 0), and comes up over
# SURROUNDINGS_IN seconds before the camera leaves the table (the track's
# `leave`), for the way out. Lit, the floor round the table was grey, and
# blue in the moon by the door, and under the table's top its rail's
# narrower front stood out in steps. What SURROUNDINGS names is the
# hangar's; the lamp's bulb glows on.
const SURROUNDINGS := ["SF1H_", "RATEL_"]
const SURROUNDINGS_GLOW := "SF1H_Glow"
const SURROUNDINGS_IN := 1.0
const CAST_RANGE := 2.3
const REACH := 0.18
const SHADER := """
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled BLEND;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D picture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D marks : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool textured = false;
uniform bool marked = false;
uniform bool grey = false;
uniform bool glows = false;
uniform bool coloured = false;
uniform vec3 shade = vec3(0.061, 0.048, 0.061);
uniform float reach = 0.18;
uniform vec3 fill_at = vec3(0.0, -1000.0, 0.0);
uniform vec3 lamp_at;
uniform vec3 lamp_dir = vec3(0.0, -1.0, 0.0);
uniform float lamp_cos = 2.0;
uniform float lamp_range = 0.0;
uniform float cast_shade = 0.45;
uniform float cast_range = 2.3;
uniform float shown = 1.0;
uniform bool wood = false;
uniform vec4 wood_dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
varying float lamped;
varying float castable;
varying vec3 to_fill;
varying vec3 to_lamp;
// The desk's grain (wood), the blend's wave bands worked out: bands across
// the desk's depth WOOD_BANDS radians a metre, warped by a noise stretched
// along its length (WOOD_ALONG, WOOD_ACROSS cells a metre) WOOD_WARP
// radians, from its colour to wood_dark. Exported as its one colour, the
// desk was flat brown.
const float WOOD_BANDS = 90.0;
const float WOOD_ALONG = 1.5;
const float WOOD_ACROSS = 14.0;
const float WOOD_WARP = 9.0;
float grain_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 c = albedo;
	if (textured) {
		c *= texture(picture, UV);
	}
	if (marked) {
		vec4 m = texture(marks, UV);
		c.rgb = mix(c.rgb, m.rgb, m.a);
	}
	if (coloured) {
		c *= COLOR;
	}
	if (grey) {
		c.rgb = vec3(dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)));
	}
	vec3 at = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (wood) {
		vec2 p = vec2(at.x * WOOD_ALONG, at.z * WOOD_ACROSS);
		float warp = grain_noise(p) * 0.6 + grain_noise(p * 2.7) * 0.3 + grain_noise(p * 7.0) * 0.1;
		float band = 0.5 + 0.5 * sin(at.z * WOOD_BANDS + warp * WOOD_WARP);
		c.rgb = mix(wood_dark.rgb, c.rgb, band);
	}
	vec3 to = lamp_at - at;
	float far = length(to);
	to /= max(far, 1e-4);
	lamped = step(0.0, dot(normal, to)) * step(lamp_cos, dot(-to, lamp_dir)) * step(far, lamp_range);
	castable = lamped * step(far, cast_range);
	to_fill = normalize((VIEW_MATRIX * vec4(fill_at, 1.0)).xyz - VERTEX);
	to_lamp = normalize((VIEW_MATRIX * vec4(lamp_at, 1.0)).xyz - VERTEX);
	ALBEDO = glows ? vec3(0.0) : c.rgb;
	EMISSION = (glows ? c.rgb : c.rgb * shade) * shown;
	ALPHA_LINE
}
void light() {
	// The fill's pass, and the door's light's (the only one parallel).
	float fill = LIGHT_IS_DIRECTIONAL ? 1.0 : step(0.9999, dot(LIGHT, to_fill));
	float lamp = LIGHT_IS_DIRECTIONAL ? 0.0 : step(0.9999, dot(LIGHT, to_lamp));
	float facing = step(0.0, dot(NORMAL, LIGHT));
	float reached = step(reach, ATTENUATION);
	float lit = facing * reached * (1.0 - fill * lamped);
	float cast = lamp * castable * facing * (1.0 - reached);
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, max(lit, cast * cast_shade) * min(LIGHT_COLOR / PI, vec3(1.0)) * shown);
}
"""
# The glb's lights: [range, shadows] by name, the cone its own, the colour
# LIGHT; any other is put out. Lit is the paint itself, as in the blend
# (toon()'s step goes to white, whatever the lamp's colour), so the light
# is near white -- the lamp's warm one turned the map's beige yellow; its
# cone hard, CONE_SOFT of the way in: Godot's fades it to the edge, and the
# pool was half the table. The lamp's pool on the whole table, the fill on
# its near edge (FILL, which the lamp's pool keeps off, SHADER), and the
# emblem's spot on the near wall. Their shadows' bias SHADOW_BIAS, a
# normal's SHADOW_NORMAL_BIAS: Godot's own lifted a loupe's or a pencil's
# shadow off the map under it.
const LIGHTS := {
	"SF1P_Lamp": [4.0, true],
	"SF1P_Fill": [4.5, true, FILL_CONE],
	"SF1H_EmblemLight": [14.0, true],
}
# The fill's cone, half its angle, degrees: the blend's 35 lit the desk's
# front only in the middle, black either side, and its edge looked ragged.
const FILL_CONE := 75.0
const LAMP := "SF1P_Lamp"
const FILL := "SF1P_Fill"
const LIGHT := Color(1.0, 0.97, 0.92)
const CONE_SOFT := 0.1
const SHADOW_BIAS := 0.005
const SHADOW_NORMAL_BIAS := 0.3
# The positional shadows' atlas of the splash's world while it plays: the
# lamp's map spread over the table, the props' shadows were coarse at 2048.
const SHADOW_ATLAS := 4096
# The renderer builds a paint's shaders the first time it draws it, in that
# light: first drawn mid-flight, as the hangar came into the shot, the flight
# stalled for a tenth of a second a frame, the first run on a machine. So a
# small view of its own (WARM_SIZE, the same world) draws the hangar from
# the track at WARM_AT seconds once, while the briefing is held on its first
# frame, so that the shaders are built before the camera gets there. The
# lights never change while it plays (Level3DSplash3D.door_light), so they
# are not built again.
const WARM_SIZE := Vector2i(320, 180)
const WARM_AT := 59.5
# The contour goes round what has some thickness; not round what is
# printed: the captions, the pictures, the map -- their least side thinner
# than this, in metres -- nor round the glass, nor round what UNLINED
# names: the telephone's dial, whose cream holes and card stand a
# millimetre or so proud of its finger wheel, under the wheel's line; and
# the paper clip on the passport photographs, its wire thinner than the
# line, which drew it black.
const UNLINED := ["SF1P_PhoneWheel", "SF1P_PhonePlate", "SF1A_IDClip"]
# And along their sharp edges as well (Level3DHull.apply's `edged`): the
# desk, the edge between its top and its sides inside its outline; a
# chamfer there instead caught the lamp and the fill in patches, and the
# edge was ragged.
const CREASED := ["SF1P_Desk"]
const PRINTED := 0.002
# The players' tokens on the map, a few centimetres long: the vehicles'
# line round them (Level3DHull.Kind.VEHICLES), thinner than the stage's,
# which was as thick as their wheels; and their shade TOKEN_SHADE, the
# paint darkened rather than gone to black -- in SHADE their sides and the
# line were one black mass round the roof.
const TOKENS := "SF1P_Token"
const TOKEN_SHADE := Color(0.35, 0.35, 0.35)

var camera := Camera3D.new()
var time := 0.0
var playing := false         # the clock running; held on its first frame till then
# --briefing-at <seconds> starts it there, and --briefing-still holds it
# there, for a shot of a moment of it.
var still := false
# Paused by the title's pause keys (Level3DTitle.PAUSE_KEYS): the clock
# held, the world round it -- the sky's breath, the jeeps' idle -- going on.
var paused := false
var end := 0.0
var arrive := 0.0
var leave := 0.0
var _surroundings: Array[ShaderMaterial] = []
var _splash: Level3DSplash3D
var _fps := 24.0
var _frames: Array = []
var _player: AnimationPlayer
var _arrived := false
var _shaders := {}           # alpha line -> Shader
var _lights := {}            # fill_at and lamp_* for SHADER, off the glb's FILL and LAMP
var _warm := SubViewport.new()
var _warm_camera := Camera3D.new()


static func available() -> bool:
	return ResourceLoader.exists(SCENE) and FileAccess.file_exists(TRACK)


func _init(splash: Level3DSplash3D) -> void:
	_splash = splash
	var track: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRACK))
	_fps = float(track.fps)
	_frames = track.frames
	end = float(track.end)
	arrive = float(track.arrive)
	leave = float(track.get("leave", arrive))
	if not is_equal_approx(float(track.door), Level3DSplash3D.HANGAR_DOOR):
		push_warning("The briefing's door is at %s, the title's ground goes under it at %s"
				% [track.door, Level3DSplash3D.HANGAR_DOOR])
	var origin: Array = track.origin
	position = Vector3(origin[0], origin[1], origin[2])
	var scene := (load(SCENE) as PackedScene).instantiate() as Node3D
	var fill := scene.find_child(FILL, true, false) as SpotLight3D
	var lamp := scene.find_child(LAMP, true, false) as SpotLight3D
	if fill != null and lamp != null:
		var lamp_place := _place_in(lamp, scene)
		_lights = {fill_at = position + _place_in(fill, scene).origin, lamp_at = position + lamp_place.origin,
				lamp_dir = -lamp_place.basis.z.normalized(), lamp_cos = cos(deg_to_rad(lamp.spot_angle)),
				lamp_range = LIGHTS[LAMP][0]}
	# Dressed before it is in the tree, where the preview would give it the
	# stage's look (Level3DPreview._toon, _engine_contour).
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		_dress(node as MeshInstance3D)
	for node in scene.find_children("*", "Light3D", true, false):
		_light(node as Light3D)
	var second := scene.find_child(SECOND_TOKEN, true, false) as Node3D
	if second != null:
		second.visible = false
	add_child(scene)
	_player = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clips := _player.get_animation_list()
		if not clips.is_empty():
			var clip: StringName = CLIP if clips.has(CLIP) else clips[0]
			_cut_jumps(_player.get_animation(clip))
			_player.play(clip)
	camera.top_level = true
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 0.02
	camera.far = splash.camera.far
	add_child(camera)
	_warm.size = WARM_SIZE
	_warm.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_warm_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_warm_camera.near = camera.near
	_warm_camera.far = camera.far
	var warm: Array = _frames[clampi(int(WARM_AT * _fps), 0, _frames.size() - 1)]
	_warm_camera.transform = Transform3D(Basis(Quaternion(warm[3], warm[4], warm[5], warm[6])),
			Vector3(warm[0], warm[1], warm[2]))
	_warm_camera.fov = warm[7]
	_warm.add_child(_warm_camera)
	add_child(_warm)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--briefing-at")
	if at >= 0 and at + 1 < args.size():
		time = clampf(float(args[at + 1]), 0.0, end)
	still = args.has("--briefing-still")
	_show()


# To `seconds` (clamped to it), back or on (Level3DTitle.SEEK_STEP); come
# back from its end, it arrives again.
func seek(seconds: float) -> void:
	time = clampf(seconds, 0.0, end)
	if time < arrive:
		_arrived = false
	_show()


# `node`'s transform in `scene`'s terms, the scene not yet in the tree.
static func _place_in(node: Node3D, scene: Node3D) -> Transform3D:
	var place := node.transform
	var up := node.get_parent() as Node3D
	while up != null and up != scene:
		place = up.transform * place
		up = up.get_parent() as Node3D
	return place


func _ready() -> void:
	_warm.world_3d = get_viewport().find_world_3d()
	_warm.msaa_3d = _splash.viewport.msaa_3d
	_warm_camera.make_current()
	_warm_up()


# The hangar drawn once in the warm-up view (WARM_AT).
func _warm_up() -> void:
	_warm.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	if playing and not still and not paused:
		time = minf(time + delta, end)
	_show()
	if not _arrived and time >= arrive:
		_arrived = true
		arrived.emit()


# A card waits out of every shot (the blend's HIDE_Z, metres over the
# lamp) and is keyed in its place from one frame to the next, and a
# caption is written (scale 0 to its own) the same way: steps in the blend
# (CONSTANT), which the glb has as two keys a frame apart, eased between.
# Played at more frames than the clip's, the card was seen falling the
# metres into its place, and a caption growing. So where a key is JUMP from the one
# before it, or one of the two is no size, the one before is held to just
# short of it.
const JUMP := 0.5
const JUMP_HELD := 0.0005


func _cut_jumps(clip: Animation) -> void:
	for i in clip.get_track_count():
		var kind := clip.track_get_type(i)
		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_SCALE_3D:
			continue
		var k := clip.track_get_key_count(i) - 1
		while k > 0:
			var a: Vector3 = clip.track_get_key_value(i, k - 1)
			var b: Vector3 = clip.track_get_key_value(i, k)
			var jumps := a.distance_to(b) > JUMP if kind == Animation.TYPE_POSITION_3D \
					else (a.length() < 0.01) != (b.length() < 0.01)
			var t := clip.track_get_key_time(i, k)
			if jumps and t - clip.track_get_key_time(i, k - 1) > 2.0 * JUMP_HELD:
				clip.track_insert_key(i, t - JUMP_HELD, a)
			k -= 1


# Everything as it is at `time`: the cards, the camera, the light. The
# glb's clip has the blend's frame f at f / fps, the track's (frames) at
# (f - 1) / fps, so the clip is a frame on: seeked to the track's time, the
# cards came down a frame behind the camera.
func _show() -> void:
	if _player != null:
		_player.seek(time + 1.0 / _fps, true)
	var f := clampf(time * _fps, 0.0, _frames.size() - 1.0)
	var i := mini(int(f), _frames.size() - 2)
	var a: Array = _frames[i]
	var b: Array = _frames[i + 1]
	var k := f - i
	var at := Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), k)
	var turn := Quaternion(a[3], a[4], a[5], a[6]).slerp(Quaternion(b[3], b[4], b[5], b[6]), k)
	camera.global_transform = Transform3D(Basis(turn), at)
	camera.fov = lerpf(a[7], b[7], k)
	var day := lerpf(a[8], b[8], k)
	var shown := smoothstep(leave - SURROUNDINGS_IN, leave, time)
	_splash.set_daylight(day, shown)
	for m in _surroundings:
		m.set_shader_parameter("shown", shown)


# The contour round `mesh_instance`, as _dress gives it (Level3DHull);
# made ahead by Level3DBoot, a few a frame while its loading sign
# breathes, they are found made: made in _init, a second and more of it,
# they held the preview's first frame on the boot's black.
static func hull(mesh_instance: MeshInstance3D) -> void:
	# Nor round the loupe's glass, whose line showed black through it.
	var glass := false   # or unlined
	for surface in mesh_instance.mesh.get_surface_count():
		var paint := mesh_instance.mesh.surface_get_material(surface)
		if paint != null and float((paint.get_meta("extras", {}) as Dictionary).get("glass", 0.0)) > 0.0:
			glass = true
	var size := mesh_instance.mesh.get_aabb().size
	var named := String(mesh_instance.name)
	for unlined in UNLINED:
		glass = glass or named.begins_with(unlined)
	if minf(size.x, minf(size.y, size.z)) > PRINTED and not glass:
		var kind := Level3DHull.Kind.VEHICLES if named.begins_with(TOKENS) else Level3DHull.Kind.STAGE
		Level3DHull.apply(mesh_instance, kind, true, named in CREASED)


func _dress(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	# The vault and the ends are single faces, turned in: both sides keep
	# the moon and the sun out.
	var extras: Dictionary = mesh_instance.get_meta("extras", {})
	var thin := mesh_instance.mesh.get_aabb().size
	# Nor the printed (PRINTED): a card lying a hair over the map, at the
	# small SHADOW_BIAS, shadowed itself in black triangles.
	var cast: bool = extras.get("cast", true) and minf(thin.x, minf(thin.y, thin.z)) > PRINTED
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED 			if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Its own layer alone: on the world's too, the sun -- whose cull mask
	# leaves the hangar's out -- lit it still, unshadowed, the map white.
	mesh_instance.layers = Level3DSplash3D.HANGAR_LAYER
	hull(mesh_instance)
	var mesh := mesh_instance.mesh
	for surface in mesh.get_surface_count():
		var paint := mesh.surface_get_material(surface) as BaseMaterial3D
		if paint != null:
			mesh_instance.set_surface_override_material(surface, _paint(paint))


var _paints := {}            # the glb's material -> SHADER's

func _paint(paint: BaseMaterial3D) -> ShaderMaterial:
	if _paints.has(paint):
		return _paints[paint]
	var extras: Dictionary = paint.get_meta("extras", {})
	var glass := float(extras.get("glass", 0.0))
	var m := ShaderMaterial.new()
	m.shader = _shader(glass > 0.0)
	var colour := paint.albedo_color
	if glass > 0.0:
		colour.a = glass
	m.set_shader_parameter("albedo", colour)
	for key in _lights:
		m.set_shader_parameter(key, _lights[key])
	var shade := TOKEN_SHADE if String(paint.resource_name).begins_with(TOKENS) else SHADE
	m.set_shader_parameter("shade", Vector3(shade.r, shade.g, shade.b))
	m.set_shader_parameter("reach", REACH)
	m.set_shader_parameter("cast_shade", CAST_SHADE)
	m.set_shader_parameter("cast_range", CAST_RANGE)
	if extras.get("sheet", false):
		m.set_shader_parameter("picture", load(PRINT))
		m.set_shader_parameter("marks", load(MARKS))
		m.set_shader_parameter("textured", true)
		m.set_shader_parameter("marked", true)
	elif paint.albedo_texture != null:
		m.set_shader_parameter("picture", paint.albedo_texture)
		m.set_shader_parameter("textured", true)
	m.set_shader_parameter("grey", extras.get("photo", false))
	if extras.get("wood", false):
		var dark: Array = extras.get("wood_dark", [0.0, 0.0, 0.0])
		m.set_shader_parameter("wood", true)
		m.set_shader_parameter("wood_dark", Color(dark[0], dark[1], dark[2]).linear_to_srgb())
	m.set_shader_parameter("glows", extras.get("flat", false) or glass > 0.0)
	m.set_shader_parameter("coloured", extras.get("vcol", false))
	var named := String(paint.resource_name)
	if named != SURROUNDINGS_GLOW:
		for prefix in SURROUNDINGS:
			if named.begins_with(prefix):
				_surroundings.append(m)
				break
	_paints[paint] = m
	return m


func _shader(see_through: bool) -> Shader:
	if not _shaders.has(see_through):
		var shader := Shader.new()
		shader.code = SHADER.replace(" BLEND", ", blend_mix, depth_draw_opaque" if see_through else "") \
				.replace("ALPHA_LINE", "ALPHA = c.a;" if see_through else "") 				.replace("cull_disabled", "cull_back" if see_through else "cull_disabled")
		_shaders[see_through] = shader
	return _shaders[see_through]


func _light(light: Light3D) -> void:
	var entry: Array = LIGHTS.get(String(light.name), [])
	if entry.is_empty():
		light.visible = false
		return
	light.light_energy = 1.0
	light.light_color = LIGHT
	light.shadow_enabled = entry[1]
	light.shadow_bias = SHADOW_BIAS
	light.shadow_normal_bias = SHADOW_NORMAL_BIAS
	if light is SpotLight3D:
		(light as SpotLight3D).spot_range = entry[0]
		if entry.size() > 2:
			(light as SpotLight3D).spot_angle = entry[2]
		(light as SpotLight3D).spot_attenuation = 0.0
		(light as SpotLight3D).spot_angle_attenuation = CONE_SOFT
	elif light is OmniLight3D:
		(light as OmniLight3D).omni_range = entry[0]
		(light as OmniLight3D).omni_attenuation = 0.0
