extends RefCounted
class_name MeshShading

# Add shading for shapekeys
func run(import_mesh: ArrayMesh = null) -> ArrayMesh:
	print('Starting mesh shading')
	# Set up data
	var start_time = Time.get_ticks_msec()
	var ST = SurfaceTool.new()
	var shaded_mesh := ArrayMesh.new()
	if import_mesh == null:
		import_mesh = load("res://addons/humanizer/data/resources/unshaded.res") as ArrayMesh
	var import_sf_arrays = import_mesh.surface_get_arrays(0)
	var import_blend_arrays = import_mesh.surface_get_blend_shape_arrays(0)	
	var lite_mesh = ArrayMesh.new()
	var blend_shapes = []
	
	# Basis shading
	shaded_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	ST.create_from(import_mesh,0)
	ST.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	ST.generate_normals()
	ST.generate_tangents()
	var mesh_arrays = ST.commit_to_arrays()
	ST.clear()
	
	# Make Lite Mesh (No skeleton/skin arrays)
	lite_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for bs_index in import_mesh.get_blend_shape_count():
		var bs_name = import_mesh.get_blend_shape_name(bs_index)
		lite_mesh.add_blend_shape(bs_name)
	var new_sf_arrays = []
	new_sf_arrays.resize(Mesh.ARRAY_MAX)
	new_sf_arrays[Mesh.ARRAY_VERTEX] = import_sf_arrays[Mesh.ARRAY_VERTEX]
	new_sf_arrays[Mesh.ARRAY_INDEX] = import_sf_arrays[Mesh.ARRAY_INDEX]
	new_sf_arrays[Mesh.ARRAY_TEX_UV] = import_sf_arrays[Mesh.ARRAY_TEX_UV]
	lite_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_sf_arrays, import_blend_arrays)

	# Generate shading for shapekeys
	for bs_index in import_mesh.get_blend_shape_count():
		var bs_name := import_mesh.get_blend_shape_name(bs_index)
		#print('Working on shapekey : ' + bs_name)
		ST.create_from_blend_shape(lite_mesh, 0, bs_name)
		ST.generate_normals()
		ST.generate_tangents()
		var commit_array := ST.commit_to_arrays()
		shaded_mesh.add_blend_shape(bs_name)
		var curr_bs := []
		curr_bs.resize(Mesh.ARRAY_MAX)
		curr_bs[Mesh.ARRAY_VERTEX] = commit_array[Mesh.ARRAY_VERTEX]
		curr_bs[Mesh.ARRAY_NORMAL] = commit_array[Mesh.ARRAY_NORMAL]
		curr_bs[Mesh.ARRAY_TANGENT] = commit_array[Mesh.ARRAY_TANGENT]
		blend_shapes.append(curr_bs)
		ST.clear()
		
	# Save results
	var flags = import_mesh.surface_get_format(0)
	shaded_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh_arrays,blend_shapes,{},flags)
	print('Finished shading mesh: Took ' + str((Time.get_ticks_msec() - start_time) / 1e3) + 's')
	return shaded_mesh
