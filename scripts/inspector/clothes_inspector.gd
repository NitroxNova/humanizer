@tool
class_name ClothesInspector
extends ScrollContainer

@export var category : int

static var visible_setting := false

var asset_option_buttons := {}
var material_option_buttons := {}
var overlay_option_buttons := {}
var overlay_option_dropdowns := {}
var config: HumanConfig

signal clothes_changed(cl: HumanizerEquipmentType)
signal clothes_cleared(slot: String)
signal material_set(name: String, material_index: int)


func _ready() -> void:
	visibility_changed.connect(_set_visibility)
	build_grid()
	await get_tree().process_frame

	if config != null:
		fill_table(config)
		config.equipment_added.connect(_on_config_equipment_added)
		config.equipment_removed.connect(_on_config_equipment_removed)
	
func _on_config_equipment_added(equip:HumanizerEquipment):
	for slot in equip.get_type().slots:
		if slot in asset_option_buttons:
			update_row(slot)
	
func _on_config_equipment_removed(equip:HumanizerEquipment):
	for slot in equip.get_type().slots:
		if slot in asset_option_buttons:
			var options = asset_option_buttons[slot]
			options.selected = 0
			fill_material_options(slot)

func _set_visibility() -> void:
	# Refuses to work as an anonymous function for some reason
	visible_setting = visible

func build_grid() -> void:
	#print("building grid") - called every time an option is pressed -- why
	var grid :GridContainer = find_child('GridContainer')
	grid.columns = 7
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var label = Label.new()
	label.text = ""
	grid.add_child(label)
	grid.add_child(VSeparator.new())
	label = Label.new()
	label.text = "Equipment"
	grid.add_child(label)
	grid.add_child(VSeparator.new())
	label = Label.new()
	label.text = "Material"
	grid.add_child(label)
	grid.add_child(VSeparator.new())
	label = Label.new()
	label.text = "Overlays"
	grid.add_child(label)
	
	for slot_label in HumanizerGlobalConfig.config.equipment_slots[category].slots:
		var slot = slot_label + HumanizerGlobalConfig.config.equipment_slots[category].suffix
		label = Label.new()
		label.text = slot_label
		grid.add_child(label)
		grid.add_child(VSeparator.new())
		var options = OptionButton.new()
		asset_option_buttons[slot] = options
		options.name = slot + 'OptionButton'
		options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(options)
		#add equipment options
		options.add_item(' -- None -- ')
		for asset in HumanizerRegistry.filter_equipment({'slot'=slot}):
			var display_name = asset.display_name
			if display_name == "":
				display_name = asset.resource_name
			var idx = options.item_count
			options.add_item(display_name)
			options.set_item_metadata(idx,asset.resource_name)
		options.unique_name_in_owner = true
		options.item_selected.connect(_item_selected.bind(slot))
		
		grid.add_child(VSeparator.new())
		var materials = OptionButton.new()
		material_option_buttons[slot] = materials
		materials.name = slot + 'TextureOptionButton'
		grid.add_child(materials)
		materials.unique_name_in_owner = true
		materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		materials.item_selected.connect(_material_selected.bind(slot))
		
		grid.add_child(VSeparator.new())
		var overlay_container = VBoxContainer.new()
		var overlay_button = Button.new()
		overlay_button.text = "Show Overlays"
		overlay_button.hide()
		overlay_container.add_child(overlay_button)
		overlay_option_buttons[slot] = overlay_button
		overlay_button.pressed.connect(_on_show_overlays_pressed.bind(slot))
		var item_list = VBoxContainer.new()
		item_list.visible = false
		overlay_container.add_child(item_list)
		overlay_option_dropdowns[slot] = item_list
		grid.add_child(overlay_container)
		
	for child in grid.get_children():
		child.owner = self
		
func fill_table(config: HumanConfig) -> void:
	#print("filling table")
	for slot in asset_option_buttons:
		update_row(slot)

func update_row(slot):
	var clothes = config.get_equipment_in_slot(slot)
	var options = asset_option_buttons[slot] as OptionButton
	if clothes == null:
		options.selected = 0
	else:
		for item_idx in options.item_count:
			if clothes.get_type().resource_name == options.get_item_metadata(item_idx):
				options.selected = item_idx
	fill_material_options(slot)
	fill_overlay_options(slot)

func fill_material_options(slot: String):
	var material_options: OptionButton = material_option_buttons[slot]
	material_options.clear()
	material_options.add_item(" -- None -- ")
	material_options.set_item_metadata(0,"")
	var equip = config.get_equipment_in_slot(slot)
	if equip == null:
		return # cant fill materials for null equipment
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

func fill_overlay_options(slot: String):
	#clear dropdowns
	for child in overlay_option_dropdowns[slot].get_children():
		overlay_option_dropdowns[slot].remove_child(child)
		child.queue_free()
	overlay_option_dropdowns[slot].hide()	
	
	var equip = config.get_equipment_in_slot(slot)
	if equip == null:
		return # cant fill overlays for null equipment
	var equip_type = equip.get_type()
	#hide button and return if no overlays to display
	if equip_type.overlays.size() < 1:
		overlay_option_buttons[slot].hide()
		return
		
	overlay_option_buttons[slot].text = "Show Overlays"
	overlay_option_buttons[slot].show()	
	for overlay_id in equip_type.overlays:
		var overlay_path = equip_type.overlays[overlay_id]
		var overlay = HumanizerResourceService.load_resource(overlay_path)
		var checkbox = CheckBox.new()
		checkbox.text = overlay.resource_name
		overlay_option_dropdowns[slot].add_child(checkbox)

func _on_show_overlays_pressed(slot):
	var equip = config.get_equipment_in_slot(slot)
	if equip == null:
		return # cant fill overlays for null equipment
	var equip_type = equip.get_type()
	#hide button and return if no overlays to display
	if equip_type.overlays.size() < 1:
		overlay_option_buttons[slot].hide()
		return
	
	var button:Button = overlay_option_buttons[slot]
	if button.text == "Show Overlays":
		overlay_option_dropdowns[slot].show()
		button.text = "Hide Overlays"
	elif button.text == "Hide Overlays":
		overlay_option_dropdowns[slot].hide()
		button.text = "Show Overlays"
			
func reset() -> void:
	for slot in asset_option_buttons:
		(asset_option_buttons[slot] as OptionButton).selected = 0
		(material_option_buttons[slot] as OptionButton).selected = -1

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
	var equip_id = options.get_item_metadata(index)
	
	if equip_id == null:
		clothes_cleared.emit(slot)
		return
		
	## Emit signals 
	if config != null and not equip_id in config.equipment:
		var clothes: HumanizerEquipmentType = HumanizerRegistry.equipment[equip_id]
		#print("clothes changed " + string_id)
		clothes_changed.emit(clothes)
	
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
