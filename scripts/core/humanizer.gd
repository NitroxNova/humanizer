@tool
extends Resource
class_name Humanizer

var human_config:HumanConfig
var helper_vertex:PackedVector3Array = []
var mesh_arrays : Dictionary = {}
var materials: Dictionary = {}
var rig: HumanizerRig 
var skeleton_data : Dictionary = {} #bone names with parent, position and rotation data

func _init(_human_config = null):
	if _human_config == null:
		human_config = HumanConfig.new()
		human_config.init_macros()
		human_config.rig = HumanizerGlobalConfig.config.default_skeleton
	else:	
		human_config = _human_config
	helper_vertex = HumanizerTargetService.init_helper_vertex(human_config.targets)
	mesh_arrays.Body = HumanizerBodyService.load_basis_arrays()
	hide_body_vertices()
	materials.Body = StandardMaterial3D.new()
	human_config.body_material.update_standard_material_3D(materials.Body)
	for equip in human_config.equipment.values():
		mesh_arrays[equip.type] = HumanizerEquipmentService.load_mesh_arrays(equip.get_type())
		init_equipment_material(equip)
	fit_all_meshes()
	set_rig(human_config.rig) #this adds the rigged bones and updates all the bone weights

func get_CharacterBody3D():
	var human = CharacterBody3D.new()
	var body_mesh = MeshInstance3D.new()
	body_mesh.mesh = standard_bake_meshes()
	human.add_child(body_mesh)
	var skeleton = get_skeleton()
	human.add_child(skeleton)
	skeleton.set_unique_name_in_owner(true)
	body_mesh.skeleton = NodePath('../' + skeleton.name)
	body_mesh.skin = skeleton.create_skin_from_rest_transforms()
	var anim_player = get_animation_tree()
	if anim_player != null:
		human.add_child(anim_player)
		anim_player.active=true
	skeleton.owner = human
	anim_player.owner = human
	if human_config.has_component("main_collider"):
		human.add_child(get_main_collider())
	return human
	
func get_animation_tree():
	if human_config.rig == 'default-RETARGETED':
		return load("res://addons/humanizer/data/animations/face_animation_tree.tscn").instantiate()
	elif human_config.rig.ends_with('RETARGETED'):
		return load("res://addons/humanizer/data/animations/animation_tree.tscn").instantiate()
	else:  # No example animator for specific rigs that aren't retargeted
		return

func standard_bake_meshes():
	var new_mesh = ArrayMesh.new()
	var opaque = get_group_bake_arrays("opaque")
	if not opaque.is_empty():
		combine_surfaces_to_mesh(opaque,new_mesh)		
	var transparent = get_group_bake_arrays("transparent")
	if not transparent.is_empty():
		combine_surfaces_to_mesh(transparent,new_mesh)	
	return new_mesh

func combine_surfaces_to_mesh(surface_names:PackedStringArray,new_mesh:=ArrayMesh.new(),atlas_resolution:int=4096):
	var bake_arrays = []
	var bake_mats = []
	for s_name in surface_names:
		var new_array = mesh_arrays[s_name].duplicate()
		new_array[Mesh.ARRAY_CUSTOM0] = null
		bake_arrays.append(new_array)
		bake_mats.append(materials[s_name])
	var surface = HumanizerMeshService.combine_surfaces(bake_arrays,bake_mats,atlas_resolution)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface.arrays)
	new_mesh.surface_set_material(new_mesh.get_surface_count()-1,surface.material)
	return new_mesh
	
func get_group_bake_arrays(group_name:String): #transparent, opaque or all
	var surface_names = PackedStringArray()
	for s_name in mesh_arrays:
		if group_name.to_lower() == "all":
			surface_names.append(s_name)
		elif materials[s_name].transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			if group_name.to_lower() == "opaque":
				surface_names.append(s_name)
		else:
			if group_name.to_lower() == "transparent":
				surface_names.append(s_name)
	return surface_names

func set_skin_color(color:Color):
	human_config.skin_color = color
	human_config.body_material.update_standard_material_3D(materials.Body)

func set_skin_texture(texture_name: String) -> void:
	human_config.set_skin_texture(texture_name)
	human_config.body_material.update_standard_material_3D(materials.Body)

func set_eye_color(color:Color):
	human_config.eye_color = color
	var slots = ["LeftEye","RightEye","Eyes"]
	for equip in human_config.get_equipment_in_slots(slots):
		equip.material_config.update_standard_material_3D(materials[equip.type])

func set_hair_color(color:Color):
	human_config.hair_color = color
	var hair_equip = human_config.get_equipment_in_slot("Hair")
	if hair_equip != null:
		materials[hair_equip.type].albedo_color = color
	set_eyebrow_color(human_config.eyebrow_color)

func set_eyebrow_color(color:Color):
	human_config.eyebrow_color = color
	var slots = ["LeftEyebrow","RightEyebrow","Eyebrows"]
	for eyebrow_equip in human_config.get_equipment_in_slots(slots):
		materials[eyebrow_equip.type].albedo_color = color
		
func init_equipment_material(equipment:HumanizerEquipment):
	var equip_type = equipment.get_type()
	materials[equipment.type] = load(equip_type.material_path)
	if equip_type.default_overlay != null and equipment.material_config == null:
		equipment.material_config = HumanizerMaterial.new()
		equipment.material_config.set_base_textures(HumanizerOverlay.from_material(materials[equipment.type]))
		equipment.material_config.add_overlay(equip_type.default_overlay)
	set_equipment_material(equipment,equipment.texture_name)

func set_equipment_material(equipment:HumanizerEquipment, texture: String)-> void:
	var equip_type = equipment.get_type()
	equipment.texture_name = texture
	var material = materials[equipment.type]
	var mat_config: HumanizerMaterial = equipment.material_config
	if mat_config != null:
		if texture in equip_type.textures:
			mat_config.overlays[0].albedo_texture_path = equip_type.textures[texture]
		else:
			mat_config.overlays[0].albedo_texture_path = ""
	elif texture not in equip_type.textures:
		material.albedo_texture = null
	else:
		material.albedo_texture = load(equip_type.textures[texture])
	if equip_type.in_slot(["LeftEye","RightEye"]):
		mat_config.overlays[1].color = human_config.eye_color
	elif equip_type.in_slot(["Hair"]):
		material.albedo_color = human_config.hair_color
	elif equip_type.in_slot(["LeftEyebrow","RightEyebrow"]):
		material.albedo_color = human_config.eyebrow_color
	if mat_config != null:
		mat_config.update_standard_material_3D(material)
		
func get_mesh(mesh_name:String):
	var new_arrays = mesh_arrays[mesh_name].duplicate()
	new_arrays[Mesh.ARRAY_CUSTOM0] = null
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_arrays)
	mesh = HumanizerMeshService.generate_normals_and_tangents(mesh)
	mesh.surface_set_material(0,materials[mesh_name])
	return mesh

func add_equipment(equip:HumanizerEquipment):
	human_config.add_equipment(equip)
	var equip_type = equip.get_type()
	mesh_arrays[equip_type.resource_name] = HumanizerEquipmentService.load_mesh_arrays(equip_type)
	fit_equipment_mesh(equip_type.resource_name)
	if equip_type.rigged:
		HumanizerRigService.skeleton_add_rigged_equipment(equip,mesh_arrays[equip_type.resource_name], skeleton_data)
	update_equipment_weights(equip_type.resource_name)
	init_equipment_material(equip)
	
func remove_equipment(equip:HumanizerEquipment):
	human_config.remove_equipment(equip)
	var equip_type = equip.get_type()
	mesh_arrays.erase(equip_type.resource_name)
	if equip_type.rigged:
		HumanizerRigService.skeleton_remove_rigged_equipment(equip, skeleton_data)
	materials.erase(equip_type.resource_name)
	
func get_body_mesh():
	return get_mesh("Body")

func hide_body_vertices():
	HumanizerBodyService.hide_vertices(mesh_arrays.Body,human_config.equipment)

func hide_clothes_vertices():
	HumanizerEquipmentService.hide_vertices(human_config.equipment,mesh_arrays)
			
func set_targets(target_data:Dictionary):
	HumanizerTargetService.set_targets(target_data,human_config.targets,helper_vertex)
	fit_all_meshes()
	HumanizerRigService.adjust_bone_positions(skeleton_data,rig,helper_vertex,human_config.equipment,mesh_arrays)

func fit_all_meshes():
	mesh_arrays.Body = HumanizerBodyService.fit_mesh_arrays(mesh_arrays.Body,helper_vertex)
	for equip_name in human_config.equipment:
		fit_equipment_mesh(equip_name)

func fit_equipment_mesh(equip_name:String):
	var equip:HumanizerEquipment = human_config.equipment[equip_name]
	var mhclo = load(equip.get_type().mhclo_path)
	mesh_arrays[equip_name] = HumanizerEquipmentService.fit_mesh_arrays(mesh_arrays[equip_name],helper_vertex,mhclo)

func set_rig(rig_name:String):
	human_config.rig = rig_name
	var retargeted: bool = rig_name.ends_with('-RETARGETED')
	rig = HumanizerRigService.get_rig(rig_name)
	skeleton_data = HumanizerRigService.init_skeleton_data(rig,retargeted)
	for equip in human_config.equipment.values():
		if equip.get_type().rigged:
			HumanizerRigService.skeleton_add_rigged_equipment(equip,mesh_arrays[equip.type],skeleton_data)
	HumanizerRigService.adjust_bone_positions(skeleton_data,rig,helper_vertex,human_config.equipment,mesh_arrays)
	update_bone_weights()
	if &'root_bone' in human_config.components:
		enable_root_bone_component()

func get_skeleton()->Skeleton3D:
	#print(skeleton_data)
	var skeleton = HumanizerRigService.get_skeleton_3D(skeleton_data)
	skeleton.motion_scale = HumanizerRigService.get_motion_scale(human_config.rig,helper_vertex)
	return skeleton

func rebuild_skeleton(skeleton:Skeleton3D):
	HumanizerRigService.rebuild_skeleton_3D(skeleton,skeleton_data)

func adjust_skeleton(skeleton:Skeleton3D):
	HumanizerRigService.adjust_skeleton_3D(skeleton,skeleton_data)
	skeleton.motion_scale = HumanizerRigService.get_motion_scale(human_config.rig,helper_vertex)

func update_bone_weights():
	HumanizerRigService.set_body_weights_array(rig,mesh_arrays.Body)
	for equip_name in human_config.equipment:
		update_equipment_weights(equip_name)
		
func update_equipment_weights(equip_name:String):
	var equip:HumanizerEquipment = human_config.equipment[equip_name]
	HumanizerRigService.set_equipment_weights_array(equip.get_type(),  mesh_arrays[equip_name], rig, skeleton_data)

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
		
func get_main_collider():
	return HumanizerColliderService.get_main_collider(helper_vertex)

func adjust_main_collider(main_collider:CollisionShape3D):
	HumanizerColliderService.adjust_main_collider(helper_vertex,main_collider)
	
func get_foot_offset()->float:
	return HumanizerBodyService.get_foot_offset(helper_vertex)
	
func get_hips_height()->float:
	return HumanizerBodyService.get_hips_height(helper_vertex)

func get_head_height()->float:
	return HumanizerBodyService.get_head_height(helper_vertex)
	
func get_max_width()->float:
	return HumanizerBodyService.get_max_width(helper_vertex)
