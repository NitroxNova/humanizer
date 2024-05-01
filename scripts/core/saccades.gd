@tool
extends Node

@export var enabled: bool = true:
	set(value):
		enabled = value
		if enabled:
			if get_tree() != null:
				_set_saccades_timer()
				_set_blink_timer()
		else:
			_saccades_timer.timeout.disconnect(_saccade)
			_blink_timer.timeout.disconnect(_blink)
			skeleton.reset_bone_poses()
@export_range(0.01, 5) var _saccades_timeout: float = 1
@export_range(0.01, 5) var _blink_timeout: float = 1

@onready var skeleton: Skeleton3D = $'../GeneralSkeleton'
@onready var _saccades_timer: SceneTreeTimer
@onready var _blink_timer: SceneTreeTimer
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_set_saccades_timer()
	_set_blink_timer()

func _set_saccades_timer() -> void:
	if enabled:
		_saccades_timer = get_tree().create_timer(_saccades_timeout * _rng.randf_range(0.3, 3))
		_saccades_timer.timeout.connect(_saccade)

func _set_blink_timer() -> void:
	if enabled:
		_blink_timer = get_tree().create_timer(_blink_timeout * _rng.randf_range(0.33, 3))
		_blink_timer.timeout.connect(_blink)
	
func _saccade() -> void:
	if skeleton == null:
		return
	var left_eyelid = skeleton.find_bone(&'orbicularis03.L')
	var right_eyelid = skeleton.find_bone(&'orbicularis03.R')
	var left_lower_lid = skeleton.find_bone(&'orbicularis04.L')
	var right_lower_lid = skeleton.find_bone(&'orbicularis04.R')
	var left_eye = skeleton.find_bone(&'LeftEye')
	var right_eye = skeleton.find_bone(&'RightEye')
	var rotation := Quaternion.from_euler(Vector3(_rng.randf_range(-.2, .12), 0, _rng.randf_range(-.3, .3)))
	var lid_rotation := Quaternion.from_euler(Vector3(rotation.get_euler().x, 0, 0))
	
	skeleton.set_bone_pose_rotation(left_eye, skeleton.get_bone_rest(left_eye).basis.get_rotation_quaternion() * rotation)
	skeleton.set_bone_pose_rotation(left_eyelid, skeleton.get_bone_rest(left_eyelid).basis.get_rotation_quaternion() * lid_rotation)
	skeleton.set_bone_pose_rotation(left_lower_lid, skeleton.get_bone_rest(left_lower_lid).basis.get_rotation_quaternion() * lid_rotation)

	skeleton.set_bone_pose_rotation(right_eye, skeleton.get_bone_rest(right_eye).basis.get_rotation_quaternion() * rotation)
	skeleton.set_bone_pose_rotation(right_eyelid, skeleton.get_bone_rest(right_eyelid).basis.get_rotation_quaternion() * lid_rotation)
	skeleton.set_bone_pose_rotation(right_lower_lid, skeleton.get_bone_rest(right_lower_lid).basis.get_rotation_quaternion() * lid_rotation)
	_set_saccades_timer()
	
func _blink() -> void:
	if skeleton == null:
		return
	var left_blink = Quaternion(0.17, -0.055, 0.05, 0.82).normalized()
	var right_blink = Quaternion(0.17, 0.055, -0.05, 0.82).normalized()
	var bone: int
	var left_eyelid = skeleton.find_bone(&'orbicularis03.L')
	var right_eyelid = skeleton.find_bone(&'orbicularis03.R')
	var prev_pose = skeleton.get_bone_pose_rotation(left_eyelid)
	
	skeleton.set_bone_pose_rotation(left_eyelid, left_blink * prev_pose)
	skeleton.set_bone_pose_rotation(right_eyelid, right_blink * prev_pose)
	await get_tree().create_timer(0.1).timeout
	skeleton.set_bone_pose_rotation(left_eyelid, prev_pose)
	skeleton.set_bone_pose_rotation(right_eyelid, prev_pose)
	_set_blink_timer()
