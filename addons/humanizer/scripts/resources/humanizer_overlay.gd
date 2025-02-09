@tool
class_name HumanizerOverlay
extends Resource

@export_file var albedo_texture_path: String:
	set(value):
		albedo_texture_path = value
		changed.emit()
		
@export_file var normal_texture_path: String:
	set(value):
		normal_texture_path = value
		changed.emit()
		
@export_file var ao_texture_path: String:
	set(value):
		ao_texture_path = value
		changed.emit()

@export var color := Color.WHITE:
	set(value):
		color = value
		changed.emit()

@export var offset: Vector2i = Vector2i.ZERO:
	set(value):
		offset = value
		changed.emit()
		
@export var normal_strength : float = 1.0 :
	set(value):
		normal_strength = value
		changed.emit()

static func from_material(material: StandardMaterial3D) -> HumanizerOverlay:
	var dict = {}
	if material.albedo_texture != null:
		dict.albedo = material.albedo_texture.resource_path
	if material.albedo_color != Color.WHITE:
		dict.color = material.albedo_color
	if material.normal_enabled and material.normal_texture != null:
		dict.normal = material.normal_texture.resource_path
		dict.normal_strength = material.normal_scale
	if material.ao_enabled and material.ao_texture != null:
		dict.ao = material.ao_texture.resource_path
	return from_dict(dict)

static func from_dict(data: Dictionary) -> HumanizerOverlay:
	var overlay = HumanizerOverlay.new()
	if data.has('offset'):
		overlay.offset = data.offset
	if data.has('albedo'):
		overlay.albedo_texture_path = data.albedo
		overlay.resource_name = data.albedo.get_file().get_basename().replace('_albedo', '').replace('_diffuse', '')
	if data.has('color'):
		overlay.color = data.get('color', Color.WHITE)
	if data.has('normal'):
		overlay.normal_texture_path = data.normal
	if data.has('normal_strength'):
		overlay.normal_strength = data.normal_strength
	if data.has('ao'):
		overlay.ao_texture_path = data.ao
	return overlay
