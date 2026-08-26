# Port of jackal.JeepYeahMode: the "yeah" / "we made it" cutscene. Two planes
# sweep past over a scrolling smoke backdrop while the jeep's guns keep firing.
class_name JeepYeahMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_PAUSED := 1
const STATE_FADE_OUT := 2
const STATE_DONE := 3

const YEAH_DELAY := 136
const BULLET_DELAY := 11

const SMOKE_VX := 0.25
const SMOKE_VY := 0.5

var main: Main
var smoke_x: float
var smoke_y: float
var explosion: JeepYeahExplosion
var left_plane: JeepYeahPlane
var right_plane: JeepYeahPlane
var fire_right: JeepYeahFireRight
var fire_left: JeepYeahFireLeft
var bullets: Array[JeepYeahBullet] = []
var bullet_delay: int = BULLET_DELAY
var yeah_visible: int = YEAH_DELAY
var yeah: bool
var state: int = STATE_FADE_IN


func _init(p_yeah: bool) -> void:
	yeah = p_yeah


func init(p_main: Main) -> void:
	main = p_main

	left_plane = JeepYeahPlane.new(true)
	right_plane = JeepYeahPlane.new(false)
	fire_left = JeepYeahFireLeft.new()
	fire_right = JeepYeahFireRight.new()

	p_main.start_fade(false, self)
	p_main.request_song(p_main.cutscene_song)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_PAUSED
	elif state == STATE_FADE_OUT:
		state = STATE_DONE
		main.request_mode(Modes.MAP)


func update() -> void:
	if yeah_visible > 0:
		yeah_visible -= 1

	smoke_x += SMOKE_VX
	if smoke_x >= 64:
		smoke_x -= 64

	smoke_y += SMOKE_VY
	if smoke_y >= 32:
		smoke_y -= 32

	if explosion == null or explosion.remove:
		explosion = JeepYeahExplosion.new(136, 608)
	explosion.update()

	if state == STATE_PAUSED:
		left_plane.update()
		right_plane.update()

		# The cutscene ends once the second plane has passed the camera.
		if right_plane.z > 0:
			state = STATE_FADE_OUT
			main.start_fade(true, self)

	fire_left.update()
	fire_right.update()

	bullet_delay -= 1
	if bullet_delay == 0:
		bullet_delay = BULLET_DELAY
		bullets.append(JeepYeahBullet.new())
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: JeepYeahBullet = bullets[i]
		bullet.update()
		if bullet.remove:
			bullets.remove_at(i)


func render() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)

	if state == STATE_DONE:
		return

	for y in 6:
		for x in 3:
			main.draw(main.smoke, 864 + (x << 6) - smoke_x, 288 + (y << 5) - smoke_y)
	explosion.render(main)

	main.jeep_yeah.draw(main, 0, 256)

	left_plane.render(main)
	right_plane.render(main)
	fire_left.render(main)
	fire_right.render(main)

	for i in range(bullets.size() - 1, -1, -1):
		bullets[i].render(main)

	if yeah_visible == 0:
		main.draw(main.yeahs[0], 452, 128)
		main.draw(main.yeahs[1], 534, 226)
		if yeah:
			main.draw(main.yeahs[2], 500, 164)
		else:
			main.draw(main.yeahs[3], 485, 164)
