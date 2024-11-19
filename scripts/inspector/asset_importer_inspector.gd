class_name AssetImporterInspectorPlugin
extends EditorInspectorPlugin

var slot_boxes = {}
var inspector
var importer

func _can_handle(node):
	return node is HumanizerAssetImporter
	
func _parse_category(_importer, category):
	#print("parsing asset importer")
	if category != 'asset_importer.gd':
		return
	importer = _importer
	inspector = HumanizerAPI.load_resource("res://addons/humanizer/scenes/inspector/asset_importer_inspector.tscn").instantiate()
	add_custom_control(inspector)
	
	slot_boxes = {}
	for slots_cat:HumanizerSlotCategory in HumanizerGlobalConfig.config.equipment:
		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = "--- " + slots_cat.category + " ---"
		inspector.get_node('%SlotsContainer').add_child(label)
		var container = HFlowContainer.new()
		for slot in slots_cat.slots:
			var checkbox = CheckBox.new()
			checkbox.text = slot
			container.add_child(checkbox)
			slot_boxes[slot+slots_cat.suffix] = checkbox
		if not importer.file_changed.is_connected(fill_options):
			importer.file_changed.connect(fill_options)
		inspector.get_node('%SlotsContainer').add_child(container)
		#print(slots_cat.category)
		
	fill_options()
	inspector.get_node('%ImportButton').pressed.connect(import_asset)

	
func fill_options():
	reset_checkboxes()
	var json_path = get_import_settings_path()
	if FileAccess.file_exists(json_path):
		#print("loading json")
		var settings = HumanizerUtils.read_json(json_path)
		for slot in settings.slots:
			slot_boxes[slot].button_pressed = true
	else:
		#print("loading resource")
		#try new resource naming convention first
		var res_path = get_equipment_resource_path()
		if not FileAccess.file_exists(res_path):
			#old naming convention has to be loaded from mhclo
			var mhclo := MHCLO.new()
			mhclo.parse_file(importer.asset_path)
			res_path = importer.asset_path.get_base_dir()
			res_path = res_path.path_join(mhclo.resource_name + ".res")
			print(res_path)
		var equip_res : HumanizerEquipmentType = HumanizerAPI.load_resource(res_path)
		for slot in equip_res.slots:
			slot_boxes[slot].button_pressed = true

func reset_checkboxes():
	for box in slot_boxes.values():
		box.button_pressed = false		

func import_asset():
	#print("importing asset")
	var import_settings = {}
	import_settings.version = 1.0
	var slot_list = []
	for slot_name in slot_boxes:
		if slot_boxes[slot_name].button_pressed:
			slot_list.append(slot_name)
	import_settings.slots = slot_list
	import_settings.mhclo = importer.asset_path
	var save_file = get_import_settings_path()
	HumanizerUtils.save_json(save_file,import_settings)
	HumanizerEquipmentImportService.import(save_file)
	
func get_import_settings_path()->String:
	var save_file = importer.asset_path.get_basename()
	save_file += ".import_settings.json"
	#print(save_file)
	return save_file

func get_equipment_resource_path()->String:
	var res_path = importer.asset_path.get_basename()
	res_path += ".res"
	return res_path
	
