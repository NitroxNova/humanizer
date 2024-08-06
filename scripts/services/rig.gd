@tool
extends Resource
class_name HumanizerRigService

static func get_rig(rig_name:String)->HumanizerRig:
	return HumanizerRegistry.rigs[rig_name.split('-')[0]]

static func get_skeleton_3D(skeleton_data:Dictionary):
	var skeleton = Skeleton3D.new()
	skeleton.name = "GeneralSkeleton"
	rebuild_skeleton_3D(skeleton,skeleton_data)
	skeleton.set_unique_name_in_owner(true)
	return skeleton

static func rebuild_skeleton_3D(skeleton3D:Skeleton3D,skeleton_data:Dictionary):
	skeleton3D.clear_bones()
	for bone_name in skeleton_data:
		skeleton3D.add_bone(bone_name)
	
	#because root bone is added after
	for bone_name in skeleton_data:
		var bone_data = skeleton_data[bone_name]
		var bone_id = skeleton3D.find_bone(bone_name)
		if "parent" in bone_data:
			var parent_id = skeleton3D.find_bone(bone_data.parent)
			skeleton3D.set_bone_parent(bone_id,parent_id)
	adjust_skeleton_3D(skeleton3D,skeleton_data)

static func adjust_skeleton_3D(skeleton3D:Skeleton3D,skeleton_data:Dictionary):
	for bone_name in skeleton_data:
		var bone_id = skeleton3D.find_bone(bone_name)
		var bone_data = skeleton_data[bone_name]
		var local_pos = bone_data.global_pos
		if "parent" in bone_data:
			var parent_id = skeleton3D.find_bone(bone_data.parent)
			var parent_xform = skeleton3D.get_bone_global_rest(parent_id)
			local_pos = local_pos * parent_xform
		var bone_xform = Transform3D(bone_data.local_xform)
		bone_xform.origin = local_pos
		skeleton3D.set_bone_rest(bone_id, bone_xform)
		skeleton3D.reset_bone_pose(bone_id)
	
		
static func adjust_bone_positions(skeleton_data:Dictionary,rig:HumanizerRig,helper_vertex:PackedVector3Array):
	var skeleton_config = HumanizerUtils.read_json(rig.config_json_path)
	var bone_id = 0
	for bone_name in skeleton_data:
		var bone_pos = Vector3.ZERO
		## manually added bones won't be in the config
		if skeleton_config.size() < bone_id + 1:
			#bone_pos = asset_bone_positions[bone_id]
			pass
		else:
			var bone_data = skeleton_config[bone_id]
			if "vertex_indices" in bone_data.head:
				for vid in bone_data.head.vertex_indices:
					bone_pos += helper_vertex[int(vid)]
				bone_pos /= bone_data.head.vertex_indices.size()
			else:
				bone_pos = helper_vertex[int(bone_data.head.vertex_index)]
		if bone_name == 'Root':
			bone_pos = Vector3.ZERO  # Root should always be at origin
		skeleton_data[bone_name].global_pos = bone_pos
		bone_id += 1
				
static func init_skeleton_data(rig: HumanizerRig,retargeted:bool)->Dictionary:
	var skeleton_data = {}
	
	var skeleton : Skeleton3D
	if retargeted:
		skeleton = rig.load_retargeted_skeleton()
	else:
		skeleton = rig.load_skeleton()
	#
	for bone_id in skeleton.get_bone_count():
		var bone_name = skeleton.get_bone_name(bone_id)
		var bone_data = {}
		var parent_id = skeleton.get_bone_parent(bone_id)
		if parent_id != -1:
			bone_data.parent = skeleton.get_bone_name(parent_id)
		bone_data.local_xform = skeleton.get_bone_rest(bone_id)
		bone_data.global_pos = skeleton.get_bone_global_rest(bone_id).origin
		skeleton_data[bone_name] = bone_data
	
	return skeleton_data

static func set_body_weights_array(rig: HumanizerRig,body_arrays:Array):
	#print("HumanizerRigService - set body weights array")
	var weights = HumanizerUtils.read_json(rig.bone_weights_json_path)
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
	body_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	body_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	for gd_id in body_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = body_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		body_arrays[Mesh.ARRAY_BONES].append_array(mh_bone_array[mh_id])
		body_arrays[Mesh.ARRAY_WEIGHTS].append_array(mh_weight_array[mh_id])

static func set_equipment_weights_array(equip:HumanAsset,  mesh_arrays:Array, rig:HumanizerRig, skeleton_data:Dictionary):
	var bone_weights = HumanizerUtils.read_json(rig.bone_weights_json_path)
	var bone_count = 8
	var mhclo: MHCLO = load(equip.mhclo_path) 
	var mh2gd_index = mhclo.mh2gd_index
	mesh_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	mesh_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	var rigged_bone_ids = []
	var mh_bone_weights = []
	for mh_id in mhclo.vertex_data.size():	
		var vertex_bone_weights = mhclo.calculate_vertex_bone_weights(mh_id,bone_weights, rigged_bone_ids)
		mh_bone_weights.append(vertex_bone_weights)
		#print(vertex_bone_weights)
	for gd_id in mesh_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = mesh_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		mesh_arrays[Mesh.ARRAY_BONES].append_array(mh_bone_weights[mh_id].bones)
		mesh_arrays[Mesh.ARRAY_WEIGHTS].append_array(mh_bone_weights[mh_id].weights)		

static func get_motion_scale(rig_name:String, helper_vertex:PackedVector3Array):
	var base_motion_scale = _get_base_motion_scale(rig_name)
	var hips_height = HumanizerBodyService.get_hips_height(helper_vertex)
	var base_hips_height = HumanizerBodyService.get_hips_height(HumanizerTargetService.data.basis)
	return base_motion_scale * (hips_height  / base_hips_height)

static func _get_base_motion_scale(rig_name:String):
	var sk: Skeleton3D
	var retargeted = is_retargeted(rig_name)
	var rig = get_rig(rig_name)
	if retargeted:
		sk = rig.load_retargeted_skeleton()
	else:
		sk = rig.load_skeleton()
	return sk.motion_scale


static func is_retargeted(rig_name:String):
	if rig_name.ends_with("RETARGETED"):
		return true
	return false

#static func adjust_skeleton_3D(skeleton:Skeleton3D,skeleton_data:Dictionary,rig:HumanizerRig,helper_vertex:PackedVector3Array):
	
	
	#var _foot_offset = HumanizerBodyService.get_foot_offset(helper_vertex)
	##print(_foot_offset)
	#skeleton.motion_scale = 1
	
	#var asset_bone_positions = []
	#asset_bone_positions.resize(skeleton.get_bone_count())	
	#if not baked:
		#for equip in human_config.equipment.values():
			#if equip.rigged:
				#_get_asset_bone_positions(equip, asset_bone_positions)
	
	
		#var parent_id = skeleton.get_bone_parent(bone_id)
		#if not parent_id == -1:
			#var parent_xform = skeleton.get_bone_global_pose(parent_id)
			#bone_pos = bone_pos * parent_xform
		#skeleton.set_bone_pose_position(bone_id, bone_pos)
		#skeleton.set_bone_rest(bone_id, skeleton.get_bone_pose(bone_id))

	
	#skeleton.motion_scale = _base_motion_scale * (humanizer.get_hips_height() - _foot_offset) / _base_hips_height

	#print('Fit skeleton to mesh')

func _get_asset_bone_positions(skeleton:Skeleton3D,asset:HumanAsset, bone_positions:Array):
	var sf_arrays = asset.node.mesh.surface_get_arrays(0)
	var mhclo : MHCLO = load(asset.mhclo_path)
	for rig_bone_id in mhclo.rigged_config.size():
		var bone_config =  mhclo.rigged_config[rig_bone_id]
		var bone_name = bone_config.name
		var bone_id = skeleton.find_bone(bone_name)
		if bone_id != -1:
			var v1 = sf_arrays[Mesh.ARRAY_VERTEX][mhclo.mh2gd_index[bone_config.vertices.ids[0]][0]]
			var v2 = sf_arrays[Mesh.ARRAY_VERTEX][mhclo.mh2gd_index[bone_config.vertices.ids[1]][0]]
			bone_positions[bone_id] = 0.5 * (v1+v2) + bone_config.vertices.offset




#func add_equipment_weights(equip:HumanAsset, rig:HumanizerRig, skeleton:Skeleton3D, mesh_arrays:Array):
	#if equip.rigged:
		#for bone_id in mhclo.rigged_config.size():
			#var bone_config = mhclo.rigged_config[bone_id]
			#if bone_config.name != "neutral_bone":
				#var bone_name = bone_config.name
				##print("adding bone " + bone_name)
				#var parent_bone = -1
				#if bone_config.parent == -1:
					#for tag in mhclo.tags:
						#if tag.begins_with("bone_name"):
							#var parent_name = tag.get_slice(" ",1)
							#parent_bone = skeleton.find_bone(parent_name)
							#if parent_bone != -1:
								#break
				#else:
					#var parent_bone_config = mhclo.rigged_config[bone_config.parent]
					#parent_bone = skeleton.find_bone(parent_bone_config.name)
				#if not parent_bone == -1:
					#skeleton.add_bone(bone_name)
					#var new_bone_id = skeleton.find_bone(bone_name)
					#skeleton.set_bone_parent(new_bone_id,parent_bone)
					#skeleton.set_bone_rest(new_bone_id, bone_config.transform)
						#
	#var rigged_bone_ids = []
	#if equip.rigged:
		#for rig_bone_id in mhclo.rigged_config.size():
			#var bone_name = mhclo.rigged_config[rig_bone_id].name
			#rigged_bone_ids.append(skeleton.find_bone(bone_name))

