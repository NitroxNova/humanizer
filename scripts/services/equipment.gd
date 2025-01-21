@tool
extends Resource
class_name HumanizerEquipmentService

static func load_mesh_arrays(equip:HumanizerEquipmentType):
	var sf_arrays = []
	sf_arrays.resize(Mesh.ARRAY_MAX)
	var mhclo = HumanizerResourceService.load_resource(equip.mhclo_path)
	sf_arrays[Mesh.ARRAY_TEX_UV] = mhclo.uv_array.duplicate()
	sf_arrays[Mesh.ARRAY_INDEX] = mhclo.index_array.duplicate()
	sf_arrays[Mesh.ARRAY_CUSTOM0] = mhclo.custom0_array.duplicate()
	sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	sf_arrays[Mesh.ARRAY_VERTEX].resize(mhclo.uv_array.size())
	sf_arrays[Mesh.ARRAY_VERTEX].fill(Vector3.ZERO)
	return sf_arrays

static func fit_mesh_arrays(mesh_arrays:Array, helper_vertex_array: PackedVector3Array, mhclo: MHCLO) -> Array: 
	var clothes_scale =	mhclo.calculate_mhclo_scale(helper_vertex_array)
	for mh_id in mhclo.vertex_data.size():
		var vertex_line = mhclo.vertex_data[mh_id]
		var new_coords = mhclo.get_mhclo_vertex_position(helper_vertex_array,vertex_line,clothes_scale)
		var g_id_array = mhclo.mh2gd_index[mh_id]
		for g_id in g_id_array:
			mesh_arrays[Mesh.ARRAY_VERTEX][g_id] = new_coords
	return mesh_arrays

static func _sort_by_z_depth(clothes_a: HumanizerEquipment, clothes_b: HumanizerEquipment): # from highest to lowest
	if HumanizerResourceService.load_resource(clothes_a.get_type().mhclo_path).z_depth > HumanizerResourceService.load_resource(clothes_b.get_type().mhclo_path).z_depth:
		return true
	return false

static func show_vertices(equip_list:Dictionary,mesh_arrays:Dictionary):
	for equip:HumanizerEquipment in equip_list.values():
		var equip_type :HumanizerEquipmentType = equip.get_type()
		var mhclo = HumanizerResourceService.load_resource(equip_type.mhclo_path)
		mesh_arrays[equip.type][Mesh.ARRAY_INDEX] = mhclo.index_array.duplicate()

static func hide_vertices(equip_list:Dictionary,mesh_arrays:Dictionary):
	var delete_verts_mh := []
	delete_verts_mh.resize(HumanizerTargetService.data.basis.size())
	var depth_sorted_clothes := []
	for equip in equip_list.values():
		depth_sorted_clothes.append(equip)
	depth_sorted_clothes.sort_custom(_sort_by_z_depth)
	
	for equip:HumanizerEquipment in depth_sorted_clothes:
		var equip_type: HumanizerEquipmentType = equip.get_type()
		var mhclo : MHCLO = HumanizerResourceService.load_resource(equip_type.mhclo_path)
		var cl_delete_verts_mh = []
		cl_delete_verts_mh.resize(mhclo.vertex_data.size())
		cl_delete_verts_mh.fill(false)
		var cl_delete_verts_gd = []
		#print(mesh_arrays[equip.type])
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

static func interpolate_weights( mhclo:MHCLO, rig:HumanizerRig,skeleton_data:Dictionary):
	#"""Try to copy rigging weights from the base mesh to the clothes mesh, hopefully #making the clothes fit the provided rig."""
	# Create an empty outline with placeholders arrays that will contain lists of
	# vertices + weights per vertex group
	var clothes_weights = []
	for i in mhclo.vertex_data.size():
		clothes_weights.append([])
		
	var bone_weights = HumanizerResourceService.load_resource(rig.bone_weights_json_path)
	
	# Build cross reference dicts to easily map between a vertex group index and # a vertex group name
	var group_index = []
	for bone_name in bone_weights.names:
		var new_bone_id = skeleton_data.keys().find(bone_name)
		if new_bone_id == -1:
			if bone_name.begins_with('toe'):
				if bone_name.ends_with('.L'): # default rig, example: toe4-1.R
					new_bone_id = skeleton_data.keys().find("toe1-1.L")
				elif bone_name.ends_with('.R'):
					new_bone_id = skeleton_data.keys().find("toe1-1.R")
				else:
					printerr("Unhandled bone " + bone_name)
		group_index.append(new_bone_id)
	for bone_name in bone_weights.names:
		var new_id = skeleton_data.keys().find(bone_name)
		group_index.append(new_id)		
	# We will now iterate over the vertices in the clothes. The idea is to then
	for vert_id in mhclo.vertex_data.size():
		var vert_groups = {}
		for match_vert in mhclo.vertex_data[vert_id].vertex.size():
			# Which human vert is the clothes vert tied to?
			var human_vert = mhclo.vertex_data[vert_id].vertex[match_vert]
			# .. and by how much?
			var assigned_weight = 1 #if its a single vertex
			if "weight" in mhclo.vertex_data[vert_id]:
				assigned_weight = mhclo.vertex_data[vert_id].weight[match_vert]
			for bone_weight_pair in bone_weights.weights[human_vert]:
				var idx = bone_weight_pair[0]
				var skeleton_bone_id = group_index[idx] #these can be different, ie no toes on standard rig
				if not skeleton_bone_id == -1:
					if not skeleton_bone_id in vert_groups:
						vert_groups[skeleton_bone_id] = 0
					vert_groups[skeleton_bone_id] += assigned_weight * bone_weight_pair[1]
		# Iterate over all found vertex groups for the current clothes vertex
		# and calculcate the average weight for each group
		var mhclo_weight_sum = 0
		if "weight" in mhclo.vertex_data[vert_id]:
			for vert_weight in mhclo.vertex_data[vert_id].weight:
				mhclo_weight_sum += vert_weight
		else:
			mhclo_weight_sum = 1*mhclo.vertex_data[vert_id].vertex.size()
		for skeleton_bone_id in vert_groups:
			var average_weight = vert_groups[skeleton_bone_id] / mhclo_weight_sum
			# If the caculated average weight is below 0.001 we will ignore it. This
			# makes the interpolation much faster later on
			if average_weight > 0.001:
				clothes_weights[vert_id].append([skeleton_bone_id, average_weight])
		if clothes_weights[vert_id].is_empty():
			printerr("empty weights" + str(vert_groups))
	
	for bw_array in clothes_weights:
		var weight_sum = 0
		for bw_pair in bw_array:
			weight_sum += bw_pair[1]
		for bw_pair in bw_array:
			bw_pair[1] /= weight_sum
		while bw_array.size() < 8:
			bw_array.append([0,0])
		while bw_array.size() > 8:
			var lowest = bw_array[0]
			for bw_pair in bw_array:
				if bw_pair[1] < lowest[1]:
					lowest = bw_pair
			bw_array.erase(lowest)
			
	mhclo.bones[rig.resource_name] = PackedInt32Array()
	mhclo.weights[rig.resource_name] = PackedFloat32Array()
	for mh_id in mhclo.custom0_array:
		for bw_pair in clothes_weights[mh_id]:
			mhclo.bones[rig.resource_name].append(bw_pair[0])
			mhclo.weights[rig.resource_name].append(bw_pair[1])

static func interpolate_rigged_weights(mhclo:MHCLO, rigged_bone_weights:Dictionary,rig_name:String):
	var base_bones = mhclo.bones[rig_name]
	var base_weights = mhclo.weights[rig_name]
	
	var output = {}
	output.bones = PackedInt32Array()
	output.weights = PackedFloat32Array()
	
	for gd_id in mhclo.custom0_array.size():
		var mh_id = mhclo.custom0_array[gd_id]
		var mh_bones = []
		var mh_weights = []
		var remainder = 0
		for array_id in rigged_bone_weights.bones[mh_id].size():
			if rigged_bone_weights.weights[mh_id][array_id] != 0:
				var old_id = rigged_bone_weights.bones[mh_id][array_id]
				var bone_id = -1
				for new_id in rigged_bone_weights.config.size():
					if rigged_bone_weights.config[new_id].old_id == old_id:
						bone_id = new_id
				if bone_id == -1: # the "neutral bone", where the hair connects to the head, for example
					remainder += rigged_bone_weights.weights[mh_id][array_id]
				else:
					mh_bones.append((bone_id+1)*-1) #offset by one because -0 = 0
					mh_weights.append(rigged_bone_weights.weights[mh_id][array_id])
		if remainder > 0:
			for array_id in range(gd_id*8,(gd_id+1)*8):
				if base_weights[array_id] > 0:
					mh_bones.append(base_bones[array_id])
					#assuming rigged weights are already normalized
					mh_weights.append(base_weights[array_id] * remainder)
		while mh_bones.size() < 8:
			mh_bones.append(0)
			mh_weights.append(0)
		while mh_bones.size() > 8:
			var lowest_id = 0
			for w in mh_weights.size():
				if mh_weights[w] < mh_weights[lowest_id]:
					lowest_id = w
			mh_bones.remove_at(lowest_id)
			mh_weights.remove_at(lowest_id)
		output.bones.append_array(mh_bones)
		output.weights.append_array(mh_weights)
	
	return output
