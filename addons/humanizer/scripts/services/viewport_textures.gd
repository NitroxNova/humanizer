@tool
extends Node
#handles the rendering of the overlays

func render_overlay_viewport(overlays:Array,type:String)->Viewport:
	var viewport = SubViewport.new()
	var texture_size = Vector2(1024,1024)
	if "texture" in overlays[0]:
		var base_texture:Texture2D = load(HumanizerMaterial.full_texture_path(overlays[0].texture,true))
		texture_size = base_texture.get_size()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for layer in overlays:
		var texture_rect = TextureRect.new()
		if "texture" in layer:
			texture_rect.texture = load(HumanizerMaterial.full_texture_path(layer.texture,true))
		if "color" in layer:
			texture_rect.modulate = layer.color
		#can only have one shader script..
		if "gradient" in layer:
			print(layer.gradient)
			texture_rect.material = ShaderMaterial.new()
			texture_rect.material.shader = load("res://addons/humanizer/scripts/shader/gradient_map.gdshader")
			texture_rect.material.set_shader_parameter("gradient",layer.gradient)
		viewport.add_child(texture_rect)
	viewport.size = texture_size
	add_child(viewport)
	return viewport

func render_overlay_texture(overlays:Array,type:String)->ImageTexture:
	var viewport = render_overlay_viewport(overlays,type)
	var viewport_texture = viewport.get_texture()
	await RenderingServer.frame_post_draw
	var image = viewport_texture.get_image()
	#cleanup viewport
	viewport.queue_free()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
