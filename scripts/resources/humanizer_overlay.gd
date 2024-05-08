@tool
class_name HumanizerOverlay
extends Resource

@export_file var albedo_texture_path: String:
	set(value):
		resource_name = value.get_file().rsplit('.', true, 1)[0]
		albedo_texture_path = value
@export_file var normal_texture_path: String
@export_file var ao_texture_path: String
@export var color := Color.WHITE

static func from_dict(textures: Dictionary) -> HumanizerOverlay:
	var overlay = HumanizerOverlay.new()
	if textures.has('albedo'):
		overlay.albedo_texture_path = textures.albedo
		overlay.resource_name = textures.albedo.get_file().get_basename().replace('_albedo', '').replace('_diffuse', '')
	if textures.has('color'):
		overlay.color = textures.get('color', Color.WHITE)
	if textures.has('normal'):
		overlay.normal_texture_path = textures.normal
	return overlay
