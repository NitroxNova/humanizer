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
	
static func adjust_bone_positions(skeleton_data:Dictionary,rig:HumanizerRig,helper_vertex:PackedVector3Array,equipment:Dictionary,mesh_arrays:Dictionary):
	var asset_bone_positions = []
	asset_bone_positions.resize(skeleton_data.size())
	for equip in equipment.values():
		if equip.rigged:
			var mhclo : MHCLO = load(equip.mhclo_path)
			for bone_config in mhclo.rigged_config:
				var bone_id = skeleton_data.keys().find(bone_config.name)
				if bone_id > -1:
					asset_bone_positions[bone_id] = get_asset_bone_position(mesh_arrays[equip.resource_name],mhclo,bone_config)				
	
	var skeleton_config = HumanizerUtils.read_json(rig.config_json_path)
	var bone_id = 0
	for bone_name in skeleton_data:
		var bone_pos = Vector3.ZERO
		if bone_name == 'Root':
			bone_pos = Vector3.ZERO  # Root should always be at origin
		## manually added bones won't be in the config
		elif skeleton_config.size() < bone_id + 1:
			bone_pos = asset_bone_positions[bone_id]
		else:
			var bone_data = skeleton_config[bone_id]
			if "vertex_indices" in bone_data.head:
				for vid in bone_data.head.vertex_indices:
					bone_pos += helper_vertex[int(vid)]
				bone_pos /= bone_data.head.vertex_indices.size()
			else:
				bone_pos = helper_vertex[int(bone_data.head.vertex_index)]
		
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
	if equip.rigged:
		for bone in mhclo.rigged_config:
			var bone_id = skeleton_data.keys().find(bone.name) 
			rigged_bone_ids.append(bone_id)
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
	
static func skeleton_add_rigged_equipment(equipment:HumanAsset, sf_arrays:Array,skeleton_data:Dictionary):
	var mhclo : MHCLO = load(equipment.mhclo_path)
	for bone_config in mhclo.rigged_config:
		var bone_name = bone_config.name
		if bone_name != "neutral_bone":
			skeleton_data[bone_name] = {}
			skeleton_data[bone_name].global_pos = get_asset_bone_position(sf_arrays,mhclo,bone_config)
			skeleton_data[bone_name].local_xform = bone_config.transform
			var parent_name = get_rigged_parent_bone(mhclo,bone_config,skeleton_data)
			if parent_name != null:
				skeleton_data[bone_name].parent = parent_name
	
static func get_asset_bone_position(sf_arrays:Array,mhclo:MHCLO,bone_config:Dictionary):
	var v1 = sf_arrays[Mesh.ARRAY_VERTEX][mhclo.mh2gd_index[bone_config.vertices.ids[0]][0]]
	var v2 = sf_arrays[Mesh.ARRAY_VERTEX][mhclo.mh2gd_index[bone_config.vertices.ids[1]][0]]
	var bone_pos = 0.5 * (v1+v2) + bone_config.vertices.offset
	return bone_pos

static func skeleton_remove_rigged_equipment(equipment:HumanAsset,skeleton_data:Dictionary):
	var mhclo : MHCLO = load(equipment.mhclo_path)
	for bone_config in mhclo.rigged_config:
		var bone_name = bone_config.name
		skeleton_data.erase(bone_name)			
				
static func get_rigged_parent_bone(mhclo:MHCLO,bone_config:Dictionary,skeleton_data:Dictionary):
	if bone_config.parent == -1:
		for tag in mhclo.tags:
			if tag.begins_with("bone_name"):
				var parent_name = tag.get_slice(" ",1)
				if parent_name in skeleton_data:
					return parent_name
	else:
		return mhclo.rigged_config[bone_config.parent].name
		 
