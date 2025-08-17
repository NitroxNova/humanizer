@tool
extends HumanizerOverlay
class_name HumanizerOverlayWhorleyGPU

#will be stretched to the biggest layer or MIN_SIZE
@export var seed : int
@export var grid_size : float = .1

func get_texture_node(target_size:Vector2,mesh_arrays:Array): 
	var sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.size = target_size
	var node = SubViewportContainer.new()
	node.add_child(sub_viewport)
	var flat_mesh = MeshInstance2D.new()
	var flat_array_mesh = ArrayMesh.new()
	var surface_arrays = []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	surface_arrays[Mesh.ARRAY_VERTEX] = mesh_arrays[Mesh.ARRAY_TEX_UV]
	surface_arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	#surface_arrays[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array()
	for i in surface_arrays[Mesh.ARRAY_VERTEX].size():
		surface_arrays[Mesh.ARRAY_VERTEX][i].x *= float(target_size.x)
		surface_arrays[Mesh.ARRAY_VERTEX][i].y *= float(target_size.y)
		surface_arrays[Mesh.ARRAY_CUSTOM0].append( mesh_arrays[Mesh.ARRAY_VERTEX][i].x)
		surface_arrays[Mesh.ARRAY_CUSTOM0].append( mesh_arrays[Mesh.ARRAY_VERTEX][i].y)
		surface_arrays[Mesh.ARRAY_CUSTOM0].append( mesh_arrays[Mesh.ARRAY_VERTEX][i].z)
		#surface_arrays[Mesh.ARRAY_CUSTOM1].append( mesh_arrays[Mesh.ARRAY_VERTEX][i].y)
	surface_arrays[Mesh.ARRAY_INDEX] = mesh_arrays[Mesh.ARRAY_INDEX] 
	var flags = 0
	flags = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	flat_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_arrays,[],{},flags)
	#print(flat_array_mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0][100])
	flat_mesh.mesh = flat_array_mesh
	sub_viewport.add_child(flat_mesh)
	var shader_material = ShaderMaterial.new()
	shader_material.shader = HumanizerResourceService.load_resource("res://addons/humanizer/scripts/overlay/whorley_GPU.gdshader") 
	shader_material.set_shader_parameter("seed",seed)
	shader_material.set_shader_parameter("grid_size",grid_size)
	flat_mesh.material = shader_material
	return node
