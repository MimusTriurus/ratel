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
