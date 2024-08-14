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
