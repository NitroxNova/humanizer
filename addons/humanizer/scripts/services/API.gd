@tool
extends Node

# called when enters the editor AND when enters the game
func _ready() -> void:
	var path = "res://humanizer"
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)
	if not DirAccess.dir_exists_absolute(path+"/target"):
		DirAccess.make_dir_absolute(path+"/target")
	if not DirAccess.dir_exists_absolute(path+"/material"):
		DirAccess.make_dir_absolute(path+"/material")
	if not DirAccess.dir_exists_absolute(path+"/equipment"):
		DirAccess.make_dir_absolute(path+"/equipment")
	HumanizerRegistry._get_rigs()
	if Engine.is_editor_hint():
		pass
		#mod loading isnt supported in the editor by default,
		#will manually scan the zip here instead, and add to the registry
	else:
		
		HumanizerTargetService.load_data()
		HumanizerRegistry._load_equipment()
		HumanizerRegistry._get_materials()
		HumanizerRegistry.load_animations()
		
		var any_zips_loaded = false
		var existing_files = [] #cant use dirAccess.get_files_at for existing files once a 'resource pack' is loaded
		for folder in ProjectSettings.get_setting("addons/humanizer/asset_import_paths"):
			existing_files.append_array(OSPath.get_files_recursive(folder))
		for file_path in existing_files:
			if file_path.get_extension() == "zip":
				ProjectSettings.load_resource_pack(file_path)
				any_zips_loaded = true
		
		if any_zips_loaded:
			HumanizerTargetService.load_data()
			HumanizerRegistry._load_equipment()
			HumanizerRegistry._get_materials()
			HumanizerRegistry.load_animations()
