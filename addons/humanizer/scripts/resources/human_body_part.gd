@tool
class_name HumanBodyPart
extends HumanAsset

@export var slot: String:
	set(value):
		if value not in HumanizerConfig.body_part_slots:
			printerr('Undefined slot ' + value)
		else:
			slot = value
@export var textures: Dictionary


