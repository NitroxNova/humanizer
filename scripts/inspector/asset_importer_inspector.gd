class_name AssetImporterInspectorPlugin
extends EditorInspectorPlugin

var slot_boxes = {}
var import_settings := {}
var inspector:Control
var importer

func _can_handle(node):
	return node is HumanizerAssetImporter
	
func _parse_category(_importer, category):
	#print("parsing asset importer")
	if category != 'asset_importer.gd':
		#print("Category: " + category + " , is not asset_importer.gd")
		return
	importer = _importer
	inspector = HumanizerResourceService.load_resource("res://addons/humanizer/scenes/inspector/asset_importer_inspector.tscn").instantiate()
	add_custom_control(inspector)
	slot_boxes = {}
	for slots_cat:HumanizerSlotCategory in HumanizerGlobalConfig.config.equipment_slots:
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
	var selected = inspector.get_node('%BoneOptions').get_selected()
	add_attach_bone(inspector.get_node('%BoneOptions').get_item_text(selected))

func add_attach_bone(text):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.name = "Label"
	label.text = text
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

func fill_material_options():
	var options :OptionButton = inspector.get_node('%DefaultMaterial')
	options.clear()
	options.add_item(" -- None (Random) --")
	options.set_item_metadata(0,"")
	var mat_list = HumanizerMaterialService.search_for_materials(get_mhclo_path())
	for mat_id in mat_list:
		var mat_res = HumanizerResourceService.load_resource(mat_list[mat_id])
		var mat_name = mat_res.resource_name
		var idx = options.item_count
		options.add_item(mat_name)
		options.set_item_metadata(idx,mat_id)
	
	for idx in options.get_item_count():
		var mat_id = options.get_item_metadata(idx)
		if mat_id == import_settings.default_material:
			options.selected = idx
		
func fill_options(path:String=""):
	#print("fill options")
	for box in slot_boxes.values():
		box.button_pressed = false
	var mhclo_path = get_mhclo_path()
	for child in inspector.get_node('%BoneList').get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	inspector.get_node('%GLB_Label').text = ""
	inspector.get_node('%LoadRiggedGLB').current_dir = mhclo_path.get_base_dir()
	
	import_settings = HumanizerEquipmentImportService.load_import_settings(mhclo_path)
	fill_material_options()
	var folder_override = HumanizerGlobalConfig.config.get_folder_override_slots(mhclo_path)
	
	if folder_override.is_empty():
		inspector.get_node('%SlotsDisabledLabel').hide()
		for slot in import_settings.slots:
			slot_boxes[slot].button_pressed = true 
		for slot in slot_boxes:	
			slot_boxes[slot].disabled = false
	else:
		inspector.get_node('%SlotsDisabledLabel').show()
		for slot in folder_override:
			slot_boxes[slot].button_pressed = true 
		for slot in slot_boxes:	
			slot_boxes[slot].disabled = true
	inspector.get_node('%DisplayName').text = import_settings.display_name
	inspector.get_node('%GLB_Label').text = import_settings.rigged_glb
	for bone in import_settings.attach_bones:
		add_attach_bone(bone)
	inspector.get_node('%DisplayName').text = import_settings.display_name
	if inspector.get_node('%GLB_Label').text == "":
		inspector.get_node('%GLB_Label').text = HumanizerEquipmentImportService.search_for_rigged_glb(mhclo_path)	
		
func get_mhclo_path():
	return inspector.get_node('%MHCLO_Label').text

func import_asset():
	#print("importing asset")
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
	var select_material = inspector.get_node('%DefaultMaterial').selected
	import_settings.default_material = inspector.get_node('%DefaultMaterial').get_item_metadata(select_material)
	import_settings.rigged_glb = inspector.get_node('%GLB_Label').text
	import_settings.attach_bones = []
	for hbox in inspector.get_node('%BoneList').get_children():
		var label = hbox.get_node("Label")
		import_settings.attach_bones.append(label.text)
	var save_file = HumanizerEquipmentImportService.get_import_settings_path(get_mhclo_path())
	HumanizerUtils.save_json(save_file,import_settings)
	HumanizerEquipmentImportService.import(save_file)
	HumanizerRegistry.load_all()
	
