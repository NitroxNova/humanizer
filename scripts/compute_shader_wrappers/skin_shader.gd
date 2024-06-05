@tool
class_name HumanizerSkinShader
extends Node

const shader_file := 'res://addons/humanizer/shaders/skin_texture_generator.glsl'

static var compute := ComputeWorker.new(shader_file)
static var human: Humanizer
static var texture_size: Vector2i


static func initialize(_human: Humanizer) -> void:
	human = _human
	
	if human.body_mesh.get_surface_override_material(0).albedo_texture == null:
		human.set_skin_texture(Random.choice(HumanizerRegistry.skin_textures.keys()))
		texture_size = human.body_mesh.get_surface_override_material(0).albedo_texture.get_size()
		
	if not compute.initialized:
		setup_uniforms()
		compute.initialize(texture_size.x / 8, texture_size.y / 8, 1)
	else:
		update_uniforms()
	
	compute.execute()
	var mapping = compute.get_uniform_data_by_alias('mapping') as Image
	human.body_mesh.get_surface_override_material(0).albedo_texture = ImageTexture.create_from_image(mapping)

static func setup_uniforms() -> void:
	#if len(compute.uniform_sets[0].uniforms) > 0:
	#	return
	
	var arrays = human.body_mesh.mesh.surface_get_arrays(0)
	var n_faces := GPU_UInt.new(len(arrays[Mesh.ARRAY_INDEX]), 'n_faces', 0)
	var vtx_positions := GPU_PackedVector3Array.new(arrays[Mesh.ARRAY_VERTEX], 'vtx_positions', 1)
	var vtx_uv := GPU_PackedVector2Array.new(arrays[Mesh.ARRAY_TEX_UV], 'vtx_uv', 2)
	var faces := GPU_PackedVector3iArray.new(arrays[Mesh.ARRAY_INDEX], 'faces', 3)
	
	var mapping_image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBAF)
	mapping_image.fill(Color.BLACK)
	var mapping := GPU_Image.new(mapping_image, 'mapping', 10)
	
	n_faces.uniform_type = GPUUniformSingle.UNIFORM_TYPES.UNIFORM_BUFFER
	compute.uniform_sets[0].uniforms = [
		n_faces, 
		vtx_positions,
		vtx_uv,
		faces,
		mapping,
	] as Array[GPUUniform]

static func update_uniforms() -> void:
	var arrays = human.body_mesh.mesh.surface_get_arrays(0)
	compute.set_uniform_data_by_alias(len(arrays[Mesh.ARRAY_INDEX]), 'n_faces')
	compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_VERTEX], 'vtx_positions')
	compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_TEX_UV], 'vtx_uv')
	compute.set_uniform_data_by_alias(arrays[Mesh.ARRAY_INDEX], 'faces')
	
