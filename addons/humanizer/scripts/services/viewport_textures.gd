@tool
extends Node
#handles the rendering of the overlays

func render_overlay_viewport(overlay:HumanizerOverlay,type:String,mesh_arrays:Array)->Viewport:
	var viewport = SubViewport.new()
	viewport.transparent_bg = true
	var default_size = Vector2(2048,2048)
	print("TODO viewport_textures - render overlay viewport")
	var texture_node = overlay.get_texture_node(default_size,mesh_arrays)
	viewport.add_child(texture_node)
	#if "texture" in overlays[0]:
		#var base_texture:Texture2D = load(HumanizerMaterial.full_texture_path(overlays[0].texture,true))
		#texture_size = base_texture.get_size()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	#for layer in overlays:
		#var texture_rect = TextureRect.new()
		#if "texture" in layer:
			#texture_rect.texture = load(HumanizerMaterial.full_texture_path(layer.texture,true))
		#if "color" in layer:
			#texture_rect.modulate = layer.color
		##can only have one shader script..
		#if "gradient" in layer:
			#print(layer.gradient)
			#texture_rect.material = ShaderMaterial.new()
			#texture_rect.material.shader = load("res://addons/humanizer/scripts/shader/gradient_map.gdshader")
			#texture_rect.material.set_shader_parameter("gradient",layer.gradient)
		#viewport.add_child(texture_rect)
	
	viewport.size = default_size
	add_child(viewport)
	return viewport

func render_overlay_texture(overlays:HumanizerOverlay,type:String,mesh_arrays:Array)->ImageTexture:
	var viewport = render_overlay_viewport(overlays,type,mesh_arrays)
	var viewport_texture = viewport.get_texture()
	await RenderingServer.frame_post_draw
	var image = viewport_texture.get_image()
	#cleanup viewport
	viewport.queue_free()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
