@tool
extends Resource
class_name HumanizerEquipmentService

static func load_mesh_arrays(equip:HumanizerEquipmentType):
	return load(equip.mesh_path).surface_get_arrays(0)

static func fit_mesh_arrays(mesh_arrays:Array, helper_vertex_array: PackedVector3Array, mhclo: MHCLO) -> Array: 
	var clothes_scale =	MeshOperations.calculate_mhclo_scale(helper_vertex_array,mhclo)
	for mh_id in mhclo.vertex_data.size():
		var vertex_line = mhclo.vertex_data[mh_id]
		var new_coords = MeshOperations.get_mhclo_vertex_position(helper_vertex_array,vertex_line,clothes_scale)
		var g_id_array = mhclo.mh2gd_index[mh_id]
		for g_id in g_id_array:
			mesh_arrays[Mesh.ARRAY_VERTEX][g_id] = new_coords
	return mesh_arrays

static func _sort_by_z_depth(clothes_a: HumanizerEquipment, clothes_b: HumanizerEquipment): # from highest to lowest
	if load(clothes_a.get_type().mhclo_path).z_depth > load(clothes_b.get_type().mhclo_path).z_depth:
		return true
	return false

static func hide_vertices(equip_list:Dictionary,mesh_arrays:Dictionary):
	var delete_verts_mh := []
	delete_verts_mh.resize(HumanizerTargetService.data.basis.size())
	var depth_sorted_clothes := []
	for equip in equip_list.values():
		depth_sorted_clothes.append(equip)
	depth_sorted_clothes.sort_custom(_sort_by_z_depth)
	
	for equip:HumanizerEquipment in depth_sorted_clothes:
		var equip_type: HumanizerEquipmentType = equip.get_type()
		var mhclo : MHCLO = load(equip_type.mhclo_path)
		var cl_delete_verts_mh = []
		cl_delete_verts_mh.resize(mhclo.vertex_data.size())
		cl_delete_verts_mh.fill(false)
		var cl_delete_verts_gd = []
		cl_delete_verts_gd.resize(mesh_arrays[equip.type][Mesh.ARRAY_VERTEX].size())
		cl_delete_verts_gd.fill(false)
		var any_deleted = false
		#
		##refer to transferVertexMaskToProxy in makehuman/shared/proxy.py
		for cl_mh_id in mhclo.vertex_data.size():
			var v_data = mhclo.vertex_data[cl_mh_id]
			var hidden_count = 0
			for hu_mh_id in v_data.vertex:
				if delete_verts_mh[hu_mh_id]:
					hidden_count += 1
			if float(hidden_count)/v_data.vertex.size() >= .66: #if 2/3 or more vertices are hidden, or 1 if theres only 1
				cl_delete_verts_mh[cl_mh_id] = true
		for gd_id in mesh_arrays[equip.type][Mesh.ARRAY_VERTEX].size():
			var mh_id = mesh_arrays[equip.type][Mesh.ARRAY_CUSTOM0][gd_id]
			if cl_delete_verts_mh[mh_id]:
				any_deleted = true
				cl_delete_verts_gd[gd_id] = true
		#
		if any_deleted:
			hide_faces(mesh_arrays[equip.type],cl_delete_verts_gd)			
		#
		##update delete verts to apply to all subsequent clothes
		for entry in mhclo.delete_vertices:
			if entry.size() == 1:
				delete_verts_mh[entry[0]] = true
			else:
				for mh_id in range(entry[0], entry[1] + 1):
					delete_verts_mh[mh_id] = true
					
#delete_verts is boolean true/false array of the same size as the mesh vertex count
#only delete face if all vertices are hidden
static func hide_faces(surface_arrays:Array,delete_verts:Array):
	var keep_faces := PackedInt32Array()
	
	for face_id in surface_arrays[Mesh.ARRAY_INDEX].size()/3:
		var slice = surface_arrays[Mesh.ARRAY_INDEX].slice(face_id*3,(face_id+1)*3)
		if not (delete_verts[slice[0]] and delete_verts[slice[1]] and delete_verts[slice[2]]):
			keep_faces.append_array(slice)
	
	surface_arrays[Mesh.ARRAY_INDEX] = keep_faces

	
