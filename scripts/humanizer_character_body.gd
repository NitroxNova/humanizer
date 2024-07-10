extends CharacterBody3D
class_name HumanizerCharacterBody

var human_config:HumanConfig
var mesh_node:MeshInstance3D

func _ready():
	var mesh_node = MeshInstance3D.new()
	add_child(mesh_node)

