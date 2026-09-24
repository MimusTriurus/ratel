# A fade between a figure's clips, on its skeleton: the enemy soldiers'
# (level3d_soldiers.gd) and the prisoners' (level3d_friends.gd).
#
# The sprites had no in-betweens, but a figure that snaps from walk to aim in
# one frame reads as a glitch rather than as the sprite's economy. The fade
# cannot be AnimationPlayer's own: a walk driven by the ground covered is
# sought, not played, and a seek does not run the blend on. So it is done
# here, for every change of clip alike -- from the pose that was on screen
# when the clip changed, which in the middle of a fade is the half-way one.
#
# Once a frame, around whatever poses the skeleton (a seek, an advance):
#     fade.before()
#     player.advance(delta)
#     fade.after(player.assigned_animation, delta)
# Nothing else may pose the skeleton between frames, or before() reads that
# instead of what was drawn.
class_name Level3DCrossfade
extends RefCounted

# Seconds a change of clip fades over.
const TIME := 0.15

var skeleton: Skeleton3D
var _clip := ""
var _shown: Array = []
var _from: Array = []
var _left := 0.0


# `clip`: the clip the figure appears in, which it does not fade into.
func _init(root: Node, clip: String) -> void:
	skeleton = root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_clip = clip


func before() -> void:
	_shown = _read()


func after(clip: String, delta: float) -> void:
	if clip != _clip:
		_clip = clip
		_from = _shown
		_left = TIME	if _left <= 0.0:
		return
	_left -= delta
	var w := smoothstep(0.0, 1.0, 1.0 - maxf(_left, 0.0) / TIME)
	for bone in skeleton.get_bone_count():
		var from: Array = _from[bone]
		skeleton.set_bone_pose_position(bone,
				(from[0] as Vector3).lerp(skeleton.get_bone_pose_position(bone), w))
		skeleton.set_bone_pose_rotation(bone,
				(from[1] as Quaternion).slerp(skeleton.get_bone_pose_rotation(bone), w))
		skeleton.set_bone_pose_scale(bone,
				(from[2] as Vector3).lerp(skeleton.get_bone_pose_scale(bone), w))


func _read() -> Array:
	var pose := []
	for bone in skeleton.get_bone_count():
		pose.append([skeleton.get_bone_pose_position(bone), skeleton.get_bone_pose_rotation(bone),
				skeleton.get_bone_pose_scale(bone)])
	return pose
