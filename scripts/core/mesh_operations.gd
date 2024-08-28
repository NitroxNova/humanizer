class_name MeshOperations

static func calculate_mhclo_scale(helper_vertex_array: Array, mhclo: MHCLO) -> Vector3:
	var mhclo_scale = Vector3.ZERO
	for axis in ["x","y","z"]:
		var scale_data = mhclo.scale_config[axis]
		var start_coords = helper_vertex_array[scale_data.start]
		var end_coords = helper_vertex_array[scale_data.end]
		var basemesh_dist = absf(end_coords[axis] - start_coords[axis])
		mhclo_scale[axis] = basemesh_dist/scale_data.length
	return mhclo_scale

static func get_mhclo_vertex_position( helper_vertex_array: PackedVector3Array, vertex_line:Dictionary, mhclo_scale:Vector3):
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
		new_coords += (vertex_line.offset * mhclo_scale)
	return new_coords
