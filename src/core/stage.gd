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

# Where the terrain is drawn from: MapIO.BACKGROUND_TILES assembles it out of
# tiles-N.png a cell at a time, as the original did, and is what a stage file
# with no background block means. MapIO.BACKGROUND_IMAGE blits the baked chunks
# instead. The chunk height is kept either way, so a baked stage can be drawn
# both ways for comparison; tiles is 0 rather than the constant because MapIO
# takes a Stage in its own signatures.
var background_mode: int = 0
var background_chunk_height: int = 0
var directions: PackedInt64Array = PackedInt64Array()
var directions_width: int
var directions_height: int
