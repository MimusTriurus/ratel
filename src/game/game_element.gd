# Port of jackal.GameElement.
#
# As in the original, the base constructor runs init() and registers the
# element with the current GameMode *before* the subclass constructor body
# assigns x/y — so init() must not read them.
class_name GameElement
extends RefCounted

var main: Main
var game_mode: GameMode

var remove: bool
var enemy: bool
var enemy_bullet: bool
var x: float
var y: float
var layer: int
var change_layer_to: int = -1

# The jeep this element goes for. Not in the original, where every enemy kept
# its own reference to the one Player from init(); with two jeeps the nearest is
# picked again on every read, so an enemy turns to whichever has come closer.
# Jeeps move after every element has updated, so the reads within one update
# agree. Read it only once x and y are set -- not from init(). A shot at the
# jeeps goes through GameMode.attack_players instead, which tries them all.
var player: Player:
	get:
		return game_mode.target_player(x, y)


func _init() -> void:
	main = Main.main
	game_mode = Main.game_mode
	init()
	game_mode.add(self)


func change_layer(l: int) -> void:
	change_layer_to = l


func do_remove() -> void:
	remove = true


func check_bounds(_max_y: float) -> void:
	pass


func init() -> void:
	pass


func update() -> void:
	pass


func render() -> void:
	pass
