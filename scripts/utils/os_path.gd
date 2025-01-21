class_name OSPath
extends RefCounted

static func is_folder_empty(folder:String):
	var contents = get_contents(folder)
	if contents.dirs.size() == 0 and contents.files.size() == 0:
		return true
	return false
	
static func delete_empty_folders(folder:String):
	for dir in DirAccess.get_directories_at(folder):
		delete_empty_folders(folder.path_join(dir))
	if is_folder_empty(folder):
		DirAccess.remove_absolute(folder)

static func read_json(file_name:String): #Array or Dictionary
	var json_as_text = FileAccess.get_file_as_string(file_name)
	var json_as_dict = JSON.parse_string(json_as_text)
	return json_as_dict
	
static func save_json(file_path, data):
	#print(file_path)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_line(JSON.stringify(data))

static func get_files_recursive(path:String):
	var paths = []
	#if not DirAccess.dir_exists_absolute(path): #dont do this, it returns false when loaded from zip, but get_files_at still works..
	for file in DirAccess.get_files_at(path):
		paths.append(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):
		paths.append_array(get_files_recursive(path.path_join(dir)))
	return paths

static func get_contents(path: String) -> Dictionary:
	return {'dirs': OSPath.get_dirs(path), 'files': OSPath.get_files(path)}

static func get_dirs(path: String) -> Array[String]:
	var dirs: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var dir_name = dir.get_next()
		while dir_name != "":
			if dir.current_is_dir():
				dirs.append(dir.get_current_dir().path_join(dir_name))
			dir_name = dir.get_next()
	return dirs

static func get_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				files.append(dir.get_current_dir().path_join(file_name))
			file_name = dir.get_next()
	return files
