@tool
extends RefCounted
class_name HumanizerUtils

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

static func read_json(file_name:String):
	var json_as_text = FileAccess.get_file_as_string(file_name)
	var json_as_dict = JSON.parse_string(json_as_text)
	return json_as_dict
	
static func save_json(file_path, data):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_line(JSON.stringify(data))

static func get_shapekey_data() -> Dictionary:
	var shapekey_data: Dictionary
	var file := FileAccess.open("res://addons/humanizer/data/resources/shapekeys.dat", FileAccess.READ)	
	shapekey_data = file.get_var(true)
	file.close()
	return shapekey_data

static var _shapekey_data: Dictionary = {}
static var shapekey_data: Dictionary:
	get:
		if _shapekey_data.size() == 0:
			_shapekey_data = get_shapekey_data()
		return _shapekey_data

static func get_shapekey_categories() -> Dictionary:
	var categories := {
		'Macro': [],
		'Race': [],
		'Head': [],
		'Eyes': [],
		'Mouth': [],
		'Nose': [],
		'Ears': [],
		'Face': [],
		'Neck': [],
		'Chest': [],
		'Breasts': [],
		'Hips': [],
		'Arms': [],
		'Legs': [],
		'Misc': [],
		'Custom': [],
	}
	for raw_name in shapekey_data.shapekeys:
		var name = raw_name.to_lower()
		if 'penis' in name:# or name.ends_with('firmness'):
			continue
		if name in shapekey_data.macro_shapekeys:
			continue
		elif name.begins_with('custom'):
			categories['Custom'].append(raw_name)
		elif 'head' in name or 'brown' in name or 'top' in name:
			categories['Head'].append(raw_name)
		elif 'eye' in name:
			categories['Eyes'].append(raw_name)
		elif 'mouth' in name:
			categories['Mouth'].append(raw_name)
		elif 'nose' in name:
			categories['Nose'].append(raw_name)
		elif 'ear' in name:
			categories['Ears'].append(raw_name)
		elif 'jaw' in name or 'cheek' in name or 'temple' in name or 'chin' in name:
			categories['Face'].append(raw_name)
		elif 'arm' in name or 'hand' in name or 'finger' in name or 'wrist' in name:
			categories['Arms'].append(raw_name)
		elif 'leg' in name or 'calf' in name or 'foot' in name or 'butt' in name or 'ankle' in name or 'thigh' in name or 'knee' in name:
			categories['Legs'].append(raw_name)
		elif 'cup' in name or 'bust' in name or 'breast' in name or 'nipple' in name:
			categories['Breasts'].append(raw_name)
		elif 'torso' in name or 'chest' in name or 'shoulder' in name:
			categories['Chest'].append(raw_name)
		elif 'hip' in name or 'trunk' in name or 'pelvis' in name or 'waist' in name or 'pelvis' in name or 'stomach' in name or 'bulge' in name:
			categories['Hips'].append(raw_name)
		elif 'hand' in name or 'finger' in name:
			categories['Hands'].append(raw_name)
		elif 'neck' in name:
			categories['Neck'].append(raw_name)
		else:
			categories['Misc'].append(raw_name)
	
	categories['Macro'] = MeshOperations.get_macro_options()
	categories['Race'].append_array(MeshOperations.get_race_options())
	categories['Macro'].erase('cupsize')
	categories['Macro'].erase('firmness')
	categories['Breasts'].append('cupsize')
	categories['Breasts'].append('firmness')
	return categories
	
