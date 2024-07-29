class_name MeshOperations

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
	var clothes_scale = calculate_mhclo_scale(helper_vertex_array,mhclo)
	for mh_id in mhclo.vertex_data.size():
		var vertex_line = mhclo.vertex_data[mh_id]
		var new_coords = get_mhclo_vertex_position(helper_vertex_array,vertex_line,clothes_scale)
		var g_id_array = mhclo.mh2gd_index[mh_id]
		for g_id in g_id_array:
			new_sf_arrays[Mesh.ARRAY_VERTEX][g_id] = new_coords
			
	#if bone_weights_enabled:
	#	add_bone_weights(new_sf_arrays)
	return new_sf_arrays

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
	
static func skin_mesh(rig: HumanizerRig, skeleton: Skeleton3D, basemesh: ArrayMesh) -> ArrayMesh:
	# Load bone and weight arrays for base mesh
	var mesh_arrays = basemesh.surface_get_arrays(0)
	var lods := {}
	var flags := basemesh.surface_get_format(0)

	mesh_arrays = HumanizerRigService.set_body_weights_array(rig,mesh_arrays)

	# Build new mesh
	var skinned_mesh = ArrayMesh.new()
	skinned_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for bs in basemesh.get_blend_shape_count():
		skinned_mesh.add_blend_shape(basemesh.get_blend_shape_name(bs))
	skinned_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays, [], lods, flags)
	return skinned_mesh

static func prepare_shapekeys_for_baking(human_config: HumanConfig, _new_shapekeys: Dictionary) -> void:
	# Add new shapekeys entries from shapekey components
	if human_config.components.has(&'size_morphs') and human_config.components.has(&'age_morphs'):
		# Use "average" as basis
		human_config.shapekeys['muscle'] = 0.5
		human_config.shapekeys['weight'] = 0.5
		human_config.shapekeys['age'] = 0.25
		for sk in _new_shapekeys:
			_new_shapekeys[sk]['muscle'] = 0.5
			_new_shapekeys[sk]['weight'] = 0.5
			_new_shapekeys[sk]['age'] = 0.25
		var new_sks = _new_shapekeys.duplicate()
		for age in HumanizerMorphs.AGE_KEYS:
			for muscle in HumanizerMorphs.MUSCLE_KEYS:
				for weight in HumanizerMorphs.WEIGHT_KEYS:
					if muscle == 'avgmuscle' and weight == 'avgweight' and age == 'young':
						continue # Basis
					var key = '-'.join([muscle, weight, age])
					var shape = human_config.shapekeys.duplicate(true)
					shape['muscle'] = HumanizerMorphs.MUSCLE_KEYS[muscle]
					shape['weight'] = HumanizerMorphs.WEIGHT_KEYS[weight]
					shape['age'] = HumanizerMorphs.AGE_KEYS[age]
					_new_shapekeys['base-' + key] = shape
					for sk_name in new_sks:
						shape = new_sks[sk_name].duplicate(true)
						shape['muscle'] = HumanizerMorphs.MUSCLE_KEYS[muscle]
						shape['weight'] = HumanizerMorphs.WEIGHT_KEYS[weight]
						shape['age'] = HumanizerMorphs.AGE_KEYS[age]
						_new_shapekeys[sk_name + '-' + key] = shape
	elif human_config.components.has(&'size_morphs'):
		human_config.shapekeys['muscle'] = 0.5
		human_config.shapekeys['weight'] = 0.5
		for sk in _new_shapekeys:
			_new_shapekeys[sk]['muscle'] = 0.5
			_new_shapekeys[sk]['weight'] = 0.5
		var new_sks = _new_shapekeys.duplicate()
		for muscle in HumanizerMorphs.MUSCLE_KEYS:
			for weight in HumanizerMorphs.WEIGHT_KEYS:
				if muscle == 'avgmuscle' and weight == 'avgweight':
					continue # Basis
				var key = '-'.join([muscle, weight])
				var shape = human_config.shapekeys.duplicate(true)
				shape['muscle'] = HumanizerMorphs.MUSCLE_KEYS[muscle]
				shape['weight'] = HumanizerMorphs.WEIGHT_KEYS[weight]
				_new_shapekeys['base-' + key] = shape
				for sk_name in new_sks:
					shape = new_sks[sk_name].duplicate(true)
					shape['muscle'] = HumanizerMorphs.MUSCLE_KEYS[muscle]
					shape['weight'] = HumanizerMorphs.WEIGHT_KEYS[weight]
					_new_shapekeys[sk_name + '-' + key] = shape
	elif human_config.components.has(&'age_morphs'):
		human_config.shapekeys['age'] = 0.25
		for sk in _new_shapekeys:
			_new_shapekeys[sk]['age'] = 0.25
		var new_sks = _new_shapekeys.duplicate()
		for age in HumanizerMorphs.AGE_KEYS:
			if age == 'young':
				continue 
			var shape = human_config.shapekeys.duplicate(true)
			shape['age'] = HumanizerMorphs.AGE_KEYS[age]
			_new_shapekeys['base-' + age] = shape
			for sk_name in new_sks:
				shape = new_sks[sk_name].duplicate(true)
				shape['age'] = HumanizerMorphs.AGE_KEYS[age]
				_new_shapekeys[sk_name + '-' + age] = shape

