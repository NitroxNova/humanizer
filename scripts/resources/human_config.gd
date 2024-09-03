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
		body_material.overlays[0].color = skin_color
			
@export var eye_color: Color = Color.SKY_BLUE:
	set(value):
		eye_color = value
		var slots: Array = [&'RightEye', &'LeftEye', &'Eyes']
		for equip in get_equipment_in_slots(slots):
			equip.material_config.overlays[1].color = eye_color

@export var eyebrow_color: Color = Color("330000")

@export var hair_color: Color = Color.WEB_MAROON:
	set(value):
		hair_color = value
		const eyebrow_color_weight := 0.4
		eyebrow_color = Color(hair_color * eyebrow_color_weight, 1.)
		notify_property_list_changed()

@export var body_material : HumanizerMaterial= init_body_material()

func init_body_material():
	var mat = HumanizerMaterial.new()
	mat.add_overlay(HumanizerOverlay.from_dict({}))
	return mat

func init_macros():
	var macros = HumanizerMacroService.get_default_macros()
	var new_targets = HumanizerMacroService.get_macro_target_combos(macros)
	targets.merge(new_targets.targets,true)
	targets.merge(macros,true)

func get_equipment_in_slot(slot_name:String):
	for equip in equipment.values():
		if slot_name in equip.get_type().slots:
			return equip # should only be one item per slot

func get_equipment_in_slots(slot_names:Array):
	var equip_list = []
	for slot_name in slot_names:
		var equip = get_equipment_in_slot(slot_name)
		if equip != null and not equip in equip_list:
			equip_list.append(equip)
	return equip_list

func add_equipment(equip:HumanizerEquipment) -> void:
	#print("Equipping " + equip.resource_name)
	var equip_type = equip.get_type()
	for prev_equip in get_equipment_in_slots(equip_type.slots):
		remove_equipment(prev_equip)
	equipment[equip.type] = equip
	equipment_added.emit(equip)
	if equip_type.default_overlay != null and equip.material_config == null:
		equip.material_config = HumanizerMaterial.new()
		equip.material_config.set_base_textures(HumanizerOverlay.from_material(load(equip_type.material_path)))
		equip.material_config.add_overlay(equip_type.default_overlay)
	if equip_type.in_slot(["LeftEye","RightEye"]):
		equip.material_config.overlays[1].color = eye_color

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

func set_skin_texture(texture_name:String):
	var texture: String
	if not HumanizerRegistry.skin_textures.has(texture_name):
		body_material.overlays[0].albedo_texture_path = ""
	else:
		texture = HumanizerRegistry.skin_textures[texture_name]
		var normal_texture = texture.get_base_dir() + '/' + texture_name + '_normal.' + texture.get_extension()
		if not FileAccess.file_exists(normal_texture):
			if body_material.overlays.size() > 0:
				var overlay = body_material.overlays[0]
				normal_texture = overlay.normal_texture_path
			else:
				normal_texture = ''
		var overlay = {&'albedo': texture, &'color': skin_color, &'normal': normal_texture}
		body_material.set_base_textures(HumanizerOverlay.from_dict(overlay))
