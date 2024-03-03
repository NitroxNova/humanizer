#  Merges previously collected shapekey data with base mesh
class_name ShapeKeyMerge
extends RefCounted

func run():
	print('Merging shape keys')
	# Set up data
	var human_mesh = load("res://addons/humanizer/data/resources/base_human.res")
	var mesh_arrays = human_mesh.surface_get_arrays(0)
	var helper_arrays = load("res://addons/humanizer/data/resources/base_helpers.res").surface_get_arrays(0)
	var shapekey_data = HumanizerUtils.get_shapekey_data()
	var human_vertex = mesh_arrays[Mesh.ARRAY_VERTEX]
	var blend_arrays := []
	var new_mesh := ArrayMesh.new()

	var mh2gd_index = Utils.get_mh2gd_index_from_mesh(human_mesh)
	for shape_name in shapekey_data.shapekeys:
		new_mesh.add_blend_shape(shape_name)
		var shape_data = shapekey_data.shapekeys[shape_name]
		var new_shape = []
		new_shape.resize(Mesh.ARRAY_MAX)
		new_shape[Mesh.ARRAY_VERTEX] = human_vertex.duplicate()
		for mh_id in shape_data:
			if mh_id < mh2gd_index.size():
				var g_id = mh2gd_index[int(mh_id)]
				var coords = shape_data[mh_id] + shapekey_data.basis[mh_id]
				for i in g_id:
					new_shape[Mesh.ARRAY_VERTEX][i] = coords
		blend_arrays.append(new_shape)

	new_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	var flags = human_mesh.surface_get_format(0)
	mesh_arrays[Mesh.ARRAY_NORMAL] = null
	mesh_arrays[Mesh.ARRAY_TANGENT] = null
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh_arrays, blend_arrays,{},flags)
	ResourceSaver.save(new_mesh, "res://addons/humanizer/data/resources/unshaded.res")

	print('Finished merging shape keys to base mesh')
