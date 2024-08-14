@tool
extends Resource
class_name HumanizerMaterial

signal on_material_updated

const TEXTURE_LAYERS = ['albedo', 'normal', 'ao']

@export var overlays: Array[HumanizerOverlay] = []
var albedo_texture: Texture2D
var normal_texture: Texture2D
var ao_texture: Texture2D

func update_standard_material_3D(mat:StandardMaterial3D) -> void:
	mat.normal_enabled = normal_texture != null
	mat.ao_enabled = ao_texture != null
	mat.set_texture(BaseMaterial3D.TEXTURE_ALBEDO, albedo_texture)
	mat.set_texture(BaseMaterial3D.TEXTURE_NORMAL, normal_texture)
	mat.set_texture(BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, ao_texture)
	
func update_material() -> void:
	#print("updating material")
	if overlays.size() == 0:
		return
	
	for texture in TEXTURE_LAYERS:
		var image: Image = null
		for overlay in overlays:
			if overlay == null:
				continue
			var path = overlay.get(texture + '_texture_path')
			if path == '':
				continue
			var overlay_image = load(path).get_image()
			overlay_image.convert(Image.FORMAT_RGBA8)
			
			if texture == 'albedo':
				#blend color with overlay texture and then copy to base image
				_blend_color(overlay_image, overlay.color)
			if image == null:
				image = overlay_image
			else:
				image.blend_rect(overlay_image, 
								Rect2i(Vector2i.ZERO, overlay_image.get_size()), 
								overlay.offset)
				
		## TODO what if a base texture is null but overlay is not? 
		## Need to create default base texture to overlay onto

		## Create output textures
		if image != null:
			image.generate_mipmaps()

		set(texture + '_texture', ImageTexture.create_from_image(image) if image != null else null)
	on_material_updated.emit()

func _blend_color(image: Image, color: Color) -> void:
	for x in image.get_width():
		for y in image.get_height():
			image.set_pixel(x, y, image.get_pixel(x, y) * color)

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
