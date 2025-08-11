@tool
extends HumanizerOverlay
class_name HumanizerOverlayImage

@export var path : String #equip_name/texture_name
@export var color : Color = Color.WHITE #includes opacity
#removed offset, all layers will be stretched to the biggest size

func get_texture_node(target_size:Vector2,mesh_arrays:Array): 
	var node = TextureRect.new()
	node.texture = HumanizerResourceService.load_resource( HumanizerMaterial.full_texture_path(path,true))
	node.modulate = color
	node.size = target_size
	return node
	
