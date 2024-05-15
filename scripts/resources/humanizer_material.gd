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
	if DirAccess.dir_exists_absolute("res://addons/compute_worker/") and overlays.size() > 1:
		update_material_gpu()
	else:
		update_material_cpu()

func update_material_gpu() -> void:
	var compute := ComputeWorker.new()
	compute.shader_file = load("res://addons/humanizer/shaders/compute/overlay.glsl")
	var uniform_set := UniformSet.new()
	compute.uniform_sets = [uniform_set]
	var colors := PackedVector3Array()
	
	var albedo: Image = null
	var normal: Image = null
	var ao: Image = null
	
	var size: Vector2i
	var textures: Array[Image]
	var t0 = Time.get_ticks_msec()
	for i in overlays.size():
		var overlay := overlays[i]
		if overlay.albedo_texture_path != '':
			var image := load(overlay.albedo_texture_path).get_image() as Image
			if image.has_mipmaps():
				image.clear_mipmaps()
			size = image.get_size()
			image.convert(Image.FORMAT_RGBAF)
			textures.append(image)
			colors.append(Vector3(overlay.color.r, overlay.color.g, overlay.color.b))
	
	if textures.size() > 0:
		var texture_array := Texture2DArray.new()
		texture_array.create_from_images(textures)
		var textures_uniform := GPU_Texture2DArray.new()
		textures_uniform.data = texture_array
		textures_uniform.binding = 0
		var output_uniform := GPU_Image.new()
		output_uniform.data = textures[0]
		output_uniform.binding = 1
		var colors_uniform := GPU_PackedVector3Array.new()
		colors_uniform.data = colors
		colors_uniform.binding = 2
		var size_uniform := GPU_Integer.new()
		size_uniform.data = textures.size()
		size_uniform.binding = 3
		uniform_set.uniforms = [textures_uniform, output_uniform, colors_uniform, size_uniform]
		compute.initialize()
		await compute.compute_end
		var image: Image = compute.get_uniform_by_binding(1).get_uniform_data(compute.rd)
		albedo_texture = ImageTexture.create_from_image(image)
	on_material_updated.emit()

func update_material_cpu() -> void:
	for texture in ['albedo', 'normal', 'ao']:
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
				var overlay: Image = load(overlays[ov].get(texture + '_texture_path')).get_image()
				if texture == 'albedo':
					blend_color(overlay, overlays[ov].color)
				var start = Vector2i()
				image.blend_rect(overlay, Rect2i(start, overlay.get_size()), start)

		## Create output textures
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
	update_material()

func add_overlay(overlay: HumanizerOverlay) -> void:
	if get_index(overlay.resource_name) != -1:
		printerr('Overlay already present?')
		return
	overlays.append(overlay)
	update_material()

func set_overlay(idx: int, overlay: HumanizerOverlay) -> void:
	overlays[idx] = overlay
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
