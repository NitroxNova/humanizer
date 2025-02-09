class_name HumanizerImageImportSettings

func run():
	set_asset_import_settings()

func set_asset_import_settings():
	for path in HumanizerGlobalConfig.config.asset_import_paths:
		for dir in OSPath.get_dirs(path):
			set_import_settings_on_file(dir)
				
func set_import_settings_on_file(path:String):
	for dir in OSPath.get_dirs(path):
		set_import_settings_on_file(dir)
	for file_name in OSPath.get_files(path):
		if file_name.ends_with("png.import"):
			var file = FileAccess.open(file_name, FileAccess.READ_WRITE)
			var content = file.get_as_text()
			content = content.replace("compress/normal_map=0","compress/normal_map=2")
			content = content.replace("compress/normal_map=1","compress/normal_map=2")
			content = content.replace("compress/mode=0","compress/mode=3")
			content = content.replace("compress/mode=1","compress/mode=3")
			content = content.replace("compress/mode=2","compress/mode=3")
			content = content.replace("compress/mode=4","compress/mode=3")
			file.store_string(content)
