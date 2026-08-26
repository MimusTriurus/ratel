class_name Stage
extends RefCounted

var tile_map: Array = []       # Array[PackedInt32Array], pristine copy
var types_map: Array = []      # Array[PackedInt32Array], pristine copy

var tiles: Array[Spr] = []
var groups: Array = []         # Array of Array of [x, y, tile, type]
var trigger_map: Array = [null, null]  # [normal, hard]; each is Array per row
var groups_map: Array = []     # Array[PackedByteArray]
var map_width: int
var map_height: int
var directions: PackedInt64Array = PackedInt64Array()
var directions_width: int
var directions_height: int
