# Not in the original, where all of this lived on jackal.Main as fields of the
# one player: lives, score, the weapon, the POWs delivered this stage. Co-op
# needs one set per jeep, and a set has to outlive the GameMode -- a Player is
# made new for every stage, the score and the lives are not. Main holds one of
# these per player, GameMode makes a Player for each.
#
# The methods are Main's, moved here unchanged.
class_name PlayerState
extends RefCounted

var main: Main
var index: int
var input: HumanInput

var extra_lives: int
var extra_lives_str: String
var score: int
var score_str: String
var has_missiles: bool
var missile_power: int
var friendly_soldiers_picked_up: int
# Lost the last life while the other player played on: no jeep, through the
# stages that follow too, until continue_player brings everyone back.
var out: bool


func _init(p_main: Main, p_index: int, p_input: HumanInput) -> void:
	main = p_main
	index = p_index
	input = p_input


func continue_player() -> void:
	if main.konami_code != null and main.konami_code.enabled:
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
	out = false


func upgrade_weapon(always_play_sound: bool) -> bool:
	var sound_played := false
	if always_play_sound:
		main.play_sound(main.weapon_upgrade_sound)
		sound_played = true
	if main.konami_code.enabled:
		if not (has_missiles and missile_power == 2):
			has_missiles = true
			missile_power = 2
			if not always_play_sound:
				main.play_sound(main.weapon_upgrade_sound)
				sound_played = true
	elif has_missiles:
		if missile_power < 2:
			missile_power += 1
			if not always_play_sound:
				main.play_sound(main.weapon_upgrade_sound)
				sound_played = true
	else:
		has_missiles = true
		if not always_play_sound:
			main.play_sound(main.weapon_upgrade_sound)
			sound_played = true
	return sound_played


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
	main.play_sound_always(main.extra_life_sound)


func friendly_soldier_picked_up() -> bool:
	add_points(500)
	friendly_soldiers_picked_up += 1
	if friendly_soldiers_picked_up == 3 or friendly_soldiers_picked_up == 8 \
			or friendly_soldiers_picked_up == 13 or friendly_soldiers_picked_up == 18:
		return upgrade_weapon(false)
	return false
