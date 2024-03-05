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

