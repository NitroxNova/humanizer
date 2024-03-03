extends RefCounted
class_name ReadBaseMesh


var mh2gd_index = []
var sf_arrays = []
var obj_data

func run():
	print('Generating base mesh resources')
	
	#region Generate base mesh with helpers
	var vertex_groups = HumanizerUtils.read_json("res://addons/humanizer/data/resources/basemesh_vertex_groups.json")
	var obj_to_mesh = ObjToMesh.new("res://addons/humanizer/data/resources/base.obj")
	var helper_mesh = obj_to_mesh.run().mesh

	obj_data = obj_to_mesh.obj_arrays
	sf_arrays = helper_mesh.surface_get_arrays(0)
	mh2gd_index = obj_to_mesh.mh2gd_index
	
	# need to move human mesh upward, so the helper cube between the feet is centered at 0,0,0
	var joint_ground = vertex_groups["joint-ground"][0]
	var ground_offset = Vector3.ZERO
	for mh_id in range(joint_ground[0],joint_ground[1]+1):
		var gd_id = mh2gd_index[mh_id][0]
		var v_pos = sf_arrays[Mesh.ARRAY_VERTEX][gd_id]
		ground_offset += v_pos
	ground_offset /= 8
	for gd_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		sf_arrays[Mesh.ARRAY_VERTEX][gd_id] -= ground_offset
	
	var new_mesh = ArrayMesh.new()
	var flags = helper_mesh.surface_get_format(0)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sf_arrays, [], {}, flags)
	ResourceSaver.save(new_mesh,"res://addons/humanizer/data/resources/base_helpers.res")
	#endregion

	#region Generate uv helper data for hiding vertices
	var mh_uv_index = {face=[], uv=[], mh_index_size = mh2gd_index.size()}
	for face_id in obj_data.face.size():
		var face_data = PackedInt32Array()
		var uv_data = PackedVector2Array()
		for i in 4:
			face_data.append(obj_data.face[face_id][i][0])
			var uv_id = obj_data.face[face_id][i][1]
			uv_data.append(obj_data.uv[uv_id])
		mh_uv_index.face.append(face_data)
		mh_uv_index.uv.append(uv_data)
	
	var save_file = FileAccess.open("res://addons/humanizer/data/resources/mh_uv_index.dat",FileAccess.WRITE)
	save_file.store_var(mh_uv_index)
	save_file.close()
	#endregion

	#region Remove helper vertices to get base mesh
	var mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(helper_mesh)
	var new_index := []
	var old_index := {}
	sf_arrays = helper_mesh.surface_get_arrays(0)
	
	var g_delete_verts = []
	for group_name in ['HelperGeometry', 'JointCubes']:
		var g_vertex_ids = []
		for v_group in vertex_groups[group_name]:
			for mh_id in range(v_group[0],v_group[1] + 1):
				for g_id in mh2gd_index[mh_id]:
					g_vertex_ids.append(g_id)
		g_delete_verts.append_array(g_vertex_ids)
	g_delete_verts.sort()
	g_delete_verts.reverse()

	for i in sf_arrays[Mesh.ARRAY_VERTEX].size():
		new_index.append(i)
	for g_id in g_delete_verts:
		new_index.remove_at(g_id)
	
	for new_id in new_index.size():
		var old_id = new_index[new_id]
		old_index[old_id] = new_id
	
	var new_sf_arrays = []
	new_sf_arrays.resize(Mesh.ARRAY_MAX)
	new_sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	new_sf_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	new_sf_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	new_sf_arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	
	for new_id in new_index.size():
		var old_id = new_index[new_id]
		new_sf_arrays[Mesh.ARRAY_VERTEX].append(sf_arrays[Mesh.ARRAY_VERTEX][old_id])
		new_sf_arrays[Mesh.ARRAY_TEX_UV].append(sf_arrays[Mesh.ARRAY_TEX_UV][old_id])
		new_sf_arrays[Mesh.ARRAY_CUSTOM0].append(sf_arrays[Mesh.ARRAY_CUSTOM0][old_id])
		
	for i in sf_arrays[Mesh.ARRAY_INDEX].size()/3:
		var index_slice = sf_arrays[Mesh.ARRAY_INDEX].slice(i*3,(i+1)*3)
		var valid = true
		for old_id in index_slice:
			if not old_id in old_index:
				valid = false
		if valid:
			var new_slice = []
			for old_id in index_slice:
				var new_id = old_index[old_id]
				new_slice.append(new_id)
			new_sf_arrays[Mesh.ARRAY_INDEX].append_array(new_slice)
			
	for gd_id in new_sf_arrays[Mesh.ARRAY_VERTEX].size():
		new_sf_arrays[Mesh.ARRAY_VERTEX][gd_id] -= ground_offset
	
	new_mesh = ArrayMesh.new()
	flags = helper_mesh.surface_get_format(0)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_sf_arrays, [], {}, flags)
	new_mesh = HumanizerUtils.generate_normals_and_tangents(new_mesh)
	ResourceSaver.save(new_mesh,"res://addons/humanizer/data/resources/base_human.res")
	#endregion
	
	print('Finished generating base mesh resources')
