@tool
class_name HumanConfig
extends Resource

signal body_part_equipped(bp: HumanAsset)
signal body_part_removed(bp: HumanAsset)
signal clothes_equipped(cl: HumanAsset)
signal clothes_removed(cl: HumanAsset)


## Rig
@export var rig: String

## Shapekey Settings
@export var shapekeys := {}

## Additional Components
@export var components := [&'main_collider', &'lod']

## Equipped body parts
@export var body_parts := {}

## Equipped clothes
@export var clothes := []

## Custom Transforms
@export var transforms := {}

## Colors
@export var skin_color: Color = Humanizer._DEFAULT_SKIN_COLOR
@export var eye_color: Color = Humanizer._DEFAULT_EYE_COLOR
@export var eyebrow_color: Color = Humanizer._DEFAULT_EYEBROW_COLOR
@export var hair_color: Color = Humanizer._DEFAULT_HAIR_COLOR

@export var body_material : HumanizerMaterial

func set_body_part(bp: HumanAsset) -> void:
	var slot = bp.slots[0]
	if body_parts.has(slot):
		remove_body_part(slot)
	body_parts[slot] = bp	
	body_part_equipped.emit(bp)

func remove_body_part(slot: String) -> void:
	var current = body_parts[slot]
	body_parts.erase(slot)
	body_part_removed.emit(current)
	
func apply_clothes(cl: HumanAsset) -> void:
	for wearing in clothes:
		for slot in cl.slots:
			if slot in wearing.slots:
				remove_clothes(wearing)
	clothes.append(cl)
	clothes_equipped.emit(cl)
	
func remove_clothes(cl: HumanAsset) -> void:
	clothes.erase(cl)
	clothes_removed.emit(cl)
