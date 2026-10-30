extends Node

# Small "alive" motion for the MetaHuman subject, so she doesn't look frozen:
# blinks, breathing, a slow sway of the body and head, and little eye
# movements. main.gd adds this node at startup.
#
# Body: only a few main joints (pelvis, spine, neck, head, clavicles) are
# rotated, by a degree or so, on top of the pose the scene was saved in. The
# MetaHuman body rig then adds the matching corrective shapes, and the spring
# bones on the arms follow. Face: the blink and gaze go through the face rig's
# face board controls (MetaHumanRig.set_control), which it turns into eyelid
# and eye joints when it next evaluates, and the body motion makes it evaluate
# every frame.
#
# Big enough to see at a full-length framing (the head drifts about 3 cm),
# small enough to stay easy to frame and focus on, like a patient sitter.

@export var enabled := true

@export_group("Blink")
@export var blink_interval := Vector2(2.0, 6.0) # seconds between blinks, picked at random
@export var double_blink_chance := 0.15
const BLINK_CLOSE := 0.08 # seconds: a real blink closes fast,
const BLINK_HOLD := 0.04 # stays shut for a moment,
const BLINK_OPEN := 0.17 # and opens more slowly

@export_group("Body")
@export var breaths_per_minute := 14.0
@export var breathing_degrees := 1.2
@export var sway_degrees := 2.4
@export var sway_speed := 1.6 # 1 = the slowest drift takes about a minute; higher sways faster

@export_group("Eyes")
@export var saccade_interval := Vector2(0.8, 3.0)
@export var gaze_range := 0.06 # face board units (the controls run -1..1)

var _skeleton: Skeleton3D
var _rig: Node
var _bones := {} # name -> {"index", "rest" (local rotation), "parent" (parent's skeleton-space rotation)}
var _right: Vector3 # the character's axes, in skeleton space
var _up: Vector3
var _forward: Vector3

var _marker: Node3D # the focus/aim point at her eyes; moved with her head
var _marker_rest: Vector3
var _head_index := -1
var _head_rest: Vector3 # head bone origin, skeleton space, in the saved pose

# Playback: Play / Pause / Reset buttons (main.gd). `_amount` scales all the
# motion; it eases to 0 on Reset (back to the saved pose) and to 1 on Play,
# so nothing jumps. Pause stops the clock but leaves her where she is.
const EASE_SECONDS := 0.9
signal state_changed(playing: bool)
var playing := true
var _amount := 1.0
var _amount_target := 1.0

var _time := 0.0
var _next_blink := 1.5
var _blink_time := -1.0
var _double_blink := false
var _gaze := Vector2.ZERO
var _gaze_target := Vector2.ZERO
var _next_saccade := 1.0


func setup(skeleton: Skeleton3D, focus_marker: Node3D = null):
	_skeleton = skeleton
	_marker = focus_marker
	if _marker:
		_marker_rest = _marker.global_position
	_head_index = skeleton.find_bone("head")
	if _head_index != -1:
		_head_rest = skeleton.get_bone_global_pose(_head_index).origin
	_rig = skeleton.get_node_or_null("MetaHumanRig")
	for bone_name in ["pelvis", "spine_01", "spine_03", "spine_05", "neck_01", "head", "clavicle_l", "clavicle_r"]:
		var index = skeleton.find_bone(bone_name)
		if index == -1:
			continue
		var parent = skeleton.get_bone_parent(index)
		_bones[bone_name] = {
			"index": index,
			"rest": skeleton.get_bone_pose_rotation(index),
			"parent": skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent != -1 else Quaternion(),
		}
	# She faces the camera along world +Z; express her right, up and forward in
	# the skeleton's own space so each rotation is about an axis that means
	# something (nod, turn, tilt), whatever the bones' local axes are.
	var to_skeleton = skeleton.global_transform.basis.inverse()
	_right = (to_skeleton * Vector3.RIGHT).normalized()
	_up = (to_skeleton * Vector3.UP).normalized()
	_forward = (to_skeleton * Vector3.BACK).normalized()
	_next_blink = randf_range(blink_interval.x, blink_interval.y)


# Sets a bone to its saved pose plus a rotation of `degrees` (x: nod about her
# right axis, y: turn about up, z: tilt about forward), about the bone's own origin.
func _rotate_bone(bone_name: String, degrees: Vector3):
	if not _bones.has(bone_name):
		return
	var b = _bones[bone_name]
	var r = Quaternion(_right, deg_to_rad(degrees.x)) * Quaternion(_up, deg_to_rad(degrees.y)) * Quaternion(_forward, deg_to_rad(degrees.z))
	# In skeleton space the bone becomes R * parent * rest; as a local pose that's parent⁻¹ * R * parent * rest.
	var parent: Quaternion = b.parent
	_skeleton.set_bone_pose_rotation(b.index, parent.inverse() * r * parent * b.rest)


# A slow, smooth, non-repeating wobble in -1..1 (incommensurate sines).
func _drift(seed: float) -> float:
	var t = _time * sway_speed
	return (sin(t * 0.37 + seed) * 0.5 + sin(t * 0.23 + seed * 2.1) * 0.3 + sin(t * 0.11 + seed * 3.7) * 0.2)


func play():
	playing = true
	_amount_target = 1.0
	state_changed.emit(true)

func pause():
	playing = false
	state_changed.emit(false)

# Eases back to the pose the scene was saved in, then stays paused there.
func reset_pose():
	playing = false
	_amount_target = 0.0
	_gaze_target = Vector2.ZERO
	state_changed.emit(false)


func _process(delta):
	if not enabled or _skeleton == null:
		return

	# Paused with no blink, ease or glance still finishing: leave the skeleton
	# untouched, so the face rig and the shadows have nothing to update.
	if not playing:
		var finishing = _blink_time >= 0.0 or _amount != _amount_target or _gaze.distance_to(_gaze_target) > 0.0005
		if not finishing:
			return
	if playing:
		_time += delta
	_amount = move_toward(_amount, _amount_target, delta / EASE_SECONDS)
	var k = smoothstep(0.0, 1.0, _amount)

	# Breathing: 0 at rest, 1 at the top of a breath, a little longer out than in.
	var phase = fmod(_time * breaths_per_minute / 60.0, 1.0)
	var breath = sin(phase * PI) if phase < 0.42 else 0.5 + 0.5 * cos((phase - 0.42) / 0.58 * PI)
	var b = breath * breathing_degrees * k

	# The body sways slowly about the hips, the way weight shifts from foot to
	# foot; the neck and head take back part of it, so her eyes stay level and
	# on the camera, as a sitter's do.
	var sway = Vector3(_drift(0.0), _drift(1.3), _drift(2.6)) * sway_degrees * k
	_rotate_bone("pelvis", Vector3(0.0, sway.y * 0.5, sway.z * 0.7))
	_rotate_bone("spine_01", Vector3(sway.x * 0.3 - b * 0.3, 0.0, 0.0))
	_rotate_bone("spine_03", Vector3(-b * 0.5, sway.y * 0.2, sway.z * 0.2))
	_rotate_bone("spine_05", Vector3(-b * 0.4, 0.0, 0.0))
	_rotate_bone("clavicle_l", Vector3(0.0, 0.0, b * 0.8))
	_rotate_bone("clavicle_r", Vector3(0.0, 0.0, -b * 0.8))
	_rotate_bone("neck_01", Vector3(b * 0.6 - sway.x * 0.2, -sway.y * 0.3, -sway.z * 0.4))
	var head_drift = sway_degrees * k
	_rotate_bone("head", Vector3(_drift(4.2) * head_drift * 0.6, _drift(5.5) * head_drift * 0.8 - sway.y * 0.2, _drift(6.1) * head_drift * 0.5 - sway.z * 0.3))

	# Keep the focus point on her eyes as her head drifts, so autofocus tracks
	# the face the way a camera's does (at 200mm f/2.8 the zone of sharpness is
	# only a centimetre or so deep).
	if _marker and _head_index != -1:
		var moved = _skeleton.global_transform.basis * (_skeleton.get_bone_global_pose(_head_index).origin - _head_rest)
		_marker.global_position = _marker_rest + moved

	if _rig == null:
		return

	# Blinks (a blink that has started always finishes, even when paused).
	if playing:
		_next_blink -= delta
	if playing and _blink_time < 0.0 and _next_blink <= 0.0:
		_blink_time = 0.0
	var lid := 0.0
	if _blink_time >= 0.0:
		_blink_time += delta
		var t = _blink_time
		if t < BLINK_CLOSE:
			lid = smoothstep(0.0, BLINK_CLOSE, t)
		elif t < BLINK_CLOSE + BLINK_HOLD:
			lid = 1.0
		elif t < BLINK_CLOSE + BLINK_HOLD + BLINK_OPEN:
			lid = 1.0 - smoothstep(BLINK_CLOSE + BLINK_HOLD, BLINK_CLOSE + BLINK_HOLD + BLINK_OPEN, t)
		else:
			_blink_time = -1.0
			if not _double_blink and randf() < double_blink_chance:
				_double_blink = true
				_next_blink = 0.12
			else:
				_double_blink = false
				_next_blink = randf_range(blink_interval.x, blink_interval.y)
	_rig.set_control("CTRL_L_eye_blink.ty", lid)
	_rig.set_control("CTRL_R_eye_blink.ty", lid)

	# Eyes: hold a point, then flick to a nearby one (a saccade takes ~50 ms).
	if playing:
		_next_saccade -= delta
	if playing and _next_saccade <= 0.0:
		_gaze_target = Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * gaze_range
		_next_saccade = randf_range(saccade_interval.x, saccade_interval.y)
	_gaze = _gaze.lerp(_gaze_target, minf(1.0, delta / 0.05))
	for side in ["L", "R"]:
		_rig.set_control("CTRL_%s_eye.tx" % side, _gaze.x)
		_rig.set_control("CTRL_%s_eye.ty" % side, _gaze.y)
