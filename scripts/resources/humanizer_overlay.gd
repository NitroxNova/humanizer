@tool
class_name HumanizerOverlay
extends Resource

@export_file var albedo_texture_path: String:
	set(value):
		if resource_name == '':
			resource_name = value.get_file().get_basename()
		albedo_texture_path = value
@export_file var normal_texture_path: String
@export_file var ao_texture_path: String
@export var color := Color.WHITE
@export var offset: Vector2i = Vector2i.ZERO

var albedo_texture: Texture2D
var normal_texture: Texture2D
var ao_texture: Texture2D

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
