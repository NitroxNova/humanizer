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
	var weights = HumanizerUtils.read_json(rig.bone_weights_json_path)
	var helper_mesh = load("res://addons/humanizer/data/resources/base_helpers.res")
	var mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(helper_mesh)
	var mh_bone_array = weights.bones
	var mh_weight_array = weights.weights

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

#delete_verts is boolean true/false array of the same size as the mesh vertex count
#only delete face if all vertices are hidden
static func delete_faces(mesh:ArrayMesh,delete_verts:Array,surface_id=0):
	var surface_arrays = mesh.surface_get_arrays(surface_id)
	var keep_faces := []
	
	for face_id in surface_arrays[Mesh.ARRAY_INDEX].size()/3:
		var slice = surface_arrays[Mesh.ARRAY_INDEX].slice(face_id*3,(face_id+1)*3)
		if not (delete_verts[slice[0]] and delete_verts[slice[1]] and delete_verts[slice[2]]):
			keep_faces.append(slice)
	
	var new_delete_verts = []
	new_delete_verts.resize(delete_verts.size())
	new_delete_verts.fill(true)
	for slice in keep_faces:
		for sl_id in 3:
			new_delete_verts[slice[sl_id]] = false
			
	surface_arrays[Mesh.ARRAY_INDEX].resize(0)		
	for slice in keep_faces:
		surface_arrays[Mesh.ARRAY_INDEX].append_array(slice)
	
	surface_arrays = delete_vertices_from_surface(surface_arrays,new_delete_verts,surface_id)
	
	var new_mesh = ArrayMesh.new()
	var format = mesh.surface_get_format(surface_id)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_arrays,[],{},format)		
	return new_mesh
	
#delete_verts is boolean true/false array of the same size as the mesh vertex count
static func delete_vertices_from_surface(surface_arrays:Array,delete_verts:Array,surface_id=0):  #delete all vertices and faces that use delete_verts
	var vertex_count = surface_arrays[Mesh.ARRAY_VERTEX].size()
	var array_increments = []
	for array_id in surface_arrays.size():
		var array = surface_arrays[array_id]
		if not array_id == Mesh.ARRAY_INDEX and not array==null:
			var increment = array.size() / vertex_count
			array_increments.append([array_id,increment])
	
	for vertex_id in range(vertex_count-1,-1,-1): #go backwards to preserve ids when deleting
		if delete_verts[vertex_id]:
			for incr_id_pair in array_increments:
				var array_id = incr_id_pair[0]
				var increment = incr_id_pair[1]
				for i in increment:
					surface_arrays[array_id].remove_at(increment*vertex_id)
	
	var remap_verts_gd = PackedInt32Array() #old to new
	remap_verts_gd.resize(vertex_count)
	remap_verts_gd.fill(-1)
	var new_vertex_size = 0
	for old_id in vertex_count:
		if not delete_verts[old_id]:
			remap_verts_gd[old_id] = new_vertex_size
			new_vertex_size += 1
	
	var new_index_array = PackedInt32Array()
	for incr in surface_arrays[Mesh.ARRAY_INDEX].size()/3:
		var slice = surface_arrays[Mesh.ARRAY_INDEX].slice(incr*3,(incr+1)*3)
		var new_slice = PackedInt32Array()
		var keep_face = true
		for old_id in slice:
			new_slice.append(remap_verts_gd[old_id])
			if remap_verts_gd[old_id] == -1:
				keep_face = false
		if keep_face:
			new_index_array.append_array(new_slice)
	
	surface_arrays[Mesh.ARRAY_INDEX] = new_index_array	
	return surface_arrays
	


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

