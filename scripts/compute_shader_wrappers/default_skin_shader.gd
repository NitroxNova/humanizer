class_name DefaultSkinShader
extends SkinShaderParameters

@export var spot_color: Color = Color.SADDLE_BROWN
@export_range(0.01, 0.99, 0.01) var spot_amount: float = 0.2
@export_range(0.005, 0.1) var spot_size: float = 0.01


func get_uniform(binding: int) -> GPU_Multi:
	var uniform := GPU_Multi.new([
		GPU_Color.new(spot_color, 'spot_color'),
		GPU_Float.new(spot_amount, 'spot_amount'),
		GPU_Float.new(spot_size, 'spot_size'),
	] as Array[GPUUniformSingle], 'shader_paramters', binding)
	uniform.uniform_type = GPUUniformSingle.UNIFORM_TYPES.UNIFORM_BUFFER
	return uniform

func default_shader_file() -> String:
	return 'res://addons/humanizer/shaders/default_skin_texture_generator.glsl'

func default_skin_textures() -> Array[String]:
	return [
		'albedo',
		'normal',
	]
