# Equivalent of jackal.Song: an intro track, an optional second intro track and
# an optional looping track, chained in that order.
class_name Song
extends RefCounted

var intro: AudioStreamPlayer
var intro2: AudioStreamPlayer
var loop: AudioStreamPlayer
var playing: bool
var played_intro2: bool

static func make_player(parent: Node, path: String, looping: bool) -> AudioStreamPlayer:
	if path.is_empty():
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		push_error("Song: missing stream %s" % path)
		return null
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = looping
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Master"
	parent.add_child(p)
	return p


func _init(p_intro: AudioStreamPlayer = null, p_intro2: AudioStreamPlayer = null,
		p_loop: AudioStreamPlayer = null) -> void:
	intro = p_intro
	intro2 = p_intro2
	loop = p_loop


func stop() -> void:
	if intro != null and intro.playing:
		intro.stop()
	if intro2 != null and intro2.playing:
		intro2.stop()
	if loop != null and loop.playing:
		loop.stop()
	playing = false
	played_intro2 = false


func play() -> void:
	if playing:
		return
	stop()
	if intro == null and intro2 == null:
		loop.play()
	elif intro == null:
		intro2.play()
	else:
		intro.play()
	playing = true


func update() -> void:
	if not playing:
		return
	if intro == null or not intro.playing:
		if not (intro2 == null or played_intro2):
			played_intro2 = true
			intro2.play()
		elif (intro2 == null or not intro2.playing) and loop != null and not loop.playing:
			loop.play()
	if loop == null and not intro.playing and (intro2 == null or not intro2.playing):
		stop()
