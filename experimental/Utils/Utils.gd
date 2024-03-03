extends Resource
class_name Utils

const MH_Scale_Factor = 0.10000000149011612

#requires that the mh_id already be set in the Custom0 array, which happens in the obj_to_mesh importer
static func get_mh2gd_index_from_mesh(input_mesh:ArrayMesh):
	var mh2gd_index = []
	var sf_arrays = input_mesh.surface_get_arrays(0)
	for gd_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = sf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		if not mh_id < mh2gd_index.size():
			mh2gd_index.resize(mh_id + 1)
		if mh2gd_index[mh_id] == null:
			mh2gd_index[mh_id] = PackedInt32Array()
		mh2gd_index[mh_id].append(gd_id)
	return mh2gd_index

static func create_unique_index(input_array:Array,keep_values=false):
	var unique_values = {}
	for v in input_array.size():
		var value = input_array[v]
		if not value in unique_values:
			unique_values[value] = []
		unique_values[value].append(v)
	if keep_values:
		return unique_values
	else:
		return unique_values.values()

static func read_json(file_name:String):
	var json_as_text = FileAccess.get_file_as_string(file_name)
	var json_as_dict = JSON.parse_string(json_as_text)
	return json_as_dict
	
static func save_json(file_path, data):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_line(JSON.stringify(data))
	
static func vector3_to_array(vec:Vector3):
	var array = []
	array.append(vec.x)
	array.append(vec.y)
	array.append(vec.z)
	return array

static func array_to_vector3(array:Array):
	var vec = Vector3(array[0],array[1],array[2])
	return vec
	
static func generate_normals_tangents(import_mesh:ArrayMesh):
	var ST = SurfaceTool.new()
	ST.clear()
	ST.create_from(import_mesh,0)
	ST.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	ST.generate_normals()
	ST.generate_tangents()
	var flags = import_mesh.surface_get_format(0)
	var new_mesh = ST.commit(null,flags)
	return new_mesh
