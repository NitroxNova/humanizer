class_name OSPath
extends RefCounted


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
	else:
		print("An error occurred when trying to access the path : " + path)
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
	else:
		print("An error occurred when trying to access the path : " + path)
	return files
