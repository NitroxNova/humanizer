# Reads mh target files to collect and cache data for all shapekeys
class_name ShapeKeyReader
extends RefCounted

var target_data : HumanizerTargetData

# Process the shape key data.
func run():
	if OSPath.get_contents(HumanizerGlobalConfig.config.asset_import_paths[0].path_join("targets")).dirs.is_empty():
		printerr("missing core target files, download from https://github.com/makehumancommunity/makehuman/tree/master/makehuman/data/targets")
		printerr("and copy them to " + HumanizerGlobalConfig.config.asset_import_paths[0].path_join("targets"))
		return
	
	print('Collecting shape key data from target files')
	target_data = HumanizerTargetData.new()
	HumanizerTargetService.data = target_data #clear reference to file
	DirAccess.remove_absolute("res://addons/humanizer/data/resources/target_data.res")
	
	# Load helper mesh and index vertices
	var helper_mesh: ArrayMesh = HumanizerAPI.load_resource('res://addons/humanizer/data/resources/base_helpers.res')
	var helper_vertices = helper_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(helper_mesh)

	# Make basis shapekey
	for mh_index in mh2gd_index.size():
		var g_index = mh2gd_index[mh_index][0]
		var coords = helper_vertices[g_index]
		target_data.basis.append(coords)

	# Get individual shapekey data
	for path in HumanizerGlobalConfig.config.asset_import_paths:
		_get_shape_keys(path + 'targets/')
	
	ResourceSaver.save(target_data,"res://addons/humanizer/data/resources/target_data.res")	
	
	HumanizerTargetService.data = HumanizerAPI.load_resource("res://addons/humanizer/data/resources/target_data.res")
	print('Finished collecting shapekey data')

func _process_shapekey(path: String,prefix:String=""):
	var start_offset = target_data.index.size()
	var shape_name = prefix + path.get_file().get_basename()
	var target_file = FileAccess.open(path, FileAccess.READ)

	while target_file.get_position() < target_file.get_length():
		var line = target_file.get_line()
		if line.begins_with('#'):
			continue
		var floats = line.split_floats(" ")
		var mh_id = int(floats[0])
		var coords = Vector3(floats[1],floats[2],floats[3])
		coords *= 0.1 # Original scale
		if coords != Vector3.ZERO:
			target_data.coords.append(coords)
			target_data.index.append(mh_id)
			
	if shape_name in target_data.names:
		print("duplicate name, overwriting target data : " + shape_name)
	target_data.names[shape_name] = [start_offset,target_data.index.size()]
		
func _get_shape_keys(path,prefix=""):
	var contents = OSPath.get_contents(path)
	for dir in contents.dirs:
		if path.ends_with("expression/units"): #expression units 
			prefix = dir.get_file()+"-"
		_get_shape_keys(dir,prefix)

	for file in contents.files:
		if file.get_extension() == 'target':
			_process_shapekey(file,prefix)
