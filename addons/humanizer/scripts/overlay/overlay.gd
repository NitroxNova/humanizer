@tool
extends Resource
class_name HumanizerOverlay
#base class, all "overlays" should return an image texture

@export var name : StringName #to reference variables, and limit layers (like changing "iris")

func get_texture_node(target_size:Vector2,mesh_arrays:Array): 
	print("TODO : implement get_texture_node for overlay type")
