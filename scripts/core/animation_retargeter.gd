@tool 
extends Node

## Click to convert
@export var _convert: bool:
	set(value):
		if value:
			convert_library()
		_convert = false
## The t-pose animation library that you want to convert
@export var library: AnimationLibrary
## The output folder
@export_dir var output_path

@export var human: Humanizer


func convert_library() -> void:
	if not DirAccess.dir_exists_absolute(output_path):
		push_error(output_path + ' is not an existing folder')
		return
	if library == null:
		push_error('Please provide an input library')
	push_warning('Retargeting animation library')
	human.animator.active = false
	var skeleton : Skeleton3D = human.skeleton
	skeleton.reset_bone_poses()
	var anim : AnimationPlayer = human.animator.get_child(0)

	var apose_rest = []
	for bone in skeleton.get_bone_count():
		#apose_rest.append(skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion())
		apose_rest.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	anim.add_animation_library('tpose', load("res://addons/humanizer/data/animations/tpose.glb"))
	anim.play('tpose/tpose')

	# Wait for pose to take.  It could give bad results if skinning shader gets delayed
	await get_tree().create_timer(1.).timeout
	var tpose_rest = []
	for bone in skeleton.get_bone_count():
		#tpose_rest.append(skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion())
		tpose_rest.append(skeleton.get_bone_pose(bone).basis.get_rotation_quaternion())
	
	var new_library := AnimationLibrary.new()
	for animation in library.get_animation_list():
		var clip : Animation = library.get_animation(animation)
		var new_clip := Animation.new()
		new_library.add_animation(animation, new_clip)
		for track in clip.get_track_count():
			new_clip.add_track(clip.track_get_type(track))
			new_clip.track_set_path(track, clip.track_get_path(track))
			new_clip.length = clip.length
			new_clip.loop_mode = clip.loop_mode
			for key in clip.track_get_key_count(track):
				var t = clip.track_get_key_time(track, key)
				if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
					var bone_name = str(clip.track_get_path(track)).split(':')[-1]
					var bone = skeleton.find_bone(bone_name)
					if bone == -1:
						continue
					var rotation : Quaternion = clip.track_get_key_value(track, key)
					var tpose_to_apose : Quaternion = apose_rest[bone].inverse() * tpose_rest[bone]
					new_clip.track_insert_key(track, t, rotation * tpose_to_apose)
				else:  # Just copy other track types
					new_clip.track_insert_key(track, t, clip.track_get_key_value(track, key))
	var libname = library.resource_path.get_file().get_basename()
	ResourceSaver.save(new_library, output_path.path_join(libname + '.res'))
	anim.add_animation_library(libname, load(output_path.path_join(libname + '.res')))
