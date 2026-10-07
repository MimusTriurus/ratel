# Who sits in the rescue helicopter on the 3D preview (level3d_rescue.gd):
# its pilot, its crewman when he is in, and the prisoners it takes aboard.
#
# Nothing here is the game's: FriendlyHelicopter took a prisoner when he
# walked into it and he was gone. Here the rule is kept -- he is aboard, his
# 500 points and the upgrade they may bring his, the tick he reaches its x, as
# Level3DFriends.deliver has it -- and what is drawn goes on round it:
#
#   * near it, BOARD_REACH off its middle, his figure is hidden and another
#     takes over from where it was (a Boarder): he walks on to a seat, turns
#     his back to it and sits -- the helicopter at the people's size
#     (Level3DRescue.MODEL_SCALE), he is as big on it as on the ground. He
#     stays in it, on its seat's mark, and flies off with it;
#   * the seats are the model's marks (jackal_littlebird_mh6.py's SEATS):
#     the benches', three a side, and the two in the cabin behind. The cabin
#     fills first -- its two seats, then in at the door, not seen again, as
#     all of them were before -- but only with as many as the benches cannot
#     take: while more are still to come (walking to it, or aboard a jeep)
#     than the benches have places left, a man goes in, and after that every
#     one goes on a bench, so the benches end as full as the number brought
#     lets them be. On them the side he comes from first -- to the other he
#     goes round the nose. A bench he sits on with his legs over its edge,
#     holding it (Sit_Hold); a seat as a passenger (Sit);
#   * the pilot sits on the left, in the crewman's orange flight suit, from
#     the start (Sit_Pilot); the crewman on the right when he is in;
#   * once it lifts off nobody is still on his way: each is put on his seat,
#     or in, at once.
#
# The sitting clips are low_poly_soldier.glb's (soldier_sit.py); with a model
# that has none (--old-soldiers) nobody is drawn sitting, and the prisoners
# go in as before.
class_name Level3DRescueSeats
extends Node3D

const PX := Level3DMap.PX
# Level metres off the helicopter's middle, across, at which a prisoner
# walking to it is taken over: the benches' outer edge, 1.0 m of the model,
# and a man's legs beyond.
const BOARD_REACH: float = (1.0 + 0.45) * Level3DRescue.MODEL_SCALE
# Model metres: where a man stands to sit on a seat, out from its mark; the
# way round the nose to the other side; where one who finds no seat goes in.
const STAND_OFF := 0.55
const CABIN_DOOR := 1.55
const ROUND_NOSE := Vector2(1.9, 3.6)
const INSIDE := Vector3(0.0, 1.35, 0.2)
# Ticks a sitting down takes, and the clip's fade into it, seconds.
const BOARD_TICKS := 45
const SIT_BLEND := 0.3
# A man's hop up: metres over the line between where he stood and his seat.
const HOP := 0.08

const SEAT_PILOT := "Seat_Pilot"
const SEAT_CREW := "Seat_Crew"
const BENCH_SEATS := ["Seat_BenchL1", "Seat_BenchL2", "Seat_BenchL3",
		"Seat_BenchR1", "Seat_BenchR2", "Seat_BenchR3"]
const CABIN_SEATS := ["Seat_Cabin1", "Seat_Cabin2"]

var friends: Level3DFriends
# `ground.call(x, z)` -> {"height", ...}.
var ground: Callable
var verbose := false

var _model: Node3D
var _figure: Dictionary         # Level3DFriends.chosen()
var _scene: PackedScene
var _can_sit := false
var _pilot: Node3D
var _crewman: Node3D
# Seat node -> its man, or null.
var _taken := {}
var _boarders: Array[Boarder] = []
var _seated: Array[Node3D] = []


class Boarder:
	var root: Node3D
	var player: AnimationPlayer
	var seat: Node3D            # null: no seat, he goes in
	var clip := ""
	var path: Array[Vector3] = []   # level points ahead of him, on the ground
	var board := -1             # ticks into sitting down; -1 walking
	var start := Transform3D()


# The model's figure in the crew's orange, sitting in `clip`; null for a
# model with no sitting clips.
static func sitting_figure(clip: String, colour: Color, dark: Color) -> Node3D:
	var figure: Dictionary = Level3DFriends.chosen()
	var scene: PackedScene = load(figure.path)
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(clip):
		root.free()
		return null
	Level3DFriends.dress(root, figure, colour, dark)
	player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.play(clip)
	return root


# The pilot on `model`'s seat, as a child of `parent` where its transform is
# `model_transform` -- not under the model, which the shop repaints whole.
# Null if the model has no seat for him or the figure cannot sit.
static func seat_pilot(model: Node3D, parent: Node3D, model_transform: Transform3D) -> Node3D:
	var seat := model.find_child(SEAT_PILOT, true, false) as Node3D
	if seat == null:
		return null
	var pilot := sitting_figure("Sit_Pilot", Level3DRescueCrew.SUIT, Level3DRescueCrew.SUIT_DARK)
	if pilot == null:
		return null
	parent.add_child(pilot)
	pilot.transform = model_transform * _relative(seat, model)
	return pilot


# `node`'s transform in `ancestor`'s space.
static func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func bind(model: Node3D) -> void:
	_model = model
	_figure = Level3DFriends.chosen()
	_scene = load(_figure.path)
	var pilot_seat := model.find_child(SEAT_PILOT, true, false) as Node3D
	_pilot = sitting_figure("Sit_Pilot", Level3DRescueCrew.SUIT, Level3DRescueCrew.SUIT_DARK)
	_can_sit = _pilot != null and pilot_seat != null
	if not _can_sit:
		if _pilot != null:
			_pilot.free()
			_pilot = null
		return
	pilot_seat.add_child(_pilot)
	var crew_seat := model.find_child(SEAT_CREW, true, false) as Node3D
	if crew_seat != null:
		_crewman = sitting_figure("Sit", Level3DRescueCrew.SUIT, Level3DRescueCrew.SUIT_DARK)
		crew_seat.add_child(_crewman)
		_crewman.visible = false
	reset()


func reset() -> void:
	for b in _boarders:
		b.root.queue_free()
	_boarders.clear()
	for man in _seated:
		man.queue_free()
	_seated.clear()
	_taken.clear()
	if _model == null:
		return
	var benches := _model.find_child(Level3DRescue.BENCHES, true, false) as Node3D
	var names: Array = CABIN_SEATS.duplicate()
	if benches != null and benches.visible:
		names = BENCH_SEATS + names
	for n in names:
		var seat := _model.find_child(n, true, false) as Node3D
		if seat != null:
			_taken[seat] = null


# A tick, after the helicopter's: `helicopter_x` its x in map px, `leaving`
# whether it is lifting off or gone, `crew_in` whether its crewman is aboard.
func tick(helicopter_x: float, leaving: bool, crew_in: bool) -> void:
	if not _can_sit:
		return
	if _crewman != null:
		_crewman.visible = crew_in
	for f in friends.friends:
		if f.state == FriendlySoldier.STATE_WALKING_TO_HELICOPTER and f.root.visible \
				and absf(f.x - helicopter_x) * PX <= BOARD_REACH:
			f.root.visible = false
			_take_over(f.root, _to_come())
	for b in _boarders.duplicate():
		if leaving:
			_sit(b)
		else:
			_step(b)


# How many are still to board after the one being taken over: walking to it
# and not taken over yet, and aboard the jeeps.
func _to_come() -> int:
	var n := friends.pows_aboard()
	for f in friends.friends:
		if f.state == FriendlySoldier.STATE_WALKING_TO_HELICOPTER and f.root.visible:
			n += 1
	return n


# A boarder where `figure` is, going to his seat (_free_seat), `after` more
# to come behind him.
func _take_over(figure: Node3D, after: int) -> void:
	var b := Boarder.new()
	b.root = _scene.instantiate() as Node3D
	add_child(b.root)
	b.root.global_transform = figure.global_transform
	b.player = b.root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	Level3DFriends.dress(b.root, _figure)
	Level3DFriends.loop_clips(b.player, _figure)
	var side := 1.0 if _model.to_local(figure.global_position).x >= 0.0 else -1.0
	b.seat = _free_seat(side, figure.global_position, after)
	if b.seat != null:
		_taken[b.seat] = b.root
	b.clip = "Sit_Hold" if b.seat != null and BENCH_SEATS.has(String(b.seat.name)) else "Sit"
	for p in _path(b.seat, side):
		b.path.append(_on_ground(_model.global_transform * p))
	var clip: String = _figure.walk
	b.player.play(clip)
	var stride: float = _figure.stride
	if stride > 0.0:
		var speed := FriendlySoldier.WALK_SPEED * PX * Engine.physics_ticks_per_second
		b.player.speed_scale = speed * b.player.get_animation(clip).length / (stride * _figure.scale)
	_boarders.append(b)
	if verbose:
		print("prisoner boarding: %s" % (b.seat.name if b.seat != null else "in"))


# The seat for a man with `after` more to come: in the cabin while that is
# as many as the benches have places left or more -- its seats, then null, in
# at the door -- and otherwise on a bench, on `side` first, the nearest to
# `from`.
func _free_seat(side: float, from: Vector3, after: int) -> Node3D:
	var room := 0
	for seat: Node3D in _taken:
		if _taken[seat] == null and BENCH_SEATS.has(String(seat.name)):
			room += 1
	if after >= room:
		return _nearest_free(CABIN_SEATS, from)
	var near: Array = BENCH_SEATS.slice(0, 3) if side > 0.0 else BENCH_SEATS.slice(3, 6)
	var far: Array = BENCH_SEATS.slice(3, 6) if side > 0.0 else BENCH_SEATS.slice(0, 3)
	var best := _nearest_free(near, from)
	return best if best != null else _nearest_free(far, from)


# The free seat of `group` nearest `from`, or null.
func _nearest_free(group: Array, from: Vector3) -> Node3D:
	var best: Node3D = null
	for seat: Node3D in _taken:
		if _taken[seat] != null or not group.has(String(seat.name)):
			continue
		if best == null or seat.global_position.distance_to(from) < best.global_position.distance_to(from):
			best = seat
	return best


# Model points to walk through to sit on `seat`, coming from `side`.
func _path(seat: Node3D, side: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if seat == null:
		out.append(Vector3(side * CABIN_DOOR, 0.0, 0.0))
		return out
	var at := _relative(seat, _model).origin
	if BENCH_SEATS.has(String(seat.name)):
		var seat_side := signf(at.x)
		if seat_side != side:
			out.append(Vector3(side * ROUND_NOSE.x, 0.0, ROUND_NOSE.y))
			out.append(Vector3(seat_side * ROUND_NOSE.x, 0.0, ROUND_NOSE.y))
		out.append(Vector3(at.x + seat_side * STAND_OFF, 0.0, at.z))
	else:
		out.append(Vector3(side * CABIN_DOOR, 0.0, at.z))
	return out


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, ground.call(p.x, p.z).height, p.z)


func _step(b: Boarder) -> void:
	if b.board < 0:
		var step := FriendlySoldier.WALK_SPEED * PX
		var to := b.path[0]
		var d := Vector2(to.x - b.root.global_position.x, to.z - b.root.global_position.z)
		if d.length() > step:
			var at := b.root.global_position + Vector3(d.x, 0.0, d.y).normalized() * step
			b.root.global_position = _on_ground(at)
			b.root.global_rotation.y = atan2(d.x, d.y)
			return
		b.root.global_position = to
		b.path.pop_front()
		if not b.path.is_empty():
			return
		b.board = 0
		b.start = b.root.global_transform
		if b.seat != null:
			b.player.speed_scale = 1.0
			b.player.play(b.clip, SIT_BLEND)
	b.board += 1
	var t := smoothstep(0.0, 1.0, float(b.board) / BOARD_TICKS)
	var end := b.seat.global_transform if b.seat != null else _model.global_transform * Transform3D(Basis(), INSIDE)
	var q := b.start.basis.get_rotation_quaternion().slerp(end.basis.get_rotation_quaternion(), t)
	var s := b.start.basis.get_scale().lerp(end.basis.get_scale(), t)
	var p := b.start.origin.lerp(end.origin, t) + Vector3(0.0, HOP * sin(PI * t), 0.0)
	b.root.global_transform = Transform3D(Basis(q).scaled(s), p)
	if b.board >= BOARD_TICKS:
		_sit(b)


# `b` on his seat for good, or gone in.
func _sit(b: Boarder) -> void:
	_boarders.erase(b)
	if b.seat == null:
		b.root.queue_free()
		return
	b.root.get_parent().remove_child(b.root)
	b.seat.add_child(b.root)
	b.root.transform = Transform3D.IDENTITY
	if b.player.current_animation != b.clip:
		b.player.speed_scale = 1.0
		b.player.play(b.clip)
	b.player.get_animation(b.clip).loop_mode = Animation.LOOP_LINEAR
	_seated.append(b.root)
