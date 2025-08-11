@tool
extends HumanizerOverlay
class_name HumanizerOverlayBlank

@export var color : Color = Color.WHITE #includes opacity
#will be stretched to the biggest layer or MIN_SIZE

func get_texture_node(target_size:Vector2,mesh_arrays:Array): 
	var node = ColorRect.new()
	#node.texture = HumanizerResourceService.load_resource( HumanizerMaterial.full_texture_path(path,true))
	node.color = color
	node.size = target_size
	return node
