@tool
extends Resource
class_name Humanizer

var human_config:HumanConfig
var helper_vertex:PackedVector3Array = []
var mesh_arrays : Dictionary = {}
var rig: HumanizerRig 
var skeleton_data : Dictionary = {} #bone names with parent, position and rotation data

func _init(_human_config = null):
	if _human_config == null:
		human_config = HumanConfig.new()
		human_config.targets.init_macros()
		human_config.rig = HumanizerGlobalConfig.config.default_skeleton
	else:	
		human_config = _human_config
	helper_vertex = HumanizerTargetService.init_helper_vertex(human_config.targets)
	mesh_arrays.body = HumanizerBodyService.load_basis_arrays()
	hide_body_vertices()
	for equip in human_config.equipment.values():
		mesh_arrays[equip.resource_name] = HumanizerEquipmentService.load_mesh_arrays(equip)
	fit_all_meshes()
	set_rig(human_config.rig) #this adds the rigged bones and updates all the bone weights
	
	
func get_mesh(mesh_name:String):
	var new_arrays = mesh_arrays[mesh_name].duplicate()
	new_arrays[Mesh.ARRAY_CUSTOM0] = null
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_arrays)
	return HumanizerMeshService.generate_normals_and_tangents(mesh)

func add_equipment(equip:HumanAsset):
	human_config.add_equipment(equip)
	mesh_arrays[equip.resource_name] = HumanizerEquipmentService.load_mesh_arrays(equip)
	fit_equipment_mesh(equip.resource_name)
	if equip.rigged:
		HumanizerRigService.skeleton_add_rigged_equipment(equip,mesh_arrays[equip.resource_name], skeleton_data)
	update_equipment_weights(equip.resource_name)
	
func remove_equipment(equip:HumanAsset):
	human_config.remove_equipment(equip)
	mesh_arrays.erase(equip.resource_name)
	if equip.rigged:
		HumanizerRigService.skeleton_remove_rigged_equipment(equip, skeleton_data)

func get_body_mesh():
	return get_mesh("body")

func hide_body_vertices():
	HumanizerBodyService.hide_vertices(mesh_arrays.body,human_config.equipment)
			
func set_targets(target_data:Dictionary):
	HumanizerTargetService.set_targets(target_data,human_config.targets,helper_vertex)
	fit_all_meshes()
	HumanizerRigService.adjust_bone_positions(skeleton_data,rig,helper_vertex,human_config.equipment,mesh_arrays)
	
func fit_all_meshes():
	mesh_arrays.body = HumanizerBodyService.fit_mesh_arrays(mesh_arrays.body,helper_vertex)
	for equip_name in human_config.equipment:
		fit_equipment_mesh(equip_name)

func fit_equipment_mesh(equip_name:String):
	var equip:HumanAsset = human_config.equipment[equip_name]
	var mhclo = load(equip.mhclo_path)
	mesh_arrays[equip_name] = HumanizerEquipmentService.fit_mesh_arrays(mesh_arrays[equip_name],helper_vertex,mhclo)

func set_rig(rig_name:String):
	human_config.rig = rig_name
	var retargeted: bool = rig_name.ends_with('-RETARGETED')
	rig = HumanizerRigService.get_rig(rig_name)
	skeleton_data = HumanizerRigService.init_skeleton_data(rig,retargeted)
	for equip in human_config.equipment.values():
		if equip.rigged:
			HumanizerRigService.skeleton_add_rigged_equipment(equip,mesh_arrays[equip.resource_name],skeleton_data)
	HumanizerRigService.adjust_bone_positions(skeleton_data,rig,helper_vertex,human_config.equipment,mesh_arrays)
	update_bone_weights()
	if &'root_bone' in human_config.components:
		enable_root_bone_component()

func get_skeleton()->Skeleton3D:
	#print(skeleton_data)
	return HumanizerRigService.get_skeleton_3D(skeleton_data)

func rebuild_skeleton(skeleton:Skeleton3D):
	HumanizerRigService.rebuild_skeleton_3D(skeleton,skeleton_data)

func adjust_skeleton(skeleton:Skeleton3D):
	HumanizerRigService.adjust_skeleton_3D(skeleton,skeleton_data)
	skeleton.motion_scale = HumanizerRigService.get_motion_scale(human_config.rig,helper_vertex)

func update_bone_weights():
	HumanizerRigService.set_body_weights_array(rig,mesh_arrays.body)
	for equip_name in human_config.equipment:
		update_equipment_weights(equip_name)
		
func update_equipment_weights(equip_name:String):
	var equip:HumanAsset = human_config.equipment[equip_name]
	var mhclo = load(equip.mhclo_path)
	HumanizerRigService.set_equipment_weights_array(equip,  mesh_arrays[equip_name], rig, skeleton_data)

func enable_root_bone_component():
	human_config.enable_component(&'root_bone')
	if "Root" not in skeleton_data:
		skeleton_data.Root = {local_xform=Transform3D(),global_pos=Vector3(0,0,0)}
		skeleton_data[skeleton_data.keys()[0]].parent = "Root"

func disable_root_bone_component():
	human_config.disable_component(&'root_bone')
	if "Root" in skeleton_data and "game_engine" not in human_config.rig:
		skeleton_data.erase("Root")
		skeleton_data[skeleton_data.keys()[0]].erase("parent")
	
func get_foot_offset()->float:
	return HumanizerBodyService.get_foot_offset(helper_vertex)
	
func get_hips_height()->float:
	return HumanizerBodyService.get_hips_height(helper_vertex)

func get_head_height()->float:
	return HumanizerBodyService.get_head_height(helper_vertex)
	
func get_max_width()->float:
	return HumanizerBodyService.get_max_width(helper_vertex)
