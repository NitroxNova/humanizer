extends Resource
class_name HumanizerRigService

static func get_rig(rig_name:String)->HumanizerRig:
	return HumanizerRegistry.rigs[rig_name.split('-')[0]]

static func set_body_weights_array(rig: HumanizerRig,body_arrays:Array)->Array:
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
		
	return body_arrays
	
