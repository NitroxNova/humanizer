@tool
class_name HumanizerOverlay
extends Resource

signal on_overlay_updated

@export_file var albedo_texture_path: String:
	set(value):
		resource_name = value.get_file().rsplit('.', true, 1)[0]
		albedo_texture_path = value
		on_overlay_updated.emit()
@export_file var normal_texture_path: String:
	set(value):
		normal_texture_path = value
		on_overlay_updated.emit()
@export_file var ao_texture_path: String:
	set(value):
		ao_texture_path = value
		on_overlay_updated.emit()
@export var color := Color.WHITE:
	set(value):
		color = value
		on_overlay_updated.emit()

static func from_dict(textures: Dictionary) -> HumanizerOverlay:
	var overlay = HumanizerOverlay.new()
	overlay.albedo_texture_path = textures.albedo
	overlay.resource_name = textures.albedo.get_file().rsplit('.', true, 1)[0].replace('_albedo', '').replace('_diffuse', '')
	overlay.color = textures.get('color', Color.WHITE)
	if textures.has('normal'):
		overlay.normal_texture_path = textures.normal
	return overlay
