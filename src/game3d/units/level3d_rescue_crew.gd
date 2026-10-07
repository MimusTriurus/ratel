# The rescue helicopter's crewman on the 3D preview: out of its door while it
# waits on the pad with prisoners to be let off and nobody letting them off,
# a few steps towards the side the jeep lets them off on, waving it over, with
# HERE! and OVER HERE! over him by turns (Level3DCallouts, through
# `call_marks`). Back in when they start walking over, when nobody has any
# left aboard, or when it makes to take off (level3d_rescue.gd).
#
# Not the game's: FriendlyHelicopter only stood there. In the 3D frame the
# pad is one more grey shape in the camp, and nothing said what it was for or
# where to stop; the pad's arrow (Level3DArrow) says where it is, and he says
# what to do there.
#
# He is the prisoners' figure (Level3DFriends.chosen) with their clips, his
# rifle hidden as theirs is, his uniform an orange flight suit: green would be
# a prisoner, and brown an enemy. The engine does the recolouring on copies of
# the model's uniform materials, as the weapon carrier's flashing does
# (Level3DFriends.dress). He walks at SPEED, a run where theirs is one, and
# the clip goes as fast as his feet go over the ground (_pose): played at its
# own speed, the walk slid them.
class_name Level3DRescueCrew
extends Node3D

const SUIT := Color8(232, 112, 24)
const SUIT_DARK := Color8(150, 62, 10)
const DOOR := Vector2(0.95, 0.3)       # level metres off the pad's middle, east and south, his start:
                                        # outside the bench, at the helicopter's 0.55 (Level3DRescue)
const STAND := Vector2(2.0, 0.9)       # and where he waves from
const SPEED := 1.2                      # metres a second
const FACING := 0.6                     # radians off due south, towards the jeep's side, as he waves
const TEXTS := ["HERE!", "OVER HERE!"]
const TEXT_COLOUR := Color(0.85, 0.36, 0.0)     # his suit's orange, darker for the white
const CALL_HEIGHT := 1.3                # metres over his feet the bubble's tail points to
# The calls: CALL_FIRST ticks after he starts waving, then CALL_ON up and
# CALL_GAP down, each the next of TEXTS.
const CALL_FIRST := 20
const CALL_ON := 130
const CALL_GAP := 160

enum { IN, OUT, WAVING, BACK }

# Whether his calls are on: Level3DSettings' HUD and HELP switches.
var calls := true
var verbose := false
var state := IN
var _state_was := IN

var _root: Node3D
var _player: AnimationPlayer
var _model: Dictionary
var _walk_clip := ""            # his walk's clip, or run's
var _walk_speed := 1.0          # what it is played at
var _pad := Vector3.ZERO        # the pad's middle, level metres
var _side := 1.0                # 1 east, -1 west: where the jeep lets them off
var _at := Vector2.ZERO         # off the pad's middle
var _ticks := 0                 # since he started waving
var _call := 0                  # the calls made


func _ready() -> void:
	_model = Level3DFriends.chosen()
	var scene: PackedScene = load(_model.path)
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	_root.scale = Vector3.ONE * _model.scale
	add_child(_root)
	_player = _root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_walk_clip = _model.run if _model.run != "" and SPEED >= _model.run_from else _model.walk
	Level3DFriends.loop_clips(_player, _model)
	# The clip's own pace over the ground, at his size; none for a walk not
	# made by its stride.
	var stride: float = _model.run_stride if _walk_clip == _model.run else _model.stride
	var length := _player.get_animation(_walk_clip).length
	_walk_speed = SPEED * length / (stride * _model.scale) if stride > 0.0 else 1.0
	Level3DFriends.dress(_root, _model, SUIT, SUIT_DARK)
	visible = false


func reset() -> void:
	state = IN
	visible = false


# A tick: `pad` the pad's middle in level metres, `side` the side he goes out
# on, `wanted` whether he is to be out.
func tick(pad: Vector3, side: float, wanted: bool) -> void:
	if _root == null:
		return
	_pad = pad
	_side = side
	var door := Vector2(DOOR.x * side, DOOR.y)
	var stand := Vector2(STAND.x * side, STAND.y)
	match state:
		IN:
			if wanted:
				state = OUT
				_at = door
				visible = true
		OUT:
			if not wanted:
				state = BACK
			elif _walk(stand):
				state = WAVING
				_ticks = 0
				_call = 0
		WAVING:
			_ticks += 1
			if not wanted:
				state = BACK
		BACK:
			if wanted:
				state = OUT
			elif _walk(door):
				state = IN
				visible = false
	if verbose and state != _state_was:
		print("rescue crewman %s at %.2f, %.2f" % [["in", "out", "waving", "back"][state], _at.x, _at.y])
	_state_was = state
	_pose()


# A tick's step towards `to`; whether he is there.
func _walk(to: Vector2) -> bool:
	var step := SPEED / Engine.physics_ticks_per_second
	var d := to - _at
	if d.length() <= step:
		_at = to
		return true
	_at += d.normalized() * step
	_root.rotation.y = atan2(d.x, d.y)
	return false


func _pose() -> void:
	_root.position = _pad + Vector3(_at.x, 0.0, _at.y)
	var clip: String = _model.wave if state == WAVING else _walk_clip
	if state == WAVING:
		_root.rotation.y = FACING * _side
	if _player.current_animation != clip:
		_player.play(clip)
		_player.speed_scale = 1.0 if state == WAVING else _walk_speed


# His call, if one is up, as Level3DFriends.help_marks gives theirs.
func call_marks() -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	if not calls or state != WAVING or _ticks < CALL_FIRST:
		return marks
	var t := (_ticks - CALL_FIRST) % (CALL_ON + CALL_GAP)
	if t >= CALL_ON:
		return marks
	var n := (_ticks - CALL_FIRST) / (CALL_ON + CALL_GAP)
	marks.append({"at": _root.position + Vector3(0.0, CALL_HEIGHT, 0.0), "small": true, "age": t,
			"seed": 9000 + n, "text": TEXTS[n % TEXTS.size()], "colour": TEXT_COLOUR})
	return marks
