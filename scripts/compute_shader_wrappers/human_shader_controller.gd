@tool
class_name HumanizerShaderController
extends Node


static var skin_compute: ComputeWorker
static var uv_map: Image
static var mesh: MeshInstance3D
static var texture_size: Vector2i
static var shader_params: SkinShaderParameters

static func initialize(_mesh: MeshInstance3D, _shader_params: SkinShaderParameters) -> void:
	mesh = _mesh
	## We can optimize and skip this later once it's working fully
	## Only need to update it when shapekeys change
	if true:#uv_map == null:
		get_texture_space_to_object_space_map(mesh)
		smooth_uv_map_seams()  ##  Why does this do nothing?

	#var mat = mesh.get_surface_override_material(0)
	#mat.albedo_texture = ImageTexture.create_from_image(uv_map)
	#return
	shader_params = _shader_params
	generate_texture_maps()

static func cleanup() -> void:
	skin_compute.destroy()

## Generate the final texture maps to put on our skin material
static func generate_texture_maps() -> void:
	if skin_compute == null:
		skin_compute = ComputeWorker.new(shader_params.shader_file)
	if not skin_compute.initialized:
		var uniforms: Array[GPUUniform] = []
		uniforms.append(GPU_ReadonlyImage.new(uv_map, 'uv_map', 0))
		var binding: int = 1
		for texture in shader_params.images:
			var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBAF)
			uniforms.append(GPU_WriteonlyImage.new(image, texture, binding))
			binding += 1
		uniforms.append(shader_params.get_uniform(binding))
		skin_compute.uniform_sets[0].uniforms = uniforms
		skin_compute.initialize(texture_size.x / 8, texture_size.y / 8, 1)
	else:
		var param_binding = len(skin_compute.uniform_sets[0].uniforms) - 1
		skin_compute.set_uniform_data(shader_params.get_uniform(0).data, param_binding)
	skin_compute.execute()
	
	var material: BaseMaterial3D = mesh.get_surface_override_material(0)
	for texture in shader_params.images:
		if texture == 'albedo':
			material.albedo_texture = ImageTexture.create_from_image(skin_compute.get_uniform_data_by_alias(texture))
	
## Generates an image representing a map from texture space to object space
static func get_texture_space_to_object_space_map(_mesh: MeshInstance3D) -> void:
	var uv_mapping_compute := ComputeWorker.new('res://addons/humanizer/shaders/uv_map_generator.glsl')
	if mesh.get_surface_override_material(0).albedo_texture != null:
		texture_size = mesh.get_surface_override_material(0).albedo_texture.get_size()
	else:
		texture_size = Vector2i(2048, 2048)

	var arrays = mesh.mesh.surface_get_arrays(0)
	if not uv_mapping_compute.initialized:
		var n_faces := GPU_UInt.new(len(arrays[Mesh.ARRAY_INDEX]), 'n_faces', 0)
		var vtx_positions := GPU_PackedVector3Array.new(arrays[Mesh.ARRAY_VERTEX], 'vtx_positions', 1)
		var vtx_uv := GPU_PackedVector2Array.new(arrays[Mesh.ARRAY_TEX_UV], 'vtx_uv', 2)
		var faces := GPU_PackedVector3iArray.new(arrays[Mesh.ARRAY_INDEX], 'faces', 3)
		var mapping_image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBAF)
		mapping_image.fill(Color.BLACK)
		var mapping := GPU_WriteonlyImage.new(mapping_image, 'mapping', 10)
		n_faces.uniform_type = GPUUniformSingle.UNIFORM_TYPES.UNIFORM_BUFFER
		uv_mapping_compute.uniform_sets[0].uniforms = [
			n_faces, 
			vtx_positions,
			vtx_uv,
			faces,
			mapping,
		] as Array[GPUUniform]
		uv_mapping_compute.initialize(texture_size.x / 8, texture_size.y / 8, 1)
	else:
		uv_mapping_compute.set_uniform_data_by_alias(len(arrays[Mesh.ARRAY_INDEX]), 'n_faces')
		uv_mapping_compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_VERTEX], 'vtx_positions')
		uv_mapping_compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_TEX_UV], 'vtx_uv')
		uv_mapping_compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_INDEX], 'faces')

	uv_mapping_compute.execute()
	uv_map = uv_mapping_compute.get_uniform_data_by_alias('mapping').duplicate()
	uv_mapping_compute.destroy()

## Trying to smooth out the seams of the uv map, not working
static func smooth_uv_map_seams() -> void:
	var seam_compute := ComputeWorker.new('res://addons/humanizer/shaders/uv_map_seam_smoother.glsl')
	var input_texture := GPU_ReadonlyImage.new(uv_map, 'input_texture', 0)
	var output_texture := GPU_WriteonlyImage.new(uv_map, 'output_texture', 1)
	seam_compute.uniform_sets[0].uniforms = [input_texture, output_texture] as Array[GPUUniform]
	seam_compute.initialize(texture_size.x / 8, texture_size.y / 8, 1)
	seam_compute.execute()
	uv_map = seam_compute.get_uniform_data_by_alias('output_texture').duplicate()
	seam_compute.destroy()
