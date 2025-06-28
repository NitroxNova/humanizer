@tool
extends Resource
class_name HumanizerRigService

static func get_rig(rig_name:String)->HumanizerRig:
	return HumanizerRegistry.rigs[rig_name]

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
		var equip_type = equip.get_type()
		if equip_type.is_rigged():
			var mhclo : MHCLO = HumanizerResourceService.load_resource(equip_type.mhclo_path)
			for bone_config in equip_type.rig_config.config:
				var bone_id = skeleton_data.keys().find(bone_config.name)
				if bone_id > -1:
					asset_bone_positions[bone_id] = get_asset_bone_position(mesh_arrays[equip.type],mhclo,bone_config)				
	
	var skeleton_config = rig.config
	var bone_id = 0
	for bone_name in skeleton_data:
		var bone_pos = Vector3.ZERO
		if bone_name == 'Root':
			bone_pos = Vector3.ZERO  # Root should always be at origin
		## manually added bones won't be in the config
		elif skeleton_config.size() < bone_id + 1:
			bone_pos = asset_bone_positions[bone_id]
		else:
			bone_pos = get_bone_position_from_config(rig,bone_id,"head",helper_vertex)
		skeleton_data[bone_name].global_pos = bone_pos
		bone_id += 1

static func get_bone_position_from_config(rig,bone_id,head:String,helper_vertex):
	var bone_data = rig.config[bone_id]
	var bone_pos = Vector3.ZERO
	for vid in bone_data[head]:
		bone_pos += helper_vertex[int(vid)]
	bone_pos /= bone_data[head].size()
	return bone_pos
				
#static func init_skeleton_data(rig: HumanizerRig,retargeted:bool)->Dictionary:
static func init_skeleton_data(skeleton:Skeleton3D)->Dictionary:
	var skeleton_data = {}
	#var skeleton : Skeleton3D
	#if retargeted:
		#skeleton = rig.load_retargeted_skeleton()
	#else:
		#skeleton = rig.load_skeleton()
	##
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

static func get_motion_scale(rig_name:String, helper_vertex:PackedVector3Array):
	var base_motion_scale = _get_base_motion_scale(rig_name)
	var hips_height = HumanizerBodyService.get_hips_height(helper_vertex)
	var base_hips_height = HumanizerBodyService.get_hips_height(HumanizerTargetService.basis)
	return base_motion_scale * (hips_height  / base_hips_height)

static func _get_base_motion_scale(rig_name:String):
	var sk: Skeleton3D
	var rig = get_rig(rig_name)
	sk = rig.load_skeleton()
	return sk.motion_scale

static func skeleton_add_rigged_equipment(equipment:HumanizerEquipment, sf_arrays:Array,skeleton_data:Dictionary):
	var mhclo : MHCLO = HumanizerResourceService.load_resource(equipment.get_type().mhclo_path)
	var equip_type = equipment.get_type()
	for bone_id in equip_type.rig_config.config.size():
		var bone_config = equip_type.rig_config.config[bone_id]
		var bone_name = bone_config.name
		skeleton_data[bone_name] = {}
		skeleton_data[bone_name].global_pos = get_asset_bone_position(sf_arrays,mhclo,bone_config)
		skeleton_data[bone_name].local_xform = bone_config.transform
		var parent_name = get_rigged_parent_bone(equip_type.rig_config,bone_id,skeleton_data)
		if parent_name != null:
			skeleton_data[bone_name].parent = parent_name
		else:
			printerr(" no valid attach bones defined for " + equipment.type)
	
static func get_asset_bone_position(sf_arrays:Array,mhclo:MHCLO,bone_config:Dictionary):
	#print(bone_config.vertices.ids)
	var v1 = sf_arrays[Mesh.ARRAY_VERTEX][mhclo.mh2gd_index[bone_config.vertices.ids[0]][0]]
	var v2 = sf_arrays[Mesh.ARRAY_VERTEX][mhclo.mh2gd_index[bone_config.vertices.ids[1]][0]]
	var bone_pos = 0.5 * (v1+v2) + bone_config.vertices.offset
	return bone_pos

static func skeleton_remove_rigged_equipment(equipment:HumanizerEquipment,skeleton_data:Dictionary):
	#var mhclo : MHCLO = HumanizerResourceService.load_resource(equipment.get_type().mhclo_path)
	for bone_config in equipment.get_type().rig_config.config:
		var bone_name = bone_config.name
		skeleton_data.erase(bone_name)			
				
static func get_rigged_parent_bone(rig_config:HumanizerEquipmentRigConfig,bone_id:int,skeleton_data:Dictionary):
	var bone_config = rig_config.config[bone_id]
	if bone_config.parent == -1:
		for parent_name in rig_config.attach_bones:
			if parent_name in skeleton_data:
				return parent_name
	else:
		return rig_config.config[bone_config.parent].name
		 
