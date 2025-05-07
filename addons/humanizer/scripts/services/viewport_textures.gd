@tool
extends Node
#handles the rendering of the overlays

func render_overlay_viewport(overlays:Array,type:String)->ViewportTexture:
	var viewport = SubViewport.new()
	var texture_size = Vector2(1024,1024)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for layer in overlays:
		var texture_rect = TextureRect.new()
		if "texture" in layer:
			texture_rect.texture = load(HumanizerMaterial.full_texture_path(layer.texture,true))
		if "color" in layer:
			texture_rect.modulate = layer.color
		viewport.add_child(texture_rect)
	viewport.size = texture_size
	add_child(viewport)
	return viewport.get_texture()

func render_overlay_texture(overlays:Array,type:String)->ImageTexture:
	var viewport_texture = render_overlay_viewport(overlays,type)
	await RenderingServer.frame_post_draw
	var image = viewport_texture.get_image()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
