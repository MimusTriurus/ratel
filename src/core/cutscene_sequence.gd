# Port of jackal.CutsceneSequence: shuffles through the three between-stage
# cutscenes without repeating one until all have been shown.
class_name CutsceneSequence
extends RefCounted

static var _modes: Array[int] = []


static func request_cutscene() -> void:
	if _modes.is_empty():
		_modes = [Modes.YEAH, Modes.WE_MADE_IT, Modes.HERE]
	var i := Main.main.random.randi_range(0, _modes.size() - 1)
	var m: int = _modes[i]
	_modes.remove_at(i)
	Main.main.request_mode(m)
