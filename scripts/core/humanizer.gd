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
		human_config.body_material = HumanizerMaterial.new()
	else:	
		human_config = _human_config
	helper_vertex = HumanizerTargetService.init_helper_vertex(human_config.targets)
	mesh_arrays.body = HumanizerBodyService.load_basis_arrays()
	hide_body_vertices()
	materials.body = StandardMaterial3D.new()
	for equip in human_config.equipment.values():
		mesh_arrays[equip.type] = HumanizerEquipmentService.load_mesh_arrays(equip.get_type())
		materials[equip.type] = StandardMaterial3D.new()
		set_equipment_material(equip,equip.texture_name)
	fit_all_meshes()
	set_rig(human_config.rig) #this adds the rigged bones and updates all the bone weights

func standard_bake_meshes():
	var new_mesh = ArrayMesh.new()
	var opaque = get_group_bake_arrays("opaque")
	if not opaque.arrays.is_empty():
		var surface = HumanizerMeshService.combine_surfaces(opaque.arrays,opaque.materials)
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface.arrays)
		new_mesh.surface_set_material(new_mesh.get_surface_count()-1,surface.material)
	var transparent = get_group_bake_arrays("transparent")
	if not transparent.arrays.is_empty():
		var surface = HumanizerMeshService.combine_surfaces(transparent.arrays,transparent.materials)
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface.arrays)
		new_mesh.surface_set_material(new_mesh.get_surface_count()-1,surface.material)
	return new_mesh
		
func get_group_bake_arrays(group_name:String): #transparent, opaque or all
	var bake_arrays = []
	var bake_mats = []
	for surface_name in mesh_arrays:
		var add_mesh = false
		if group_name.to_lower() == "all":
			add_mesh = true
		elif materials[surface_name].TRANSPARENCY_DISABLED:
			if group_name.to_lower() == "opaque":
				add_mesh = true
		else:
			if group_name.to_lower() == "transparent":
				add_mesh = true
		if add_mesh:		
			var new_array = mesh_arrays[surface_name]
			new_array[Mesh.ARRAY_CUSTOM0] = null
			bake_arrays.append(new_array)
			bake_mats.append(materials[surface_name])
	return {arrays=bake_arrays,materials=bake_mats}

func set_skin_texture(texture_name: String) -> void:
	var texture: String
	if not HumanizerRegistry.skin_textures.has(texture_name):
		human_config.body_material.set_base_textures(HumanizerOverlay.new())
	else:
		texture = HumanizerRegistry.skin_textures[texture_name]
		var normal_texture = texture.get_base_dir() + '/' + texture_name + '_normal.' + texture.get_extension()
		if not FileAccess.file_exists(normal_texture):
			if human_config.body_material.overlays.size() > 0:
				var overlay = human_config.body_material.overlays[0]
				normal_texture = overlay.normal_texture_path
			else:
				normal_texture = ''
		var overlay = {&'albedo': texture, &'color': human_config.skin_color, &'normal': normal_texture}
		human_config.body_material.set_base_textures(HumanizerOverlay.from_dict(overlay))
	human_config.body_material.update_material()
	human_config.body_material.update_standard_material_3D(materials.body)

func set_equipment_material(equipment:HumanizerEquipment, texture: String)-> void:
	var equip_type = equipment.get_type()
	equipment.texture_name = texture
	var material = materials[equip_type.resource_name]
	if equip_type.default_overlay != null and texture != "" and texture != null:
		var mat_config: HumanizerMaterial = equipment.material_config
		var overlay_dict = {&'albedo': equip_type.textures[texture]}
		if material.normal_texture != null:
			overlay_dict[&'normal'] = material.normal_texture.resource_path
		if material.ao_texture != null:
			overlay_dict[&'ao'] = material.ao_texture.resource_path
		mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	elif texture not in equip_type.textures:
		material.albedo_texture = null
	else:
		material.albedo_texture = load(equip_type.textures[texture])
		
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
	materials[equip_type.resource_name] = load(equip_type.material_path)
	if equip_type.default_overlay != null:
		equip.material_config = HumanizerMaterial.new()
	set_equipment_material(equip,equip.texture_name)
	
func remove_equipment(equip:HumanizerEquipment):
	human_config.remove_equipment(equip)
	var equip_type = equip.get_type()
	mesh_arrays.erase(equip_type.resource_name)
	if equip_type.rigged:
		HumanizerRigService.skeleton_remove_rigged_equipment(equip, skeleton_data)
	materials.erase(equip_type.resource_name)
	
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
	
func get_foot_offset()->float:
	return HumanizerBodyService.get_foot_offset(helper_vertex)
	
func get_hips_height()->float:
	return HumanizerBodyService.get_hips_height(helper_vertex)

func get_head_height()->float:
	return HumanizerBodyService.get_head_height(helper_vertex)
	
func get_max_width()->float:
	return HumanizerBodyService.get_max_width(helper_vertex)
