@tool
extends HumanizerOverlay
class_name HumanizerOverlayMask

@export var mask_image : HumanizerOverlay
#@export var overlay_image : HumanizerOverlay
@export var base_image : HumanizerOverlay

func get_texture_node(target_size:Vector2,mesh_arrays:Array): 
	var base_image_node = base_image.get_texture_node(target_size,mesh_arrays)
	var node = SubViewportContainer.new()
	#add the texture node last so it displays
	var mask_viewport = SubViewport.new()
	mask_viewport.transparent_bg = true
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	mask_viewport.size = target_size
	mask_viewport.add_child(mask_image.get_texture_node(target_size,mesh_arrays))
	node.add_child(mask_viewport)
	
	#var overlay_viewport = SubViewport.new()
	#overlay_viewport.transparent_bg = true
	#overlay_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	#overlay_viewport.size = target_size
	#overlay_viewport.add_child(overlay_image.get_texture_node(target_size,mesh_arrays))
	#node.add_child(overlay_viewport)
	
	var sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.size = target_size
	sub_viewport.add_child(base_image_node)
	
	node.add_child(sub_viewport)
	var shader_material = ShaderMaterial.new()
	shader_material.shader = HumanizerResourceService.load_resource("res://addons/humanizer/scripts/overlay/mask.gdshader") 
	
	
	shader_material.set_shader_parameter("mask_image",mask_viewport.get_texture())
	shader_material.set_shader_parameter("base_image",sub_viewport.get_texture())
	#shader_material.set_shader_parameter("overlay_image",overlay_viewport.get_texture())
	#shader_material.set_shader_parameter("blend_amount",blend_amount)
	
	node.material = shader_material
	return node
