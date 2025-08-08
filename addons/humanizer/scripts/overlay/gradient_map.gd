@tool
extends HumanizerOverlay
class_name HumanizerOverlayGradientMap

@export var gradient : GradientTexture1D
@export var blend_amount : float = 1.0
@export var base_image : HumanizerOverlay

func get_texture_node(target_size:Vector2): 
	var base_image_node = base_image.get_texture_node(target_size)
	var sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.size = target_size
	sub_viewport.add_child(base_image_node)
	var node = SubViewportContainer.new()
	node.add_child(sub_viewport)
	var shader_material = ShaderMaterial.new()
	shader_material.shader = HumanizerResourceService.load_resource("res://addons/humanizer/scripts/overlay/gradient_map.gdshader") 
	shader_material.set_shader_parameter("gradient",gradient)
	shader_material.set_shader_parameter("blend_amount",blend_amount)
	
	node.material = shader_material
	return node
