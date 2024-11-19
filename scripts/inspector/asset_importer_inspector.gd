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
		#print("Category: " + category + " , is not asset_importer.gd")
		return
	importer = _importer
	inspector = load("res://addons/humanizer/scenes/inspector/asset_importer_inspector.tscn").instantiate()
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
		inspector.get_node('%SlotsContainer').add_child(container)
	
	if not inspector.get_node('%MHCLO_FileLoader').file_selected.is_connected(fill_options):
		inspector.get_node('%MHCLO_FileLoader').file_selected.connect(fill_options)
	inspector.get_node('%MHCLO_FileLoader').current_dir = HumanizerGlobalConfig.config.asset_import_paths[-1].path_join("equipment")
	

	
	inspector.get_node('%SkeletonOptions').add_item(" -- Select Skeleton --")
	var rigs = HumanizerRegistry.rigs
	for rig in rigs:
		if rigs[rig].skeleton_retargeted_path != '':
			inspector.get_node('%SkeletonOptions').add_item(rig + '-RETARGETED')
		if rigs[rig].skeleton_path != '':
			inspector.get_node('%SkeletonOptions').add_item(rig)
	inspector.get_node('%SkeletonOptions').item_selected.connect(fill_bone_options)		
	#fill_options()
	
	inspector.get_node('%AddBoneButton').pressed.connect(_add_bone_pressed)
	inspector.get_node('%ImportButton').pressed.connect(import_asset)

func _add_bone_pressed():
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.name = "Label"
	var selected = inspector.get_node('%BoneOptions').get_selected()
	label.text = inspector.get_node('%BoneOptions').get_item_text(selected)
	hbox.add_child(label)
	var button = Button.new()
	button.text = " Remove "
	button.size_flags_horizontal = Control.SIZE_SHRINK_END + Control.SIZE_EXPAND
	button.pressed.connect(_remove_bone_pressed.bind(hbox))
	hbox.add_child(button)
	inspector.get_node('%BoneList').add_child(hbox)

func _remove_bone_pressed(node:Control):
	inspector.get_node('%BoneList').remove_child(node)

func fill_bone_options(idx:int):
	inspector.get_node('%BoneOptions').clear()
	if idx == 0: #  -- select skeleton -- 
		return
		
	var rig_name = inspector.get_node('%SkeletonOptions').get_item_text(idx)
	var retargeted: bool = rig_name.ends_with('-RETARGETED')
	var rig = HumanizerRigService.get_rig(rig_name)
	var skeleton_data = HumanizerRigService.init_skeleton_data(rig,retargeted)
	for bone_name in skeleton_data:
		inspector.get_node('%BoneOptions').add_item(bone_name)

func fill_options(path:String=""):
	#print("fill options")
	reset_checkboxes()
	inspector.get_node('%GLB_Label').text = ""
	inspector.get_node('%LoadRiggedGLB').current_dir = inspector.get_node('%MHCLO_Label').text.get_base_dir()
	var json_path = get_import_settings_path()
	if FileAccess.file_exists(json_path):
		#print("loading json")
		var settings = HumanizerUtils.read_json(json_path)
		for slot in settings.slots:
			slot_boxes[slot].button_pressed = true
		inspector.get_node('%DisplayName').text = settings.display_name
		inspector.get_node('%GLB_Label').text = settings.rigged_glb
	else:
		#print("loading resource")
		#try new resource naming convention first
		var res_path = get_equipment_resource_path()
		if not FileAccess.file_exists(res_path):
			#old naming convention has to be loaded from mhclo
			var mhclo := MHCLO.new()
			mhclo.parse_file(inspector.get_node('%MHCLO_Label').text)
			res_path = inspector.get_node('%MHCLO_Label').text.get_base_dir()
			res_path = res_path.path_join(mhclo.display_name + ".res")
			inspector.get_node('%DisplayName').text = mhclo.display_name
		#print(res_path)
		var equip_res : HumanizerEquipmentType = load(res_path)
		for slot in equip_res.slots:
			slot_boxes[slot].button_pressed = true
	if inspector.get_node('%GLB_Label').text == "":
		inspector.get_node('%GLB_Label').text = HumanizerEquipmentImportService.search_for_rigged_glb(inspector.get_node('%MHCLO_Label').text)
		
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
	import_settings.mhclo = inspector.get_node('%MHCLO_Label').text 
	import_settings.display_name = inspector.get_node('%DisplayName').text 
	if import_settings.display_name.strip_edges() == "":
		var string_id = import_settings.mhclo.get_basename().get_file()
		printerr("No display name set, using string ID " + string_id) 
	import_settings.rigged_glb = inspector.get_node('%GLB_Label').text
	import_settings.attach_bones = []
	for hbox in inspector.get_node('%BoneList').get_children():
		var label = hbox.get_node("Label")
		import_settings.attach_bones.append(label.text)
	var save_file = get_import_settings_path()
	HumanizerUtils.save_json(save_file,import_settings)
	HumanizerEquipmentImportService.import(save_file)
	
func get_import_settings_path()->String:
	var save_file = inspector.get_node('%MHCLO_Label').text.get_basename()
	save_file += ".import_settings.json"
	#print(save_file)
	return save_file

func get_equipment_resource_path()->String:
	var res_path = inspector.get_node('%MHCLO_Label').text.get_basename()
	res_path += ".res"
	return res_path
	
