@tool
class_name HumanizerEditorTool
extends Node3D

## editor tool for creating new humans

const BASE_MESH_NAME: String = 'Body'
const eyebrow_color_weight := 0.4
var humanizer : Humanizer
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var baked := false
var bake_in_progress := false
var scene_loaded: bool = false
var main_collider: CollisionShape3D
var animator: Node

var _base_hips_height: float:
	get:
		return HumanizerTargetService.data.basis[HumanizerBodyService.hips_id].y

var save_path: String:
	get:
		var path = HumanizerGlobalConfig.config.human_export_path
		if path == null:
			path = 'res://data/humans'
		return path.path_join(human_name)
var human_name: String = 'MyHuman'
var _save_path_valid: bool:
	get:
		if FileAccess.file_exists(save_path.path_join(human_name + '.tscn')):
			printerr('A human with this name has already been saved.  Use a different name.')
			return false
		return true
var bake_surface_name: String
var new_shapekey_name: String = ''
var morph_data := {}

var skin_color: Color = Color.WHITE:
	set(value):
		skin_color = value
		if body_mesh == null or (body_mesh as HumanizerMeshInstance) == null:
			return
		if scene_loaded and body_mesh.material_config.overlays.size() == 0:
			return
		human_config.skin_color = skin_color
		if body_mesh.material_config.overlays.size() > 0:
			body_mesh.material_config.overlays[0].color = skin_color
var hair_color: Color = Color.WHITE:
	set(value):
		hair_color = value
		if human_config == null or not scene_loaded:
			return
		human_config.hair_color = hair_color
		var hair_equip = human_config.get_equipment_in_slot("Hair")
		if hair_equip != null:
			var mesh = hair_equip.node
			(mesh as MeshInstance3D).get_surface_override_material(0).albedo_color = hair_color 
		eyebrow_color = Color(hair_color * eyebrow_color_weight, 1.)
		notify_property_list_changed()
var eyebrow_color: Color = Color.WHITE:
	set(value):
		eyebrow_color = value
		if human_config == null or not scene_loaded:
			return
		human_config.eyebrow_color = eyebrow_color
		var slots: Array = ['RightEyebrow', 'LeftEyebrow', 'Eyebrows']
		for equip in human_config.get_equipment_in_slots(slots):
			var mesh = equip.node
			(mesh as MeshInstance3D).get_surface_override_material(0).albedo_color = eyebrow_color 
var eye_color: Color = Color.WHITE:
	set(value):
		eye_color = value
		if human_config == null or not scene_loaded:
			return
		human_config.eye_color = eye_color
		var slots: Array = [&'RightEye', &'LeftEye', &'Eyes']
		for equip in human_config.get_equipment_in_slots(slots):
			var mesh = equip.node
			var overlay = mesh.material_config.overlays[1]
			overlay.color = eye_color
			mesh.material_config.set_overlay(1, overlay)
## The meshes selected to be baked to a new surface
@export var _bake_meshes: Array[MeshInstance3D]
var bake_mesh_names: Array = []:
	set(value):
		bake_mesh_names = value
		if bake_mesh_names.size() == 0:
			return
		_bake_meshes = []
		for name in value:
			var node = get_node_or_null(name)
			if node and not node in _bake_meshes:
				_bake_meshes.append(node)
## The new shapekeys which have been defined for this human.  These will survive the baking process.
@export var _new_shapekeys: Dictionary = {}

@export_category("Humanizer Node Settings")
## This resource stores all the data necessary to build the human model
@export var human_config: HumanConfig:
	set(value):
		human_config = value
		#if scene_loaded and human_config != null:
			#load_human()
			#notify_property_list_changed()

@export_group('Node Overrides')
## The root node type for baked humans
@export_enum("CharacterBody3D", "RigidBody3D", "StaticBody3D", "Area3D") var _baked_root_node: String = HumanizerGlobalConfig.config.default_baked_root_node
## The script to put on the root node of saved characters
@export_file var _character_script: String
## Texture atlas resolution for the baked character
@export_enum("1k:1024", "2k:2048", "4k:4096") var atlas_resolution: int = HumanizerGlobalConfig.config.atlas_resolution
## The scene to be added as an animator for the character
@export var _animator_scene: PackedScene = HumanizerGlobalConfig.config.default_animation_tree
## THe rendering layers for the human's 3d mesh instances
@export_flags_3d_render var _render_layers = HumanizerGlobalConfig.config.default_character_render_layers:
	set(value):
		_render_layers = value
		for child in get_children():
			if child is MeshInstance3D:
				child.layers = _render_layers
## The physics layers the character collider resides in
@export_flags_3d_physics var _character_layers = HumanizerGlobalConfig.config.default_character_physics_layers
## The physics layers a staticbody character collider resides in
@export_flags_3d_physics var _staticbody_layers = HumanizerGlobalConfig.config.default_staticbody_physics_layers
## The physics layers the character collider collides with
@export_flags_3d_physics var _character_mask = HumanizerGlobalConfig.config.default_character_physics_mask
## The physics layers the physical bones reside in
@export_flags_3d_physics var _ragdoll_layers = HumanizerGlobalConfig.config.default_physical_bone_layers
## The physics layers the physical bones collide with
@export_flags_3d_physics var _ragdoll_mask = HumanizerGlobalConfig.config.default_physical_bone_mask


func _ready() -> void:
	body_mesh = get_node_or_null(BASE_MESH_NAME)
	if human_config == null:
		human_config = HumanConfig.new()
	for child in get_children():
		if child.name.begins_with('Baked-'):
			baked = true
	if not baked:
		load_human()
	scene_loaded = true

####  HumanConfig Resource and Scene Management ####
func reset_human() -> void:
	if has_node('MorphDriver'):
		_delete_child_node($MorphDriver)
	baked = false
	humanizer = Humanizer.new()
	human_config = humanizer.human_config
	for child in get_children():
		if child is MeshInstance3D:
			_delete_child_node(child)
	body_mesh = null
	_set_body_mesh(load("res://addons/humanizer/data/resources/base_human.res"))
	set_component_state(true, &'main_collider')
	if has_node('Saccades'):
		_delete_child_by_name('Saccades')
	notify_property_list_changed()

func load_human() -> void:
	if human_config.rig == '':
		human_config.rig = HumanizerGlobalConfig.config.default_skeleton
	baked = false
	reset_human()
	_deserialize()

	notify_property_list_changed()

func create_human_branch() -> Node3D:
	#_adjust_skeleton()
	var new_mesh = _combine_meshes()

	var root_node: Node
	var script: String
	if _baked_root_node == 'StaticBody3D':
		root_node = StaticBody3D.new()
		script = HumanizerGlobalConfig.config.default_staticbody_script
	elif _baked_root_node == 'CharacterBody3D':
		root_node = CharacterBody3D.new()
		script = HumanizerGlobalConfig.config.default_characterbody_script
	elif _baked_root_node == 'RigidBody3D':
		root_node = RigidBody3D.new()
		script = HumanizerGlobalConfig.config.default_rigidbody_script
	elif _baked_root_node == 'Area3D':
		root_node = Area3D.new()
		script = HumanizerGlobalConfig.config.default_area_script

	root_node.name = human_name
	if _character_script not in ['', null]:
		root_node.set_script(load(_character_script))
	elif script != '':
		root_node.set_script(load(script))
		
	root_node.collision_layer = _character_layers
	root_node.collision_mask = _character_mask
	
	var sk = skeleton.duplicate(true) as Skeleton3D
	sk.reset_bone_poses()
	sk.scene_file_path = ''
	root_node.add_child(sk)
	sk.owner = root_node
	
	for child in skeleton.get_children():
		var phys_bone = child as PhysicalBone3D
		if phys_bone:
			var bone = phys_bone.duplicate(true)
			sk.add_child(bone)
			bone.owner = root_node
			for coll in phys_bone.get_children():
				var collider = coll.duplicate(true)
				bone.add_child(collider)
				collider.owner = root_node
			bone.name = phys_bone.name.replace("Physical Bone ", '')

	if _animator_scene != null:
		var _animator = _animator_scene.instantiate()
		root_node.add_child(_animator)
		_animator.owner = root_node
		_animator.active = true  # Doesn't work unfortunately
		root_node.set_editable_instance(_animator, true)
		var root_bone = sk.get_bone_name(0)
		if _animator is AnimationTree:
			_animator.advance_expression_base_node = '../' + root_node.name
			if root_bone in ['Root'] or &'root_bone' in human_config.components:
				_animator.root_motion_track = '../' + sk.name + ":Root"

	var mi = MeshInstance3D.new()
	mi.name = "Avatar"
	mi.mesh = new_mesh
	root_node.add_child(mi)
	mi.owner = root_node
	mi.skeleton = NodePath('../' + sk.name)
	mi.skin = sk.create_skin_from_rest_transforms()
	if root_node is StaticBody3D:
		pass  # can't currently bake posed mesh
		mi.create_trimesh_collision()
		var coll: CollisionShape3D = mi.get_child(0).get_child(0)
		var new_coll := CollisionShape3D.new()
		new_coll.shape = coll.shape.duplicate(true)
		mi.get_child(0).queue_free()
		root_node.add_child(new_coll)
		new_coll.owner = root_node
		new_coll.name = 'CollisionShape3D'
		root_node.collision_layer = _staticbody_layers
		#await get_tree().create_timer(1).timeout

	if human_config.components.has(&'main_collider') and not root_node is StaticBody3D:
		var coll = main_collider.duplicate(true)
		root_node.add_child(coll)
		coll.owner = root_node
	if human_config.components.has(&'saccades'):
		var saccades : Node = load("res://addons/humanizer/scenes/subscenes/saccades.tscn").instantiate()
		root_node.add_child(saccades)
		saccades.owner = root_node
	if has_node('MorphDriver'):
		var morph_driver = $MorphDriver.duplicate()
		morph_driver.bone_positions = $MorphDriver.bone_positions
		morph_driver.skeleton_motion_scale = $MorphDriver.skeleton_motion_scale
		morph_driver.collider_shapes = $MorphDriver.collider_shapes
		morph_driver.skeleton = sk
		morph_driver.mesh_paths = [NodePath('../Avatar')] as Array[NodePath]
		root_node.add_child(morph_driver)
		morph_driver.owner = root_node

	return root_node

func save_human_scene() -> void:
	var scene_root_node = create_human_branch()
	var mi: MeshInstance3D = scene_root_node.get_node('Avatar')
	var scene = PackedScene.new()
	scene.pack(scene_root_node)
	DirAccess.make_dir_recursive_absolute(save_path)
	
	for surface in mi.mesh.get_surface_count():
		var mat = mi.mesh.surface_get_material(surface)
		var surf_name: String = mi.mesh.surface_get_name(surface)
		if mat.albedo_texture != null:
			var path := save_path.path_join('texture_albedo_' + surf_name + '.res')
			mat.albedo_texture.take_over_path(path)
		if mat.normal_texture != null:
			var path := save_path.path_join('texture_normal_' + surf_name + '.res')
			mat.normal_texture.take_over_path(path)
		if mat.ao_texture != null:
			var path := save_path.path_join('texture_ao_' + surf_name + '.res')
			mat.ao_texture.take_over_path(path)
		var path := save_path.path_join('material_' + surf_name + '.tres')
		ResourceSaver.save(mat, path)
		mat.take_over_path(path)
		
	var path := save_path.path_join('mesh.tres')
	ResourceSaver.save(mi.mesh, path)
	mi.mesh.take_over_path(path)
	path = save_path.path_join('config_' + human_name + '.res')
	ResourceSaver.save(human_config, save_path.path_join('config_' + human_name + '.res'))
	if not FileAccess.file_exists(save_path.path_join('scene_' + human_name + '.tscn')):
		ResourceSaver.save(scene, save_path.path_join('scene_' + human_name + '.tscn'))
	print('Saved human to : ' + save_path)
	HumanizerJobQueue.enqueue({callable=HumanizerSurfaceCombiner.compress_material,mesh=mi.mesh})

func _add_child_node(node: Node) -> void:
	add_child(node)
	node.owner = self
	if node is MeshInstance3D or node is SoftBody3D:
		(node as MeshInstance3D).layers = _render_layers

func _delete_child_node(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.queue_free()

func _delete_child_by_name(name: String) -> void:
	var node = get_node_or_null(name)
	if node != null:
		_delete_child_node(node)

func _get_asset_by_name(mesh_name: String) -> HumanAsset:
	var res: HumanAsset = null
	if mesh_name in human_config.equipment:
		res = human_config.equipment[mesh_name]
	return res

func _deserialize() -> void:
	## set rig
	set_rig(human_config.rig)

	## Load Assets
	for equip: HumanAsset in human_config.equipment.values():
		add_equipment(equip)
		
	## Load components
	for component in human_config.components:
		if component in [&'root_bone', &'ragdoll']:
			continue  # These are already set in set_rig
		set_component_state(true, component)
	
	## Load colors
	skin_color = human_config.skin_color
	hair_color = human_config.hair_color
	eye_color = human_config.eye_color
	eyebrow_color = human_config.eyebrow_color

	## Update materials with overlays
	body_mesh.material_config.update_material()
	for equip in human_config.equipment.values():
		if equip.node is HumanizerMeshInstance:
			if equip.node.material_config.overlays.size() > 0:
				equip.node.material_config.update_material()
	## Finalize
	_adjust_skeleton()
	_fit_all_meshes()

#### Mesh Management ####
func add_equipment(equip: HumanAsset) -> void:
	if baked:
		push_warning("Can't change equipment.  Already baked")
		notify_property_list_changed()
		return
	for prev_equip in human_config.get_equipment_in_slots(equip.slots):
		remove_equipment(prev_equip)
	
	humanizer.add_equipment(equip)	
	#human_config.add_equipment(equip)
	
	var mesh_inst = load(equip.scene_path).instantiate() as MeshInstance3D
	mesh_inst.name = equip.resource_name
	equip.node = mesh_inst
	if equip.default_overlay != null or equip.material_config != null:
		_setup_overlay_material(equip, equip.material_config)
	else:
		mesh_inst.get_surface_override_material(0).resource_local_to_scene = true
	if equip.texture_name == null:
		set_equipment_material(equip, Random.choice(equip.textures.keys()))
	if human_config.transforms.has(equip.resource_name):
		equip.node.transform = Transform3D(human_config.transforms[equip.resource_name])
	
	_add_child_node(mesh_inst)	
	if equip.rigged:
		set_rig(human_config.rig) #update rig with additional asset bones, and remove any from previous asset
	else:
		_add_bone_weights(equip)
	if equip.in_slot(["LeftEyebrow","RightEyebrow","Eyebrows"]):
		eyebrow_color = eyebrow_color  ## trigger setter logic
	elif equip.in_slot(["Eyes","LeftEye","RightEye"]):
		eye_color = eye_color
	elif equip.in_slot(["Hair"]):
		hair_color = hair_color
	notify_property_list_changed()
	
func remove_equipment(equip: HumanAsset) -> void:
	if baked:
		push_warning("Can't change equipment.  Already baked")
		notify_property_list_changed()
		return
	_delete_child_by_name(equip.resource_name)
	human_config.remove_equipment(equip)
	if equip.rigged:
		set_rig(human_config.rig) #remove bones from previous asset

func remove_equipment_in_slot(slot: String) -> void:
	if baked:
		push_warning("Can't change clothes.  Already baked")
		notify_property_list_changed()
		return
	var equip = human_config.get_equipment_in_slot(slot)
	if equip != null:
		remove_equipment(equip)	

func hide_body_vertices() -> void:
	if baked:
		push_warning("Can't alter meshes.  Already baked")
		return
	
	humanizer.hide_body_vertices()
	body_mesh.mesh = humanizer.get_body_mesh()

func hide_clothes_vertices():
	if baked:
		push_warning("Can't alter meshes.  Already baked")
		return
	var delete_verts_mh := []
	delete_verts_mh.resize(humanizer.helper_vertex.size())
	
	var depth_sorted_clothes := []
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var res: HumanAsset = _get_asset_by_name(child.name)
		if res != null:
			depth_sorted_clothes.append(child)
	
	depth_sorted_clothes.sort_custom(_sort_clothes_by_z_depth)
	
	for clothes_node:MeshInstance3D in depth_sorted_clothes:
		var res: HumanAsset = _get_asset_by_name(clothes_node.name)
		var mhclo : MHCLO = load(res.mhclo_path)
		var cl_delete_verts_mh = []
		cl_delete_verts_mh.resize(mhclo.vertex_data.size())
		cl_delete_verts_mh.fill(false)
		var cl_delete_verts_gd = []
		cl_delete_verts_gd.resize(clothes_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
		cl_delete_verts_gd.fill(false)
		var any_deleted = false
		
		#refer to transferVertexMaskToProxy in makehuman/shared/proxy.py
		for cl_mh_id in mhclo.vertex_data.size():
			var v_data = mhclo.vertex_data[cl_mh_id]
			var hidden_count = 0
			for hu_mh_id in v_data.vertex:
				if delete_verts_mh[hu_mh_id]:
					hidden_count += 1
			if float(hidden_count)/v_data.vertex.size() >= .66: #if 2/3 or more vertices are hidden
				cl_delete_verts_mh[cl_mh_id] = true
		for gd_id in clothes_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size():
			var mh_id = clothes_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0][gd_id]
			if cl_delete_verts_mh[mh_id]:
				any_deleted = true
				cl_delete_verts_gd[gd_id] = true
		
		#if any_deleted:
			#clothes_node.mesh = MeshOperations.delete_faces(clothes_node.mesh,cl_delete_verts_gd)			
		
		#update delete verts to apply to all subsequent clothes
		for entry in mhclo.delete_vertices:
			if entry.size() == 1:
				delete_verts_mh[entry[0]] = true
			else:
				for mh_id in range(entry[0], entry[1] + 1):
					delete_verts_mh[mh_id] = true

func _sort_clothes_by_z_depth(clothes_a, clothes_b): # from highest to lowest
	var res_a: HumanAsset = _get_asset_by_name(clothes_a.name)
	var res_b: HumanAsset = _get_asset_by_name(clothes_b.name)
	if load(res_a.mhclo_path).z_depth > load(res_b.mhclo_path).z_depth:
		return true
	return false

func unhide_body_vertices() -> void:
	if baked:
		push_warning("Can't alter meshes.  Already baked")
		return
	var mat = body_mesh.get_surface_override_material(0)
	_set_body_mesh(load("res://addons/humanizer/data/resources/base_human.res"))
	_set_shapekey_data(human_config.shapekeys)
	body_mesh.set_surface_override_material(0, mat)
	set_rig(human_config.rig)

func unhide_clothes_vertices() -> void:
	if baked:
		push_warning("Can't alter meshes.  Already baked")
		return
	for equip:HumanAsset in human_config.equipment.values():
		equip.node.mesh = load(equip.get_mesh_path())
		_add_bone_weights(equip)

func set_bake_meshes(subset: String) -> void:
	_bake_meshes = []
	bake_surface_name = subset
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		if child.name.begins_with('Baked-'):
			continue
		var mat = (child as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D
		var add: bool = false
		add = add or subset == 'All'
		add = add or subset == 'Opaque' and mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		add = add or subset == 'Transparent' and mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		if add:
			_bake_meshes.append(child)
	notify_property_list_changed()

func standard_bake() -> void:
	set_bake_meshes('Opaque')
	if _bake_meshes.size() > 0:
		bake_surface()
	set_bake_meshes('Transparent')
	if _bake_meshes.size() > 0:
		bake_surface()

func bake_surface() -> void:
	if bake_surface_name in [null, '']:
		push_error('Please provide a surface name before baking')
		return
	for child in get_children():
		if child.name == 'Baked-' + bake_surface_name:
			push_error('Surface ' + bake_surface_name + ' already exists.  Choose a different name.')
			return
			
	bake_in_progress = true
	for node in _bake_meshes:
		if not node.transform == Transform3D.IDENTITY:
			human_config.transforms[node.name] = Transform3D(node.transform)
		if node is HumanizerMeshInstance:
			node.material_config.update_material()
	
	if human_config.components.has(&'size_morphs') or human_config.components.has(&'age_morphs'):
		if not baked:
			if _new_shapekeys.size() > 1:
				push_error('Age and Size morphs can not be mixed with more than 1 custom shape')
				return
			MeshOperations.prepare_shapekeys_for_baking(human_config, _new_shapekeys)
			_set_shapekey_data(human_config.shapekeys) ## To get correct shapes on basis
			_fit_all_meshes()

	if body_mesh != null and body_mesh in _bake_meshes:
		_bake_meshes.erase(body_mesh)
		hide_body_vertices()
		_bake_meshes.append(body_mesh)
		
	if atlas_resolution == 0:
		atlas_resolution = HumanizerGlobalConfig.config.atlas_resolution
	var baked_surface :ArrayMesh = HumanizerSurfaceCombiner.new(_bake_meshes, atlas_resolution).run()
	#cant regenerate normals and tangents after baking, because it reorders the vertices, and in some cases resizes, which makes absolutely no sense, but it then breaks the exported morph shapekeys  
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = baked_surface
	mi.name = 'Baked-' + bake_surface_name

	# Add new shapekeys to mesh arrays, collect metadata for skeleton/collider
	if not _new_shapekeys.is_empty():
		morph_data['bone_positions'] = {}
		morph_data['motion_scale'] = {}
		morph_data['collider_shape'] = {}
		var initial_shapekeys = human_config.shapekeys.duplicate(true)
		var bs_arrays = []
		var baked_mesh = ArrayMesh.new()
		baked_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
		for shape_name in _new_shapekeys:
			baked_mesh.add_blend_shape(shape_name)
			var new_bs_array = []
			new_bs_array.resize(Mesh.ARRAY_MAX)
			new_bs_array[Mesh.ARRAY_VERTEX] = PackedVector3Array()
			new_bs_array[Mesh.ARRAY_TANGENT] = PackedFloat32Array()
			new_bs_array[Mesh.ARRAY_NORMAL] = PackedVector3Array()
			_set_shapekey_data(_new_shapekeys[shape_name])
			_adjust_skeleton()
			_fit_all_meshes()
			morph_data['bone_positions'][shape_name] = []
			for bone in skeleton.get_bone_count():
				morph_data['bone_positions'][shape_name].append(skeleton.get_bone_pose_position(bone))
			morph_data['motion_scale'][shape_name] = skeleton.motion_scale
			morph_data['collider_shape'][shape_name] = {&'center': main_collider.position.y, &'radius': main_collider.shape.radius, &'height': main_collider.shape.height}
			for mesh_instance in _bake_meshes:
				var sf_arrays = mesh_instance.mesh.surface_get_arrays(0)
				new_bs_array[Mesh.ARRAY_VERTEX].append_array(sf_arrays[Mesh.ARRAY_VERTEX])
				new_bs_array[Mesh.ARRAY_TANGENT].append_array(sf_arrays[Mesh.ARRAY_TANGENT])
				new_bs_array[Mesh.ARRAY_NORMAL].append_array(sf_arrays[Mesh.ARRAY_NORMAL])
			bs_arrays.append(new_bs_array)
		baked_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mi.mesh.surface_get_arrays(0),bs_arrays)
		baked_mesh.surface_set_material(0,mi.mesh.surface_get_material(0))
		mi.mesh = baked_mesh
		## then need to reset mesh to base shape
		_set_shapekey_data(initial_shapekeys)
		_adjust_skeleton()
		_fit_all_meshes()
		morph_data['bone_positions']['basis'] = []
		for bone in skeleton.get_bone_count():
			morph_data['bone_positions']['basis'].append(skeleton.get_bone_pose_position(bone))
		morph_data['motion_scale']['basis'] = skeleton.motion_scale
		morph_data['collider_shape']['basis'] = {&'center': main_collider.position.y, &'radius': main_collider.shape.radius, &'height': main_collider.shape.height}
	
	# Finalize
	add_child(mi)
	mi.owner = self
	mi.skeleton = '../' + skeleton.name
	for mesh in _bake_meshes:
		remove_child(mesh)
		mesh.queue_free()
	_bake_meshes = []

	# Add morph driver if necessary
	if _new_shapekeys.size() > 0 :
		var morph_driver : Node
		if not has_node('MorphDriver'):
			morph_driver = load("res://addons/humanizer/scenes/subscenes/morph_driver.tscn").instantiate()
			morph_driver.meshes = [mi]
			morph_driver.skeleton = skeleton
			morph_driver.bone_positions = morph_data.bone_positions
			morph_driver.skeleton_motion_scale = morph_data.motion_scale
			morph_driver.collider_shapes = morph_data.collider_shape
			add_child(morph_driver)
			morph_driver.owner = self
			move_child(morph_driver, 0)
		else:
			morph_driver = $'MorphDriver'
			morph_driver.meshes.append(mi)
	
	baked = true
	bake_in_progress = false

func _set_body_mesh(meshdata: ArrayMesh) -> void:
	var visible = true
	var mat_config: HumanizerMaterial = null
	if body_mesh != null:
		visible = body_mesh.visible
		if body_mesh is HumanizerMeshInstance:
			mat_config = body_mesh.material_config
	if body_mesh == null:
		body_mesh = MeshInstance3D.new()
		body_mesh.name = BASE_MESH_NAME
		_add_child_node(body_mesh)
	body_mesh.mesh = meshdata
	body_mesh.set_surface_override_material(0, StandardMaterial3D.new())
	body_mesh.set_script(load('res://addons/humanizer/scripts/core/humanizer_mesh_instance.gd'))
	body_mesh.material_config = HumanizerMaterial.new() if mat_config == null else mat_config
	if skeleton != null:
		body_mesh.skeleton = '../' + skeleton.name
		body_mesh.skin = skeleton.create_skin_from_rest_transforms()
	body_mesh.visible = visible

func _fit_all_meshes() -> void:
	_fit_body_mesh()
	for equip in human_config.equipment.values():
		_fit_equipment_mesh(equip)
	
func _fit_body_mesh() -> void:
	# fit body mesh
	if body_mesh == null:
		print("body mesh is null")
		return
	body_mesh.mesh = humanizer.get_body_mesh()
	#body_mesh.mesh = HumanizerBodyService.fit_mesh(body_mesh.mesh,humanizer.helper_vertex)

func _fit_equipment_mesh(equipment: HumanAsset) -> void:
	if equipment.node == null:
		print("missing equipment node")
		return
	equipment.node.mesh = humanizer.get_mesh(equipment.resource_name)

func _combine_meshes() -> ArrayMesh:
	var new_mesh = ImporterMesh.new()
	new_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var material: BaseMaterial3D
		if child.get_surface_override_material(0) != null:
			material = child.get_surface_override_material(0).duplicate(true)
		else:
			material = child.mesh.surface_get_material(0).duplicate(true)
		var surface_arrays = child.mesh.surface_get_arrays(0)
		if child.transform != Transform3D.IDENTITY and not child.name.begins_with('Baked-'):
			human_config.transforms[child.name] = Transform3D(child.transform)
			surface_arrays = surface_arrays.duplicate(true)
			for vtx in surface_arrays[Mesh.ARRAY_VERTEX].size():
				surface_arrays[Mesh.ARRAY_VERTEX][vtx] = child.transform * surface_arrays[Mesh.ARRAY_VERTEX][vtx]
		var blend_shape_arrays = child.mesh.surface_get_blend_shape_arrays(0)
		if new_mesh.get_blend_shape_count() != child.mesh.get_blend_shape_count():
			if new_mesh.get_blend_shape_count() == 0:
				#each surface needs to have the exact same number of shapekeys
				for bs_id in child.mesh.get_blend_shape_count():
					var bs_name = child.mesh.get_blend_shape_name(bs_id)
					new_mesh.add_blend_shape(bs_name)
			else:
				printerr("inconsistent number of blend shapes")
		var format = child.mesh.surface_get_format(0)
		new_mesh.add_surface(
			Mesh.PRIMITIVE_TRIANGLES, 
			surface_arrays, 
			blend_shape_arrays, 
			{},
			material, 
			child.name.replace('Baked-', ''), 
			format
		)
		
	if human_config.components.has(&'lod'):
		new_mesh.generate_lods(25, 60, [])
	return new_mesh.get_mesh()

func _set_shapekey_data(shapekeys: Dictionary) -> void:
	if baked and not bake_in_progress:
		printerr('Cannot change shapekeys on baked mesh.  Reset the character.')
		notify_property_list_changed()
		return
	humanizer.set_targets(shapekeys)
	#print(body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	
func add_shapekey() -> void:
	if new_shapekey_name in ['', null]:
		printerr('Invalid shapekey name')
		return
	if _new_shapekeys.has(new_shapekey_name):
		printerr('A new shape with this name already exists')
		return
	_new_shapekeys[new_shapekey_name] = human_config.shapekeys.duplicate(true)
	notify_property_list_changed()

#### Materials ####
func set_skin_texture(name: String) -> void:
	#print('setting skin texture : ' + name)
	if baked:
		push_warning("Can't change skin.  Already baked")
		notify_property_list_changed()
		return
	var texture: String
	if not HumanizerRegistry.skin_textures.has(name):
		body_mesh.material_config.set_base_textures(HumanizerOverlay.new())
	else:
		texture = HumanizerRegistry.skin_textures[name]
		var normal_texture = texture.get_base_dir() + '/' + name + '_normal.' + texture.get_extension()
		if not FileAccess.file_exists(normal_texture):
			if body_mesh.material_config.overlays.size() > 0:
				var overlay = body_mesh.material_config.overlays[0]
				normal_texture = overlay.normal_texture_path
			else:
				normal_texture = ''
		var overlay = {&'albedo': texture, &'color': skin_color, &'normal': normal_texture}
		body_mesh.material_config.set_base_textures(HumanizerOverlay.from_dict(overlay))

func set_skin_normal_texture(name: String) -> void:
	if baked:
		printerr('Cannot change skin textures. Alrady baked.')
		notify_property_list_changed()
		return
	#print('setting skin normal texture')
	var texture: String = '' if name == 'None' else HumanizerRegistry.skin_normals[name]
	if body_mesh.material_config.overlays.size() == 0:
		if texture == '':
			return
		var overlay = {&'normal': texture, &'color': skin_color}
		body_mesh.material_config.set_base_textures(HumanizerOverlay.from_dict(overlay))
	else:
		var overlay = body_mesh.material_config.overlays[0]
		overlay.normal_texture_path = texture
		body_mesh.material_config.set_base_textures(overlay)

func set_equipment_texture_by_slot(slot_name:String, texture: String):
	var equip = human_config.get_equipment_in_slot(slot_name)
	if equip != null:
		set_equipment_material(equip,texture)

func set_equipment_texture_by_name(equip_name:String, texture:String):
	if equip_name in human_config.equipment:
		var equip = human_config.equipment[equip_name]
		set_equipment_material(equip,texture)

func set_equipment_material(equipment:HumanAsset, texture: String) -> void:
	if baked:
		printerr('Cannot change materials. Already baked.')
		return
	equipment.texture_name = texture
	var mesh_inst = equipment.node
	if mesh_inst == null:
		print(equipment.resource_name + " has no mesh instance " )
		return
	if equipment.default_overlay != null:
		var mat_config: HumanizerMaterial = mesh_inst.material_config
		var overlay_dict = {&'albedo': equipment.textures[texture]}
		if mesh_inst.get_surface_override_material(0).normal_texture != null:
			overlay_dict[&'normal'] = mesh_inst.get_surface_override_material(0).normal_texture.resource_path
		if mesh_inst.get_surface_override_material(0).ao_texture != null:
			overlay_dict[&'ao'] = mesh_inst.get_surface_override_material(0).ao_texture.resource_path
		mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	else:
		mesh_inst.get_surface_override_material(0).albedo_texture = load(equipment.textures[texture])
	
	if equipment.in_slot(['LeftEye', 'RightEye', 'Eyes']):	
		var iris: HumanizerOverlay = mesh_inst.material_config.overlays[1]
		iris.color = eye_color
		mesh_inst.material_config.set_overlay(1, iris)	
		mesh_inst.material_config.update_material()
	elif equipment.in_slot(['RightEyebrow', 'LeftEyebrow', 'Eyebrows']):
		mesh_inst.get_surface_override_material(0).albedo_color = Color(hair_color * eyebrow_color_weight, 1) 
	elif equipment.in_slot(['Hair']):
		mesh_inst.get_surface_override_material(0).albedo_color = hair_color
	notify_property_list_changed()
	
func _setup_overlay_material(asset: HumanAsset, existing_config: HumanizerMaterial = null) -> void:
	var mi: MeshInstance3D = asset.node
	mi.set_script(load("res://addons/humanizer/scripts/core/humanizer_mesh_instance.gd"))
	if existing_config != null:
		mi.material_config = existing_config
		return
	mi.material_config = HumanizerMaterial.new()
	var overlay_dict = {'albedo': asset.textures.values()[0]}
	if mi.get_surface_override_material(0).normal_texture != null:
		overlay_dict['normal'] = mi.get_surface_override_material(0).normal_texture.resource_path
	if mi.get_surface_override_material(0).ao_texture != null:
		overlay_dict['ao'] = mi.get_surface_override_material(0).ao_texture.resource_path
	var overlay = HumanizerOverlay.from_dict(overlay_dict)
	mi.material_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	mi.material_config.add_overlay(asset.default_overlay.duplicate(true))

#### Animation ####
func set_rig(rig_name: String) -> void:
	if baked:
		printerr('Cannot change rig on baked mesh.  Reset the character.')
		return
	# Delete existing skeleton
	for child in get_children():
		if child is Skeleton3D:
			_delete_child_node(child)
	if rig_name == '':
		return

	var retargeted: bool = rig_name.ends_with('-RETARGETED')
	humanizer.set_rig(rig_name)
	var rig:HumanizerRig = humanizer.rig
	skeleton = humanizer.get_skeleton()
	_add_child_node(skeleton)
	skeleton.unique_name_in_owner = true
	# Set new mesh
	var mat = body_mesh.get_surface_override_material(0)
	body_mesh.mesh = humanizer.get_body_mesh()
	body_mesh.set_surface_override_material(0, mat)
	body_mesh.skeleton = '../' + skeleton.name
	body_mesh.skin = skeleton.create_skin_from_rest_transforms()
	_reset_animator()

	if human_config.components.has(&'ragdoll'):
		set_component_state(false, &'ragdoll')
		set_component_state(true, &'ragdoll')
	if human_config.components.has(&'root_bone'):
		set_component_state(true, &'root_bone')
		notify_property_list_changed()
	if human_config.components.has(&'saccades'):
		if rig_name != &'default-RETARGETED':
			set_component_state(false, &'saccades')

func _adjust_skeleton() -> void:
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	humanizer.adjust_skeleton(skeleton)	
	skeleton.reset_bone_poses()
	for child in get_children():
		if child is MeshInstance3D:
			child.skin = skeleton.create_skin_from_rest_transforms()
		
func _add_bone_weights(asset: HumanAsset) -> void:
	if asset.node == null:
		return
	var mi: MeshInstance3D = asset.node
	mi.mesh = humanizer.get_mesh(asset.resource_name)
	mi.skeleton = &'../' + skeleton.name
	mi.skin = skeleton.create_skin_from_rest_transforms()

func _reset_animator() -> void:
	for child in get_children():
		if child is AnimationTree or child is AnimationPlayer:
			_delete_child_node(child)
	if human_config.rig == 'default-RETARGETED':
		animator = load("res://addons/humanizer/data/animations/face_animation_tree.tscn").instantiate()
	elif human_config.rig.ends_with('RETARGETED'):
		animator = load("res://addons/humanizer/data/animations/animation_tree.tscn").instantiate()
	else:  # No example animator for specific rigs that aren't retargeted
		return
	_add_child_node(animator)
	animator.active = true
	set_editable_instance(animator, true)
	if human_config.rig == 'default-RETARGETED':
		reset_face_pose()

func reset_face_pose() -> void:
	var face_poses: AnimationLibrary = load("res://addons/humanizer/data/animations/face_poses.glb")
	for clip: String in face_poses.get_animation_list():
		animator.set("parameters/" + clip + "/add_amount", 0.)

#### Additional Components ####
func set_component_state(enabled: bool, component: StringName) -> void:
	if enabled:
		human_config.enable_component(component)
		if component == &'main_collider':
			_add_main_collider()
		elif component == &'ragdoll':
			_add_physical_skeleton()
		elif component == &'saccades':
			_add_saccades()
		elif component == &'root_bone':
			humanizer.enable_root_bone_component()
			rebuild_skeleton()
	else:
		human_config.disable_component(component)
		if component == &'main_collider':
			if main_collider != null:
				_delete_child_node(main_collider)
			main_collider = null
		elif component == &'ragdoll':
			skeleton.physical_bones_stop_simulation()
			for child in skeleton.get_children():
				if child is PhysicalBone3D:
					_delete_child_node(child)
		elif component == &'saccades':
			var saccades = get_node_or_null('Saccades')
			if saccades:
				saccades.queue_free()
			if animator != null:
				animator.active = true
			notify_property_list_changed()
		elif component == &'root_bone':
			humanizer.disable_root_bone_component()
			if skeleton != null:
				rebuild_skeleton()

func _add_main_collider() -> void:
	if has_node('MainCollider'):
		main_collider = $MainCollider
	else:
		main_collider = CollisionShape3D.new()
		main_collider.shape = CapsuleShape3D.new()
		main_collider.name = 'MainCollider'
		_add_child_node(main_collider)
	_adjust_main_collider()

func _add_physical_skeleton() -> void:
	if skeleton == null:
		return
	animator.active = false
	skeleton.reset_bone_poses()
	HumanizerPhysicalSkeleton.new(skeleton, humanizer.helper_vertex, _ragdoll_layers, _ragdoll_mask).run()
	skeleton.reset_bone_poses()
	animator.active = true
	skeleton.animate_physical_bones = true

func _adjust_main_collider():
	var head_height = humanizer.get_head_height()
	var offset = humanizer.get_foot_offset()
	var height = head_height - offset
	main_collider.shape.height = height
	main_collider.position.y = height/2 + offset

	main_collider.shape.radius = humanizer.get_max_width()

func _add_saccades() -> void:
	if human_config.rig == 'default-RETARGETED':
		var saccades : Node = get_node_or_null('Saccades')
		if saccades != null:
			saccades.human = self
			saccades.enabled = true
			return
		saccades = load("res://addons/humanizer/scenes/subscenes/saccades.tscn").instantiate()
		saccades.skeleton = skeleton
		_add_child_node(saccades)
		move_child(saccades, 0)
		## So you can see the effect without the animation tree overriding
		animator.active = false 
	else:
		printerr('Saccades are not compatible with the selected rig')
		set_component_state(false, &'saccades')
	
func rebuild_skeleton():
	humanizer.update_skeleton(skeleton)
	$AnimationTree.set_active(false)
	skeleton.reset_bone_poses()
	$AnimationTree.set_active(true)
	#for child in get_children():
		#if child is MeshInstance3D:
			#child.skin = skeleton.create_skin_from_rest_transforms()
	
