@tool
class_name HumanConfig
extends Resource

signal equipment_added(equip:HumanAsset)
signal equipment_removed(equip:HumanAsset)

## Rig
@export var rig: String

## Shapekey Settings
@export var targets : HumanTargetConfig = HumanTargetConfig.new()

## Additional Components
@export var components := [&'main_collider', &'lod']

## Equipped Assets: Clothes and Body Parts
@export var equipment := {}

## Custom Transforms
@export var transforms := {}

## Colors
@export var skin_color: Color = HumanizerEditorTool._DEFAULT_SKIN_COLOR
@export var eye_color: Color = HumanizerEditorTool._DEFAULT_EYE_COLOR
@export var eyebrow_color: Color = HumanizerEditorTool._DEFAULT_EYEBROW_COLOR
@export var hair_color: Color = HumanizerEditorTool._DEFAULT_HAIR_COLOR

@export var body_material : HumanizerMaterial

func get_equipment_in_slot(slot_name:String):
	for equip in equipment.values():
		if slot_name in equip.slots:
			return equip # should only be one item per slot

func get_equipment_in_slots(slot_names:Array):
	var equip_list = []
	for slot_name in slot_names:
		var equip = get_equipment_in_slot(slot_name)
		if equip != null and not equip in equip_list:
			equip_list.append(equip)
	return equip_list

func add_equipment(equip:HumanAsset) -> void:
	#print("Equipping " + equip.resource_name)
	for prev_equip in get_equipment_in_slots(equip.slots):
		remove_equipment(prev_equip)
	equipment[equip.resource_name] = equip
	equipment_added.emit(equip)

func remove_equipment(equip:HumanAsset):
	#print("Removing " + equip.resource_name)
	if equip.resource_name in equipment: #make sure hasnt already been unequipped
		equipment.erase(equip.resource_name)
		equipment_removed.emit(equip)
		
