@tool
extends Resource
class_name HumanizerMaterial

signal on_material_updated

const TEXTURE_LAYERS = ['albedo', 'normal', 'ao']

@export var overlays: Array[HumanizerOverlay] = []
@export_file var base_material_path: String

func duplicate(subresources=false):
	if not subresources:
		return super(subresources)
	else:
		var dupe = HumanizerMaterial.new()
		dupe.base_material_path = base_material_path
		for overlay in overlays:
			dupe.overlays.append(overlay.duplicate(true))	
		return dupe

func generate_material_3D() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	if FileAccess.file_exists(base_material_path):
		material = load(base_material_path).duplicate() #dont want to overwrite base material values

	if overlays.size() == 0:
		pass
	elif overlays.size() == 1:
		material.albedo_color = overlays[0].color
		if not overlays[0].albedo_texture_path in ["",null]:
			material.set_texture(BaseMaterial3D.TEXTURE_ALBEDO, load(overlays[0].albedo_texture_path))
		else:
			material.set_texture(BaseMaterial3D.TEXTURE_ALBEDO,null)
		if overlays[0].normal_texture_path in ["",null]:
			material.normal_enabled = false
			material.set_texture(BaseMaterial3D.TEXTURE_NORMAL,null)
		else:
			material.normal_enabled = true
			material.normal_scale = overlays[0].normal_strength
			material.set_texture(BaseMaterial3D.TEXTURE_NORMAL, load(overlays[0].normal_texture_path))
		if not overlays[0].ao_texture_path in ["",null]:
			material.set_texture(BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, load(overlays[0].ao_texture_path))
	else:
		#print("more than 1 overlay")
		(func():
			var textures = await _update_material()
			material.normal_enabled = textures.normal != null
			material.ao_enabled = textures.ao != null
			material.albedo_texture = textures.albedo
			material.normal_texture = textures.normal
			material.ao_texture = textures.ao
		).call_deferred()
	return material
	
func _update_material() -> Dictionary:
	var textures : Dictionary = {}
	if overlays.size() <= 1:
		return textures
	for texture in TEXTURE_LAYERS: #albedo, normal, ambient occulsion ect..
		var texture_size = Vector2(2**11,2**11)
		if overlays[0].albedo_texture_path != "":
			texture_size = load(overlays[0].albedo_texture_path).get_size()
		var image_vp = SubViewport.new()
		
		image_vp.size = texture_size
		image_vp.transparent_bg = true
	

		for overlay in overlays:
			if overlay == null:
				continue
			var path = overlay.get(texture + '_texture_path')
			if path == null || path == '':
				if texture == 'albedo':
					var im_col_rect = ColorRect.new()
					im_col_rect.color = overlay.color
					image_vp.add_child(im_col_rect)
				continue
			var im_texture = load(path)
			var im_tex_rect = TextureRect.new()
			im_tex_rect.position = overlay.offset
			im_tex_rect.texture = im_texture
			#image_vp.call_deferred("add_child",im_tex_rect)
			image_vp.add_child(im_tex_rect)
			if texture == 'albedo':
				#blend color with overlay texture and then copy to base image
				im_tex_rect.modulate = overlay.color
		
		if image_vp.get_child_count() == 0:
			textures[texture] = null
		else:
			Engine.get_main_loop().get_root().add_child.call_deferred(image_vp)
			image_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			if not image_vp.is_inside_tree():
				await Signal(image_vp,"tree_entered")
			await Signal(RenderingServer, "frame_post_draw")
			await RenderingServer.frame_post_draw
			var image = image_vp.get_texture().get_image()
			image.generate_mipmaps()
			textures[texture] = ImageTexture.create_from_image(image)
		image_vp.queue_free()
	return textures


func set_base_textures(overlay: HumanizerOverlay) -> void:
	if overlays.size() == 0:
		# Don't append, we want to call the setter 
		overlays = [overlay]
	overlays[0] = overlay

func add_overlay(overlay: HumanizerOverlay) -> void:
	if _get_index(overlay.resource_name) != -1:
		printerr('Overlay already present?')
		return
	overlays.append(overlay)

func set_overlay(idx: int, overlay: HumanizerOverlay) -> void:
	if overlays.size() - 1 >= idx:
		overlays[idx] = overlay
	else:
		push_error('Invalid overlay index')

func remove_overlay(ov: HumanizerOverlay) -> void:
	for o in overlays:
		if o == ov:
			overlays.erase(o) 
			return
	push_warning('Cannot remove overlay ' + ov.resource_name + '. Not found.')
	
func remove_overlay_at(idx: int) -> void:
	if overlays.size() - 1 < idx or idx < 0:
		push_error('Invalid index')
		return
	overlays.remove_at(idx)

func remove_overlay_by_name(name: String) -> void:
	var idx := _get_index(name)
	if idx == -1:
		printerr('Overlay not present?')
		return
	overlays.remove_at(idx)
	
func _get_index(name: String) -> int:
	for i in overlays.size():
		if overlays[i].resource_name == name:
			return i
	return -1
