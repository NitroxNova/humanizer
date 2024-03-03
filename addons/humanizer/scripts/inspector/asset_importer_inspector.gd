class_name AssetImporterInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(node):
	return node is HumanizerAssetImporter
	
func _parse_category(importer, category):
	if category != 'asset_importer.gd':
		return
	var scene = load("res://addons/humanizer/scenes/inspector/asset_importer_inspector.tscn").instantiate()
	add_custom_control(scene)
	
	var clothing_slots = scene.get_node('%ClothingSlots')
	for child in clothing_slots.get_children():
		child.queue_free()
		
	for slot in HumanizerConfig.clothing_slots:
		var checkbox = CheckBox.new()
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.name = slot
		checkbox.text = slot
		checkbox.button_pressed = slot in importer.clothing_slots
		checkbox.toggled.connect(_add_clothes_slot.bind(importer, slot))
		clothing_slots.add_child(checkbox)
		
	scene.get_node('%ImportButton').pressed.connect(import.bind(importer, scene))
	#if importer.asset_type == HumanizerRegistry.AssetType.BodyPart:
	#	scene.get_node('%AssetTypeOptionButton').selected = 0
	#else:
	#	scene.get_node('%AssetTypeOptionButton').selected = 1

func _add_clothes_slot(enabled: bool, importer: HumanizerAssetImporter, slot: String) -> void:
	if enabled:
		if slot not in importer.clothing_slots:
			importer.clothing_slots.append(slot)
	else:
		if slot in importer.clothing_slots:
			importer.clothing_slots.erase(slot)

func import(importer, scene) -> void:
	if importer._asset_path == null:
		printerr('No path provided')
		return 
		
	if not DirAccess.dir_exists_absolute(importer._asset_path):
		printerr('Invalid path : ' + importer._asset_path)
		return
		
	var assets := scene.get_node('%AssetTypeOptionButton') as OptionButton
	if assets.get_item_text(assets.selected) == 'Clothes':
		importer.asset_type = HumanizerRegistry.AssetType.Clothes
	else:
		importer.asset_type = HumanizerRegistry.AssetType.BodyPart
	
	var clothing_slots = []
	for child in scene.get_node('%ClothingSlots').get_children(): 
		if (child as CheckBox).button_pressed:
			clothing_slots.append(child.name)
	importer.clothing_slots = clothing_slots
	importer.run()
