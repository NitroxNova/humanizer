@tool
extends Resource
class_name HumanizerEquipmentType #base equipment definition

@export_dir var path: String
@export var default_material: String
@export var rigged: bool = false
@export var textures: Dictionary
@export var slots: Array[String]

var mhclo_path: String:
	get:
		return path.path_join(resource_name.replace("_Rigged","") + '_mhclo.res')

func in_slot(slot_names:Array):
	for sl_name in slot_names:
		if sl_name in slots:
			return true
	return false
	
