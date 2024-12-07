@tool
class_name ClothesInspector
extends ScrollContainer

@export var category : int

static var visible_setting := false

var asset_option_buttons := {}
var material_option_buttons := {}
var config: HumanConfig

signal clothes_changed(cl: HumanizerEquipmentType)
signal clothes_cleared(slot: String)
signal material_set(name: String, material_index: int)


func _ready() -> void:
	visibility_changed.connect(_set_visibility)
	build_grid()
	await get_tree().process_frame
	for slot in HumanizerGlobalConfig.config.equipment_slots[category].get_slots():
		asset_option_buttons[slot] = get_node('%' + slot + 'OptionButton')
		material_option_buttons[slot] = get_node('%' + slot + 'TextureOptionButton')
		
		asset_option_buttons[slot].clear()
		material_option_buttons[slot].clear()
		
		var options = asset_option_buttons[slot] as OptionButton
		var materials = material_option_buttons[slot] as OptionButton

		options.item_selected.connect(_item_selected.bind(slot))
		materials.item_selected.connect(_material_selected.bind(slot))
		
		options.add_item('None')
		for asset in HumanizerRegistry.filter_equipment({'slot'=slot}):
			var display_name = asset.display_name
			if display_name == "":
				display_name = asset.resource_name
			var idx = options.item_count
			options.add_item(display_name)
			options.set_item_metadata(idx,asset.resource_name)
			
	if config != null:
		fill_table(config)

func _set_visibility() -> void:
	# Refuses to work as an anonymous function for some reason
	visible_setting = visible

func build_grid() -> void:
	var grid = find_child('GridContainer')
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for slot_label in HumanizerGlobalConfig.config.equipment_slots[category].slots:
		var slot = slot_label + HumanizerGlobalConfig.config.equipment_slots[category].suffix
		var label = Label.new()
		label.text = slot_label
		grid.add_child(label)
		grid.add_child(VSeparator.new())
		label = Label.new()
		label.text = 'Asset'
		grid.add_child(label)
		var options = OptionButton.new()
		options.name = slot + 'OptionButton'
		options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(options)
		options.unique_name_in_owner = true
		grid.add_child(VSeparator.new())
		label = Label.new()
		label.text = 'Texture'
		grid.add_child(label)
		options = OptionButton.new()
		options.name = slot + 'TextureOptionButton'
		grid.add_child(options)
		options.unique_name_in_owner = true
		options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in grid.get_children():
		child.owner = self
		
func fill_table(config: HumanConfig) -> void:
	#print("filling table")
	for slot in HumanizerGlobalConfig.config.equipment_slots[category].get_slots():
		var clothes = config.get_equipment_in_slot(slot)
		if clothes != null:
			var options = asset_option_buttons[slot] as OptionButton
			var materials = material_option_buttons[slot] as OptionButton 
			for item_idx in options.item_count:
				if clothes.get_type().resource_name == options.get_item_metadata(item_idx):
					options.selected = item_idx
					fill_material_options(slot)

func fill_material_options(slot: String):
	var material_options: OptionButton = material_option_buttons[slot]
	material_options.clear()
	material_options.add_item(" -- None -- ")
	material_options.set_item_metadata(0,"")
	
	var equip = config.get_equipment_in_slot(slot)
	if equip == null:
		return # can fill materials for null equipment
	var equip_type = equip.get_type()
	for mat_id in equip_type.textures:
		var option_id = material_options.item_count
		var mat_path = equip_type.textures[mat_id]
		var mat_res = HumanizerResourceService.load_resource(mat_path)
		var mat_name = mat_res.resource_name
		material_options.add_item(mat_name)
		material_options.set_item_metadata(option_id,mat_id)
		if equip.texture_name == mat_id:
			material_options.selected = option_id
	
func reset() -> void:
	for slot in HumanizerGlobalConfig.config.clothing_slots:
		(asset_option_buttons[slot] as OptionButton).selected = 0
		(material_option_buttons[slot] as OptionButton).selected = -1

func clear_clothes(slot: String) -> void:
	var equip = config.get_equipment_in_slot(slot)
	var equip_type = equip.get_type()
	var slots = equip_type.slots
	for sl in slots:
		var equip_options = asset_option_buttons[sl]
		equip_options.selected = 0

func _get_slots(index: int, slot: String) -> Array[String]:
	var slots: Array[String] = []
	var selected = asset_option_buttons[slot].selected
	var name = asset_option_buttons[slot].get_item_text(selected)
	for sl in asset_option_buttons:
		var options = asset_option_buttons[sl] as OptionButton
		for item in options.item_count:
			if options.get_item_text(item) == name:
				slots.append(sl)
	return slots

func _item_selected(index: int, slot: String):
	## Get corresponding slot option and material buttons
	var options: OptionButton = asset_option_buttons[slot]
	
	## Get selected item name
	var name = options.get_item_text(index)
	if name == 'None':
		clothes_cleared.emit(slot)
		clear_clothes(slot)
		return
	
	var string_id = options.get_item_metadata(index)
	
	## Find other slots with same item (same name)
	var slots: Array[String] = []
	var selected = asset_option_buttons[slot].selected
	for sl in asset_option_buttons:
		options = asset_option_buttons[sl] as OptionButton
		for item in options.item_count:
			if options.get_item_text(item) == name:
				slots.append(sl)
	
	## Choose same item in those slots
	for sl in slots:
		options = asset_option_buttons[sl] as OptionButton
		for item in options.item_count:
			if options.get_item_text(item) == name:
				options.selected = item
	
	## Fill material options for each
	for sl in slots:
		fill_material_options(sl)
	
	## Emit signals and set to default material
	if config != null and not string_id in config.equipment:
		var clothes: HumanizerEquipmentType = HumanizerRegistry.equipment[string_id]
		#print("clothes changed " + string_id)
		clothes_changed.emit(clothes)
		var textures = material_option_buttons[slot]
		material_set.emit(name, textures.get_item_text(textures.selected))

func _material_selected(idx: int, slot: String) -> void:
	var material_options: OptionButton = material_option_buttons[slot]
	var mat_id = material_options.get_item_metadata(idx)
	#var name: String = options.get_item_text(options.selected)
	var equip = config.get_equipment_in_slot(slot)
	var slots = equip.get_type().slots
	
	for sl in slots:
		material_options = material_option_buttons[sl]
		for option_id in material_options.item_count:
			if material_options.get_item_metadata(option_id) == mat_id:
				material_options.selected = option_id
				
		
	material_set.emit(equip.type, mat_id)
