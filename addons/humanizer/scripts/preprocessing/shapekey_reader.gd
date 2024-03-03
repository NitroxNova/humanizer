# Reads mh target files to collect and cache data for all shapekeys
class_name ShapeKeyReader
extends RefCounted

var shapekey_data := {}

# Process the shape key data.
func run():
	print('Collecting shape key data from target files')
	shapekey_data = {}
	
	# Load helper mesh and index vertices
	var helper_mesh: ArrayMesh = load('res://addons/humanizer/data/resources/base_helpers.res')
	var helper_vertices = helper_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(helper_mesh)

	# Make basis shapekey
	shapekey_data.basis = []
	for mh_index in mh2gd_index.size():
		var g_index = mh2gd_index[mh_index][0]
		var coords = helper_vertices[g_index]
		shapekey_data.basis.append(coords)

	# Get individual shapekey data
	shapekey_data.shapekeys = {}
	for path in HumanizerConfig.asset_import_paths:
		_get_shape_keys(path + 'targets/')
	var file := FileAccess.open("res://addons/humanizer/data/resources/shapekeys.dat", FileAccess.WRITE)
	file.store_var(shapekey_data.basis)
	file.store_var(shapekey_data.shapekeys)
	file.close()
	print('Finished collecting shapekey data')

func _process_shapekey(path: String):
	var shape_name = path.get_file().get_basename()
	shapekey_data.shapekeys[shape_name] = {}
	var target_file = FileAccess.open(path, FileAccess.READ)

	while target_file.get_position() < target_file.get_length():
		var line = target_file.get_line()
		if line.begins_with('#'):
			continue
		var floats = line.split_floats(" ")
		var sk_index = int(floats[0])
		var sk_coords = Vector3(floats[1],floats[2],floats[3])
		sk_coords *= 0.1 # Original scale
		shapekey_data.shapekeys[shape_name][sk_index] = sk_coords
		
func _get_shape_keys(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_get_shape_keys(path + file_name + '/')
			elif file_name.get_extension() == "target":
				_process_shapekey(path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("An error occurred when trying to access the path.")
