@tool
class_name Humanizer
extends Node3D

const _BASE_MESH_NAME: String = 'Human'
const _DEFAULT_SKIN_COLOR = Color.WHITE
const _DEFAULT_EYE_COLOR = Color.SKY_BLUE
const _DEFAULT_HAIR_COLOR = Color.WEB_MAROON
## Vertex ids
const shoulder_id: int = 16951 
const waist_id: int = 17346
const hips_id: int = 18127
const feet_ids: Array[int] = [15500, 16804]

var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var baked := false
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

var skin_color: Color = _DEFAULT_SKIN_COLOR:
	set(value):
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
		hair_color = value
		if human_config == null or not scene_loaded:
			return
		human_config.hair_color = hair_color
		var slots: Array = [&'RightEyebrow', &'LeftEyebrow', &'Eyebrows', &'Hair']
		for slot in slots:
			if not human_config.body_parts.has(slot):
				continue
			var mesh = get_node(human_config.body_parts[slot].resource_name)
			(mesh as MeshInstance3D).get_surface_override_material(0).albedo_color = hair_color
var eye_color: Color = _DEFAULT_EYE_COLOR:
	set(value):
		eye_color = value
		if human_config == null or not scene_loaded:
			return
		human_config.eye_color = eye_color
		var slots: Array = [&'RightEye', &'LeftEye', &'Eyes']
		for slot in slots:
			if not human_config.body_parts.has(slot):
				continue
			var mesh = get_node(human_config.body_parts[slot].resource_name)
			mesh.material_config.overlays[1].color = eye_color

@export var _bake_meshes: Array[MeshInstance3D]

@export_category("Humanizer Node Settings")
@export var human_config: HumanConfig:
	set(value):
		human_config = value
		if human_config.rig == '':
			human_config.rig = HumanizerGlobalConfig.config.default_skeleton
		# This gets set before _ready causing issues so make sure we're loaded
		if scene_loaded:
			load_human()

@export_group('Node Overrides')
## The root node type for baked humans
@export_enum("CharacterBody3D", "RigidBody3D", "StaticBody3D") var _baked_root_node: String = HumanizerGlobalConfig.config.default_baked_root_node
## Texture atlas resolution for the baked character
@export_enum("1k:1024", "2k:2048", "4k:4096") var atlas_resolution: int = HumanizerGlobalConfig.config.atlas_resolution
## The scene to be added as an animator for the character
@export var _animator_scene: PackedScene = HumanizerGlobalConfig.config.default_animation_tree:
	set(value):
		_animator_scene = value
		if scene_loaded and skeleton != null:
			_reset_animator()
## THe rendering layers for the human's 3d mesh instances
@export_flags_3d_render var _render_layers = HumanizerGlobalConfig.config.default_character_render_layers:
	set(value):
		_render_layers = value
		for child in get_children():
			if child is MeshInstance3D:
				child.layers = _render_layers
## The physics layers the character collider resides in
@export_flags_3d_physics var _character_layers = HumanizerGlobalConfig.config.default_character_physics_layers:
	set(value):
		_character_layers = value
## The physics layers the character collider collides with
@export_flags_3d_physics var _character_mask = HumanizerGlobalConfig.config.default_character_physics_mask:
	set(value):
		_character_mask = value
		if main_collider != null:
			pass
## The physics layers the physical bones reside in
@export_flags_3d_physics var _ragdoll_layers = HumanizerGlobalConfig.config.default_physical_bone_layers:
	set(value):
		_ragdoll_layers = value
## The physics layers the physical bones collide with
@export_flags_3d_physics var _ragdoll_mask = HumanizerGlobalConfig.config.default_physical_bone_mask:
	set(value):
		_ragdoll_mask = value


func _ready() -> void:
	if human_config == null:
		reset_human()
	load_human()
	scene_loaded = true

####  HumanConfig Resource Management ####
func _add_child_node(node: Node) -> void:
	add_child(node)
	node.owner = self
	if node is MeshInstance3D:
		(node as MeshInstance3D).layers = _render_layers

func _delete_child_node(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.queue_free()

func _delete_child_by_name(name: String) -> void:
	for child in get_children():
		if child.name == name:
			_delete_child_node(child)

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

func load_human() -> void:
	## if we are calling on a node ont in the tree ready won't be called
	if human_config == null and not scene_loaded:
		human_config = HumanConfig.new()
	baked = false
	reset_human(false)
	_deserialize()
	notify_property_list_changed()

func _deserialize() -> void:
	human_config.shapekeys = {}
	set_rig(human_config.rig, body_mesh.mesh)
	for slot: String in human_config.body_parts:
		var bp = human_config.body_parts[slot]
		var mat = human_config.body_part_materials[slot]
		set_body_part(bp)
		set_body_part_material(bp.slot, mat)
	for clothes: HumanClothes in human_config.clothes:
		_add_clothes_mesh(clothes)
	for clothes: String in human_config.clothes_materials:
		set_clothes_material(clothes, human_config.clothes_materials[clothes])
	if human_config.body_part_materials.has(&'skin'):
		set_skin_texture(human_config.body_part_materials[&'skin'])
	for component in human_config.components:
		set_component_state(true, component)

func reset_human(reset_config: bool = true) -> void:
	baked = false
	_helper_vertex = shapekey_data.basis.duplicate(true)
	for child in get_children():
		if child is MeshInstance3D:
			_delete_child_node(child)
	if body_mesh != null and body_mesh is HumanizerMeshInstance:
		body_mesh.set_script(null)
	_set_body_mesh(load("res://addons/humanizer/data/resources/base_human.res"))
	_delete_child_by_name('MainCollider')
	main_collider = null
	if reset_config:
		human_config = HumanConfig.new()
	skin_color = _DEFAULT_SKIN_COLOR
	hair_color = _DEFAULT_HAIR_COLOR
	eye_color = _DEFAULT_EYE_COLOR
	notify_property_list_changed()
	#print('Reset human')

func save_human_scene(to_file: bool = true) -> PackedScene:
	## Save to files for easy load later
	#if not _save_path_valid:
	#	return
	DirAccess.make_dir_recursive_absolute(save_path)
	
	var new_mesh = _combine_meshes()
	var scene = PackedScene.new()
	var root_node: Node
	if _baked_root_node == &'StaticBody3D':
		root_node = StaticBody3D.new()
	elif _baked_root_node == &'CharacterBody3D':
		root_node = CharacterBody3D.new()
	elif _baked_root_node == &'RigidBody3D':
		root_node = RigidBody3D.new()
	root_node.collision_layer = _character_layers
	root_node.collision_mask = _character_mask
	
	if HumanizerGlobalConfig.config.default_human_script not in ['', null]:
		root_node.set_script(load(HumanizerGlobalConfig.config.default_human_script))
	
	var sk = skeleton.duplicate(true) as Skeleton3D
	sk.scene_file_path = ''
	root_node.add_child(sk)
	sk.owner = root_node
	
	for phys_bone: PhysicalBone3D in skeleton.get_children():
		var bone = phys_bone.duplicate(true)
		sk.add_child(bone)
		bone.owner = root_node
		for coll in phys_bone.get_children():
			var collider = coll.duplicate(true)
			bone.add_child(collider)
			collider.owner = root_node
			
	if main_collider != null:
		var coll = main_collider.duplicate(true)
		root_node.add_child(coll)
		coll.owner = root_node
	
	var animator = get_node_or_null(^'AnimationTree')
	if animator == null:
		animator = get_node_or_null(^'AnimationPlayer')
	if animator != null:
		animator = animator.duplicate(true)
		root_node.add_child(animator)
		animator.owner = root_node
	
	root_node.name = human_name
	var mi = MeshInstance3D.new()
	mi.mesh = new_mesh
	root_node.add_child(mi)
	mi.owner = root_node
	mi.skeleton = NodePath('../' + sk.name)
	mi.skin = sk.create_skin_from_rest_transforms()
	scene.pack(root_node)
	
	if not to_file:
		return scene
		
	for surface in mi.mesh.get_surface_count():
		var mat = mi.mesh.surface_get_material(surface)
		var surf_name: String = mi.mesh.surface_get_name(surface)
		if mat.albedo_texture != null:
			var path := save_path.path_join(surf_name + '_albedo.png')
			ResourceSaver.save(mat.albedo_texture, path)
			mat.albedo_texture.take_over_path(path)
		if mat.normal_texture != null:
			var path := save_path.path_join(surf_name + '_normal.png')
			ResourceSaver.save(mat.albedo_texture, path)
			mat.normal_texture.take_over_path(path)
		if mat.ao_texture != null:
			var path := save_path.path_join(surf_name + '_ao.png')
			ResourceSaver.save(mat.albedo_texture, path)
			mat.ao_texture.take_over_path(path)
		var path := save_path.path_join(surf_name + '_material.tres')
		ResourceSaver.save(mat, path)
		mat.take_over_path(path)
		
	var path := save_path.path_join('mesh.tres')
	ResourceSaver.save(mi.mesh, path)
	mi.mesh.take_over_path(path)
	path = save_path.path_join(human_name + '.res')
	ResourceSaver.save(human_config, save_path.path_join(human_name + '_config.res'))
	ResourceSaver.save(scene, save_path.path_join(human_name + '.tscn'))
	print('Saved human to : ' + save_path)
	return scene

#### Mesh Management ####
func _set_body_mesh(meshdata: ArrayMesh) -> void:
	var visible = true
	var mat_config: HumanizerMaterial = null
	if body_mesh != null:
		visible = body_mesh.visible
		if body_mesh is HumanizerMeshInstance:
			mat_config = body_mesh.material_config.duplicate(true)
	_delete_child_by_name(_BASE_MESH_NAME)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = _BASE_MESH_NAME
	body_mesh.mesh = meshdata
	body_mesh.set_surface_override_material(0, StandardMaterial3D.new())
	body_mesh.set_script(load('res://addons/humanizer/scripts/assets/humanizer_mesh_instance.gd'))
	if mat_config != null:
		body_mesh.material_config = mat_config
	else:
		body_mesh.material_config = HumanizerMaterial.new()
	body_mesh.initialize()
	if skeleton != null:
		body_mesh.skeleton = &'../' + skeleton.name
		body_mesh.skin = skeleton.create_skin_from_rest_transforms()
	body_mesh.visible = visible
	_add_child_node(body_mesh)

func set_body_part(bp: HumanBodyPart) -> void:
	if human_config.body_parts.has(bp.slot):
		if get_node_or_null(bp.resource_name) != null:
			return
		var current = human_config.body_parts[bp.slot]
		_delete_child_by_name(current.resource_name)
	human_config.body_parts[bp.slot] = bp
	var mi = load(bp.scene_path).instantiate() as MeshInstance3D
	if bp.default_overlay != null:
		setup_overlay_material(bp, mi)
	else:
		mi.get_surface_override_material(0).resource_path = ''
	_add_child_node(mi)
	set_body_part_material(bp.slot, Random.choice(bp.textures.keys()))
	_add_bone_weights(bp)
	set_shapekeys(human_config.shapekeys)
	#notify_property_list_changed()

func clear_body_part(clear_slot: String) -> void:
	for slot in human_config.body_parts:
		if slot == clear_slot:
			var res = human_config.body_parts[clear_slot]
			_delete_child_by_name(res.resource_name)
			human_config.body_parts.erase(clear_slot)
			return

func apply_clothes(cl: HumanClothes) -> void:
	for wearing in human_config.clothes:
		for slot in cl.slots:
			if slot in wearing.slots:
				remove_clothes(wearing)
	#print('applying ' + cl.resource_name + ' clothes')
	_add_clothes_mesh(cl)

func _add_clothes_mesh(cl: HumanClothes) -> void:
	if get_node_or_null(cl.resource_name) != null:
		return
	if not cl in human_config.clothes:
		human_config.clothes.append(cl)
	var mi = load(cl.scene_path).instantiate()
	if cl.default_overlay != null:
		setup_overlay_material(cl, mi)
	_add_child_node(mi)
	_add_bone_weights(cl)
	set_shapekeys(human_config.shapekeys)

func clear_clothes_in_slot(slot: String) -> void:
	for cl in human_config.clothes:
		if slot in cl.slots:
			print('clearing ' + cl.resource_name + ' clothes')
			remove_clothes(cl)

func remove_clothes(cl: HumanClothes) -> void:
	if human_config.clothes_materials.has(cl.resource_name):
		human_config.clothes_materials.erase(cl.resource_name)
	for child in get_children():
		if child.name == cl.resource_name:
			#print('removing ' + cl.resource_name + ' clothes')
			_delete_child_node(child)
	human_config.clothes.erase(cl)

func update_hide_vertices() -> void:
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
	recalculate_normals()
	body_mesh.set_surface_override_material(0, skin_mat)
	body_mesh.skeleton = &'../' + skeleton.name

func update_clothes_hide_vertices():
	
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

func _sort_clothes_by_z_depth(clothes_a,clothes_b): # from highest to lowest
	var res_a: HumanAsset = _get_asset_by_name(clothes_a.name)
	var res_b: HumanAsset = _get_asset_by_name(clothes_b.name)
	if load(res_a.mhclo_path).z_depth > load(res_b.mhclo_path).z_depth:
		return true
	return false

func restore_hidden_vertices() -> void:
	var mat = body_mesh.get_surface_override_material(0)
	_set_body_mesh(load("res://addons/humanizer/data/resources/base_human.res"))
	set_shapekeys(human_config.shapekeys)
	body_mesh.set_surface_override_material(0, mat)
	set_rig(human_config.rig, body_mesh.mesh)

func set_shapekeys(shapekeys: Dictionary) -> void:
	var prev_sk = human_config.shapekeys.duplicate()

	# Set default macro/race values
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
	
	var mesh := body_mesh.mesh as ArrayMesh
	var surf_arrays = mesh.surface_get_arrays(0)
	var fmt = mesh.surface_get_format(0)
	var lods = {}
	var vtx_arrays = surf_arrays[Mesh.ARRAY_VERTEX]
	for i in _helper_vertex.size():
		_helper_vertex[i] -= _foot_offset
	surf_arrays[Mesh.ARRAY_VERTEX] = _helper_vertex.slice(0, vtx_arrays.size())
	for gd_id in surf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = surf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		surf_arrays[Mesh.ARRAY_VERTEX][gd_id] = _helper_vertex[mh_id]
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf_arrays, [], lods, fmt)
	
	# Apply to body parts and clothes
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var res: HumanAsset = _get_asset_by_name(child.name)
		if res != null:   # Body parts/clothes
			var mhclo: MHCLO = load(res.mhclo_path)
			var new_mesh = MeshOperations.build_fitted_mesh(child.mesh, _helper_vertex, mhclo)
			child.mesh = new_mesh
	
	recalculate_normals()
	adjust_skeleton()
	for key in shapekeys:
		human_config.shapekeys[key] = shapekeys[key]
	if main_collider != null:
		_adjust_main_collider()

func set_bake_meshes(subset: String) -> void:
	_bake_meshes = []
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
			bake_surface_name = subset
			_bake_meshes.append(child)
		else:
			bake_surface_name = ''
	notify_property_list_changed()
	
func standard_bake() -> void:
	if baked:
		printerr('Already baked.  Reload the scene, load a human_config, or reset human to start over.')
		return
	adjust_skeleton()
	update_hide_vertices()
	set_bake_meshes('Opaque')
	if _bake_meshes.size() > 0:
		bake_surface()
	set_bake_meshes('Transparent')
	if _bake_meshes.size() > 0:
		bake_surface()

func bake_surface() -> void:
	if bake_surface_name in [null, '']:
		bake_surface_name = 'Surface0'
	for child in get_children():
		if child.name == 'Baked-' + bake_surface_name:
			printerr('Surface ' + bake_surface_name + ' already exists.  Choose a different name.')
			return
	if atlas_resolution == 0:
		atlas_resolution = HumanizerGlobalConfig.config.atlas_resolution
	var mi: MeshInstance3D = HumanizerSurfaceCombiner.new(_bake_meshes, atlas_resolution).run()
	mi.name = 'Baked-' + bake_surface_name
	add_child(mi)
	mi.owner = self
	mi.skeleton = &'../' + skeleton.name
	for mesh in _bake_meshes:
		remove_child(mesh)
		mesh.queue_free()
	_bake_meshes = []
	baked = true

func _combine_meshes() -> ArrayMesh:
	var new_mesh = ImporterMesh.new()
	new_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	var i = 0
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var material: BaseMaterial3D
		if child.get_surface_override_material(0) != null:
			material = child.get_surface_override_material(0).duplicate(true)
		else:
			material = child.mesh.surface_get_material(0).duplicate(true)
		var surface_arrays = child.mesh.surface_get_arrays(0)
		var blend_shape_arrays = child.mesh.surface_get_blend_shape_arrays(0)
		var lods := {}
		var format = child.mesh.surface_get_format(0)
		new_mesh.add_surface(
			Mesh.PRIMITIVE_TRIANGLES, 
			surface_arrays, 
			blend_shape_arrays, 
			lods, 
			material, 
			child.name.replace('Baked-', ''), 
			format
		)
		i += 1
	if human_config.components.has(&'lod'):
		new_mesh.generate_lods(25, 60, [])
	return new_mesh.get_mesh()

func recalculate_normals() -> void:
	var mat = body_mesh.get_surface_override_material(0)
	_set_body_mesh(MeshOperations.generate_normals_and_tangents(body_mesh.mesh))
	body_mesh.set_surface_override_material(0, mat)
	
	for mesh in get_children():
		if not mesh is MeshInstance3D:
			continue
		mesh.mesh = MeshOperations.generate_normals_and_tangents(mesh.mesh)
	
#### Materials ####
func set_skin_texture(name: String) -> void:
	#print('setting skin texture')
	var base_texture: String
	if not HumanizerRegistry.skin_textures.has(name):
		human_config.body_part_materials[&'skin'] = &''
	else:
		human_config.body_part_materials[&'skin'] = name
		base_texture = HumanizerRegistry.skin_textures[name].albedo
	body_mesh.material_config.set_base_textures(HumanizerOverlay.from_dict({'name': name, 'albedo': base_texture, 'color': skin_color}))

func set_body_part_material(set_slot: String, texture: String) -> void:
	#print('setting material ' + texture + ' on ' + set_slot)
	var bp: HumanBodyPart = human_config.body_parts[set_slot]
	human_config.body_part_materials[set_slot] = texture
	var mi = get_node(bp.resource_name) as MeshInstance3D
	if bp.default_overlay != null:
		var mat_config: HumanizerMaterial = (mi as HumanizerMeshInstance).material_config
		var overlay_dict = {&'albedo': bp.textures[texture]}
		if mi.get_surface_override_material(0).normal_texture != null:
			overlay_dict[&'normal'] = mi.get_surface_override_material(0).normal_texture.resource_path
		if mi.get_surface_override_material(0).ao_texture != null:
			overlay_dict[&'ao'] = mi.get_surface_override_material(0).ao_texture.resource_path
		mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	else:
		var mat: BaseMaterial3D = mi.get_surface_override_material(0)
		mat.albedo_texture = load(bp.textures[texture])
	if bp.slot in [&'LeftEye', &'RightEye', &'Eyes']:
		#if get_tree() != null:
		#	await get_tree().process_frame
		mi.material_config.overlays[1].color = eye_color
	if bp.slot in [&'RightEyebrow', &'LeftEyebrow', &'Eyebrows', &'Hair']:
		#if get_tree() != null:
		#	await get_tree().process_frame
		mi.get_surface_override_material(0).albedo_color = hair_color
	notify_property_list_changed()

func set_clothes_material(cl_name: String, texture: String) -> void:
	#print('setting texture ' + texture + ' on ' + cl_name)
	var cl: HumanClothes = HumanizerRegistry.clothes[cl_name]
	var mi: MeshInstance3D = get_node(cl_name)

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
			if cl != other:
				var other_mat: BaseMaterial3D = get_node(other.resource_name).get_surface_override_material(0)
				var this_mat: BaseMaterial3D = mi.get_surface_override_material(0)
				if other_mat.resource_path == this_mat.resource_path:
					human_config.clothes_materials[other.resource_name] = texture
					notify_property_list_changed()
	human_config.clothes_materials[cl_name] = texture

func setup_overlay_material(asset: HumanAsset, mi: MeshInstance3D) -> void:
	mi.set_script(load("res://addons/humanizer/scripts/assets/humanizer_mesh_instance.gd"))
	mi.material_config = HumanizerMaterial.new()
	mi.initialize()
	#if get_tree() != null:
	#	await get_tree().process_frame
	var mat_config = mi.material_config as HumanizerMaterial
	var overlay_dict = {'albedo': asset.textures.values()[0]}
	if mi.get_surface_override_material(0).normal_texture != null:
		overlay_dict['normal'] = mi.get_surface_override_material(0).normal_texture.resource_path
	if mi.get_surface_override_material(0).ao_texture != null:
		overlay_dict['ao'] = mi.get_surface_override_material(0).ao_texture.resource_path
	mat_config.set_base_textures(HumanizerOverlay.from_dict(overlay_dict))
	mat_config.add_overlay(asset.default_overlay)

func get_helper_vertex_position(mh_id:int):
	return _helper_vertex[mh_id]

#### Animation ####
func set_rig(rig_name: String, basemesh: ArrayMesh = null) -> void:
	# Delete existing skeleton
	for child in get_children():
		if child is Skeleton3D:
			_delete_child_node(child)
	if rig_name == '':
		return
	if baked:
		printerr('Cannot change rig on baked mesh.  Reset the character.')
		return
	
	if basemesh == null:
		basemesh = load('res://addons/humanizer/data/resources/base_human.res')
	var retargeted: bool = rig_name.ends_with('-RETARGETED')
	var rig: HumanizerRig = HumanizerRegistry.rigs[rig_name.split('-')[0]]
	human_config.rig = rig_name
	skeleton = rig.load_skeleton()  # Json file needs base skeleton names
	var skinned_mesh: ArrayMesh = MeshOperations.skin_mesh(rig, skeleton, basemesh)

	# Set rig in scene
	if retargeted:
		skeleton = rig.load_retargeted_skeleton()
	_add_child_node(skeleton)
	skeleton.unique_name_in_owner = true
	_reset_animator()
	# Set new mesh
	var mat = body_mesh.get_surface_override_material(0)
	_set_body_mesh(skinned_mesh)
	body_mesh.set_surface_override_material(0, mat)
	body_mesh.skeleton = &'../' + skeleton.name
	adjust_skeleton()
	set_shapekeys(human_config.shapekeys)
	for cl in human_config.clothes:
		_add_bone_weights(cl)
	for bp in human_config.body_parts.values():
		_add_bone_weights(bp)

func adjust_skeleton() -> void:
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	var rig = human_config.rig.split('-')[0]
	var skeleton_config = HumanizerUtils.read_json(HumanizerRegistry.rigs[rig].config_json_path)
	var offset = max(_helper_vertex[feet_ids[0]].y, _helper_vertex[feet_ids[1]].y)
	var _foot_offset = Vector3.UP * offset
	
	for bone_id in skeleton.get_bone_count():
		var bone_data = skeleton_config[bone_id]
		var bone_pos = Vector3.ZERO
		for vid in bone_data.head.vertex_indices:
			bone_pos += _helper_vertex[int(vid)]
		bone_pos /= bone_data.head.vertex_indices.size()
		if skeleton.get_bone_name(bone_id) != 'Root':
			bone_pos -= _foot_offset
		else:
			bone_pos *= 0  # Root should always be at origin
		var parent_id = skeleton.get_bone_parent(bone_id)
		if not parent_id == -1:
			var parent_xform = skeleton.get_bone_global_pose(parent_id)
			bone_pos = bone_pos * parent_xform
		skeleton.set_bone_pose_position(bone_id,bone_pos)
		skeleton.set_bone_rest(bone_id,skeleton.get_bone_pose(bone_id))
	skeleton.reset_bone_poses()
	for child in get_children():
		if child is MeshInstance3D:
			child.skin = skeleton.create_skin_from_rest_transforms()
	
	skeleton.motion_scale = _base_motion_scale * (_helper_vertex[hips_id].y - _foot_offset.y) / _base_hips_height
	#print('Fit skeleton to mesh')

func _add_bone_weights(asset: HumanAsset) -> void:
	var mi: MeshInstance3D = get_node_or_null(asset.resource_name)
	if mi == null:
		return
		
	var rig = human_config.rig.split('-')[0]
	var bone_weights = HumanizerUtils.read_json(HumanizerRegistry.rigs[rig].bone_weights_json_path)
	var bone_count = 8
	var mhclo: MHCLO = load(asset.mhclo_path) 
	var mh2gd_index = mhclo.mh2gd_index
	var mesh: ArrayMesh

	mesh = mi.mesh as ArrayMesh
	var new_sf_arrays = mesh.surface_get_arrays(0)
	
	new_sf_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	new_sf_arrays[Mesh.ARRAY_BONES].resize(bone_count * new_sf_arrays[Mesh.ARRAY_VERTEX].size())
	new_sf_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	new_sf_arrays[Mesh.ARRAY_WEIGHTS].resize(bone_count * new_sf_arrays[Mesh.ARRAY_VERTEX].size())

	for mh_id in mhclo.vertex_data.size():
		var bones = []
		var weights = []
		var v_data = mhclo.vertex_data[mh_id]
		if v_data.format == 'single':
			var id = v_data.vertex[0]
			bones = bone_weights.bones[id]
			weights = bone_weights.weights[id]
		else:
			for i in 3:
				var v_id = v_data.vertex[i]
				var v_weight = v_data.weight[i]
				var vb_id = bone_weights.bones[v_id]
				var vb_weights = bone_weights.weights[v_id]
				for j in vb_weights.size():
					var l_weight = vb_weights[j]
					if not l_weight == 0:
						var l_bone = vb_id[j]
						l_weight *= v_weight
						if l_bone in bones:
							var l_id = bones.find(l_bone)
							weights[l_id] += l_weight
						else:
							bones.append(l_bone)
							weights.append(l_weight)
							
		for weight_id in range(weights.size()-1,-1,-1):
			if v_data.format == "triangle":
				weights[weight_id] /= (v_data.weight[0] + v_data.weight[1] + v_data.weight[2])
			if weights[weight_id] > 1:
				weights[weight_id] = 1
			elif weights[weight_id] < 0.001: #small weights and NEGATIVE
				weights.remove_at(weight_id)
				bones.remove_at(weight_id)
		
		#normalize		
		var total_weight = 0
		for weight in weights:
			total_weight += weight
		var ratio = 1/total_weight
		for weight_id in weights.size():
			weights[weight_id] *= ratio
						
		while bones.size() < bone_count:
			bones.append(0)
			weights.append(0)
		
		if mh_id < mh2gd_index.size():
			var g_id_array = mh2gd_index[mh_id]
			for g_id in g_id_array:
				for i in bone_count:
					new_sf_arrays[Mesh.ARRAY_BONES][g_id * bone_count + i] = bones[i]
					new_sf_arrays[Mesh.ARRAY_WEIGHTS][g_id * bone_count + i] = weights[i]
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
	if _animator_scene != null:
		animator = _animator_scene.instantiate()
		_add_child_node(animator)
		animator.active = true
		set_editable_instance(animator, true)
		var root_bone = skeleton.get_bone_name(0)
		if animator is AnimationTree and root_bone in ['Root']:
			animator.root_motion_track = &'../' + skeleton.name + ":" + root_bone

#### Additional Components ####
func set_component_state(enabled: bool, component: String) -> void:
	if enabled:
		if not human_config.components.has(component):
			human_config.components.append(component)
		if component == &'main_collider':
			_add_main_collider()
		elif component == &'ragdoll':
			_add_physical_skeleton()
	else:
		human_config.components.erase(component)
		if component == &'main_collider':
			_delete_child_node(main_collider)
			main_collider = null
		elif component == &'ragdoll':
			skeleton.physical_bones_stop_simulation()
			for child in skeleton.get_children():
				_delete_child_node(child)

func _add_main_collider() -> void:
	if get_node_or_null('MainCollider') != null:
		main_collider = $MainCollider
	else:
		main_collider = CollisionShape3D.new()
		main_collider.shape = CapsuleShape3D.new()
		main_collider.name = &'MainCollider'
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
