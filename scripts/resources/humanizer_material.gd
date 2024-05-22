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
	if false:#DirAccess.dir_exists_absolute("res://addons/compute_companion/") and overlays.size() > 1:
		update_material_gpu()
	else:
		update_material_cpu()

func update_material_gpu() -> void:
	var colors := PackedVector3Array()
	var size: Vector2i
	var textures: Array[Image]
	
	for i in overlays.size():
		var overlay := overlays[i]
		if overlay.albedo_texture_path != '':
			var image := load(overlay.albedo_texture_path).get_image() as Image
			size = image.get_size()
			textures.append(image)
			colors.append(Vector3(overlay.color.r, overlay.color.g, overlay.color.b))
	
	if textures.size() > 0:
		var compute := ComputeWorker.create("res://addons/humanizer/shaders/compute/overlay.glsl")
		var textures_uniform := GPU_Texture2DArray.new(textures, 0, 'textures')
		var output_uniform := GPU_Image.new(textures[0], 1, 'output_texture')
		var colors_uniform := GPU_PackedVector3Array.new(colors, 2, true, 'colors')
		var size_uniform = GPU_Int.new(len(textures), 3, false, 'size')
		compute.uniform_sets[0].uniforms = [textures_uniform, output_uniform, colors_uniform, size_uniform]
		compute.initialize(textures[0].get_size().x / 8, textures[0].get_size().y / 8, 1)
		compute.execute_compute_shader()
		var image: Image = output_uniform.get_uniform_data()
		albedo_texture = ImageTexture.create_from_image(image)
	on_material_updated.emit()

func update_material_cpu() -> void:
	for texture in textures:
		var image: Image = null
		if overlays[0].get(texture + '_texture_path') != '':
			image = load(overlays[0].albedo_texture_path).get_image()
			image.convert(Image.FORMAT_RGBA8)
			## Blend albedo color
			if texture == 'albedo':
				blend_color(image, overlays[0].color)
				
		## TODO what if a base texture is null but overlay is not? 
		## Need to create default base texture to overlay onto

		## Blend overlay with its color then onto base texture
		if overlays.size() > 1:
			for ov in range(1, overlays.size()):
				var path = overlays[ov].get(texture + '_texture_path')
				if path == '':
					continue
				var overlay: Image = load(path).get_image()
				if texture == 'albedo':
					blend_color(overlay, overlays[ov].color)
				var start = Vector2i()
				image.blend_rect(overlay, Rect2i(start, overlay.get_size()), start)
		## Create output textures
		if image != null:
			image.generate_mipmaps()
		set(texture + '_texture', ImageTexture.create_from_image(image) if image != null else null)
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

func add_overlay(overlay: HumanizerOverlay) -> void:
	if get_index(overlay.resource_name) != -1:
		printerr('Overlay already present?')
		return
	overlays.append(overlay)

func set_overlay(idx: int, overlay: HumanizerOverlay) -> void:
	overlays[idx] = overlay
	
func remove_overlay(name: String) -> void:
	var idx := get_index(name)
	if idx == -1:
		printerr('Overlay not present?')
		return
	overlays.remove_at(idx)
	
func get_index(name: String) -> int:
	for i in overlays.size():
		if overlays[i].resource_name == name:
			return i
	return -1
