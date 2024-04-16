@tool
class_name ClothesInspector
extends MarginContainer

static var visible_setting := false

static var last_equipped := {}
static var last_materials := {}
var asset_option_buttons := {}
var material_option_buttons := {}
var config: HumanConfig

signal clothes_changed(cl: HumanClothes)
signal clothes_cleared(slot: String)
signal material_set(name: String, material_index: int)


func _ready() -> void:
	visibility_changed.connect(_set_visibility)
	build_grid()
	await get_tree().process_frame
	for slot in HumanizerGlobalConfig.config.clothing_slots:
		asset_option_buttons[slot] = get_node('%' + slot + 'OptionButton')
		material_option_buttons[slot] = get_node('%' + slot + 'TextureOptionButton')
		
		asset_option_buttons[slot].clear()
		material_option_buttons[slot].clear()
		
		var options = asset_option_buttons[slot] as OptionButton
		var materials = material_option_buttons[slot] as OptionButton

		options.item_selected.connect(_item_selected.bind(slot))
		materials.item_selected.connect(_material_selected.bind(slot))
		
		options.add_item('None')
		for asset in HumanizerRegistry.clothes.values():
			if slot in asset.slots:
				options.add_item(asset.resource_name)
	
	if config != null:
		fill_table(config)

func _set_visibility() -> void:
	# Refuses to work as an anonymous function for some reason
	visible_setting = visible

func build_grid() -> void:
	var grid = get_node('%GridContainer')
	for slot in HumanizerGlobalConfig.config.clothing_slots:
		var label = Label.new()
		label.text = slot
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
	for clothes: HumanClothes in config.clothes:
		for slot in asset_option_buttons:
			var options = asset_option_buttons[slot] as OptionButton
			var materials = material_option_buttons[slot] as OptionButton 
			for item in options.item_count:
				if clothes.resource_name == options.get_item_text(item):
					options.selected = item
					var mat: int = 0
					for texture in clothes.textures:
						materials.add_item(texture)
						if materials.get_item_text(mat) == config.clothes_materials[clothes.resource_name]:
							materials.selected = mat
						mat += 1
			
func reset() -> void:
	last_equipped = {}
	last_materials = {}
	for slot in HumanizerGlobalConfig.config.clothing_slots:
		(asset_option_buttons[slot] as OptionButton).selected = 0
		(material_option_buttons[slot] as OptionButton).selected = -1

func clear_clothes(slot: String) -> void:
	var cl = last_equipped[slot]
	for sl in asset_option_buttons:
		if last_equipped.has(sl) and last_equipped[sl] == cl:
			last_equipped.erase(sl)
			var options = asset_option_buttons[sl] as OptionButton
			options.selected = 0
			material_option_buttons[sl].selected = -1

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
	var material_options = material_option_buttons[slot]
	material_options.clear()
	
	## Get selected item name
	var name = options.get_item_text(index)
	if name == 'None':
		clothes_cleared.emit(slot)
		clear_clothes(slot)
		return
	
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
		var materials: OptionButton = material_option_buttons[sl]
		materials.clear()
		for mat in HumanizerRegistry.clothes[name].textures:
			materials.add_item(mat.get_file().replace('.tres', ''))
	
	## Emit signals and set to default material
	if config != null and not config.clothes.has(HumanizerRegistry.clothes[name]):
		var clothes: HumanClothes = HumanizerRegistry.clothes[name]
		for sl in slots:
			last_equipped[sl] = clothes
		clothes_changed.emit(clothes)
		var textures = material_option_buttons[slot]
		material_set.emit(name, textures.get_item_text(textures.selected))

func _material_selected(idx: int, slot: String) -> void:
	var texture_name: String = material_option_buttons[slot].get_item_text(idx)
	var options: OptionButton = asset_option_buttons[slot]
	var name: String = options.get_item_text(options.selected)
	
	var slots: Array[String] = []
	for sl: String in asset_option_buttons:
		options = asset_option_buttons[sl] as OptionButton
		if options.get_item_text(options.selected) == name:
			slots.append(sl)
	
	for sl in slots:
		var materials: OptionButton = material_option_buttons[sl]
		materials.selected = idx
		
	material_set.emit(name, texture_name)
