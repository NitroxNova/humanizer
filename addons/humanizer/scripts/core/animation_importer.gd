@tool
extends Node

@export var run = false:
	set(value):
		create_import_settings()
		create_animation_resource()
		
@export var input_folder = "res://addons/humanizer/data/animations/Input/"
@export var output_name = "animations"
@export var output_folder = "res://addons/humanizer/data/animations/Output/"
@export var add_root = true

func create_import_settings():
	var import_text = FileAccess.open("res://addons/humanizer/data/animations/import_settings.txt", FileAccess.READ).get_as_text()
	var ep = EditorPlugin.new()
	for file_name in OSPath.get_files(input_folder):
		if file_name.get_extension() == "fbx":
			var import_filename = file_name + ".import"	
			FileAccess.open(import_filename, FileAccess.WRITE).store_string(import_text.replace("FBX_FILE_NAME",file_name))
			ep.get_editor_interface().get_resource_filesystem().update_file(file_name)
			ep.get_editor_interface().get_resource_filesystem().reimport_files(PackedStringArray([file_name]))
	ep.free()

func create_animation_resource():
	var anim_lib = AnimationLibrary.new()
	for file_name in OSPath.get_files(input_folder):
		if file_name.get_extension() == "fbx":
			var curr_lib : AnimationLibrary = HumanizerResourceService.load_resource(file_name)
			var loop = false
			if file_name.get_file().get_basename().to_lower().ends_with("-loop"):
				loop = true
			for anim_name in curr_lib.get_animation_list():
				var anim : Animation = curr_lib.get_animation(anim_name)
				if loop or anim_name.to_lower().ends_with("-loop"):
					anim.loop_mode = Animation.LOOP_LINEAR
				if add_root:
					#add root as first track
					var root_pos_track:int = 0
					anim.add_track(Animation.TYPE_POSITION_3D,root_pos_track)
					anim.track_set_path(root_pos_track,"%GeneralSkeleton:Root")
					var hips_pos_track:int = anim.find_track("%GeneralSkeleton:Hips",Animation.TYPE_POSITION_3D)
					if hips_pos_track > -1:
						for key in anim.track_get_key_count(hips_pos_track):
							var value = anim.track_get_key_value(hips_pos_track,key)
							var time = anim.track_get_key_time(hips_pos_track,key)
							var root_pos = Vector3(value.x,0,value.z)
							var hips_pos = Vector3(0,value.y,0)
							anim.position_track_insert_key(root_pos_track,time,root_pos)
							anim.track_set_key_value(hips_pos_track,key,hips_pos)
				#assuming theres only 1 animation per fbx file (standard mixamo output)
				anim_lib.add_animation(file_name.get_file().get_basename(),anim)
	var file_name = output_folder.path_join(output_name+".res")
	var increment = 2
	while FileAccess.file_exists(file_name):
		file_name = output_folder.path_join(output_name + str(increment) + ".res")
		increment += 1
	ResourceSaver.save(anim_lib,file_name)
	
