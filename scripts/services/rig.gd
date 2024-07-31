@tool
extends Resource
class_name HumanizerRigService

static func get_rig(rig_name:String)->HumanizerRig:
	return HumanizerRegistry.rigs[rig_name.split('-')[0]]

static func get_skeleton_3D(skeleton_data:Dictionary,bone_ids:Array):
	var skeleton = Skeleton3D.new()
	skeleton.name = "GeneralSkeleton"
	for bone_id in bone_ids.size():
		var bone_name = bone_ids[bone_id]
		var bone_data = skeleton_data[bone_name]
		skeleton.add_bone(bone_name)
		skeleton.set_bone_rest(bone_id,bone_data.xform)
		if "parent" in bone_data:
			var parent_id = skeleton.find_bone(bone_data.parent)
			skeleton.set_bone_parent(bone_id,parent_id)
	return skeleton

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
		bone_data.xform = skeleton.get_bone_rest(bone_id)
		skeleton_data[bone_name] = bone_data
	
	return skeleton_data

static func set_body_weights_array(rig: HumanizerRig,body_arrays:Array):
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

