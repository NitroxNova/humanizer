@tool
extends Resource
class_name HumanAsset

@export_dir var path: String

var scene_path: String:
	get:
		return path.path_join(resource_name + '_scene.tscn')
var mesh_path: String:
	get:
		return path.path_join(resource_name + '_mesh.res')
var material_path: String:
	get:
		return path.path_join(resource_name + '_material.res')
var mhclo_path: String:
	get:
		return path.path_join(resource_name + '_mhclo.res')
