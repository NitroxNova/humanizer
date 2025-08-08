@tool
extends HumanizerOverlay
class_name HumanizerOverlayStack

#rendered from first to last (last on top) - works like layers in photoshop or gimp 
@export var layers : Array[HumanizerOverlay]

func get_texture_node(target_size:Vector2): 
	var node = Control.new()
	for layer in layers:
		node.add_child(layer.get_texture_node(target_size))
	return node
