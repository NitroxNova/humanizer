@tool
class_name HumanConfig
extends Resource

signal equipment_added(equip:HumanizerEquipment)
signal equipment_removed(equip:HumanizerEquipment)

## Rig
@export var rig: String

## Shapekey Settings
@export var targets : Dictionary = {}

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
		for equip in get_equipment_in_slots([&'Body']):
			_handle_color_overrides(equip)
			
@export var eye_color: Color = Color.SKY_BLUE:
	set(value):
		eye_color = value
		var slots: Array = [&'RightEye', &'LeftEye', &'Eyes']
		for equip in get_equipment_in_slots(slots):
			_handle_color_overrides(equip)

@export var eyebrow_color: Color = Color("330000"):
	set(value):
		eyebrow_color = value
		var slots: Array = [&'RightEyebrow', &'LeftEyebrow', &'Eyebrows']
		for equip in get_equipment_in_slots(slots):
			_handle_color_overrides(equip)

@export var hair_color: Color = Color.WEB_MAROON:
	set(value):
		hair_color = value
		const eyebrow_color_weight := 0.4
		eyebrow_color = Color(hair_color * eyebrow_color_weight, 1.)
		for equip in get_equipment_in_slots([&'Hair']):
			_handle_color_overrides(equip)
		notify_property_list_changed()

static func new_default():
	var new_config = HumanConfig.new()
	new_config.init_macros()
	new_config.rig = HumanizerGlobalConfig.config.default_skeleton
	new_config.add_equipment(HumanizerEquipment.new("DefaultBody"))
	new_config.add_equipment(HumanizerEquipment.new("RightEye-LowPolyEyeball"))
	new_config.add_equipment(HumanizerEquipment.new("LeftEye-LowPolyEyeball"))
	return new_config
	
func init_macros():
	var default_macros = HumanizerMacroService.get_default_macros()
	var macros = {}
	for m in default_macros:
		if m in targets:
			macros[m] = targets[m]
		else:
			macros[m] = default_macros[m]
	var new_targets = HumanizerMacroService.get_macro_target_combos(macros)
	targets.merge(new_targets.targets,true)
	targets.merge(macros,true)

func set_targets(new_targets:Dictionary): 
	var empty_helper = PackedVector3Array()
	empty_helper.resize(22000)
	empty_helper.fill(Vector3.ZERO)
	HumanizerTargetService.set_targets(new_targets,targets,empty_helper)

func _handle_color_overrides(equip:HumanizerEquipment):
	var equip_type = equip.get_type()
	if equip_type.in_slot(["LeftEye","RightEye","Eyes"]):
		if equip.material_config.overlays.size() > 1:
			equip.material_config.overlays[1].color = eye_color
	elif equip_type.in_slot(["Body"]):
		equip.material_config.overlays[0].color = skin_color
	elif equip_type.in_slot(["Hair"]):
		equip.material_config.overlays[0].color = hair_color
	elif equip_type.in_slot(["LeftEyebrow","RightEyebrow","Eyebrows"]):
		equip.material_config.overlays[0].color = eyebrow_color

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
	#print("Equipping " + equip.type)
	var equip_type = equip.get_type()
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
