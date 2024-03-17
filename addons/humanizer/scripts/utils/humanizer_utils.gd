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
	
	shapekey_data.basis = file.get_var(true)
	shapekey_data.shapekeys = file.get_var(true)
	file.close()
	return shapekey_data

static func get_shapekey_categories() -> Dictionary:
	var shapekeys = get_shapekey_data()
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
	}
	for name in shapekeys.shapekeys:
		if 'penis' in name.to_lower():# or name.ends_with('firmness'):
			continue
		if 'caucasian' in name.to_lower() or 'african' in name.to_lower() or 'asian' in name.to_lower():
			continue#categories['RaceAge'].append(name)
		elif 'averagemuscle' in name.to_lower() or 'minmuscle' in name.to_lower() or 'maxmuscle' in name.to_lower():
			continue#categories['MuscleWeight'].append(name)
		elif 'head' in name.to_lower() or 'brown' in name.to_lower() or 'top' in name.to_lower():
			categories['Head'].append(name)
		elif 'eye' in name.to_lower():
			categories['Eyes'].append(name)
		elif 'mouth' in name.to_lower():
			categories['Mouth'].append(name)
		elif 'nose' in name.to_lower():
			categories['Nose'].append(name)
		elif 'ear' in name.to_lower():
			categories['Ears'].append(name)
		elif 'jaw' in name.to_lower() or 'cheek' in name.to_lower() or 'temple' in name.to_lower() or 'chin' in name.to_lower():
			categories['Face'].append(name)
		elif 'arm' in name.to_lower() or 'hand' in name.to_lower() or 'finger' in name.to_lower() or 'wrist' in name.to_lower():
			categories['Arms'].append(name)
		elif 'leg' in name.to_lower() or 'calf' in name.to_lower() or 'foot' in name.to_lower() or 'butt' in name.to_lower() or 'ankle' in name.to_lower() or 'thigh' in name.to_lower() or 'knee' in name.to_lower():
			categories['Legs'].append(name)
		elif 'cup' in name.to_lower() or 'bust' in name.to_lower() or 'breast' in name.to_lower() or 'nipple' in name.to_lower():
			categories['Breasts'].append(name)
		elif 'torso' in name.to_lower() or 'chest' in name.to_lower() or 'shoulder' in name.to_lower():
			categories['Chest'].append(name)
		elif 'hip' in name.to_lower() or 'trunk' in name.to_lower() or 'pelvis' in name.to_lower() or 'waist' in name.to_lower() or 'pelvis' in name.to_lower() or 'stomach' in name.to_lower() or 'bulge' in name.to_lower():
			categories['Hips'].append(name)
		elif 'hand' in name.to_lower() or 'finger' in name.to_lower():
			categories['Hands'].append(name)
		elif 'neck' in name.to_lower():
			categories['Neck'].append(name)
		else:
			categories['Misc'].append(name)
	
	categories['Macro'] = MeshOperations.get_macro_options()
	categories['Race'].append_array(MeshOperations.get_race_options())
	categories['Macro'].erase('cupsize')
	categories['Macro'].erase('firmness')
	categories['Breasts'].append('cupsize')
	categories['Breasts'].append('firmness')
	return categories
	
static func show_window(interior, closeable: bool = true, size=Vector2i(500, 500)) -> void:
	if not Engine.is_editor_hint():
		return
	var window = Window.new()
	if interior is PackedScene:
		interior = interior.instantiate()
	window.add_child(interior)	
	if closeable:
		window.close_requested.connect(func(): window.queue_free())
	window.size = size
	EditorInterface.popup_dialog_centered(window)

