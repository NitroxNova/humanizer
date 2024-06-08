@tool
class_name HumanizerShaderController
extends Node

@export var surface_name: String = 'Body':
	set(value):
		surface_name = value
		find_material()
@export var mesh: MeshInstance3D:
	set(value):
		mesh = value
		find_material()
@export var shader_params: SkinShaderParameters
@export_enum("1k:1024", "2k:2048", "4k:4096") var texture_size: int = 2048

var uv_map: Image
var material: BaseMaterial3D
var skin_compute: ComputeWorker


func _ready() -> void:
	if uv_map == null:
		HumanizerJobQueue.enqueue({'callable': self.get_texture_space_to_object_space_map})

func _exit_tree() -> void:
	if skin_compute != null:
		skin_compute.destroy()

func find_material() -> void:
	if material != null:
		return
	if mesh == null:
		push_error('No mesh assigned in the skin shader controller')
		return
	if mesh.get_surface_override_material(0) != null:
		material = mesh.get_surface_override_material(0)
	else:
		var surf: int = (mesh.mesh as ArrayMesh).surface_find_by_name(surface_name)
		material = mesh.mesh.surface_get_material(surf)
	
## Generate the final texture maps to put on our skin material
func generate_texture_maps(job: Dictionary) -> void:
	print('generating texture maps')
	if skin_compute == null:
		skin_compute = ComputeWorker.new(shader_params.shader_file)
	if true:#not skin_compute.initialized:
		var uniforms: Array[GPUUniform] = []
		uniforms.append(GPU_ReadonlyImage.new(uv_map, 'uv_map', 0))
		var binding: int = 1
		for texture in shader_params.skin_textures:
			var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
			uniforms.append(GPU_WriteonlyUImage.new(image, texture, binding))
			binding += 1
		uniforms.append(shader_params.get_uniform(binding))
		skin_compute.uniform_sets[0].uniforms = uniforms
		skin_compute.initialize(texture_size / 8, texture_size / 8, 1)
	else:
		var param_binding = len(skin_compute.uniform_sets[0].uniforms) - 1
		skin_compute.set_uniform_data(shader_params.get_uniform(0).data, param_binding)
	skin_compute.execute()
	
	for texture in shader_params.skin_textures:
		if texture == 'albedo':
			var albedo = skin_compute.get_uniform_data_by_alias(texture)
			material.set_texture(BaseMaterial3D.TEXTURE_ALBEDO, ImageTexture.create_from_image(albedo))
	
## Generates an image representing a map from texture space to object space
func get_texture_space_to_object_space_map(job: Dictionary) -> void:
	print('generating texture space to object space map')
	var uv_mapping_compute := ComputeWorker.new('res://addons/humanizer/shaders/uv_map_generator.glsl')

	var arrays = mesh.mesh.surface_get_arrays(0)
	if not uv_mapping_compute.initialized:
		var n_faces := GPU_UInt.new(len(arrays[Mesh.ARRAY_INDEX]), 'n_faces', 0)
		var vtx_positions := GPU_PackedVector3Array.new(arrays[Mesh.ARRAY_VERTEX], 'vtx_positions', 1)
		var vtx_uv := GPU_PackedVector2Array.new(arrays[Mesh.ARRAY_TEX_UV], 'vtx_uv', 2)
		var faces := GPU_PackedVector3iArray.new(arrays[Mesh.ARRAY_INDEX], 'faces', 3)
		var mapping_image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBAF)
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
		uv_mapping_compute.initialize(texture_size / 8, texture_size / 8, 1)
	else:
		uv_mapping_compute.set_uniform_data_by_alias(len(arrays[Mesh.ARRAY_INDEX]), 'n_faces')
		uv_mapping_compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_VERTEX], 'vtx_positions')
		uv_mapping_compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_TEX_UV], 'vtx_uv')
		uv_mapping_compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_INDEX], 'faces')

	uv_mapping_compute.execute()
	uv_map = uv_mapping_compute.get_uniform_data_by_alias('mapping').duplicate()
	job.on_finished = self.smooth_uv_map_seams
	uv_mapping_compute.destroy()

## Trying to smooth out the seams of the uv map, not working
func smooth_uv_map_seams(job: Dictionary) -> void:
	print('smoothing uv map seams')
	var seam_compute := ComputeWorker.new('res://addons/humanizer/shaders/uv_map_seam_smoother.glsl')
	var input_texture := GPU_ReadonlyImage.new(uv_map, 'input_texture', 0)
	var output_texture := GPU_WriteonlyImage.new(uv_map, 'output_texture', 1)
	seam_compute.uniform_sets[0].uniforms = [input_texture, output_texture] as Array[GPUUniform]
	seam_compute.initialize(texture_size / 8, texture_size / 8, 1)
	seam_compute.execute()
	uv_map = seam_compute.get_uniform_data_by_alias('output_texture').duplicate()
	seam_compute.destroy()
	job.on_finished = self.generate_texture_maps
