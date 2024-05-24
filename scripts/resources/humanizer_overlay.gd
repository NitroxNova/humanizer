@tool
class_name HumanizerOverlay
extends Resource

@export_file var albedo_texture_path: String
@export_file var normal_texture_path: String
@export_file var ao_texture_path: String
@export var color := Color.WHITE
@export var offset: Vector2i = Vector2i.ZERO

var albedo_texture: Texture2D
var normal_texture: Texture2D
var ao_texture: Texture2D

static func from_dict(data: Dictionary) -> HumanizerOverlay:
	var overlay = HumanizerOverlay.new()
	if data.has('albedo'):
		overlay.albedo_texture_path = data.albedo
		overlay.resource_name = data.albedo.get_file().get_basename().replace('_albedo', '').replace('_diffuse', '')
	if data.has('color'):
		overlay.color = data.get('color', Color.WHITE)
	if data.has('normal'):
		overlay.normal_texture_path = data.normal
	if data.has('ao'):
		overlay.ao_texture_path = data.ao
	return overlay
