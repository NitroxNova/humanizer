@tool
class_name Humanizer
extends Node3D

## Base humanizer node for use in-game when loading a new human from config

const _BASE_MESH_NAME: String = 'Body'
const _DEFAULT_SKIN_COLOR = Color.WHITE
const _DEFAULT_EYE_COLOR = Color.SKY_BLUE
const _DEFAULT_HAIR_COLOR = Color.WEB_MAROON
const _DEFAULT_EYEBROW_COLOR = Color.BLACK
## Vertex ids
const shoulder_id: int = 16951 
const waist_id: int = 17346
const hips_id: int = 18127
const feet_ids: Array[int] = [15500, 16804]
const eyebrow_color_weight := 0.4

var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var baked := false
var bake_in_progress := false
var scene_loaded: bool = false
var main_collider: CollisionShape3D
var animator: Node
var _base_motion_scale: float:
	get:
		var rig: HumanizerRig = HumanizerRegistry.rigs[human_config.rig.split('-')[0]]
		var sk: Skeleton3D
		if human_config.rig.ends_with('RETARGETED'):
			sk = rig.load_retargeted_skeleton()
		else:
			sk = rig.load_skeleton()
		return sk.motion_scale
var _base_hips_height: float:
	get:
		return shapekey_data.basis[hips_id].y
var shapekey_data: Dictionary:
	get:
		return HumanizerUtils.shapekey_data
var _helper_vertex: PackedVector3Array = []
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

var skin_color: Color = _DEFAULT_SKIN_COLOR:
	set(value):
		if skin_color == value:
			return
		skin_color = value
		if body_mesh == null or (body_mesh as HumanizerMeshInstance) == null:
			return
		if scene_loaded and body_mesh.material_config.overlays.size() == 0:
			return
		human_config.skin_color = skin_color
		if body_mesh.material_config.overlays.size() > 0:
			body_mesh.material_config.overlays[0].color = skin_color
var hair_color: Color = _DEFAULT_HAIR_COLOR:
	set(value):
		if hair_color == value:
			return
		hair_color = value
		if human_config == null or not scene_loaded:
			return
		human_config.hair_color = hair_color
		if human_config.body_parts.has(&'Hair'):
			var mesh = human_config.body_parts[&'Hair'].node
			(mesh as MeshInstance3D).get_surface_override_material(0).albedo_color = hair_color 
		eyebrow_color = Color(hair_color * eyebrow_color_weight, 1.)
		notify_property_list_changed()
var eyebrow_color: Color = _DEFAULT_EYEBROW_COLOR:
	set(value):
		if eyebrow_color == value:
			return
		eyebrow_color = value
		if human_config == null or not scene_loaded:
			return
		human_config.eyebrow_color = eyebrow_color
		var slots: Array = [&'RightEyebrow', &'LeftEyebrow', &'Eyebrows']
		for slot in slots:
			if not human_config.body_parts.has(slot):
				continue
			var mesh = human_config.body_parts[slot].node
			(mesh as MeshInstance3D).get_surface_override_material(0).albedo_color = eyebrow_color 
var eye_color: Color = _DEFAULT_EYE_COLOR:
	set(value):
		if eye_color == value:
			return
		eye_color = value
		if human_config == null or not scene_loaded:
			return
		human_config.eye_color = eye_color
		var slots: Array = [&'RightEye', &'LeftEye', &'Eyes']
		for slot in slots:
			if not human_config.body_parts.has(slot):
				continue
			var mesh = human_config.body_parts[slot].node
			var overlay = mesh.material_config.overlays[1]
			overlay.color = eye_color
			mesh.material_config.set_overlay(1, overlay)
## The meshes selected to be baked to a new surface
@export var _bake_meshes: Array[MeshInstance3D]
## The new shapekeys which have been defined for this human.  These will survive the baking process.
@export var _new_shapekeys: Dictionary = {}

@export_category("Humanizer Node Settings")
## This resource stores all the data necessary to build the human model
@export var human_config: HumanConfig:
	set(value):
		human_config = value
		if scene_loaded and human_config != null:
			load_human()
			notify_property_list_changed()

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
	_new_shapekeys = {}
	if has_node('MorphDriver'):
		_delete_child_node($MorphDriver)
	baked = false
	_helper_vertex = shapekey_data.basis.duplicate(true)
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
	_adjust_skeleton()
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
	for slot in human_config.body_parts:
		if human_config.body_parts[slot].resource_name == mesh_name:
			res = human_config.body_parts[slot] as HumanBodyPart
	if res == null:
		for cl in human_config.clothes:
			if cl.resource_name == mesh_name:
				res = cl as HumanClothes
	return res

func _deserialize() -> void:
	## Set shapekeys
	var sk = human_config.shapekeys.duplicate()
	human_config.shapekeys = {}
	set_rig(human_config.rig)
	_set_shapekey_data(sk)

	## Load Assets
	for bp: HumanBodyPart in human_config.body_parts.values():
		set_body_part(bp)
	for cl: HumanClothes in human_config.clothes:
		_add_clothes_mesh(cl)
		
	## Load materials with overlays
	for child in get_children():
		if child.name in human_config.material_configs:
			var mat_config = human_config.material_configs[child.name]
			child.material_config = mat_config
	
	## Load textures for non-overlay materials
	for slot in human_config.body_parts:
		if not get_node(human_config.body_parts[slot].resource_name) is HumanizerMeshInstance:
			set_body_part_material(slot, human_config.body_part_materials[slot])
	for cl: String in human_config.clothes_materials:
		if not get_node(cl) is HumanizerMeshInstance:
			set_clothes_material(cl, human_config.clothes_materials[cl])

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
	for bp in human_config.body_parts.values():
		if bp.node is HumanizerMeshInstance:
			if bp.node.material_config.overlays.size() > 0:
				bp.node.material_config.update_material()
	for cl in human_config.clothes:
		if cl.node is HumanizerMeshInstance:
			if cl.node.material_config.overlays.size() > 0:
				cl.node.material_config.update_material()
	
	## Finalize
	hide_body_vertices()
	_adjust_skeleton()
	_fit_all_meshes()
	_recalculate_normals()

#### Mesh Management ####
func set_body_part(bp: HumanBodyPart) -> void:
	if baked:
		push_warning("Can't change body parts.  Already baked")
		notify_property_list_changed()
		return
	var rig_changed = bp.rigged #rebuild skeleton if the new asset or the removed assets have a rig
	if human_config.body_parts.has(bp.slot):
		var current = human_config.body_parts[bp.slot]
		if current.rigged:
			rig_changed = true
		_delete_child_by_name(current.resource_name)
	human_config.body_parts[bp.slot] = bp
	var mi = load(bp.scene_path).instantiate() as MeshInstance3D
	mi.name = bp.resource_name
	bp.node = mi
	if bp.default_overlay != null or human_config.material_configs.has(bp.resource_name):
		_setup_overlay_material(bp, human_config.material_configs.get(bp.resource_name))
	else:
		mi.get_surface_override_material(0).resource_path = ''
	if not human_config.body_part_materials.has(bp.slot):
		set_body_part_material(bp.slot, Random.choice(bp.textures.keys()))
	_add_child_node(mi)
	
	if rig_changed:
		set_rig(human_config.rig) #update rig with additional asset bones, and remove any from previous asset
	else:
		_add_bone_weights(bp)

	if 'eyebrow' in bp.slot.to_lower():
		eyebrow_color = eyebrow_color  ## trigger setter logic
	if human_config.transforms.has(bp.resource_name):
		bp.node.transform = Transform3D(human_config.transforms[bp.resource_name])
	#notify_property_list_changed()

func clear_body_part(clear_slot: String) -> void:
	if baked:
		push_warning("Can't change body parts.  Already baked")
		notify_property_list_changed()
		return
	for slot in human_config.body_parts:
		if slot == clear_slot:
			var res = human_config.body_parts[clear_slot]
			res.node = null
			_delete_child_by_name(res.resource_name)
			human_config.body_parts.erase(clear_slot)
			if res.rigged:
				set_rig(human_config.rig) #remove bones from previous asset
			return

func apply_clothes(cl: HumanClothes) -> void:
	if baked:
		push_warning("Can't change clothes.  Already baked")
		notify_property_list_changed()
		return
	for wearing in human_config.clothes:
		for slot in cl.slots:
			if slot in wearing.slots:
				remove_clothes(wearing)
	#print('applying ' + cl.resource_name + ' clothes')
	_add_clothes_mesh(cl)

func _add_clothes_mesh(cl: HumanClothes) -> void:
	if not cl in human_config.clothes:
		human_config.clothes.append(cl)
	var mi = load(cl.scene_path).instantiate()
	cl.node = mi
	mi.name = cl.resource_name
	if cl.default_overlay != null:
		_setup_overlay_material(cl, human_config.material_configs.get(cl.resource_name))
	_add_child_node(mi)
	_add_bone_weights(cl)
	if human_config.clothes_materials.has(cl.resource_name):
		set_clothes_material(cl.resource_name, Random.choice(cl.textures.keys()))
	if human_config.transforms.has(cl.resource_name):
		cl.node.transform = Transform3D(human_config.transforms[cl.resource_name])

func clear_clothes_in_slot(slot: String) -> void:
	if baked:
		push_warning("Can't change clothes.  Already baked")
		notify_property_list_changed()
		return
	for cl in human_config.clothes:
		if slot in cl.slots:
			#print('clearing ' + cl.resource_name + ' clothes')
			remove_clothes(cl)

func remove_clothes(cl: HumanClothes) -> void:
	if baked:
		push_warning("Can't change clothes.  Already baked")
		notify_property_list_changed()
		return
	cl.node = null
	if human_config.clothes_materials.has(cl.resource_name):
		human_config.clothes_materials.erase(cl.resource_name)
	for child in get_children():
		if child.name == cl.resource_name:
			#print('removing ' + cl.resource_name + ' clothes')
			_delete_child_node(child)
	human_config.clothes.erase(cl)

func hide_body_vertices() -> void:
	if baked:
		push_warning("Can't alter meshes.  Already baked")
		return
	var skin_mat = body_mesh.get_surface_override_material(0)
	var arrays: Array = (body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var delete_verts_gd := []
	delete_verts_gd.resize(arrays[Mesh.ARRAY_VERTEX].size())
	var delete_verts_mh := []
	delete_verts_mh.resize(_helper_vertex.size())
	var remap_verts_gd = PackedInt32Array() #old to new
	remap_verts_gd.resize(arrays[Mesh.ARRAY_VERTEX].size())
	remap_verts_gd.fill(-1)
	
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var res: HumanAsset = _get_asset_by_name(child.name)
		if res is HumanClothes or res is HumanBodyPart:
			var mhclo : MHCLO = load(res.mhclo_path)
			for entry in mhclo.delete_vertices:
					if entry.size() == 1:
						delete_verts_mh[entry[0]] = true
					else:
						for mh_id in range(entry[0], entry[1] + 1):
							delete_verts_mh[mh_id] = true
	
	for gd_id in arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		if delete_verts_mh[mh_id]:
			delete_verts_gd[gd_id] = true
			
	_set_body_mesh(MeshOperations.delete_faces(body_mesh.mesh,delete_verts_gd))
	body_mesh.set_surface_override_material(0, skin_mat)
	body_mesh.skeleton = '../' + skeleton.name

func hide_clothes_vertices():
	if baked:
		push_warning("Can't alter meshes.  Already baked")
		return
	var delete_verts_mh := []
	delete_verts_mh.resize(_helper_vertex.size())
	
	var depth_sorted_clothes := []
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var res: HumanAsset = _get_asset_by_name(child.name)
		if res is HumanClothes or res is HumanBodyPart:
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
		
		if any_deleted:
			clothes_node.mesh = MeshOperations.delete_faces(clothes_node.mesh,cl_delete_verts_gd)			
		
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
	for cl in human_config.clothes:
		_delete_child_by_name(cl.resource_name)
		_add_clothes_mesh(cl)

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
		body_mesh.name = _BASE_MESH_NAME
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
	for bp in human_config.body_parts.values():
		_fit_body_part_mesh(bp)
	for cl in human_config.clothes:
		_fit_clothes_mesh(cl)
	
func _fit_body_mesh() -> void:
	# fit body mesh
	if body_mesh == null:
		return
	var mesh := body_mesh.mesh as ArrayMesh
	var surf_arrays = mesh.surface_get_arrays(0)
	var fmt = mesh.surface_get_format(0)
	var vtx_arrays = surf_arrays[Mesh.ARRAY_VERTEX]
	surf_arrays[Mesh.ARRAY_VERTEX] = _helper_vertex.slice(0, vtx_arrays.size())
	for gd_id in surf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = surf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		surf_arrays[Mesh.ARRAY_VERTEX][gd_id] = _helper_vertex[mh_id]
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf_arrays, [], {}, fmt)

func _fit_body_part_mesh(bp: HumanBodyPart) -> void:
	if bp.node == null:
		return
	var mhclo: MHCLO = load(bp.mhclo_path)
	var new_mesh = MeshOperations.build_fitted_mesh(bp.node.mesh, _helper_vertex, mhclo)
	new_mesh = MeshOperations.generate_normals_and_tangents(new_mesh)
	bp.node.mesh = new_mesh

func _fit_clothes_mesh(cl: HumanClothes) -> void:
	if cl.node == null:
		return
	var mhclo: MHCLO = load(cl.mhclo_path)
	var new_mesh = MeshOperations.build_fitted_mesh(cl.node.mesh, _helper_vertex, mhclo)
	new_mesh = MeshOperations.generate_normals_and_tangents(new_mesh)
	cl.node.mesh = new_mesh

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

func _recalculate_normals() -> void:
	if body_mesh != null:
		var mat = body_mesh.get_surface_override_material(0)
		_set_body_mesh(MeshOperations.generate_normals_and_tangents(body_mesh.mesh))
		body_mesh.set_surface_override_material(0, mat)
	
	for mesh in get_children():
		if not mesh is MeshInstance3D or mesh == body_mesh: #dont need to generate body_mesh again
			continue
		if not mesh.name.begins_with("Baked-"):
			mesh.mesh = MeshOperations.generate_normals_and_tangents(mesh.mesh)

func _set_shapekey_data(shapekeys: Dictionary) -> void:
	if baked and not bake_in_progress:
		printerr('Cannot change shapekeys on baked mesh.  Reset the character.')
		notify_property_list_changed()
		return
	var prev_sk = human_config.shapekeys.duplicate()

	# Set default macro/race values if not present
	var macro_vals := {}
	for sk in MeshOperations.get_macro_options():
		macro_vals[sk] = shapekeys.get(sk, prev_sk.get(sk, 0.5))
	var race_vals := {}
	for sk in MeshOperations.get_race_options():
		race_vals[sk] = shapekeys.get(sk, prev_sk.get(sk, 0.333))
	
	for sk in macro_vals:
		shapekeys[sk] = macro_vals[sk]
	for sk in race_vals:
		shapekeys[sk] = race_vals[sk]
	
	# Clear all macro shapekeys then re-apply results from macro sliders
	for sk in shapekey_data.macro_shapekeys:
		shapekeys[sk] = 0
	var sk_values = MeshOperations.get_macro_shapekey_values(macro_vals, race_vals)
	for sk in sk_values:
		shapekeys[sk] = sk_values[sk]
	
	# Apply shapekey changes to base mesh
	for sk in shapekeys:
		var prev_val: float = prev_sk.get(sk, 0)
		if prev_val == shapekeys[sk]:
			continue
		if sk not in shapekey_data.shapekeys:
			continue
		for mh_id in shapekey_data.shapekeys[sk]:
			_helper_vertex[mh_id] += shapekey_data.shapekeys[sk][mh_id] * (shapekeys[sk] - prev_val)
	
	var offset = max(_helper_vertex[feet_ids[0]].y, _helper_vertex[feet_ids[1]].y)
	var _foot_offset = Vector3.UP * offset
	
	for i in _helper_vertex.size():
		_helper_vertex[i] -= _foot_offset
		
	for key in shapekeys:
		human_config.shapekeys[key] = shapekeys[key]

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

func set_body_part_material(set_slot: String, texture: String) -> void:
	#print('setting material ' + texture + ' on ' + set_slot)
	if baked:
		printerr('Cannot change materials. Already baked.')
		return
	var bp: HumanBodyPart = human_config.body_parts[set_slot]
	if bp.node == null:
		return
	var mi = bp.node as MeshInstance3D
	human_config.body_part_materials[set_slot] = texture

	if bp.default_overlay != null:
		var mat_config: HumanizerMaterial = mi.material_config
		var overlay_dict = {&'albedo': bp.textures[texture]}
		if mi.get_surface_override_material(0).normal_texture != null:
			overlay_dict[&'normal'] = mi.get_surface_override_material(0).normal_texture.resource_path
		if mi.get_surface_override_material(0).ao_texture != null:
			overlay_dict[&'ao'] = mi.get_surface_override_material(0).ao_texture.resource_path
		mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	else:
		var mat: BaseMaterial3D = mi.get_surface_override_material(0)
		mat.albedo_texture = load(bp.textures[texture])
	if bp.slot in ['LeftEye', 'RightEye', 'Eyes']:
		var iris: HumanizerOverlay = mi.material_config.overlays[1]
		iris.color = eye_color
		mi.material_config.set_overlay(1, iris)
	if bp.slot in ['RightEyebrow', 'LeftEyebrow', 'Eyebrows']:
		mi.get_surface_override_material(0).albedo_color = Color(hair_color * eyebrow_color_weight, 1) 
	elif bp.slot == 'Hair':
		mi.get_surface_override_material(0).albedo_color = hair_color
	notify_property_list_changed()

func set_clothes_material(cl_name: String, texture: String) -> void:
	#print('setting texture ' + texture + ' on ' + cl_name)
	if baked:
		printerr('Cannot change materials. Already baked.')
		return
	var cl: HumanClothes = HumanizerRegistry.clothes[cl_name]
	if cl.node == null:
		return
	var mi: MeshInstance3D = cl.node
	
	if cl.default_overlay != null:
		## HumanizerMaterials are always local to scene
		var mat_config: HumanizerMaterial = (mi as HumanizerMeshInstance).mat_config
		var overlay_dict = HumanizerOverlay.from_dict({'albedo': cl.textures[texture]})
		if mi.get_surface_override_material(0).normal_texture != null:
			overlay_dict['normal'] = mi.get_surface_override_material(0).normal_texture.resource_path
		if mi.get_surface_override_material(0).ao_texture != null:
			overlay_dict['ao'] = mi.get_surface_override_material(0).ao_texture.resource_path
		mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	else:
		mi.get_surface_override_material(0).albedo_texture = load(cl.textures[texture])
		## Need to set material settings for other assets sharing the same material
		for other: HumanClothes in human_config.clothes:
			if cl != other and not baked:
				var other_mat: BaseMaterial3D = other.node.get_surface_override_material(0)
				var this_mat: BaseMaterial3D = mi.get_surface_override_material(0)
				if other_mat.resource_path == this_mat.resource_path:
					human_config.clothes_materials[other.resource_name] = texture
					notify_property_list_changed()
	human_config.clothes_materials[cl_name] = texture

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
	mi.material_config.add_overlay(asset.default_overlay)

func update_asset_material(asset:HumanAsset):
	var mesh = asset.node
	if "material_config" in mesh:
		mesh.material_config.update_material()
		
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
	var rig: HumanizerRig = HumanizerRegistry.rigs[rig_name.split('-')[0]]
	human_config.rig = rig_name
	skeleton = rig.load_skeleton()  # Json file needs base skeleton names even if using retargeted
	var skinned_mesh: ArrayMesh = MeshOperations.skin_mesh(rig, skeleton, body_mesh.mesh)
	
	# Set rig in scene
	if retargeted:
		skeleton = rig.load_retargeted_skeleton()
	_add_child_node(skeleton)
	skeleton.unique_name_in_owner = true
	# Set new mesh
	var mat = body_mesh.get_surface_override_material(0)
	_set_body_mesh(skinned_mesh)
	body_mesh.set_surface_override_material(0, mat)
	body_mesh.skeleton = '../' + skeleton.name
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
	var rig = human_config.rig.split('-')[0]
	var skeleton_config = HumanizerUtils.read_json(HumanizerRegistry.rigs[rig].config_json_path)
	var offset = max(_helper_vertex[feet_ids[0]].y, _helper_vertex[feet_ids[1]].y)
	var _foot_offset = Vector3.UP * offset
	skeleton.motion_scale = 1
	
	var asset_bone_positions = []
	asset_bone_positions.resize(skeleton.get_bone_count())	
	
	if not baked:
		for cl in human_config.clothes:
			if cl.rigged:
				_get_asset_bone_positions(cl, asset_bone_positions)
		for bp in human_config.body_parts.values():
			if bp.rigged:
				_get_asset_bone_positions(bp, asset_bone_positions)
	
	for bone_id in skeleton.get_bone_count():
		var bone_pos = Vector3.ZERO
		## manually added bones won't be in the config
		if skeleton_config.size() < bone_id + 1:
			bone_pos = asset_bone_positions[bone_id]
		else:
			var bone_data = skeleton_config[bone_id]
			if "vertex_indices" in bone_data.head:
				for vid in bone_data.head.vertex_indices:
					bone_pos += _helper_vertex[int(vid)]
				bone_pos /= bone_data.head.vertex_indices.size()
			else:
				bone_pos = _helper_vertex[int(bone_data.head.vertex_index)]
		if skeleton.get_bone_name(bone_id) != 'Root':
			bone_pos -= _foot_offset
		else:
			bone_pos = Vector3.ZERO  # Root should always be at origin
		var parent_id = skeleton.get_bone_parent(bone_id)
		if not parent_id == -1:
			var parent_xform = skeleton.get_bone_global_pose(parent_id)
			bone_pos = bone_pos * parent_xform
		skeleton.set_bone_pose_position(bone_id, bone_pos)
		skeleton.set_bone_rest(bone_id, skeleton.get_bone_pose(bone_id))

	
	skeleton.motion_scale = _base_motion_scale * (_helper_vertex[hips_id].y - _foot_offset.y) / _base_hips_height
	skeleton.reset_bone_poses()
	for child in get_children():
		if child is MeshInstance3D:
			child.skin = skeleton.create_skin_from_rest_transforms()
	#print('Fit skeleton to mesh')

func _get_asset_bone_positions(asset:HumanAsset, bone_positions:Array):
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

func _add_bone_weights(asset: HumanAsset) -> void:
	if asset.node == null:
		return
	var mi: MeshInstance3D = asset.node

	var rig = human_config.rig.split('-')[0]
	var bone_weights = HumanizerUtils.read_json(HumanizerRegistry.rigs[rig].bone_weights_json_path)
	var bone_count = 8
	var mhclo: MHCLO = load(asset.mhclo_path) 
	var mh2gd_index = mhclo.mh2gd_index
	var mesh: ArrayMesh
	
	if asset.rigged:
		for bone_id in mhclo.rigged_config.size():
			var bone_config = mhclo.rigged_config[bone_id]
			if bone_config.name != "neutral_bone":
				var bone_name = bone_config.name
				#print("adding bone " + bone_name)
				var parent_bone = -1
				if bone_config.parent == -1:
					for tag in mhclo.tags:
						if tag.begins_with("bone_name"):
							var parent_name = tag.get_slice(" ",1)
							parent_bone = skeleton.find_bone(parent_name)
							if parent_bone != -1:
								break
				else:
					var parent_bone_config = mhclo.rigged_config[bone_config.parent]
					parent_bone = skeleton.find_bone(parent_bone_config.name)
				if not parent_bone == -1:
					skeleton.add_bone(bone_name)
					var new_bone_id = skeleton.find_bone(bone_name)
					skeleton.set_bone_parent(new_bone_id,parent_bone)
					skeleton.set_bone_rest(new_bone_id, bone_config.transform)
					
	mesh = mi.mesh as ArrayMesh
	var new_sf_arrays = mesh.surface_get_arrays(0)
	
	new_sf_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	new_sf_arrays[Mesh.ARRAY_BONES].resize(bone_count * new_sf_arrays[Mesh.ARRAY_VERTEX].size())
	new_sf_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	new_sf_arrays[Mesh.ARRAY_WEIGHTS].resize(bone_count * new_sf_arrays[Mesh.ARRAY_VERTEX].size())
	
	var rigged_bone_ids = []
	if asset.rigged:
		for rig_bone_id in mhclo.rigged_config.size():
			var bone_name = mhclo.rigged_config[rig_bone_id].name
			rigged_bone_ids.append(skeleton.find_bone(bone_name))
	for mh_id in mhclo.vertex_data.size():
		
		var vertex_bone_weights = mhclo.calculate_vertex_bone_weights(mh_id,bone_weights, rigged_bone_ids)
		
		if mh_id < mh2gd_index.size():
			var g_id_array = mh2gd_index[mh_id]
			for g_id in g_id_array:
				for i in bone_count:
					new_sf_arrays[Mesh.ARRAY_BONES][g_id * bone_count + i] = vertex_bone_weights.bones[i]
					new_sf_arrays[Mesh.ARRAY_WEIGHTS][g_id * bone_count + i] = vertex_bone_weights.weights[i]
		else:
			print("missing " + str(mh_id) + " from " + mhclo.name)

	var flags = mesh.surface_get_format(0)
	var lods = {}
	var bs_arrays = mesh.surface_get_blend_shape_arrays(0)
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_sf_arrays, bs_arrays, lods, flags)
	mi.mesh = mesh
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
		if not human_config.components.has(component):
			human_config.components.append(component)
		if component == &'main_collider':
			_add_main_collider()
		elif component == &'ragdoll':
			_add_physical_skeleton()
		elif component == &'saccades':
			_add_saccades()
		elif component == &'root_bone':
			_add_root_bone(skeleton)
	else:
		human_config.components.erase(component)
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
			if skeleton != null:
				set_rig(human_config.rig)

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
	HumanizerPhysicalSkeleton.new(skeleton, _helper_vertex, _ragdoll_layers, _ragdoll_mask).run()
	skeleton.reset_bone_poses()
	animator.active = true
	skeleton.animate_physical_bones = true

func _adjust_main_collider():
	var head_height = _helper_vertex[14570].y
	var offset = max(_helper_vertex[feet_ids[0]].y, _helper_vertex[feet_ids[1]].y)
	var height = head_height - offset
	main_collider.shape.height = height
	main_collider.position.y = height/2 + offset

	var width_ids = [shoulder_id,waist_id,hips_id]
	var max_width = 0
	for mh_id in width_ids:
		var vertex_position = _helper_vertex[mh_id]
		var distance = Vector2(vertex_position.x,vertex_position.z).distance_to(Vector2.ZERO)
		if distance > max_width:
			max_width = distance
	main_collider.shape.radius = max_width * 1.5

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

func _add_root_bone(sk: Skeleton3D) -> void:
	if sk.find_bone('Root') != -1:
		push_warning("Rig already has root bone")
		return
	if sk.find_bone('Hips') != 0:
		push_error('Cannot add root bone.  Current root bone must be "Hips"')
		return
	sk.add_bone('Root')
	sk.set_bone_parent(0, skeleton.get_bone_count() - 1)
