@tool
extends RefCounted
class_name HumanizerUtils

#requires that the mh_id already be set in the Custom0 array, which happens in the obj_to_mesh importer
static func get_mh2gd_index_from_mesh(input_mesh:ArrayMesh):
	var mh2gd_index = []
	var sf_arrays = input_mesh.surface_get_arrays(0)
	for gd_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = sf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		if not mh_id < mh2gd_index.size():
			mh2gd_index.resize(mh_id + 1)
		if mh2gd_index[mh_id] == null:
			mh2gd_index[mh_id] = PackedInt32Array()
		mh2gd_index[mh_id].append(gd_id)
	return mh2gd_index



static func set_node_owner(node:Node,owner:Node):
	for child in node.get_children():
		set_node_owner(child,owner)
	node.owner=owner

	
