@tool
class_name ClothesInspector
extends MarginContainer

var last_materials := {}
var asset_option_buttons := {}
var material_option_buttons := {}
var config: HumanConfig

signal clothes_changed(cl: HumanClothes)
signal clothes_cleared(slot: String)
signal material_set(name: String, material_index: int)


func _ready() -> void:
	build_grid()
	await get_tree().process_frame
	for slot in HumanizerConfig.clothing_slots:
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

func build_grid() -> void:
	var grid = get_node('%GridContainer')
	for slot in HumanizerConfig.clothing_slots:
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
	for clothes in config.clothes:
		for slot in asset_option_buttons:
			var options = asset_option_buttons[slot] as OptionButton
			var materials = material_option_buttons[slot] as OptionButton 
			for item in options.item_count:
				if clothes.resource_name == options.get_item_text(item):
					options.selected = item
					if config.clothes_materials.has(clothes.resource_name):
						materials.selected = config.clothes_materials[clothes.resource_name]
			
func reset() -> void:
	for slot in HumanizerConfig.clothing_slots:
		(asset_option_buttons[slot] as OptionButton).selected = 0
		(material_option_buttons[slot] as OptionButton).selected = -1

func clear_clothes(cl: HumanClothes) -> void:
	for slot in asset_option_buttons:
		var options = asset_option_buttons[slot] as OptionButton
		if options.get_item_text(options.selected) == cl.resource_name:
			options.selected = 0
			material_option_buttons[slot].selected = -1

func _item_selected(index: int, slot: String):
	var options: OptionButton = asset_option_buttons[slot]
	var material_options = material_option_buttons[slot]
	material_options.clear()
	
	var name = options.get_item_text(index)
	if name == 'None':
		clothes_cleared.emit(slot)
		return
	
	var slots := []
	for sl in asset_option_buttons:
		options = asset_option_buttons[sl] as OptionButton
		for item in options.item_count:
			if options.get_item_text(item) == name:
				slots.append(sl)
				options.selected = item
	
	for sl in slots:
		var materials: OptionButton = material_option_buttons[sl]
		materials.clear()
		for mat in HumanizerRegistry.clothes[name].textures:
			materials.add_item(mat.get_file().replace('.tres', ''))
		
	if config == null or not config.clothes.has(name):
		clothes_changed.emit(HumanizerRegistry.clothes[name])
		_material_selected(0, slot)

func _material_selected(idx: int, slot: String) -> void:
	var options = asset_option_buttons[slot] as OptionButton
	var name: String = options.get_item_text(options.selected)
	
	var slots := []
	for sl in asset_option_buttons:
		options = asset_option_buttons[sl] as OptionButton
		if options.get_item_text(options.selected) == name:
			slots.append(sl)
	
	for sl in material_option_buttons:
		var materials: OptionButton = material_option_buttons[sl]
		materials.selected = idx
	material_set.emit(name, name)
