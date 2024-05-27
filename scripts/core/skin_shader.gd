@tool
extends Node
class_name HumanizerSkinShader

@export var spot_color: Color = Color.SADDLE_BROWN:
	set(value):
		if material:
			material.set_shader_parameter('spot_color', value)
			spot_color = value

var human: Humanizer
var material: ShaderMaterial
var shader: Shader = preload("res://addons/humanizer/shaders/skin.tres")

var _spots_lower_bound := 0.1
var _spots_upper_bound := 0.12

func setup_material(_human: Humanizer) -> ShaderMaterial:
	human = _human
	material = ShaderMaterial.new()
	material.shader = shader
	
	var spot_noise := NoiseTexture2D.new()
	spot_noise.noise = FastNoiseLite.new()
	spot_noise.noise.noise_type = FastNoiseLite.NoiseType.TYPE_CELLULAR
	spot_noise.noise.frequency = 0.77
	spot_noise.color_ramp = Gradient.new()
	spot_noise.color_ramp.set_offset(0, _spots_lower_bound)
	spot_noise.color_ramp.set_offset(1, _spots_upper_bound)
	spot_noise.color_ramp.set_color(0, Color.WHITE)
	spot_noise.color_ramp.set_color(1, Color.BLACK)
	material.set_shader_parameter('spots', spot_noise)
	
	var skin_cracks := NoiseTexture2D.new()
	skin_cracks.noise = FastNoiseLite.new()
	skin_cracks.noise.noise_type = FastNoiseLite.NoiseType.TYPE_CELLULAR
	material.set_shader_parameter('skin_cracks', skin_cracks)
	
	material.set_shader_parameter('albedo_texture', load(Random.choice(HumanizerRegistry.skin_textures.values())))
	print(material.get_shader_parameter('albedo_texture'))
	return material
