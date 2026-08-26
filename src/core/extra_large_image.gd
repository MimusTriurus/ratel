# jackal.ExtraLargeImage: like LargeImage, but stored as a flat list of
# (tile, x, y) cells sorted by tile index so that draws batch per source tile.
class_name ExtraLargeImage
extends RefCounted

var tiles: Array[Spr]
var map: Array          # Array of [tile, x, y]

func _init(p_tiles: Array[Spr], p_map: Array) -> void:
	tiles = p_tiles
	map = p_map


func draw(m: Main, x: float, y: float) -> void:
	for i in range(map.size() - 1, -1, -1):
		var cell: Array = map[i]
		m.draw(tiles[cell[0]], float(cell[1]) + x, float(cell[2]) + y)
