@tool
extends Resource
class_name HumanizerMaterial

signal on_material_updated

@export var overlays: Array[HumanizerOverlay] = []:
	set(value):
		overlays = value
		if overlays.size() > 0:
			update_material()
var albedo_texture: Texture2D
var normal_texture: Texture2D
var ao_texture: Texture2D

func update_material() -> void:
	var albedo: Image = null
	var normal: Image = null
	var ao: Image = null
	
	if overlays[0].albedo_texture_path != '':
		albedo = load(overlays[0].albedo_texture_path).get_image()
		albedo.convert(Image.FORMAT_RGBA8)
	if overlays[0].normal_texture_path != '':
		normal = load(overlays[0].normal_texture_path).get_image()
	if overlays[0].ao_texture_path != '':
		ao = load(overlays[0].ao_texture_path).get_image()
		
	## TODO what if a base texture is null but overlay is not? 
	## Need to create default base texture to overlay onto
	
	## Blend albedo color
	if albedo != null:
		blend_color(albedo, overlays[0].color)
	## Blend overlay with its color then onto base texture
	if overlays.size() > 1:
		for texture in range(1, overlays.size()):
			var overlay: Image = load(overlays[texture].albedo_texture_path).get_image()
			blend_color(overlay, overlays[texture].color)
			var start = Vector2i()
			albedo.blend_rect(overlay, Rect2i(start, overlay.get_size()), start)

	## Create output textures
	normal_texture = null
	albedo_texture = null
	ao_texture = null
	if albedo != null:
		albedo.generate_mipmaps()
		albedo_texture = ImageTexture.create_from_image(albedo)
	if normal != null:
		normal.generate_mipmaps()
		normal_texture = ImageTexture.create_from_image(normal)
	if ao != null:
		ao.generate_mipmaps()
		ao_texture = ImageTexture.create_from_image(normal)
	on_material_updated.emit()

func blend_color(image: Image, color: Color) -> void:
	for x in image.get_width():
		for y in image.get_height():
			image.set_pixel(x, y, image.get_pixel(x, y) * color)

func set_base_textures(overlay: HumanizerOverlay) -> void:
	if overlays.size() == 0:
		# Don't append, we want to call the setter 
		overlays = [overlay]
	overlays[0] = overlay
	update_material()

func add_overlay(overlay: HumanizerOverlay) -> void:
	if get_index(overlay.resource_name) != -1:
		printerr('Overlay already present?')
		return
	overlays.append(overlay)
	update_material()
	
func remove_overlay(name: String) -> void:
	var idx := get_index(name)
	if idx == -1:
		printerr('Overlay not present?')
		return
	overlays.remove_at(idx)
	update_material()
	
func get_index(name: String) -> int:
	for i in overlays.size():
		if overlays[i].resource_name == name:
			return i
	return -1
