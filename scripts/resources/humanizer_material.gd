@tool
extends Resource
class_name HumanizerMaterial

signal on_material_updated

const TEXTURE_LAYERS = ['albedo', 'normal', 'ao']

@export var overlays: Array[HumanizerOverlay] = []
var albedo_texture: Texture2D
var normal_texture: Texture2D
var ao_texture: Texture2D

func update_standard_material_3D(mat:StandardMaterial3D,update_textures=true) -> void:
	if overlays.size() == 1:
		mat.albedo_color = overlays[0].color
		if not overlays[0].albedo_texture_path in ["",null]:
			mat.set_texture(BaseMaterial3D.TEXTURE_ALBEDO, load(overlays[0].albedo_texture_path))
		else:
			mat.set_texture(BaseMaterial3D.TEXTURE_ALBEDO,null)
		if overlays[0].normal_texture_path in ["",null]:
			mat.normal_enabled = false
			mat.set_texture(BaseMaterial3D.TEXTURE_NORMAL,null)
		else:
			mat.normal_enabled = true
			mat.normal_scale = overlays[0].normal_strength
			mat.set_texture(BaseMaterial3D.TEXTURE_NORMAL, load(overlays[0].normal_texture_path))
		if not overlays[0].ao_texture_path in ["",null]:
			mat.set_texture(BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, load(overlays[0].ao_texture_path))
	else:
		if update_textures:
			await update_material()
		mat.normal_enabled = normal_texture != null
		mat.ao_enabled = ao_texture != null
		mat.set_texture(BaseMaterial3D.TEXTURE_ALBEDO, albedo_texture)
		mat.set_texture(BaseMaterial3D.TEXTURE_NORMAL, normal_texture)
		mat.set_texture(BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, ao_texture)
	
func update_material() -> void:
	if overlays.size() <= 1:
		return
	
	for texture in TEXTURE_LAYERS: #albedo, normal, ambient occulsion ect..
		var texture_size = load(overlays[0].albedo_texture_path).get_size()
		var image_vp = SubViewport.new()
		
		image_vp.size = texture_size
		image_vp.transparent_bg = true
		Engine.get_main_loop().get_root().add_child.call_deferred(image_vp)
	

		for overlay in overlays:
			if overlay == null:
				continue
			var path = overlay.get(texture + '_texture_path')
			if path == '':
				if texture == 'albedo':
					var im_col_rect = ColorRect.new()
					im_col_rect.color = overlay.color
					image_vp.add_child(im_col_rect)
				continue
			var im_texture = load(path)
			var im_tex_rect = TextureRect.new()
			im_tex_rect.texture = im_texture
			image_vp.add_child(im_tex_rect)

			if texture == 'albedo':
				#blend color with overlay texture and then copy to base image
				im_tex_rect.modulate = overlay.color
		
		if image_vp.get_child_count() == 0:
			set(texture + '_texture',null)
		else:
			image_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw	
			var image = image_vp.get_texture().get_image()
			image.generate_mipmaps()
			set(texture + '_texture', ImageTexture.create_from_image(image))
		image_vp.queue_free()
		on_material_updated.emit()


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
