@tool
extends Resource
class_name HumanAsset

@export_dir var path: String
@export var default_overlay: HumanizerOverlay = null
@export var rigged: bool = false

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

## Non-serialized node reference.  
var node: Node3D
