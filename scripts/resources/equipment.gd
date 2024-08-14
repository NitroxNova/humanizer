@tool
extends Resource
class_name HumanizerEquipment

@export var type:String #base equipment definition, refers to the registry.equipment
@export var texture_name: String #currently selected texture name
@export var material_config: HumanizerMaterial

func _init(_type=type,_texture_name=texture_name,_material_config=material_config):
	type=_type
	texture_name = _texture_name
	material_config = _material_config

func get_type():
	return HumanizerRegistry.equipment[type]
