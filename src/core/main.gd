# Port of jackal.Main.
#
# Timing note. The original runs game logic on a fixed 100 Hz accumulator while
# rendering once per vsync, and several counters (the fade ramp, song chaining,
# the jeep rumble, the invincibility flash, mine and star animation) advance
# from render() rather than update(). To keep those identical, logic runs in
# _physics_process at 100 Hz and the frame rate is capped at 60 in the project
# settings, so _process/_draw fire at the same cadence the original assumed.
class_name Main
extends Node2D

const DISPLAY_WIDTH := 1024
const DISPLAY_HEIGHT := 960

const FONT_WHITE := 0
const FONT_GRAY := 1
const FONT_ORANGE := 2
const FONT_ORANGE_GRAY := 3

const ISQRT2 := 0.7071067811865476
const I_QUARTER_WIDTH := 4.0 / DISPLAY_WIDTH
const I_WIDTH := 1.0 / DISPLAY_WIDTH
const MINIMUM_SOUND_TIME := 125  # milliseconds

const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ.,'-0123456789©!:()&`\" "

const TILES: Array[int] = [218, 235, 273, 233, 328, 330]

const FADE_COUNT := 23

static var main: Main
static var game_mode = null  # GameMode

static var FADES: Array[Color] = []

var random := RandomNumberGenerator.new()
var button_mapping := ButtonMapping.new()
var mode = null                    # IMode
var input: HumanInput
var current_song: Song
var requested_song: Song
var load_index: int

var fade_listener = null           # IFadeListener
var fading: bool
var fade_index: int
var fade_out: bool

var extra_lives: int
var extra_lives_str: String
var score: int
var score_str: String
var stage_index: int
var has_missiles: bool
var missile_power: int
var friendly_soldiers_picked_up: int
var hard_mode: bool
var continued: bool
var close_requested: bool

var stages: Array = [null, null, null, null, null, null]  # Array[Stage]

var players: Array = []            # [4][5]
var explosions: Array[Spr] = []
var grenade: Spr
var player_missile: Spr
var yellow_bullet: Spr
var white_bullet: Spr
var bullet_hit: Spr
var gray_guns: Array[Spr] = []
var enemy_soldiers: Array = []     # [2][8]
var swamp_soldiers: Array = []     # [2][8]
var dead_enemy_soldier: Spr
var brown_tanks: Array[Spr] = []
var friendly_soldiers: Array = []  # [4][12]
var help: Spr
var green_boats: Array[Spr] = []
var stars: Array[Spr] = []
var friendly_helicopters: Array[Spr] = []
var lamps: Array[Spr] = []
var boss_blue_tanks: Array = []    # [4][5]
var fonts: Array = []              # [4][256]
var statue_blue_eyes: Spr
var statue_blue_mouth: Spr
var statue_white_eyes: Spr
var statue_white_mouth: Spr
var statue_missiles: Array[Spr] = []
var airplanes: Array = []          # [2][2]
var bomb: Spr
var gray_jeeps: Array[Spr] = []
var gray_tanks: Array[Spr] = []
var cannonball: Spr
var columns: Array[Spr] = []
var parked_gray_jeep: Spr
var gray_boats: Array[Spr] = []
var submarines: Array[Spr] = []
var lasers: Array[Spr] = []
var troops_truck: Spr
var floor_guns: Array[Spr] = []
var ship_guns: Array[Spr] = []
var plain_floor_guns: Array[Spr] = []
var player_wakes: Array[Spr] = []
var swamp_missiles: Array[Spr] = []
var mines: Array[Spr] = []
var rock: Spr
var cannon_truck: Array = []       # [2][2]
var cliff_missile_launcher: Spr
var trains: Array[Spr] = []
var boss_helicopters: Array[Spr] = []
var parachutes: Array[Spr] = []
var tank_shack: Spr
var cliff_guns: Array[Spr] = []
var fires: Array = []              # [2][3]
var fire_tanks: Array[Spr] = []
var garages: Array[Spr] = []
var sparks: Array = []             # [2][7]
var conveyors: Array[Spr] = []
var green_guns: Array[Spr] = []
var brown_guns: Array[Spr] = []
var parked_brown_tank: Spr
var floor_missile_launcher: Array[Spr] = []
var enemy_helicopters: Array[Spr] = []
var headquarters_lights: Array[Spr] = []
var elephant_guns: Array[Spr] = []
var super_tanks: Array = []        # [4][5]
var super_fires: Array = []        # [2][3]
var super_guns: Array[Spr] = []
var chinooks: Array[Spr] = []
var heres: Array[Spr] = []
var smoke: Spr
var black_plane: Spr
var gun_fires: Array[Spr] = []
var jeep_yeah_bullet: Spr
var yeahs: Array[Spr] = []
var suns: Array[Spr] = []
var waves: Array[Spr] = []
var rescue_helicopters: Array[Spr] = []
var controllers: Array[Spr] = []

var jeep_here: LargeImage
var title: LargeImage
var map: LargeImage
var soldiers: Array = [null, null, null, null]  # Array[LargeImage]
var sunset: ExtraLargeImage
var jeep_yeah: ExtraLargeImage

var boss_intro: AudioStreamPlayer
var boss_repeat: AudioStreamPlayer
var super_tank_intro: AudioStreamPlayer
var stage0_intro: AudioStreamPlayer
var stage0_repeat: AudioStreamPlayer
var start: AudioStreamPlayer

var boss_song: Song
var continue_song: Song
var cutscene_song: Song
var ending_song: Song
var intro_song: Song
var stage_song0: Song
var stage_song1: Song
var stage_song2: Song
var super_tank_song: Song
var title_song: Song

var bullet_hit_sound: Sfx
var enemy_hit_sound: Sfx
var explode_sound: Sfx
var explode_sound2: Sfx
var explode_sound3: Sfx
var extra_life_sound: Sfx
var fire_sound: Sfx
var helicopter_sound: Sfx
var helicopter_sound2: Sfx
var helicopter_pickup_sound: Sfx
var headquarters_explodes_sound: Sfx
var hut_sound: Sfx
var intro_ching_sound: Sfx
var intro_type_sound: Sfx
var laser_sound: Sfx
var machine_gun_sound: Sfx
var missile_sound: Sfx
var pause_sound: Sfx
var pickup_sound: Sfx
var player_explode_sound: Sfx
var plane_sound: Sfx
var soldier_killed_sound: Sfx
var throw_sound: Sfx
var weapon_upgrade_sound: Sfx
var well_done_sound: Sfx

var trigger_sizes: Array = []      # Array of [width, height]
var unit_vector := PackedFloat32Array([0.0, 0.0, 0.0])
var _last_play_time: Dictionary = {}
var konami_code: KonamiCode

var music_on := true

# --- Slick/OpenGL matrix-stack emulation -------------------------------------

var _xf: Transform2D = Transform2D.IDENTITY
var _xf_stack: Array[Transform2D] = []
var _clip_rect: Rect2 = Rect2()
var _clipping: bool = false


static func _static_init() -> void:
	FADES.resize(FADE_COUNT)
	for i in FADE_COUNT:
		FADES[i] = Color(0, 0, 0, float(i) / float(FADE_COUNT - 1))


func _ready() -> void:
	Main.main = self
	random.randomize()

	button_mapping.load_saved()
	input = HumanInput.new(button_mapping)

	load_progress_bar()
	load_font()

	konami_code = KonamiCode.new(self)
	start_player()
	request_mode(Modes.LOADING)


# One logic tick, matching the original's 100 Hz accumulator.
func _physics_process(_delta: float) -> void:
	if mode == null:
		return
	full_screen_toggle_check()
	input.snap()
	mode.update()


# Once-per-frame work, matching the original's update(GameContainer, int).
func _process(_delta: float) -> void:
	if fading:
		if fade_out:
			fade_index += 1
			if fade_index == FADE_COUNT:
				fade_index = FADE_COUNT - 1
				fading = false
				if fade_listener != null:
					fade_listener.fade_completed()
		else:
			fade_index -= 1
			if fade_index == -1:
				fade_index = 0
				fading = false
				if fade_listener != null:
					fade_listener.fade_completed()

	if current_song != requested_song:
		if current_song != null:
			current_song.stop()
		current_song = requested_song
		if current_song != null:
			current_song.play()
	if current_song != null:
		current_song.update()

	queue_redraw()


func _draw() -> void:
	_xf = Transform2D.IDENTITY
	_xf_stack.clear()
	_clipping = false
	draw_set_transform_matrix(_xf)

	if mode != null:
		mode.render()

	if fading:
		draw_rect(Rect2(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT), FADES[fade_index], true)


# InputMode needs raw key/pad events for its remapping screen.
func _input(event: InputEvent) -> void:
	if mode != null and mode.has_method("input_event"):
		mode.input_event(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		close_requested = true
		stop_all_sound()


# --- Progression -------------------------------------------------------------

func advance_player_to_hard_mode() -> void:
	hard_mode = true
	friendly_soldiers_picked_up = 0
	FriendlySoldier.reset_count()
	continued = true
	stage_index = 0


func continue_player() -> void:
	if konami_code != null and konami_code.enabled:
		extra_lives = 30
		extra_lives_str = "30"
	else:
		extra_lives = 4
		extra_lives_str = "4"

	has_missiles = false
	missile_power = 0

	score = 0
	score_str = "000000"

	friendly_soldiers_picked_up = 0
	FriendlySoldier.reset_count()

	continued = true


func start_player() -> void:
	continue_player()
	continued = false
	stage_index = 0


func upgrade_weapon(always_play_sound: bool) -> bool:
	var sound_played := false
	if always_play_sound:
		play_sound(weapon_upgrade_sound)
		sound_played = true
	if konami_code.enabled:
		if not (has_missiles and missile_power == 2):
			has_missiles = true
			missile_power = 2
			if not always_play_sound:
				play_sound(weapon_upgrade_sound)
				sound_played = true
	elif has_missiles:
		if missile_power < 2:
			missile_power += 1
			if not always_play_sound:
				play_sound(weapon_upgrade_sound)
				sound_played = true
	else:
		has_missiles = true
		if not always_play_sound:
			play_sound(weapon_upgrade_sound)
			sound_played = true
	return sound_played


func advance_stage_index() -> void:
	stage_index += 1


func add_points(points: int) -> void:
	var before := score
	score += points
	if (before < 20000 and score >= 20000) \
			or ((before - 20000) / 50000 != (score - 20000) / 50000):
		gain_extra_life()
	score_str = "%06d" % score


func lose_life() -> void:
	extra_lives -= 1
	extra_lives_str = str(extra_lives)


func gain_extra_life() -> void:
	extra_lives += 1
	extra_lives_str = str(extra_lives)
	play_sound_always(extra_life_sound)


func friendly_soldier_picked_up() -> bool:
	add_points(500)
	friendly_soldiers_picked_up += 1
	if friendly_soldiers_picked_up == 3 or friendly_soldiers_picked_up == 8 \
			or friendly_soldiers_picked_up == 13 or friendly_soldiers_picked_up == 18:
		return upgrade_weapon(false)
	return false


# --- Modes -------------------------------------------------------------------

func request_mode(m: int) -> void:
	match m:
		Modes.GAME:
			var gm := GameMode.new()
			Main.game_mode = gm
			gm.set_stage(stage_index, stages[stage_index], hard_mode)
			set_mode(gm)
		Modes.INTRO:
			set_mode(IntroMode.new())
		Modes.HERE:
			set_mode(JeepHereMode.new())
		Modes.YEAH:
			set_mode(JeepYeahMode.new(true))
		Modes.WE_MADE_IT:
			set_mode(JeepYeahMode.new(false))
		Modes.SUNSET:
			set_mode(SunsetMode.new())
		Modes.HARD_ENDING:
			set_mode(HardEndingMode.new())
		Modes.MAP:
			set_mode(MapMode.new())
		Modes.CONTINUE:
			set_mode(ContinueMode.new())
		Modes.DIFFICULTY:
			set_mode(DifficultyMode.new())
		Modes.OPTIONS:
			set_mode(OptionsMode.new())
		Modes.INPUT:
			set_mode(InputMode.new())
		Modes.INTRO_MAP:
			set_mode(IntroMapMode.new())
		Modes.LOADING:
			set_mode(LoadingMode.new())


func set_mode(m) -> void:
	input.clear_key_pressed_record()
	mode = m
	m.init(self)
	m.update()


func start_fade(p_fade_out: bool, p_fade_listener) -> void:
	fading = true
	fade_out = p_fade_out
	fade_listener = p_fade_listener
	fade_index = 0 if p_fade_out else FADE_COUNT - 1


func remove_fade_listener() -> void:
	fade_listener = null


func full_screen_toggle_check() -> void:
	var is_escape := input.is_escape()
	if not (input.is_f12() or is_escape):
		return
	var win := get_window()
	var fullscreen := win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN \
		or win.mode == Window.MODE_FULLSCREEN
	if fullscreen:
		win.mode = Window.MODE_WINDOWED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif not is_escape:
		win.mode = Window.MODE_FULLSCREEN
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


# --- Vector helpers ----------------------------------------------------------

static func rotate_point(x: float, y: float, angle: float) -> Vector2:
	var c := cos(angle)
	var s := sin(angle)
	return Vector2(x * c - y * s, x * s + y * c)


func create_unit_vector2(angle: float) -> PackedFloat32Array:
	unit_vector[0] = cos(angle)
	unit_vector[1] = sin(angle)
	return unit_vector


func create_unit_vector(angle: int) -> PackedFloat32Array:
	match angle:
		0, 360:
			unit_vector[0] = 1
			unit_vector[1] = 0
		45, 405:
			unit_vector[0] = ISQRT2
			unit_vector[1] = ISQRT2
		90:
			unit_vector[0] = 0
			unit_vector[1] = 1
		135:
			unit_vector[0] = -ISQRT2
			unit_vector[1] = ISQRT2
		180:
			unit_vector[0] = -1
			unit_vector[1] = 0
		225:
			unit_vector[0] = -ISQRT2
			unit_vector[1] = -ISQRT2
		270:
			unit_vector[0] = 0
			unit_vector[1] = -1
		315, -45:
			unit_vector[0] = ISQRT2
			unit_vector[1] = -ISQRT2
	return unit_vector


# Continuous-angle version, for mouse aiming. A multiple of 45 still goes
# through the table above, so keyboard and pad aiming stay bit-identical to the
# original — cos(deg_to_rad(90)) is 6e-17, not 0.
func create_unit_vector_deg(angle: float) -> PackedFloat32Array:
	if fmod(angle, 45.0) == 0.0:
		return create_unit_vector(int(fposmod(angle, 360.0)))
	return create_unit_vector2(deg_to_rad(angle))


# --- Drawing -----------------------------------------------------------------
#
# The original pushes an OpenGL matrix around every rotated/scaled sprite and
# draws the image with its top-left at the (possibly negative) offset given.
# _push/pop_graphics reproduce that matrix stack on top of CanvasItem.

func _push(t: Transform2D) -> void:
	_xf_stack.push_back(_xf)
	_xf = _xf * t
	draw_set_transform_matrix(_xf)


func pop_graphics() -> void:
	_xf = _xf_stack.pop_back()
	draw_set_transform_matrix(_xf)


func translate_graphics(x: float, y: float) -> void:
	_push(Transform2D(0.0, Vector2(x, y)))


func rotate_graphics(x: float, y: float, angle: float, scale: float = 1.0) -> void:
	_push(Transform2D(deg_to_rad(angle), Vector2(scale, scale), 0.0, Vector2(x, y)))


func scale_graphics(x: float, y: float, scale_x: float, scale_y: float) -> void:
	_push(Transform2D(0.0, Vector2(scale_x, scale_y), 0.0, Vector2(x, y)))


func _blit(s: Spr, x: float, y: float, alpha: float = -1.0) -> void:
	var a: float = s.alpha if alpha < 0.0 else clampf(alpha, 0.0, 1.0)
	if _clipping:
		_blit_clipped(s, x, y, a)
		return
	draw_texture_rect_region(s.tex, Rect2(x, y, s.w, s.h), s.region,
		Color(1.0, 1.0, 1.0, a))


# --- Clipping ----------------------------------------------------------------
#
# Slick's Graphics.setWorldClip() has no direct equivalent in Godot's immediate
# mode drawing, so a clipped sprite is emitted as a textured polygon: the quad
# is transformed into device space, clipped against the rectangle with
# Sutherland-Hodgman, and its UVs recovered through the inverse transform. This
# is exact for rotated and scaled sprites alike.

func set_clip(cx: float, cy: float, cw: float, ch: float) -> void:
	var p0 := _xf * Vector2(cx, cy)
	var p1 := _xf * Vector2(cx + cw, cy + ch)
	_clip_rect = Rect2(p0, p1 - p0).abs()
	_clipping = true


func clear_clip() -> void:
	_clipping = false


func _blit_clipped(s: Spr, x: float, y: float, a: float) -> void:
	var quad := PackedVector2Array([
		_xf * Vector2(x, y),
		_xf * Vector2(x + s.w, y),
		_xf * Vector2(x + s.w, y + s.h),
		_xf * Vector2(x, y + s.h),
	])
	var poly := _clip_to_rect(quad, _clip_rect)
	if poly.size() < 3:
		return

	var inv := _xf.affine_inverse()
	var tex_size := s.tex.get_size()
	var uvs := PackedVector2Array()
	for p in poly:
		var lp := inv * p
		uvs.append((s.region.position + Vector2(lp.x - x, lp.y - y)) / tex_size)

	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_polygon(poly, PackedColorArray([Color(1.0, 1.0, 1.0, a)]), uvs, s.tex)
	draw_set_transform_matrix(_xf)


static func _clip_to_rect(poly: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var out := poly
	# left, right, top, bottom
	out = _clip_half_plane(out, 0, r.position.x, true)
	out = _clip_half_plane(out, 0, r.position.x + r.size.x, false)
	out = _clip_half_plane(out, 1, r.position.y, true)
	out = _clip_half_plane(out, 1, r.position.y + r.size.y, false)
	return out


# Keeps the side of the axis-aligned line at `limit` selected by `keep_greater`.
static func _clip_half_plane(poly: PackedVector2Array, axis: int, limit: float,
		keep_greater: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	if n == 0:
		return out
	for i in n:
		var cur := poly[i]
		var prev := poly[(i + n - 1) % n]
		var cur_v := cur.x if axis == 0 else cur.y
		var prev_v := prev.x if axis == 0 else prev.y
		var cur_in := cur_v >= limit if keep_greater else cur_v <= limit
		var prev_in := prev_v >= limit if keep_greater else prev_v <= limit
		if cur_in:
			if not prev_in:
				out.append(prev.lerp(cur, (limit - prev_v) / (cur_v - prev_v)))
			out.append(cur)
		elif prev_in:
			out.append(prev.lerp(cur, (limit - prev_v) / (cur_v - prev_v)))
	return out


# Slick: Image.draw(x, y) — top-left anchored.
func draw(s: Spr, x: float, y: float, alpha: float = -1.0) -> void:
	_blit(s, x, y, alpha)


func draw_offset(s: Spr, x: float, y: float, alpha: float = -1.0) -> void:
	_blit(s, x, y, alpha)


func draw_centered(s: Spr, x: float, y: float) -> void:
	_blit(s, x - s.w * 0.5, y - s.h * 0.5)


func draw_centered_origin(s: Spr) -> void:
	_blit(s, -s.w * 0.5, -s.h * 0.5)


func draw_centered_alpha(s: Spr, x: float, y: float, alpha: float) -> void:
	_blit(s, x - s.w * 0.5, y - s.h * 0.5, alpha)


func draw_centered_scaled(s: Spr, x: float, y: float, scale: float,
		alpha: float = -1.0) -> void:
	_push(Transform2D(0.0, Vector2(scale, scale), 0.0, Vector2(x, y)))
	_blit(s, -s.w * 0.5, -s.h * 0.5, alpha)
	pop_graphics()


func draw_scaled(s: Spr, x: float, y: float, scale: float,
		alpha: float = -1.0) -> void:
	draw_centered_scaled(s, x, y, scale, alpha)


# Slick: drawRotated(image, x, y, angle) — rotate about the sprite centre.
func draw_rotated(s: Spr, x: float, y: float, angle: float,
		alpha: float = -1.0) -> void:
	_push(Transform2D(deg_to_rad(angle), Vector2(x, y)))
	_blit(s, -s.w * 0.5, -s.h * 0.5, alpha)
	pop_graphics()


func draw_rotated_alpha(s: Spr, x: float, y: float, angle: float,
		alpha: float) -> void:
	draw_rotated(s, x, y, angle, alpha)


# Slick: drawRotated(image, x, y, centers, angle) — the pivot offset comes from
# a per-sprite table rather than the sprite centre.
func draw_rotated_centers(s: Spr, x: float, y: float, centers,
		angle: float) -> void:
	_push(Transform2D(deg_to_rad(angle), Vector2(x, y)))
	_blit(s, centers[0], centers[1])
	pop_graphics()


func draw_rotated_offset(s: Spr, x: float, y: float, center_x: float,
		center_y: float, angle: float) -> void:
	_push(Transform2D(deg_to_rad(angle), Vector2(x, y)))
	_blit(s, center_x, center_y)
	pop_graphics()


func draw_rotated_offset_scaled(s: Spr, x: float, y: float, center_x: float,
		center_y: float, angle: float, scale: float, alpha: float = -1.0) -> void:
	_push(Transform2D(deg_to_rad(angle), Vector2(scale, scale), 0.0, Vector2(x, y)))
	_blit(s, center_x, center_y, alpha)
	pop_graphics()


func draw_rotated_scaled_xy(s: Spr, x: float, y: float, center_x: float,
		center_y: float, angle: float, scale_x: float, scale_y: float,
		alpha: float = -1.0) -> void:
	_push(Transform2D(deg_to_rad(angle), Vector2(scale_x, scale_y), 0.0,
		Vector2(x, y)))
	_blit(s, center_x, center_y, alpha)
	pop_graphics()


# Slick: draw(image, x, y, angle, scale) — centred, rotated and scaled.
func draw_angle_scale(s: Spr, x: float, y: float, angle: float,
		scale: float) -> void:
	_push(Transform2D(deg_to_rad(angle), Vector2(scale, scale), 0.0, Vector2(x, y)))
	_blit(s, -s.w * 0.5, -s.h * 0.5)
	pop_graphics()


# --- Text --------------------------------------------------------------------

func draw_text(text: String, x: float, y: float, color: int,
		length: int = -1) -> void:
	var font: Array = fonts[color]
	var n := text.length() if length < 0 else length
	var X := x
	for i in n:
		var s: Spr = font[text.unicode_at(i)]
		if s != null:
			_blit(s, X, y)
		X += 32.0


func draw_text_alpha(text: String, x: float, y: float, color: int,
		alpha: float) -> void:
	var font: Array = fonts[color]
	var X := x
	for i in text.length():
		var s: Spr = font[text.unicode_at(i)]
		if s != null:
			_blit(s, X, y, alpha)
		X += 32.0


func draw_number(value: int, digits: int, x: float, y: float, color: int) -> void:
	var font: Array = fonts[color]
	var X := x + float((digits - 1) << 5)
	var v := value
	for i in digits:
		_blit(font[0x30 + (v % 10)], X, y)
		X -= 32.0
		v /= 10


# --- Vehicles ----------------------------------------------------------------
#
# Vehicles ship five hand-drawn orientations 45 degrees apart; the nearest one
# is picked and the remainder of the angle is applied as a rotation.

func draw_vehicle_centers(sprites: Array, x: float, y: float, centers: Array,
		angle: float) -> void:
	var a := fposmod(angle, 360.0)
	if a >= 337.5 or a < 22.5:
		draw_rotated_centers(sprites[0], x, y, centers[0], a)
	elif a < 67.5:
		draw_rotated_centers(sprites[1], x, y, centers[1], a + 45.0)
	elif a < 112.5:
		draw_rotated_centers(sprites[2], x, y, centers[2], a + 90.0)
	elif a < 157.5:
		draw_rotated_centers(sprites[4], x, y, centers[4], a - 225.0)
	elif a < 202.5:
		draw_rotated_centers(sprites[3], x, y, centers[3], a - 180.0)
	elif a < 247.5:
		draw_rotated_centers(sprites[4], x, y, centers[4], a - 225.0)
	elif a < 292.5:
		draw_rotated_centers(sprites[2], x, y, centers[2], a + 90.0)
	else:
		draw_rotated_centers(sprites[1], x, y, centers[1], a + 45.0)


func draw_vehicle(sprites: Array, x: float, y: float, angle: float,
		alpha: float = -1.0) -> void:
	var a := fposmod(angle, 360.0)
	if a >= 337.5 or a < 22.5:
		draw_rotated(sprites[0], x, y, a, alpha)
	elif a < 67.5:
		draw_rotated(sprites[1], x, y, a + 45.0, alpha)
	elif a < 112.5:
		draw_rotated(sprites[2], x, y, a + 90.0, alpha)
	elif a < 157.5:
		draw_rotated(sprites[4], x, y, a - 225.0, alpha)
	elif a < 202.5:
		draw_rotated(sprites[3], x, y, a - 180.0, alpha)
	elif a < 247.5:
		draw_rotated(sprites[4], x, y, a - 225.0, alpha)
	elif a < 292.5:
		draw_rotated(sprites[2], x, y, a + 90.0, alpha)
	else:
		draw_rotated(sprites[1], x, y, a + 45.0, alpha)


# --- Sound -------------------------------------------------------------------

func play_hit_explode_sound() -> void:
	play_sound(enemy_hit_sound, 0.6)
	play_sound(explode_sound, 0.65)


func play_explode_sound2() -> void:
	play_sound(explode_sound2, 0.65)


func play_explode_sound3() -> void:
	play_sound(explode_sound3, 0.65)


func is_sound_playing(sound: Sfx) -> bool:
	return sound != null and sound.playing()


# Repeat plays of the same effect within MINIMUM_SOUND_TIME are dropped, which
# is what keeps rapid-fire hits from stacking into noise.
func play_sound(sound: Sfx, volume: float = 1.0) -> void:
	if close_requested or sound == null:
		return
	var now := Time.get_ticks_msec()
	var last = _last_play_time.get(sound)
	if last == null or now - int(last) > MINIMUM_SOUND_TIME:
		sound.play(volume)
		_last_play_time[sound] = now


func play_sound_always(sound: Sfx) -> void:
	if close_requested or sound == null:
		return
	sound.play()


func play_sound_if_not_playing(sound: Sfx, volume: float = 1.0) -> void:
	if close_requested or sound == null:
		return
	if not sound.playing():
		sound.play(volume)


func stop_sound(sound: Sfx) -> void:
	if sound != null and sound.playing():
		sound.stop()


func stop_song_of(song: Song) -> void:
	if song != null:
		song.stop()


func is_song_playing() -> bool:
	return current_song != null and current_song.playing


func stop_song() -> void:
	if current_song != null:
		current_song.stop()
	requested_song = null
	current_song = null


func request_song(song: Song) -> void:
	if close_requested:
		return
	requested_song = song


func set_music_on(on: bool) -> void:
	music_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), not on)


func stop_all_sound() -> void:
	for song in [boss_song, continue_song, cutscene_song, ending_song, intro_song,
			stage_song0, stage_song1, stage_song2, super_tank_song, title_song]:
		stop_song_of(song)
	for sound in [bullet_hit_sound, enemy_hit_sound, explode_sound, explode_sound2,
			explode_sound3, extra_life_sound, fire_sound, helicopter_sound,
			helicopter_sound2, helicopter_pickup_sound, headquarters_explodes_sound,
			hut_sound, intro_ching_sound, intro_type_sound, laser_sound,
			machine_gun_sound, missile_sound, pause_sound, pickup_sound,
			player_explode_sound, plane_sound, soldier_killed_sound, throw_sound,
			weapon_upgrade_sound, well_done_sound]:
		stop_sound(sound)


# --- Asset loading -----------------------------------------------------------

const IMAGES := "res://assets/images/"
const MAPS := "res://assets/maps/"
const MUSIC := "res://assets/music/"
const SFX := "res://assets/soundeffects/"


static func _spr_array(n: int) -> Array[Spr]:
	var a: Array[Spr] = []
	a.resize(n)
	return a


static func _spr_array_2d(rows: int, cols: int) -> Array:
	var a: Array = []
	for i in rows:
		a.append(_spr_array(cols))
	return a


static func _atlas(name: String) -> Atlas:
	return Atlas.new(IMAGES + name + ".png", IMAGES + name + ".xml")


static func _character_name(c: int) -> String:
	match c:
		0x2E: return "period"
		0x2C: return "comma"
		0x27: return "apostrophe"
		0x21: return "exclamation"
		0x2D: return "hyphen"
		0x40, 0xA9: return "copyright"
		0x20: return "space"
		0x3A: return "colon"
		0x28: return "left-paren"
		0x29: return "right-paren"
		0x26: return "ampersand"
		0x60: return "left-quote"
		0x22: return "right-quote"
		_: return String.chr(c)


func load_font() -> void:
	var pack := _atlas("font")
	fonts = []
	for i in 4:
		fonts.append(_spr_array(256))
	const COLORS := ["black", "gray", "orange", "orange-gray"]
	for i in 4:
		var font: Array = fonts[i]
		for j in CHARS.length():
			var c := CHARS.unicode_at(j)
			var s := pack.get_sprite("font-%s-%s.png" % [COLORS[i], _character_name(c)])
			font[c] = s
			font[String.chr(c).to_lower().unicode_at(0)] = s


func load_progress_bar() -> void:
	var pack9 := _atlas("sprites-9")
	controllers = _spr_array(2)
	controllers[0] = pack9.get_sprite("controller-0.png")
	controllers[1] = pack9.get_sprite("controller-1.png")


func load_tiles(index: int, stage: Stage) -> void:
	var pack := _atlas("tiles-%d" % index)
	var size: int = TILES[index]
	stage.tiles = _spr_array(size)
	for i in size:
		if i == 225:
			pack = _atlas("large-5") if index == 5 else _atlas("tiles-6")
		stage.tiles[i] = pack.get_sprite("tile-%d-%03d.png" % [index, i])
	if index == 5:
		conveyors = _spr_array(16)
		for i in 16:
			conveyors[i] = stage.tiles[i]


func load_sprites() -> void:
	var pack1 := _atlas("sprites-1")

	players = _spr_array_2d(4, 5)
	const PLAYER_COLORS := ["green", "yellow", "brown", "gray"]
	for i in 4:
		var row: Array[Spr] = players[i]
		for j in 3:
			row[j] = pack1.get_sprite("player-%s-%d.png" % [PLAYER_COLORS[i], j])
		row[3] = row[0].flipped_copy(true, false)
		row[4] = row[1].flipped_copy(true, false)

	explosions = _spr_array(4)
	for i in 4:
		explosions[i] = pack1.get_sprite("explosion-%d.png" % i)

	grenade = pack1.get_sprite("grenade-large.png")
	player_missile = pack1.get_sprite("player-missile-1.png")
	white_bullet = pack1.get_sprite("white-bullet.png")
	yellow_bullet = pack1.get_sprite("yellow-bullet.png")
	bullet_hit = pack1.get_sprite("bullet-hit.png")

	gray_guns = _spr_array(2)
	gray_guns[0] = pack1.get_sprite("gray-gun-4.png")
	gray_guns[1] = pack1.get_sprite("gray-gun-5.png")

	enemy_soldiers = _spr_array_2d(2, 8)
	for i in 2:
		var color := "brown" if i == 0 else "yellow"
		var row: Array[Spr] = enemy_soldiers[i]
		for j in 8:
			if j < 6:
				row[j] = pack1.get_sprite("enemy-soldier-%s-%d.png" % [color, j])
			else:
				row[j] = row[j - 4].flipped_copy(true, false)
	dead_enemy_soldier = pack1.get_sprite("enemy-soldier-dead.png")

	brown_tanks = _spr_array(5)
	for i in 3:
		brown_tanks[i] = pack1.get_sprite("brown-tank-%d.png" % i)
	brown_tanks[3] = brown_tanks[0].flipped_copy(true, false)
	brown_tanks[4] = brown_tanks[1].flipped_copy(true, false)

	gray_jeeps = _spr_array(5)
	for i in 3:
		gray_jeeps[i] = pack1.get_sprite("gray-jeep-%d.png" % i)
	gray_jeeps[3] = gray_jeeps[0].flipped_copy(true, false)
	gray_jeeps[4] = gray_jeeps[1].flipped_copy(true, false)

	cannonball = pack1.get_sprite("cannonball.png")
	parked_gray_jeep = pack1.get_sprite("gray-parked.png")

	mines = _spr_array(4)
	mines[0] = pack1.get_sprite("mine-green.png")
	mines[1] = pack1.get_sprite("mine-brown.png")
	mines[2] = pack1.get_sprite("mine-gray.png")
	mines[3] = pack1.get_sprite("mine-yellow.png")

	lamps = _spr_array(4)
	lamps[0] = pack1.get_sprite("lamp-blue-bright.png")
	lamps[1] = pack1.get_sprite("lamp-blue-dark.png")
	lamps[2] = pack1.get_sprite("lamp-red-bright.png")
	lamps[3] = pack1.get_sprite("lamp-red-dark.png")

	bomb = pack1.get_sprite("bomb-large.png")

	statue_blue_eyes = pack1.get_sprite("blue-eyes.png")
	statue_blue_mouth = pack1.get_sprite("blue-mouth.png")
	statue_white_eyes = pack1.get_sprite("white-eyes.png")
	statue_white_mouth = pack1.get_sprite("white-mouth.png")
	statue_missiles = _spr_array(2)
	statue_missiles[0] = pack1.get_sprite("statue-missile.png")
	statue_missiles[1] = statue_missiles[0].flipped_copy(true, false)

	lasers = _spr_array(6)
	lasers[0] = pack1.get_sprite("laser-green.png")
	lasers[1] = pack1.get_sprite("laser-brown.png")
	lasers[2] = pack1.get_sprite("laser-gray.png")
	lasers[3] = pack1.get_sprite("laser-yellow.png")
	lasers[4] = pack1.get_sprite("laser-flash-0.png")
	lasers[5] = pack1.get_sprite("laser-flash-1.png")

	swamp_missiles = _spr_array(5)
	swamp_missiles[0] = pack1.get_sprite("swamp-missile-0.png")

	parked_brown_tank = pack1.get_sprite("brown-parked.png")

	var pack2 := _atlas("sprites-2")

	swamp_missiles[1] = pack2.get_sprite("missile-splash-0.png")
	swamp_missiles[2] = swamp_missiles[1].flipped_copy(true, false)
	swamp_missiles[3] = pack2.get_sprite("missile-splash-1.png")
	swamp_missiles[4] = pack2.get_sprite("missile-splash-2.png")

	friendly_soldiers = _spr_array_2d(4, 12)
	const FRIENDLY_COLORS := ["green", "brown", "gray", "yellow"]
	for i in 4:
		var color: String = FRIENDLY_COLORS[i]
		var row: Array[Spr] = friendly_soldiers[i]
		row[1] = pack2.get_sprite("friendly-soldier-%s-0.png" % color)
		row[0] = row[1].flipped_copy(true, false)
		row[2] = pack2.get_sprite("friendly-soldier-%s-1.png" % color)
		row[3] = pack2.get_sprite("friendly-soldier-%s-2.png" % color)
		row[4] = pack2.get_sprite("friendly-soldier-%s-3.png" % color)
		row[5] = row[4].flipped_copy(true, false)
		row[6] = row[2].flipped_copy(true, false)
		row[7] = row[3].flipped_copy(true, false)
		row[8] = pack2.get_sprite("friendly-soldier-%s-4.png" % color)
		row[9] = pack2.get_sprite("friendly-soldier-%s-5.png" % color)
		row[10] = row[8].flipped_copy(true, false)
		row[11] = row[9].flipped_copy(true, false)

	help = pack2.get_sprite("help.png")

	green_boats = _spr_array(2)
	green_boats[0] = pack2.get_sprite("green-boat-0.png")
	green_boats[1] = pack2.get_sprite("green-boat-1.png")

	stars = _spr_array(4)
	stars[0] = pack2.get_sprite("star-brown.png")
	stars[1] = pack2.get_sprite("star-gray.png")
	stars[2] = pack2.get_sprite("star-green.png")
	stars[3] = pack2.get_sprite("star-yellow.png")

	friendly_helicopters = _spr_array(4)
	friendly_helicopters[0] = pack2.get_sprite("friendly-helicopter-large.png")
	friendly_helicopters[1] = pack2.get_sprite("friendly-helicopter-shadow.png")
	friendly_helicopters[2] = pack2.get_sprite("friendly-helicopter-wing-15.png")
	friendly_helicopters[3] = pack2.get_sprite("friendly-helicopter-wing-30.png")

	airplanes = _spr_array_2d(2, 2)
	airplanes[0][0] = pack2.get_sprite("airplane.png")
	airplanes[0][1] = pack2.get_sprite("airplane-shadow.png")
	airplanes[1][0] = airplanes[0][0].flipped_copy(false, true)
	airplanes[1][1] = airplanes[0][1].flipped_copy(false, true)

	columns = _spr_array(2)
	columns[0] = pack2.get_sprite("column-0.png").flipped_copy(true, false)
	columns[1] = pack2.get_sprite("column-0.png").flipped_copy(false, true)

	gray_boats = _spr_array(3)
	gray_boats[0] = pack2.get_sprite("gray-boat-0.png")
	gray_boats[1] = pack2.get_sprite("gray-boat-1.png")
	gray_boats[2] = pack2.get_sprite("gray-boat-2.png")

	player_wakes = _spr_array(6)
	player_wakes[0] = pack2.get_sprite("player-wake-0.png")
	player_wakes[1] = player_wakes[0].flipped_copy(true, false)
	player_wakes[2] = pack2.get_sprite("player-wake-2.png")
	player_wakes[3] = player_wakes[2].flipped_copy(false, true)
	player_wakes[4] = pack2.get_sprite("player-wake-1.png")
	player_wakes[5] = player_wakes[4].flipped_copy(true, false)

	rock = pack2.get_sprite("rock-large.png")

	swamp_soldiers = _spr_array_2d(2, 8)
	for i in 2:
		var color := "brown" if i == 0 else "yellow"
		var row: Array[Spr] = swamp_soldiers[i]
		for j in 8:
			if j < 6:
				row[j] = pack2.get_sprite("swamp-soldier-%s-%d.png" % [color, j])
			else:
				row[j] = row[j - 4].flipped_copy(true, false)

	cliff_missile_launcher = pack2.get_sprite("missile-launcher.png")

	var pack3 := _atlas("sprites-3")

	boss_blue_tanks = _spr_array_2d(4, 5)
	for j in 2:
		var color := "blue" if j == 0 else "brown"
		var k := j << 1
		var row: Array[Spr] = boss_blue_tanks[k]
		for i in 3:
			row[i] = pack3.get_sprite("boss-%s-tank-%d.png" % [color, i << 1])
		row[3] = row[0].flipped_copy(true, false)
		row[4] = row[1].flipped_copy(true, false)

		k += 1
		row = boss_blue_tanks[k]
		for i in 3:
			row[i] = pack3.get_sprite("boss-%s-tank-%d.png" % [color, (i << 1) + 1])
		row[3] = row[0].flipped_copy(true, false)
		row[4] = row[1].flipped_copy(true, false)

	gray_tanks = _spr_array(5)
	for i in 3:
		gray_tanks[i] = pack3.get_sprite("gray-tank-%d.png" % i)
	gray_tanks[3] = gray_tanks[0].flipped_copy(true, false)
	gray_tanks[4] = gray_tanks[1].flipped_copy(true, false)

	troops_truck = pack3.get_sprite("troops-truck.png")

	cannon_truck = _spr_array_2d(2, 2)
	cannon_truck[0][0] = pack3.get_sprite("cannon-truck-0.png")
	cannon_truck[0][1] = pack3.get_sprite("cannon-truck-1.png")
	cannon_truck[1][0] = cannon_truck[0][0].flipped_copy(true, false)
	cannon_truck[1][1] = cannon_truck[0][1].flipped_copy(true, false)

	tank_shack = pack3.get_sprite("gray-tank-shack.png")

	sparks = _spr_array_2d(2, 7)
	for i in 7:
		sparks[0][i] = pack3.get_sprite("spark-%d.png" % i)
		sparks[1][i] = sparks[0][i].flipped_copy(true, false)

	green_guns = _spr_array(2)
	green_guns[0] = pack3.get_sprite("green-gun-4.png")
	green_guns[1] = pack3.get_sprite("green-gun-5.png")
	brown_guns = _spr_array(2)
	brown_guns[0] = pack3.get_sprite("brown-gun-4.png")
	brown_guns[1] = pack3.get_sprite("brown-gun-5.png")

	var pack4 := _atlas("sprites-4")

	submarines = _spr_array(4)
	for i in 4:
		submarines[i] = pack4.get_sprite("submarine-%d.png" % i)

	floor_guns = _spr_array(8)
	floor_guns[0] = pack4.get_sprite("floor-gun-gray.png")
	floor_guns[1] = pack4.get_sprite("floor-gun-yellow.png")
	floor_guns[2] = pack4.get_sprite("floor-gun-brown.png")
	floor_guns[3] = pack4.get_sprite("floor-gun-green.png")
	floor_guns[4] = pack4.get_sprite("floor-gun-background-black.png")
	floor_guns[5] = pack4.get_sprite("floor-gun-background-red.png")
	floor_guns[6] = pack4.get_sprite("floor-gun-stripes-mask.png")
	floor_guns[7] = pack4.get_sprite("floor-gun-striped-panel.png")

	ship_guns = _spr_array(3)
	ship_guns[0] = pack4.get_sprite("ship-gun-mask.png")
	ship_guns[1] = pack4.get_sprite("ship-gun-upper-panel.png")
	ship_guns[2] = pack4.get_sprite("ship-gun-lower-panel.png")

	plain_floor_guns = _spr_array(2)
	plain_floor_guns[0] = pack4.get_sprite("floor-gun-plain-mask.png")
	plain_floor_guns[1] = pack4.get_sprite("floor-gun-plain-panel.png")

	trains = _spr_array(3)
	trains[0] = pack4.get_sprite("train-0.png")
	trains[1] = pack4.get_sprite("train-1.png")
	trains[2] = pack4.get_sprite("tunnel.png")

	boss_helicopters = _spr_array(6)
	boss_helicopters[0] = pack4.get_sprite("boss-helicopter-0.png")
	boss_helicopters[1] = boss_helicopters[0].flipped_copy(true, false)
	boss_helicopters[2] = pack4.get_sprite("boss-helicopter-blade.png")
	boss_helicopters[3] = pack4.get_sprite("boss-helicopter-tail-0.png")
	boss_helicopters[4] = pack4.get_sprite("boss-helicopter-tail-1.png")
	boss_helicopters[5] = pack4.get_sprite("boss-helicopter-shadow.png")

	parachutes = _spr_array(5)
	for i in 5:
		parachutes[i] = pack4.get_sprite("parachute-%d.png" % i)

	cliff_guns = _spr_array(5)
	for i in 5:
		cliff_guns[i] = pack4.get_sprite("cliff-gun-%d.png" % i)

	fires = _spr_array_2d(2, 3)
	for i in 3:
		fires[0][i] = pack4.get_sprite("fire-%d.png" % i)
		if i == 2:
			fires[1][i] = fires[0][i].flipped_copy(true, false)
		else:
			fires[1][i] = fires[0][i].flipped_copy(true, true)

	fire_tanks = _spr_array(5)
	for i in 3:
		fire_tanks[i] = pack4.get_sprite("fire-tank-%d.png" % i)
	fire_tanks[3] = fire_tanks[0].flipped_copy(true, false)
	fire_tanks[4] = fire_tanks[1].flipped_copy(true, false)

	garages = _spr_array(5)
	for i in 5:
		garages[i] = pack4.get_sprite("door-%d.png" % i)

	var pack5 := _atlas("sprites-5")

	floor_missile_launcher = _spr_array(4)
	for i in 4:
		floor_missile_launcher[i] = pack5.get_sprite("missile-launcher-floor-%d.png" % i)

	enemy_helicopters = _spr_array(3)
	enemy_helicopters[0] = pack5.get_sprite("enemy-helicopter-body.png")
	enemy_helicopters[1] = pack5.get_sprite("enemy-helicopter-blade.png")
	enemy_helicopters[2] = pack5.get_sprite("enemy-helicopter-shadow.png")

	headquarters_lights = _spr_array(2)
	headquarters_lights[0] = pack5.get_sprite("headquarters-light-yellow.png")
	headquarters_lights[1] = pack5.get_sprite("headquarters-light-brown.png")

	elephant_guns = _spr_array(9)
	elephant_guns[1] = pack5.get_sprite("elephant-gun-0.png")
	elephant_guns[2] = pack5.get_sprite("elephant-gun-1.png")
	elephant_guns[0] = elephant_guns[2].flipped_copy(true, false)
	elephant_guns[3] = pack5.get_sprite("elephant-gun-5.png")
	elephant_guns[4] = pack5.get_sprite("elephant-gun-2.png")
	elephant_guns[5] = pack5.get_sprite("elephant-gun-3.png")
	elephant_guns[6] = pack5.get_sprite("elephant-gun-4.png")
	elephant_guns[7] = elephant_guns[6].flipped_copy(true, false)
	elephant_guns[8] = pack5.get_sprite("elephant-missile.png")

	super_tanks = _spr_array_2d(4, 5)
	super_tanks[0][0] = pack5.get_sprite("super-tank-tread-yellow.png")
	super_tanks[0][1] = pack5.get_sprite("super-tank-wheel-yellow.png")
	super_tanks[0][2] = pack5.get_sprite("super-tank-top-yellow.png")
	super_tanks[0][3] = pack5.get_sprite("super-tank-middle-yellow.png")
	super_tanks[0][4] = pack5.get_sprite("super-tank-bottom-yellow.png")

	super_fires = _spr_array_2d(2, 3)
	super_fires[0][0] = pack5.get_sprite("super-fire-0.png")
	super_fires[0][1] = pack5.get_sprite("super-fire-1.png")
	super_fires[0][2] = super_fires[0][0].flipped_copy(false, true)
	super_fires[1][0] = pack5.get_sprite("super-fire-2.png")
	super_fires[1][1] = pack5.get_sprite("super-fire-3.png")
	super_fires[1][2] = super_fires[0][0].flipped_copy(false, true)

	super_guns = _spr_array(2)
	super_guns[0] = pack5.get_sprite("super-tank-gun-green-0.png")
	super_guns[1] = pack5.get_sprite("super-tank-gun-brown-0.png")

	var pack6 := _atlas("sprites-6")

	super_tanks[1][0] = pack6.get_sprite("super-tank-tread-orange.png")
	super_tanks[1][1] = pack6.get_sprite("super-tank-wheel-orange.png")
	super_tanks[1][2] = pack6.get_sprite("super-tank-top-orange.png")
	super_tanks[1][3] = pack6.get_sprite("super-tank-middle-orange.png")
	super_tanks[1][4] = pack6.get_sprite("super-tank-bottom-orange.png")

	super_tanks[2][0] = pack6.get_sprite("super-tank-tread-red.png")
	super_tanks[2][1] = pack6.get_sprite("super-tank-wheel-red.png")
	super_tanks[2][2] = pack6.get_sprite("super-tank-top-red.png")
	super_tanks[2][3] = pack6.get_sprite("super-tank-middle-red.png")
	super_tanks[2][4] = pack6.get_sprite("super-tank-bottom-red.png")

	var pack7 := _atlas("sprites-7")

	super_tanks[3][0] = super_tanks[2][0]
	super_tanks[3][1] = super_tanks[2][1]
	super_tanks[3][2] = pack7.get_sprite("super-tank-top-smashed.png")
	super_tanks[3][3] = pack7.get_sprite("super-tank-middle-smashed.png")
	super_tanks[3][4] = pack7.get_sprite("super-tank-bottom-smashed.png")

	chinooks = _spr_array(4)
	chinooks[0] = pack7.get_sprite("chinook-body.png")
	chinooks[1] = chinooks[0].flipped_copy(false, true)
	chinooks[2] = pack7.get_sprite("chinook-blade.png")
	chinooks[3] = pack7.get_sprite("chinook-shadow.png")

	heres = _spr_array(2)
	heres[0] = pack7.get_sprite("here-0.png")
	heres[1] = pack7.get_sprite("here-1.png")
	smoke = pack7.get_sprite("smoke.png")
	black_plane = pack7.get_sprite("jeep-yeah-plane.png")
	gun_fires = _spr_array(2)
	gun_fires[0] = pack7.get_sprite("jeep-yeah-fire-0.png")
	gun_fires[1] = pack7.get_sprite("jeep-yeah-fire-1.png")
	jeep_yeah_bullet = pack7.get_sprite("jeep-yeah-bullet.png")
	yeahs = _spr_array(4)
	for i in 4:
		yeahs[i] = pack7.get_sprite("yeah-%d.png" % i)

	var pack8 := _atlas("sprites-8")

	# The sun and the wave band are sliced into scanlines so that later modes
	# can shift each row independently.
	var sun := pack8.get_sprite("sun.png")
	suns = _spr_array(int(sun.h))
	for i in range(suns.size() - 1, -1, -1):
		suns[i] = sun.sub_image(0, i, int(sun.w), 1)

	var wave := pack8.get_sprite("waves-0.png")
	waves = _spr_array(int(wave.h))
	for i in range(waves.size() - 1, -1, -1):
		waves[i] = wave.sub_image(0, i, int(wave.w), 1)

	rescue_helicopters = _spr_array(3)
	rescue_helicopters[0] = pack8.get_sprite("rescue-helicopter-body-0.png")
	rescue_helicopters[1] = pack8.get_sprite("rescue-helicopter-body-1.png")
	rescue_helicopters[2] = pack8.get_sprite("rescue-helicopter-blade.png")


func load_large_images() -> void:
	sunset = load_extra_large_image("sunset", ["large-0", "large-1"])
	map = load_large_image("map", "large-1")
	jeep_yeah = load_extra_large_image("jeep-yeah", ["large-2", "large-3"])
	soldiers[0] = load_large_image("soldier-0", "large-3")
	soldiers[1] = load_large_image("soldier-1", "large-3")
	soldiers[2] = load_large_image("soldier-2", "large-3")
	soldiers[3] = load_large_image("soldier-3", "large-3")
	jeep_here = load_large_image("jeep-here", "large-4")
	title = load_large_image("title", "large-5")


func load_large_image(name: String, pack_name: String) -> LargeImage:
	var f := _open(IMAGES + name + ".dat")
	var width := _s16(f)
	var height := _s16(f)
	var tile_count := _s16(f)
	var m: Array = []
	for y in height:
		var row := PackedInt32Array()
		row.resize(width)
		for x in width:
			row[x] = _s16(f)
		m.append(row)
	f.close()

	var pack := _atlas(pack_name)
	var tiles := _spr_array(tile_count)
	for i in tile_count:
		tiles[i] = pack.get_sprite("%s-%03d.png" % [name, i])

	return LargeImage.new(tiles, m, width, height)


func load_extra_large_image(name: String, pack_names: Array) -> ExtraLargeImage:
	var packs: Array[Atlas] = []
	for p in pack_names:
		packs.append(_atlas(p))

	var f := _open(IMAGES + name + ".dat")
	var width := _s16(f)
	var height := _s16(f)
	var tile_count := _s16(f)
	var m: Array = []
	m.resize(width * height)
	for y in height:
		var Y := width * y
		var y2 := y << 5
		for x in width:
			m[Y + x] = [_s16(f), x << 5, y2]
	f.close()

	# Sorting by tile index keeps identical source tiles adjacent in the draw
	# order, exactly as the original does.
	m.sort_custom(func(a, b): return a[0] < b[0])

	var tiles := _spr_array(tile_count)
	for i in tile_count:
		var j := 0
		while true:
			tiles[i] = packs[j].get_sprite("%s-%03d.png" % [name, i])
			if tiles[i] == null:
				j += 1
			else:
				break

	return ExtraLargeImage.new(tiles, m)


# --- Binary data -------------------------------------------------------------
#
# Every .dat file is a big-endian java.io.DataInputStream dump.

static func _open(path: String) -> FileAccess:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return null
	f.big_endian = true
	return f


static func _s16(f: FileAccess) -> int:
	var v := f.get_16()
	return v - 65536 if v >= 32768 else v


static func _s32(f: FileAccess) -> int:
	var v := f.get_32()
	return v - 4294967296 if v >= 2147483648 else v


func load_sizes() -> void:
	var f := _open(MAPS + "sizes.dat")
	var count := _s16(f)
	trigger_sizes = []
	for i in count:
		var width := _s16(f)
		var height := _s16(f)
		# Boss triggers fire four rows earlier so the camera pan can start.
		if i == Triggers.BOSS_BLUE_TANKS or i == Triggers.BOSS_GARAGE \
				or i == Triggers.BOSS_HEADQUARTERS or i == Triggers.BOSS_HELICOPTER \
				or i == Triggers.BOSS_SHIP or i == Triggers.BOSS_STATUES:
			height -= 4
		trigger_sizes.append([width, height])
	f.close()


func load_maps(index: int, stage: Stage) -> void:
	var f := _open(MAPS + "map-%d.dat" % index)
	stage.map_width = _s16(f)
	stage.map_height = _s16(f)

	stage.tile_map = []
	stage.groups_map = []
	for y in stage.map_height + 1:
		var row := PackedInt32Array()
		row.resize(stage.map_width)
		stage.tile_map.append(row)
		var grow := PackedByteArray()
		grow.resize(stage.map_width)
		stage.groups_map.append(grow)

	for y in stage.map_height:
		var row: PackedInt32Array = stage.tile_map[y]
		for x in stage.map_width:
			row[x] = _s16(f)

	var group_count := _s16(f)
	stage.groups = []
	for i in group_count:
		var group_size := _s16(f)
		var group: Array = []
		for j in group_size:
			var gx := _s16(f)
			var gy := _s16(f)
			var tile := _s16(f)
			group.append([gx, gy, tile, 0])
			stage.groups_map[gy][gx] = i
		stage.groups.append(group)
	f.close()


func load_types(index: int, stage: Stage) -> void:
	var f := _open(MAPS + "types-%d.dat" % index)
	stage.map_width = _s16(f)
	stage.map_height = _s16(f)

	stage.types_map = []
	for y in stage.map_height + 1:
		var row := PackedInt32Array()
		row.resize(stage.map_width)
		stage.types_map.append(row)

	for y in stage.map_height:
		var row: PackedInt32Array = stage.types_map[y]
		for x in stage.map_width:
			row[x] = _s16(f)

	# The row past the bottom of the map is water, so anything that falls off
	# the end drowns instead of reading out of bounds.
	var last: PackedInt32Array = stage.types_map[stage.map_height]
	for x in stage.map_width:
		last[x] = GameMode.TYPE_WATER
	stage.map_height += 1

	var group_count := _s16(f)
	for i in group_count:
		var group_size := _s16(f)
		var group: Array = stage.groups[i]
		for j in group_size:
			_s16(f)  # x
			_s16(f)  # y
			group[j][3] = _s16(f)
	f.close()


func load_directions(index: int, stage: Stage) -> void:
	var f := _open(MAPS + "dirs-%d.dat" % index)
	var size := _s32(f)
	stage.directions_width = _s32(f)
	stage.directions_height = _s32(f)
	var dirs := PackedInt64Array()
	dirs.resize(size)
	for i in size:
		dirs[i] = f.get_64()
	stage.directions = dirs
	f.close()


func load_trigger_map(height: int, enemy_sizes: Array, index: int,
		stage: Stage, hard: bool) -> void:
	var lists: Array = []
	for i in height:
		lists.append([])

	var f := _open(MAPS + "enemies%s-%d.dat" % ["-hard" if hard else "", index])
	var count := _s16(f)
	for i in count:
		var trigger_index := _s16(f)
		var tile_x := _s16(f)
		var tile_y := _s16(f)
		var trigger_y: int = tile_y + enemy_sizes[trigger_index][1] - 1
		lists[trigger_y].append([trigger_index, tile_x << 5, tile_y << 5])
	f.close()

	stage.trigger_map[1 if hard else 0] = lists


func load_stage(index: int, stage: Stage) -> void:
	load_tiles(index, stage)
	load_maps(index, stage)
	load_types(index, stage)
	load_directions(index, stage)
	load_trigger_map(stage.map_height, trigger_sizes, index, stage, false)
	load_trigger_map(stage.map_height, trigger_sizes, index, stage, true)


func load_stages() -> void:
	for i in 6:
		stages[i] = Stage.new()
		load_stage(i, stages[i])


# --- Incremental loading -----------------------------------------------------
#
# LoadingMode calls this once per tick and draws the returned progress.

func load_next() -> float:
	match load_index:
		0:
			boss_intro = Song.make_player(self, MUSIC + "boss_intro.ogg", false)
		1:
			boss_repeat = Song.make_player(self, MUSIC + "boss_repeat.ogg", true)
		2:
			super_tank_intro = Song.make_player(self, MUSIC + "super_tank_intro.ogg", false)
		3:
			stage0_intro = Song.make_player(self, MUSIC + "stage0_intro.ogg", false)
		4:
			stage0_repeat = Song.make_player(self, MUSIC + "stage0_repeat.ogg", true)
		5:
			start = Song.make_player(self, MUSIC + "start.ogg", false)
		6:
			boss_song = Song.new(boss_intro, null, boss_repeat)
			continue_song = Song.new(
				Song.make_player(self, MUSIC + "continue.ogg", false))
		7:
			cutscene_song = Song.new(
				Song.make_player(self, MUSIC + "cutscene.ogg", false))
		8:
			ending_song = Song.new(
				Song.make_player(self, MUSIC + "ending_intro.ogg", false), null,
				Song.make_player(self, MUSIC + "ending_repeat.ogg", true))
		9:
			intro_song = Song.new(start, stage0_intro, stage0_repeat)
			stage_song0 = Song.new(stage0_intro, null, stage0_repeat)
			stage_song1 = Song.new(
				Song.make_player(self, MUSIC + "stage1_intro.ogg", false), null,
				Song.make_player(self, MUSIC + "stage1_repeat.ogg", true))
		10:
			stage_song2 = Song.new(null, null,
				Song.make_player(self, MUSIC + "stage2_repeat.ogg", true))
		11:
			super_tank_song = Song.new(super_tank_intro, null, boss_repeat)
			title_song = Song.new(Song.make_player(self, MUSIC + "title.ogg", false))
			boss_intro = null
			boss_repeat = null
			super_tank_intro = null
			stage0_intro = null
			stage0_repeat = null
			start = null
		12:
			bullet_hit_sound = Sfx.new(self, SFX + "bullet_hit.ogg")
		13:
			enemy_hit_sound = Sfx.new(self, SFX + "enemy_hit.ogg")
		14:
			explode_sound = Sfx.new(self, SFX + "explode.ogg")
		15:
			explode_sound2 = Sfx.new(self, SFX + "explode2.ogg")
		16:
			explode_sound3 = Sfx.new(self, SFX + "explode3.ogg")
		17:
			extra_life_sound = Sfx.new(self, SFX + "extra_life.ogg")
		18:
			fire_sound = Sfx.new(self, SFX + "fire.ogg")
		19:
			helicopter_sound = Sfx.new(self, SFX + "helicopter.ogg")
		20:
			helicopter_sound2 = Sfx.new(self, SFX + "helicopter2.ogg")
		21:
			helicopter_pickup_sound = Sfx.new(self, SFX + "helicopter_pickup.ogg")
		22:
			headquarters_explodes_sound = Sfx.new(self, SFX + "hq_explodes.ogg")
		23:
			hut_sound = Sfx.new(self, SFX + "hut.ogg")
		24:
			intro_ching_sound = Sfx.new(self, SFX + "intro_ching.ogg")
		25:
			intro_type_sound = Sfx.new(self, SFX + "intro_type.ogg")
		26:
			laser_sound = Sfx.new(self, SFX + "laser.ogg")
		27:
			machine_gun_sound = Sfx.new(self, SFX + "machine_gun.ogg")
		28:
			missile_sound = Sfx.new(self, SFX + "missile.ogg")
		29:
			pause_sound = Sfx.new(self, SFX + "pause.ogg")
		30:
			pickup_sound = Sfx.new(self, SFX + "pickup.ogg")
		31:
			player_explode_sound = Sfx.new(self, SFX + "player_explodes.ogg")
		32:
			soldier_killed_sound = Sfx.new(self, SFX + "soldier_killed.ogg")
		33:
			plane_sound = Sfx.new(self, SFX + "plane.ogg")
		34:
			throw_sound = Sfx.new(self, SFX + "throw.ogg")
		35:
			weapon_upgrade_sound = Sfx.new(self, SFX + "weapon_upgrade.ogg")
		36:
			well_done_sound = Sfx.new(self, SFX + "well_done.ogg")
		37:
			load_sprites()
		38:
			load_large_images()
		39:
			load_sizes()
		40:
			load_stages()
		41:
			request_mode(Modes.INTRO)

	load_index += 1
	return load_index / 42.0
