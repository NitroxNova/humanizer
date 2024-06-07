@tool
class_name SkinShaderParameters
extends Resource

## Extend this class,
## export shader parameters,
## write the function to create a GPU_Multi Uniform
## override the default functions below

## The path to the glsl shader file
@export var shader_file: String = default_shader_file()
## A list of textures to be output by the shader
@export var skin_textures: Array[String] = default_skin_textures()


## Gets a GPU_Multi uniform for aggregation of non-image shader parameters
func get_uniform(binding) -> GPU_Multi:
	var some_data = 0
	return GPUUniform.new(some_data, 'some_uniform', binding)

## Since we can't override member variables we have to point to intializers
func default_skin_textures() -> Array[String]:
	return [] as Array[String]

func default_shader_file() -> String:
	return ''
