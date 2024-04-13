@tool
extends Resource
class_name HumanAsset

@export_dir var path: String
@export var default_overlay: HumanizerOverlay = null

var scene_path: String:
	get:
		return path.path_join(resource_name + '_scene.tscn')
var mesh_path: String:
	get:
		return path.path_join(resource_name + '_mesh.tres')
var mhclo_path: String:
	get:
		return path.path_join(resource_name + '_mhclo.tres')
var material_path: String:
	get:
		return path.path_join(path.get_file() + '_material.tres')
