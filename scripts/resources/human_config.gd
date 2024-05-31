@tool
class_name HumanConfig
extends Resource

signal body_part_equipped(bp: HumanBodyPart)
signal body_part_removed(bp: HumanBodyPart)
signal clothes_equipped(cl: HumanClothes)
signal clothes_removed(cl: HumanClothes)


## Rig
@export var rig: String

## Shapekey Settings
@export var shapekeys := {}

## Additional Components
@export var components := [&'main_collider', &'lod']

## Equipped body parts
@export var body_parts := {}
@export var body_part_materials := {}

## Equipped clothes
@export var clothes := []
@export var clothes_materials := {}

## Custom Transforms
@export var transforms := {}

## Colors
@export var skin_color: Color = Humanizer._DEFAULT_SKIN_COLOR
@export var eye_color: Color = Humanizer._DEFAULT_EYE_COLOR
@export var eyebrow_color: Color = Humanizer._DEFAULT_EYEBROW_COLOR
@export var hair_color: Color = Humanizer._DEFAULT_HAIR_COLOR

## Overlay configs
@export var material_configs := {}


func set_body_part(bp: HumanBodyPart) -> void:
	if body_parts.has(bp.slot):
		remove_body_part(bp.slot)
	body_parts[bp.slot] = bp	
	if body_part_materials.has(bp.slot):
		body_part_materials.erase(bp.slot)
	body_part_equipped.emit(bp)

func remove_body_part(slot: String) -> void:
	var current = body_parts[slot]
	body_parts.erase(slot)
	body_part_removed.emit(current)
	
func apply_clothes(cl: HumanClothes) -> void:
	for wearing in clothes:
		for slot in cl.slots:
			if slot in wearing.slots:
				remove_clothes(wearing)
	clothes.append(cl)
	clothes_equipped.emit(cl)
	
func remove_clothes(cl: HumanClothes) -> void:
	clothes.erase(cl)
	clothes_removed.emit(cl)
