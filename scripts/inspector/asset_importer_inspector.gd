class_name AssetImporterInspectorPlugin
extends EditorInspectorPlugin

var asset_path = ""
var slot_boxes = {}
var inspector_scene

func _can_handle(node):
	return node is HumanizerAssetImporter
	
func _parse_category(importer, category):
	#print("parsing asset importer")
	if category != 'asset_importer.gd':
		return
	inspector_scene = load("res://addons/humanizer/scenes/inspector/asset_importer_inspector.tscn").instantiate()
	add_custom_control(inspector_scene)
	
	slot_boxes = {}
	for slots_cat:HumanizerSlotCategory in HumanizerGlobalConfig.config.equipment:
		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = "--- " + slots_cat.category + " ---"
		inspector_scene.get_node('%SlotsContainer').add_child(label)
		var container = HFlowContainer.new()
		for slot in slots_cat.slots:
			var checkbox = CheckBox.new()
			checkbox.text = slot
			container.add_child(checkbox)
			slot_boxes[slot+slots_cat.suffix] = checkbox
		inspector_scene.get_node('%SlotsContainer').add_child(container)
		#print(slots_cat.category)
	if not importer.file_changed.is_connected(asset_path_changed):
		importer.file_changed.connect(asset_path_changed)
	inspector_scene.get_node('%ImportButton').pressed.connect(import_asset)

func fill_options_from_file():
	pass
	#for slot in slot_boxes:
		

func asset_path_changed(path):
	print("asset path changed")
	asset_path = path

func import_asset():
	#print("importing asset")
	var import_settings = {}
	import_settings.version = 1.0
	var slot_list = []
	for slot_name in slot_boxes:
		if slot_boxes[slot_name].button_pressed:
			slot_list.append(slot_name)
	import_settings.slots = slot_list
	import_settings.mhclo = asset_path
	var save_file = asset_path.get_basename()
	save_file += ".import_settings.json"
	HumanizerUtils.save_json(save_file,import_settings)
	
