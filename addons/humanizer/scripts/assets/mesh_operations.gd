class_name MeshOperations


static func generate_normals_and_tangents(import_mesh:ArrayMesh):
	var ST = SurfaceTool.new()
	ST.clear()
	ST.create_from(import_mesh,0)
	ST.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	ST.generate_normals()
	ST.generate_tangents()
	var flags = import_mesh.surface_get_format(0)
	var new_mesh = ST.commit(null,flags)
	return new_mesh

static func build_fitted_mesh(mesh: ArrayMesh, helper_vertex_array: PackedVector3Array, mhclo: MHCLO) -> ArrayMesh: 
	# the static mesh with no shapekeys
	var new_mesh = ArrayMesh.new()
	var new_sf_arrays = build_fitted_arrays(mesh, helper_vertex_array, mhclo)
	var flags = mesh.surface_get_format(0)
	var lods := {}
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays, [], lods, flags)
	return new_mesh

static func build_fitted_arrays(mesh: ArrayMesh, helper_vertex_array: PackedVector3Array, mhclo: MHCLO) -> Array: 
	var new_sf_arrays = mesh.surface_get_arrays(0)
	var clothes_scale = Vector3.ZERO
	clothes_scale.x = _calculate_scale("x", helper_vertex_array, mhclo)
	clothes_scale.y = _calculate_scale("y", helper_vertex_array, mhclo)
	clothes_scale.z = _calculate_scale("z", helper_vertex_array, mhclo)
	for mh_id in mhclo.vertex_data.size():
		var vertex_line = mhclo.vertex_data[mh_id]
		var new_coords = Vector3.ZERO
		if vertex_line.format == "single":
			var vertex_id = vertex_line.vertex[0]
			new_coords = helper_vertex_array[vertex_id]
		else:
			for i in 3:
				var vertex_id = vertex_line.vertex[i]
				var v_weight = vertex_line.weight[i]
				var v_coords = helper_vertex_array[vertex_id]
				v_coords *= v_weight
				new_coords += v_coords
			new_coords += (vertex_line.offset * clothes_scale)
		var g_id_array = mhclo.mh2gd_index[mh_id]
		for g_id in g_id_array:
			new_sf_arrays[Mesh.ARRAY_VERTEX][g_id] = new_coords
			
	#if bone_weights_enabled:
	#	add_bone_weights(new_sf_arrays)
	return new_sf_arrays

static func _calculate_scale(axis: String, helper_vertex_array: Array, mhclo: MHCLO) -> float:
	# axis = x y or z
	var scale_data = mhclo.scale_config[axis]
	var start_coords = helper_vertex_array[scale_data.start]
	var end_coords = helper_vertex_array[scale_data.end]
	var basemesh_dist = absf(end_coords[axis] - start_coords[axis])
	var scale = basemesh_dist/scale_data.length
	return scale
	
static func skin_mesh(rig: HumanizerRig, skeleton: Skeleton3D, basemesh: ArrayMesh) -> ArrayMesh:
	# Load bone and weight arrays for base mesh
	var mesh_arrays = basemesh.surface_get_arrays(0)
	var lods := {}
	var flags := basemesh.surface_get_format(0)
	var weights = rig.load_bone_weights()
	var helper_mesh = load("res://addons/humanizer/data/resources/base_helpers.res")
	var mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(helper_mesh)
	var mh_bone_array = []
	var mh_weight_array = []
	var len = mesh_arrays[Mesh.ARRAY_VERTEX].size()
	mh_bone_array.resize(len)
	mh_weight_array.resize(len)
	# Read mh skeleton weights
	for bone_name in weights:
		var bone_id = skeleton.find_bone(bone_name)
		for bw_pair in weights[bone_name]:
			var mh_id = bw_pair[0]
			if mh_id >= len:  # Helper verts
				continue
			var weight = bw_pair[1]
			if mh_bone_array[mh_id] == null:
				mh_bone_array[mh_id] = PackedInt32Array()
				mh_weight_array[mh_id] = PackedFloat32Array()
			mh_bone_array[mh_id].append(bone_id)
			mh_weight_array[mh_id].append(weight)
	# Normalize
	for mh_id in mh_bone_array.size():
		var array = mh_weight_array[mh_id]
		var multiplier : float = 0
		for weight in array:
			multiplier += weight
		multiplier = 1 / multiplier
		for i in array.size():
			array[i] *= multiplier
		mh_weight_array[mh_id] = array
		mh_bone_array[mh_id].resize(8)
		mh_weight_array[mh_id].resize(8)
	# Convert to godot vertex format
	mesh_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	mesh_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	for gd_id in mesh_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = mesh_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		mesh_arrays[Mesh.ARRAY_BONES].append_array(mh_bone_array[mh_id])
		mesh_arrays[Mesh.ARRAY_WEIGHTS].append_array(mh_weight_array[mh_id])
	# Build new mesh
	var skinned_mesh = ArrayMesh.new()
	skinned_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for bs in basemesh.get_blend_shape_count():
		skinned_mesh.add_blend_shape(basemesh.get_blend_shape_name(bs))
	skinned_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays, [], lods, flags)
	return skinned_mesh
