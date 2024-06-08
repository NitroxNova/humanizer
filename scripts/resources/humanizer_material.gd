@tool
extends Resource
class_name HumanizerMaterial

signal on_material_updated

const textures = ['albedo', 'normal', 'ao']

@export var overlays: Array[HumanizerOverlay] = []
var albedo_texture: Texture2D
var normal_texture: Texture2D
var ao_texture: Texture2D

func update_material() -> void:
	if overlays.size() == 0:
		return
	
	var base_size: Vector2i 
	for texture in textures:
		var image: Image = null
		var path = overlays[0].get(texture + '_texture_path')
		if path == '':
			set(texture + '_texture', null)
			continue
		image = load(path).get_image()
		base_size = image.get_size()
		image.convert(Image.FORMAT_RGBA8)
		## Blend albedo color
		if texture == 'albedo':
			_blend_color(image, overlays[0].color)
				
		## TODO what if a base texture is null but overlay is not? 
		## Need to create default base texture to overlay onto

		## Blend overlay with its color then onto base texture
		if overlays.size() > 1:
			for ov in range(1, overlays.size()):
				if ov == null:
					continue
				var overlay = overlays[ov]
				path = overlay.get(texture + '_texture_path')
				if path == '':
					continue
				var overlay_image: Image = load(path).get_image()
				if texture == 'albedo':
					_blend_color(overlay_image, overlay.color)
				image.blend_rect(overlay_image, 
								Rect2i(Vector2i.ZERO, overlay_image.get_size()), 
								overlay.offset)
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
