@tool
class_name SkinShaderParameters
extends Resource

## Extend this class,
## export shader parameters,
## write the function to create a GPU_Multi Uniform
## override the skin_textures function as needed

## The path to the glsl shader file
@export_file var shader_file: String
## A list of textures to be output by the shader
@export var images := skin_textures()

func _init(_file := '') -> void:
	shader_file = _file

## Gets a GPU_Multi uniform for aggregation of non-image shader parameters
func get_uniform(binding) -> GPU_Multi:
	var some_data = 0
	return GPUUniform.new(some_data, 'some_uniform', binding)

func skin_textures() -> Array[String]:
	return [] as Array[String]
