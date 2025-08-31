@tool
class_name HumanConfig
extends Resource

signal equipment_added(equip:HumanizerEquipment)
signal equipment_removed(equip:HumanizerEquipment)

## Rig
@export var rig: String

## Shapekey Settings
@export var targets : Dictionary = {macro={},combo={},single={}}

## Additional Components
@export var components := [&'main_collider', &'lod']

## Equipped Assets: Clothes and Body Parts
@export var equipment := {}

## Custom Transforms
@export var transforms := {}

## Colors
@export var skin_color: Color = Color.WHITE:
	set(value):
		skin_color = value
		for equip in get_equipment_in_slots([&'body']):
			_handle_color_overrides(equip)
			
@export var eye_color: Color = Color.SKY_BLUE:
	set(value):
		eye_color = value
		var slots: Array = [&'righteye', &'lefteye', &'eyes']
		for equip in get_equipment_in_slots(slots):
			_handle_color_overrides(equip)

@export var eyebrow_color: Color = Color("330000"):
	set(value):
		eyebrow_color = value
		var slots: Array = [&'righteyebrow', &'lefteyebrow', &'eyebrows']
		for equip in get_equipment_in_slots(slots):
			_handle_color_overrides(equip)

@export var hair_color: Color = Color.WEB_MAROON:
	set(value):
		hair_color = value
		const eyebrow_color_weight := 0.4
		eyebrow_color = Color(hair_color * eyebrow_color_weight, 1.)
		for equip in get_equipment_in_slots([&'hair']):
			_handle_color_overrides(equip)
		notify_property_list_changed()

static func new_default():
	var new_config = HumanConfig.new()
	new_config.set_targets( HumanizerMacroService.get_default_macros())
	new_config.rig = ProjectSettings.get_setting("addons/humanizer/default_skeleton")
	new_config.add_equipment(HumanizerEquipment.new("Body-Default"))
	new_config.add_equipment(HumanizerEquipment.new("RightEye-LowPolyEyeball"))
	new_config.add_equipment(HumanizerEquipment.new("LeftEye-LowPolyEyeball"))
	return new_config
	
func set_targets(new_targets:Dictionary): 
	# to calculate macros before loading into a humanizer
	HumanizerTargetService.set_targets(new_targets,targets)

func _handle_color_overrides(equip:HumanizerEquipment):
	print("TODO human config - handle color overrides")
	var equip_type = equip.get_type()
	if equip_type.in_slot(["lefteye","righteye","eyes"]):
		pass
		#if equip.material_config.texture_overlays.albedo.size() > 1:
			#equip.material_config.texture_overlays.albedo[1].color = eye_color
	elif equip_type.in_slot(["body"]):
		equip.material_config.texture_overlays.albedo.color = skin_color
	#elif equip_type.in_slot(["hair"]):
		#equip.material_config.texture_overlays.albedo[0].color = hair_color
	#elif equip_type.in_slot(["lefteyebrow","righteyebrow","eyebrows"]):
		#equip.material_config.texture_overlays.albedo[0].color = eyebrow_color

func set_equipment_material(equip:HumanizerEquipment,material):
	equip.set_material(material)
	_handle_color_overrides(equip)

func get_equipment_in_slot(slot_name:String)->HumanizerEquipment:
	for equip in equipment.values():
		if slot_name in equip.get_type().slots:
			return equip # should only be one item per slot
	return null

func get_equipment_in_slots(slot_names:Array):
	var equip_list = []
	for slot_name in slot_names:
		var equip = get_equipment_in_slot(slot_name)
		if equip != null and not equip in equip_list:
			equip_list.append(equip)
	return equip_list

func add_equipment(equip:HumanizerEquipment) -> void:
	if equip == null:
		printerr("cant equip null")
		return
	#print("Equipping " + equip.type)
	var equip_type = equip.get_type()
	if equip_type == null:
		return
	for prev_equip in get_equipment_in_slots(equip_type.slots):
		remove_equipment(prev_equip)
	equipment[equip.type] = equip
	_handle_color_overrides(equip)
	equipment_added.emit(equip)
		
func remove_equipment(equip:HumanizerEquipment):
	#print("Removing " + equip.resource_name)
	var type = equip.get_type()
	if type.resource_name in equipment: #make sure hasnt already been unequipped
		equipment.erase(type.resource_name)
		equipment_removed.emit(equip)

func enable_component(c_name:StringName):
	if not components.has(c_name):
			components.append(c_name)

func disable_component(c_name:StringName):
	components.erase(c_name)
	
func has_component(c_name:StringName):
	return c_name in components
