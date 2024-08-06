@tool
extends Resource
class_name HumanAsset

@export_dir var path: String
@export var default_overlay: HumanizerOverlay = null
@export var rigged: bool = false
@export var textures: Dictionary
@export var slots: Array[String]
@export var texture_name: String #currently selected texture name
@export var material_config: HumanizerMaterial

var scene_path: String:
	get:
		return path.path_join(resource_name.replace("_Rigged","") + '_scene.tscn')
var mesh_path: String:
	get:
		return path.path_join(resource_name.replace("_Rigged","") + '_mesh.res')
var mhclo_path: String:
	get:
		return path.path_join(resource_name.replace("_Rigged","") + '_mhclo.res')
var material_path: String:
	get:
		return path.path_join(path.get_file() + '_material.res')

func in_slot(slot_names:Array):
	for sl_name in slot_names:
		if sl_name in slots:
			return true
	return false
	
