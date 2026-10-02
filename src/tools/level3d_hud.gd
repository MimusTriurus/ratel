# The 3D preview's HUD line, drawn in the preview's font (Level3DFont) and with icons
# rendered from the preview's own models (level3d_preview.gd, _show_state
# hands it the run's state, _render_icons the icons):
#
#     CHEATS: LIVES  WALLS  GUN X2
#     CLASSIC DRIVE  CURSOR FIRE
#     004500
#     [jeep] 3   [prisoner] 3   [missile]
#
#   * the score as GameMode._draw_score writes it, the number without its
#     "1P", in the font's white (the sheet calls it black: white glyphs, dark
#     shadow): which line is whose is said by its corner and by its jeep's
#     colour. Points added roll up to the new score over ROLL_TIME rather
#     than land at once, and the number shows in the player's colour while it
#     does and fades back to white over FLASH_FADE, its digits hopping up
#     HOP font pixels at the start: the score is the one thing on the line
#     that changes without the player looking at it, and a number that only
#     jumps is not seen to. A hop, not a grow, since a bigger score would
#     shove the rest of the line along, and a glyph scaled by a fraction is a
#     ragged one. A score that goes down -- a new run -- is put straight;
#   * the spare lives as the vehicle the preview drives and the count, as the
#     game's "P 4" counts them, in the player's colour (`lives_icon`). A row
#     of them, one each, was tried: it changed the line's width with every
#     life, shoving what came after it, and read differently from the
#     prisoners beside it. Dimmed with none left; with the infinite lives
#     cheat, an infinity for the count, drawn: the font has no glyph for it;
#   * the prisoners aboard as a prisoner and the count, dimmed with none
#     aboard. Dimmed is the icon faded and the 0 in the font's gray, not
#     faded: a faded white over stage 1's sand all but went. A life or a
#     prisoner gained flashes its count and hops it and its icon as points
#     do the score; one lost does not, the jeep's blast or the helicopter
#     taking him being what is watched then;
#   * the weapon as its round -- the mortar's bomb, the missile, the heavy
#     missile, the staged one -- each its own outline, so the level needs
#     nothing beside it. An upgrade -- the only way it is noticed -- hops it
#     as the counts hop and washes it in the player's colour, a silhouette
#     of it over it (TINT_SHADER) at WEAPON_TINT, fading as their tint does.
#     It used to blink for a second and a half, which read as something wrong
#     beside the counts' flash; a weapon lost is not marked, as a life is not;
#   * every icon ringed in white with a thin black line outside it, as the
#     pops over the stage are (Level3DScorePops): the vehicle and the
#     prisoner are the forest's green and went into it, and the white alone
#     went into the beach's surf. Drawn under the line (z_index), as the
#     icon's silhouette (TINT_SHADER) stamped round it, and a dimmed icon's
#     faded with it as one (a CanvasGroup), not stamp by stamp;
#   * on lines of their own, a size smaller, in the font's gray: the driving
#     and firing modes when shown, and the cheats that are on
#     (Level3DSettings.hud_cheats).
#
# At the bottom by default (Level3DSettings.hud_corner), not the game's top:
# everything new comes in at the top of the frame, and the tilted view spreads
# more of the level over a strip at the top than at the bottom, so a line there
# hides more of what is coming. The modes and cheats stack up from it.
#
# On two rows by default, the score over the rest (`two_rows`): one line
# stretched a player's corner a quarter of the way across the frame, and two
# a player read as two blocks, one each side, rather than as two rows of
# stuff meeting in the middle. Taller by a glyph, which the pad's arrow and
# the co-op frame keep clear of (line_height). One line is the setting's
# other choice.
#
# With two players each has a line of its own, the second's in the corner
# across the frame, its groups in the same order, as GameMode's score puts the
# second player's at the other side of the frame.
#
# Sizes are whole multiples of a pixel. A glyph is 32 px at 100%, as the
# game's own HUD draws it on the same 2048x1152 frame, 24 to 48 through
# Level3DSettings.hud_scale, 8 of the font's pixels either way. The icons
# (Level3DIcons) are rendered ICON_HEIGHT glyphs tall, ICON_PIXEL of the
# frame's pixels to one of theirs, and drawn at that: re-rendered when the size
# changes, so the factor holds. At 2 -- a quarter of the glyph's pixel -- they
# read coarse beside the models on the stage; at 1 they keep the hard edge and
# the line of a sprite with the detail of the model. Until they are rendered,
# the game's sprites stand in, as they did before there were icons. The
# project's canvas filter is nearest, so the pixels stay square.
class_name Level3DHud
extends Control

const GLYPH := 32.0                     # at 100%
const MARGIN := Vector2(16, 12)
const GAP := 1.0                        # between groups, in glyphs
const ICON_HEIGHT := 1.5                # glyphs: the line's height
const ICON_PIXEL := 1.0                 # frame pixels to an icon's pixel
const LIFE_SPRITE := "player-green-2.png"
const POW_SPRITE := "friendly-soldier-green-1.png"
const GRENADE_SPRITE := "grenade-large.png"
const MISSILE_SPRITE := "player-missile-1.png"
const COLOURS := [Level3DFont.WHITE, Level3DFont.GRAY]
enum { WHITE, GRAY }
# The glyphs' shadow, under the infinity: white on the font's dark, since
# stage 1's sand is the font's orange, near enough.
const SHADOW := Color(0.2, 0.2, 0.2)
const WEAPON_TINT := 0.8               # the colour's alpha over the icon, at its height
const OUTLINE := 3.0                    # the icons' white ring, frame px at 100%
const OUTLINE_LINE := 1.0               # the black line outside it
const DIM := 0.45                       # a dimmed icon's alpha
const ROW_GAP := 0.25                   # glyphs between the score's row and the rest's
# An icon as a silhouette in the colour it is drawn with, for the weapon's.
const TINT_SHADER := """
shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a); }
"""
const ROLL_TIME := 0.45
const FLASH_FADE := 0.35
const HOP := 4.0                        # font pixels, of the glyph's 32
const HOP_TIME := 0.2

# What the line shows, set whole by `show_state` and drawn by _draw.
var score := 0
var lives := 0              # spare lives; -1 for the infinite lives cheat
var pows := 0
var has_missiles := false
var missile_power := 0
var modes := ""             # "" for none
var cheats := ""            # the cheats on, "" for none or not shown
var parts := {"score": true, "lives": true, "pows": true, "weapon": true}
var bottom := false         # the bottom left corner rather than the top left
var right := false          # the right-hand corner, the second player's
# Which of the icons is this player's vehicle: the second's is blue.
var lives_icon := "lives"
# The score on a row of its own, over the rest, rather than leading the line
# (Level3DSettings.hud_two_rows).
var two_rows := true
# The player's, its vehicle's: the score flashes in it (ROLL_TIME).
var colour := Color.WHITE
var scale_factor := 1.0
# Level3DIcons.render_all's: {"lives", "pow", "weapons": [4]}, or empty.
var icons := {}

var _sprites := {}          # sprite name -> Spr, until the icons come
var _weapon_was := -1       # the weapon's level last shown, -1 before the first
var _weapon_time := INF     # seconds since an upgrade, as _roll_time
var _tint_layer: Control    # over the line, the weapon's colour wash
var _tints: Array = []      # this frame's [texture, rect, region or null, colour]
var _icon_layer: Control
var _icon_draws: Array = [] # this frame's icons, as _tints
# The icons' rings, under the line: [lit, dimmed], each a CanvasGroup with a
# Node2D in it drawing this frame's [texture, rect, region or null] of `_rings`.
var _ring_groups: Array[CanvasGroup] = []
var _rings: Array = [[], []]
var _measuring := false     # laying the line out to see how wide it is
var _shown := 0.0           # the score as it reads now, rolling up to `score`
var _roll_from := 0.0
var _rolled_to := 0         # the score the roll is to
var _roll_time := INF       # seconds since the last points came, while they show
var _lives_was := -2         # -2 before the first state, which is not a gain
var _lives_time := INF      # seconds since a life was gained, as _roll_time
var _pows_was := 0
var _pows_time := INF       # and a prisoner


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The icons, nearest however the font is drawn (Level3DFont.filter), under
	# the weapon's wash.
	_icon_layer = Control.new()
	_icon_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_layer.draw.connect(func():
		for d in _icon_draws:
			if d[2] == null:
				_icon_layer.draw_texture_rect(d[0], d[1], false, d[3])
			else:
				_icon_layer.draw_texture_rect_region(d[0], d[1], d[2], d[3]))
	add_child(_icon_layer)
	_tint_layer = Control.new()
	_tint_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tint_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = TINT_SHADER
	_tint_layer.material = ShaderMaterial.new()
	(_tint_layer.material as ShaderMaterial).shader = shader
	_tint_layer.draw.connect(_draw_tints)
	add_child(_tint_layer)
	for i in 2:
		var group := CanvasGroup.new()
		group.z_index = -1
		group.self_modulate.a = 1.0 if i == 0 else DIM
		var stamps := Node2D.new()
		stamps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stamps.material = _tint_layer.material
		stamps.draw.connect(_draw_rings.bind(stamps, i))
		group.add_child(stamps)
		add_child(group)
		_ring_groups.append(group)
	var bank := SpriteBank.new(Main.SPRITES)
	for name in [LIFE_SPRITE, POW_SPRITE, GRENADE_SPRITE, MISSILE_SPRITE]:
		_sprites[name] = bank.get_sprite(name)


# How much of the frame's edge the main line takes, margin and all: what the
# pad's arrow and the co-op frame keep clear of when it is at the bottom.
func line_height() -> float:
	var g := GLYPH * scale_factor
	return MARGIN.y + g * ICON_HEIGHT + (roundf(g * ROW_GAP) + g if two_rows else 0.0)


# The icons' height in their own pixels at the current size: ICON_HEIGHT
# glyphs, ICON_PIXEL frame pixels to each.
func icon_pixels() -> int:
	return roundi(GLYPH * scale_factor * ICON_HEIGHT / ICON_PIXEL)


func show_state() -> void:
	var new_run := score < _rolled_to
	var weapon := _weapon_level()
	if weapon > _weapon_was and _weapon_was >= 0 and not new_run:
		_weapon_time = 0.0
	_weapon_was = weapon
	if new_run:
		_shown = score
		_roll_time = INF
	elif score > _rolled_to:
		_roll_from = _shown
		_roll_time = 0.0
	_rolled_to = score
	# A new run's lives and an infinity let go of are not gains.
	if lives > _lives_was and _lives_was >= 0 and not new_run:
		_lives_time = 0.0
	_lives_was = lives
	if pows > _pows_was and not new_run:
		_pows_time = 0.0
	_pows_was = pows
	queue_redraw()


func _process(delta: float) -> void:
	if _roll_time < ROLL_TIME + FLASH_FADE:
		_roll_time += delta
		var t := clampf(_roll_time / ROLL_TIME, 0.0, 1.0)
		_shown = lerpf(_roll_from, score, 1.0 - (1.0 - t) * (1.0 - t))
		queue_redraw()
	if _lives_time < ROLL_TIME + FLASH_FADE or _pows_time < ROLL_TIME + FLASH_FADE 			or _weapon_time < ROLL_TIME + FLASH_FADE:
		_lives_time += delta
		_pows_time += delta
		_weapon_time += delta
		queue_redraw()


func _draw() -> void:
	texture_filter = Level3DFont.filter()
	_tints.clear()
	_icon_draws.clear()
	_rings = [[], []]
	var g := GLYPH * scale_factor
	var row := g * ICON_HEIGHT
	var top := size.y - MARGIN.y - row if bottom else MARGIN.y
	# [top, height, which parts] a row: the line, or the score over the rest.
	var rows := [[top, row, ALL]]
	if two_rows:
		var gap := roundf(g * ROW_GAP)
		if bottom:
			rows = [[top - gap - g, g, SCORE], [top, row, REST]]
		else:
			rows = [[top, g, SCORE], [top + g + gap, row, REST]]
		top = rows[0][0]
	var row_bottom: float = rows[-1][0] + rows[-1][1]
	for r in rows:
		var x := MARGIN.x
		if right:
			# Laid out once without drawing, to end at the margin.
			_measuring = true
			x = size.x - MARGIN.x - _line(0.0, r[0], g, r[1], r[2])
			_measuring = false
		_line(x, r[0], g, r[1], r[2])
	var left := MARGIN.x if not right else size.x - MARGIN.x - _measure(rows, g)
	_tint_layer.queue_redraw()
	_icon_layer.queue_redraw()
	for group in _ring_groups:
		group.get_child(0).queue_redraw()
	# The modes and the cheats on lines of their own, smaller, stacked away
	# from the corner: they are several words each and would run the main line
	# off the frame at the bigger sizes.
	var small := roundf(g * 0.75 / 8.0) * 8.0 if g >= 32.0 else g
	var gap := roundf(g * 0.25)
	var at := top - gap - small if bottom else row_bottom + gap
	for line in [modes, cheats]:
		if line == "":
			continue
		_text(line, left, at, small, GRAY)
		at += -(small + gap) if bottom else small + gap


# The widest of the rows, for the modes' and cheats' lines to start where
# it does on the right.
func _measure(rows: Array, g: float) -> float:
	_measuring = true
	var widest := 0.0
	for r in rows:
		widest = maxf(widest, _line(0.0, r[0], g, r[1], r[2]))
	_measuring = false
	return widest


# The main line from `x`, or the part of it `which` says; returns where it ends.
enum { ALL, SCORE, REST }

func _line(x: float, top: float, g: float, row: float, which := ALL) -> float:
	var y := top + roundf((row - g) * 0.5)      # the glyphs' top
	var groups := 0
	var show := parts.duplicate()
	if which == SCORE:
		show = {"score": parts.score, "lives": false, "pows": false, "weapon": false}
	elif which == REST:
		show.score = false
	if show.score:
		x = _text("%06d" % int(_shown), x, y - _hop(_roll_time, g), g, WHITE, 1.0, _flash(_roll_time))
		groups += 1
	if show.lives:
		x = _gap(x, g, groups)
		groups += 1
		var dim := 1.0 if lives != 0 else DIM
		var hop := _hop(_lives_time, g)
		x = _icon(icons.get(lives_icon, icons.get("lives")), LIFE_SPRITE, x, top - hop, row, dim) + g * 0.25
		x = _infinity(x, y, g) if lives < 0 \
				else _text(str(lives), x, y - hop, g, WHITE if lives > 0 else GRAY, 1.0, _flash(_lives_time))
	if show.pows:
		x = _gap(x, g, groups)
		groups += 1
		var dim := 1.0 if pows > 0 else DIM
		var hop := _hop(_pows_time, g)
		x = _icon(icons.get("pow"), POW_SPRITE, x, top - hop, row, dim) + g * 0.25
		x = _text(str(pows), x, y - hop, g, WHITE if pows > 0 else GRAY, 1.0, _flash(_pows_time))
	if show.weapon:
		x = _gap(x, g, groups)
		groups += 1
		var level := _weapon_level()
		var rounds: Array = icons.get("weapons", [])
		x = _icon(rounds[level] if level < rounds.size() else null,
				MISSILE_SPRITE if has_missiles else GRENADE_SPRITE, x, top - _hop(_weapon_time, g), row, 1.0,
				_flash_amount(_weapon_time) * WEAPON_TINT)
	return x


# The tint of a number `time` seconds after it went up: the player's colour,
# back to white over FLASH_FADE once ROLL_TIME is over.
func _flash(time: float) -> Color:
	return Color.WHITE.lerp(colour, _flash_amount(time))


# How much of the player's colour there is `time` seconds after, 1 to 0.
static func _flash_amount(time: float) -> float:
	return clampf((ROLL_TIME + FLASH_FADE - time) / FLASH_FADE, 0.0, 1.0)


# The grenade 0, the missile 1 and its two upgrades 2 and 3: the icon's index.
func _weapon_level() -> int:
	return 1 + missile_power if has_missiles else 0


# The ring's white reach and the black line's outside it, frame px.
func _ring_white() -> float:
	return maxf(roundf(OUTLINE * scale_factor), 1.0)


func _ring_reach() -> float:
	return _ring_white() + maxf(roundf(OUTLINE_LINE * scale_factor), 1.0)


func _draw_rings(on: Node2D, which: int) -> void:
	var white := _ring_white()
	var black := _ring_reach()
	for ring in [[Color.BLACK, black], [Color.WHITE, white]]:
		for icon in _rings[which]:
			for r in range(1, int(ring[1]) + 1):
				for k in 16:
					var a := TAU * k / 16.0
					var rect: Rect2 = icon[1]
					rect.position += (Vector2(cos(a), sin(a)) * r).round()
					if icon[2] == null:
						on.draw_texture_rect(icon[0], rect, false, ring[0])
					else:
						on.draw_texture_rect_region(icon[0], rect, icon[2], ring[0])


func _draw_tints() -> void:
	for t in _tints:
		if t[2] == null:
			_tint_layer.draw_texture_rect(t[0], t[1], false, t[3])
		else:
			_tint_layer.draw_texture_rect_region(t[0], t[1], t[2], t[3])


# How far up it is `time` seconds after: HOP font pixels and back over HOP_TIME.
static func _hop(time: float, g: float) -> float:
	return roundf(sin(PI * clampf(time / HOP_TIME, 0.0, 1.0)) * HOP) * g / 32.0


func _gap(x: float, g: float, groups: int) -> float:
	return x + g * GAP if groups > 0 else x


# The game's draw_text, in the preview's font (Level3DFont).
func _text(text: String, x: float, y: float, g: float, colour: int, alpha := 1.0,
		tint := Color.WHITE) -> float:
	if _measuring:
		return x + Level3DFont.width(text, g)
	return Level3DFont.draw(self, text, x, y, g, COLOURS[colour], Color(tint, alpha))


# A rendered icon at the line's height, its own proportions kept, or the
# game's sprite at the glyphs' until the icons are there, and `tint` of the
# player's colour washed over it. Returns where it ends.
func _icon(icon: Texture2D, sprite: String, x: float, top: float, row: float, alpha: float,
		tint := 0.0) -> float:
	# Room for the ring on either side, so that it does not run into the count.
	var ring := _ring_reach()
	x += ring
	if icon != null:
		var factor := row / icon.get_height()
		var w := roundf(icon.get_width() * factor)
		if not _measuring:
			_icon_draws.append([icon, Rect2(x, top, w, row), null, Color(1, 1, 1, alpha)])
			if alpha > 0.0:
				_rings[0 if alpha >= 1.0 else 1].append([icon, Rect2(x, top, w, row), null])
			if tint > 0.0:
				_tints.append([icon, Rect2(x, top, w, row), null, Color(colour, tint)])
		return x + w + ring
	var s: Spr = _sprites.get(sprite)
	if s == null:
		return x - ring
	var h := row * 0.8
	var sw := roundf(s.w * h / s.h)
	if _measuring:
		return x + sw + ring
	_icon_draws.append([s.tex, Rect2(x, top + (row - h) * 0.5, sw, h), s.region, Color(1, 1, 1, alpha)])
	if alpha > 0.0:
		_rings[0 if alpha >= 1.0 else 1].append([s.tex, Rect2(x, top + (row - h) * 0.5, sw, h), s.region])
	if tint > 0.0:
		_tints.append([s.tex, Rect2(x, top + (row - h) * 0.5, sw, h), s.region, Color(colour, tint)])
	return x + sw + ring


# The infinity the font does not have: two rings in the glyphs' white with
# their shadow under them, a glyph and a half wide.
func _infinity(x: float, y: float, g: float) -> float:
	var r := g * 0.3
	var width := maxf(roundf(g / 8.0), 1.0)
	if _measuring:
		return x + r * 4.0 + width * 2.0
	for pass_colour in [SHADOW, Color.WHITE]:
		var offset := Vector2(width, width) if pass_colour != Color.WHITE else Vector2.ZERO
		var centre := Vector2(x + r + width, y + g * 0.5) + offset
		draw_arc(centre, r, 0.0, TAU, 24, pass_colour, width)
		draw_arc(centre + Vector2(r * 2.0, 0.0), r, 0.0, TAU, 24, pass_colour, width)
	return x + r * 4.0 + width * 2.0
