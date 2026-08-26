# Equivalent of Slick2D's Sound. Voices come from a shared pool owned by Main
# so that repeated plays overlap the way OpenAL sources do.
class_name Sfx
extends RefCounted

const POOL_SIZE := 6

var stream: AudioStream
var _players: Array[AudioStreamPlayer] = []

func _init(parent: Node, path: String) -> void:
	stream = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = &"Master"
		parent.add_child(p)
		_players.append(p)


func play(volume: float = 1.0) -> void:
	var p := _free_player()
	p.volume_db = linear_to_db(clampf(volume, 0.0001, 1.0))
	p.play()


func playing() -> bool:
	for p in _players:
		if p.playing:
			return true
	return false


func stop() -> void:
	for p in _players:
		if p.playing:
			p.stop()


# Reuse the voice that has been running longest once the pool is exhausted.
func _free_player() -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = _players[0]
	var oldest_pos := -1.0
	for p in _players:
		if not p.playing:
			return p
		var pos := p.get_playback_position()
		if pos > oldest_pos:
			oldest_pos = pos
			oldest = p
	return oldest
