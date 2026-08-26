# jackal.LargeImage: a big picture stored as a rectangular grid of 32x32 tiles.
class_name LargeImage
extends RefCounted

var tiles: Array[Spr]
var map: Array          # Array[PackedInt32Array], indexed [y][x]
var width: int
var height: int

func _init(p_tiles: Array[Spr], p_map: Array, p_width: int, p_height: int) -> void:
	tiles = p_tiles
	map = p_map
	width = p_width
	height = p_height


func draw(m: Main, x: float, y: float) -> void:
	for i in range(height - 1, -1, -1):
		var row: PackedInt32Array = map[i]
		var Y := y + float(i << 5)
		for j in range(width - 1, -1, -1):
			m.draw(tiles[row[j]], x + float(j << 5), Y)
