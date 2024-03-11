@tool
class_name Humanizer
extends Node3D

const humanizer_mesh_instance = preload('res://addons/humanizer/scripts/assets/humanizer_mesh_instance.gd')
const _BASE_MESH_NAME: String = 'Human'
## Vertex ids
const shoulder_id: int = 16951 
const waist_id: int = 17346
const hips_id: int = 18127

var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var main_collider: CollisionShape3D
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
var baked := false
var scene_loaded: bool = false
var _shapekey_data: Dictionary = {}
var shapekey_data: Dictionary:
	get:
		if _shapekey_data.size() == 0:
			_shapekey_data = HumanizerUtils.get_shapekey_data()
		return _shapekey_data
var _helper_vertex: PackedVector3Array = []

@export_color_no_alpha var skin_color: Color = Color.WHITE:
	set(value):
		skin_color = value
		if scene_loaded and body_mesh.material_config.overlays.size() == 0:
			return
		body_mesh.material_config.overlays[0].color = skin_color
		body_mesh.material_config.update_material()
@export_color_no_alpha var hair_color: Color = Color.WEB_MAROON:
	set(value):
		hair_color = value
		if human_config == null:
			return
		var slots: Array = [&'RightEyebrow', &'LeftEyebrow', &'Eyebrows', &'Hair']
		for slot in slots:
			if not human_config.body_parts.has(slot):
				return
			print(slot)
			var mesh = get_node(human_config.body_parts[slot].resource_name)
			(mesh as MeshInstance3D).get_surface_override_material(0).albedo_color = hair_color
@export_color_no_alpha var eye_color: Color = Color.SKY_BLUE:
	set(value):
		eye_color = value
		if human_config == null:
			return
		var slots: Array = [&'RightEye', &'LeftEye', &'Eyes']
		for slot in slots:
			if not human_config.body_parts.has(slot):
				return
			var mesh = get_node(human_config.body_parts[slot].resource_name)
			mesh.material_config.overlays[1].color = eye_color
@export var _bake_meshes: Array[NodePath]:
	set(value):
		for el in value:
			if el == ^'':
				continue
			if not get_node(el) is MeshInstance3D:
				printerr("Can only bakek MeshInstance3D nodes")
				return
		_bake_meshes = value

@export_category("Humanizer Node Settings")
@export var human_config: HumanConfig:
	set(value):
		human_config = value
		if human_config.rig == '':
			human_config.rig = HumanizerConfig.default_skeleton
		# This gets set before _ready causing issues so make sure we're loaded
		if scene_loaded:
			load_human()

@export_group('Node Overrides')
## The scene to be added as an animator for the character
@export var _animator: PackedScene:
	set(value):
		_animator = value
		_reset_animator()
## THe renderingn layers for the human's 3d mesh instances
@export_flags_3d_render var _render_layers:
	set(value):
		_render_layers = value
		for child in get_children():
			if child is MeshInstance3D:
				child.layers = _render_layers
## The physics layers the character collider resides in
@export_flags_3d_physics var _character_layers:
	set(value):
		_character_layers = value
		if main_collider != null:
			pass
## The physics layers the character collider collides with
@export_flags_3d_physics var _character_mask:
	set(value):
		_character_mask = value
		if main_collider != null:
			pass
## The physics layers the physical bones reside in
@export_flags_3d_physics var _ragdoll_layers:
	set(value):
		_ragdoll_layers = value
## The physics layers the physical bones collide with
@export_flags_3d_physics var _ragdoll_mask:
	set(value):
		_ragdoll_mask = value


signal on_bake_complete
signal on_human_reset
signal on_clothes_removed(clothes: HumanClothes)


func _ready() -> void:
	scene_loaded = true
	load_human()
	skeleton.physical_bones_start_simulation()

####  HumanConfig Resource Management ####
func _add_child_node(node: Node) -> void:
	add_child(node)
	node.owner = self
	if node is MeshInstance3D:
		var render_layers = _render_layers
		if render_layers == null:
			render_layers = HumanizerConfig.default_character_render_layers
		(node as MeshInstance3D).layers = render_layers

func _delete_child_node(node: Node) -> void:
	remove_child(node)
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
	if human_config == null:
		reset_human()
	else:
		var mesh_path := human_config.resource_path.get_base_dir().path_join('mesh.res')
		if FileAccess.file_exists(mesh_path):
			baked = true
			set_rig(human_config.rig, load(mesh_path))
			name = human_config.resource_path.get_file().replace('.res', '')
		else:
			baked = false
			reset_human(false)
			deserialize()
		notify_property_list_changed()

func reset_human(reset_config: bool = true) -> void:
	baked = false
	_helper_vertex = shapekey_data.basis.duplicate(true)
	for child in get_children():
		if child is MeshInstance3D:
			_delete_child_node(child)
	_set_body_mesh(load("res://addons/humanizer/data/resources/base_human.res"))
	_delete_child_by_name('MainCollider')
	main_collider = null
	if reset_config:
		human_config = HumanConfig.new()
	on_human_reset.emit()
	notify_property_list_changed()
	print('Reset human')

func deserialize() -> void:
	set_shapekeys(human_config.shapekeys, true)
	set_rig(human_config.rig, body_mesh.mesh)
	for slot in human_config.body_parts:
		var bp = human_config.body_parts[slot]
		var mat = human_config.body_part_materials[slot]
		set_body_part(bp)
		set_body_part_material(bp.slot, mat)
	for clothes in human_config.clothes:
		apply_clothes(clothes)
		set_clothes_material(clothes.resource_name, human_config.clothes_materials[clothes.resource_name])
	if human_config.body_part_materials.has(&'skin'):
		set_skin_texture(human_config.body_part_materials[&'skin'])
	for component in human_config.components:
		set_component_state(true, component)
	
func serialize(name: String) -> void:
	## Save to files for easy load later
	var path = HumanizerConfig.human_export_path
	if path == null:
		path = 'res://data/humans'
	path = path.path_join(name)
	if DirAccess.dir_exists_absolute(path):
		printerr('A human with this name has already been saved.  Use a different name.')
		return
	DirAccess.make_dir_recursive_absolute(path)
	if not baked:
		bake()
	ResourceSaver.save(human_config, path.path_join(name + '.res'))
	human_config.take_over_path(path.path_join(name + '.res'))
	ResourceSaver.save(body_mesh.mesh, path.path_join('mesh.res'))
	print('Saved human to : ' + path)
	notify_property_list_changed()

func bake() -> void:
	if baked:
		printerr('Already baked.  Reset human to start over or load another config.')
		return
	_combine_meshes()
	adjust_skeleton()
	baked = true
	on_bake_complete.emit()
	notify_property_list_changed()

func _combine_meshes() -> void:
	var new_mesh = ArrayMesh.new()
	new_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for shape_id in body_mesh.get_blend_shape_count():
		var shape_name = body_mesh.mesh.get_blend_shape_name(shape_id)
		new_mesh.add_blend_shape(shape_name)
	var i = 0
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var surface_arrays = child.mesh.surface_get_arrays(0)
		var blend_shape_arrays = child.mesh.surface_get_blend_shape_arrays(0)
		var lods := {}
		var format = child.mesh.surface_get_format(0)
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays, blend_shape_arrays, lods, format)
		new_mesh.surface_set_name(i, child.name)
		new_mesh.surface_set_material(i,  child.get_surface_override_material(0))
		i += 1
		child.queue_free()
	_set_body_mesh(new_mesh)

#### Mesh Management ####
func _set_body_mesh(meshdata: ArrayMesh) -> void:
	_delete_child_by_name(_BASE_MESH_NAME)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = _BASE_MESH_NAME
	body_mesh.mesh = meshdata
	body_mesh.set_script(humanizer_mesh_instance)
	_add_child_node(body_mesh)

func set_body_part(bp: HumanBodyPart) -> void:
	if human_config.body_parts.has(bp.slot):
		var current = human_config.body_parts[bp.slot]
		_delete_child_by_name(current.resource_name)
	human_config.body_parts[bp.slot] = bp
	var bp_scene = load(bp.scene_path).instantiate() as MeshInstance3D
	_add_child_node(bp_scene)
	_add_bone_weights(bp)
	set_shapekeys(human_config.shapekeys)
	if bp.slot in [&'RightEye', &'LeftEye', &'Eyes']:
		await get_tree().process_frame
		bp_scene.material_config.overlays[1].color = eye_color
	elif bp.slot in [&'RightEyebrow', &'LeftEyebrow', &'Eyebrows', &'Hair']:
		(bp_scene as MeshInstance3D).get_surface_override_material(0).albedo_color = hair_color
	#notify_property_list_changed()

func apply_clothes(cl: HumanClothes) -> void:
	for wearing in human_config.clothes:
		for slot in cl.slots:
			if slot in wearing.slots:
				remove_clothes(wearing)
	print('applying ' + cl.resource_name + ' clothes')
	if not cl in human_config.clothes:
		human_config.clothes.append(cl)
	var mi = load(cl.scene_path).instantiate()
	_add_child_node(mi)
	_add_bone_weights(cl)
	set_shapekeys(human_config.shapekeys)

func clear_body_part(clear_slot: String) -> void:
	for slot in human_config.body_parts:
		if slot == clear_slot:
			var res = human_config.body_parts[clear_slot]
			_delete_child_by_name(res.resource_name)
			human_config.body_parts.erase(clear_slot)
			return

func clear_clothes_in_slot(slot: String) -> void:
	for cl in human_config.clothes:
		if slot in cl.slots:
			print('clearing ' + cl.resource_name + ' clothes')
			remove_clothes(cl)

func remove_clothes(cl: HumanClothes) -> void:
	for child in get_children():
		if child.name == cl.resource_name:
			#print('removing ' + cl.resource_name + ' clothes')
			_delete_child_node(child)
			on_clothes_removed.emit(cl)
	human_config.clothes.erase(cl)

func update_hide_vertices() -> void:
	var skin_mat = body_mesh.get_surface_override_material(0)
	var arrays: Array = (body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var delete_verts_gd := []
	delete_verts_gd.resize(arrays[Mesh.ARRAY_VERTEX].size())
	var delete_verts_mh := []
	delete_verts_mh.resize(_helper_vertex.size())
	var remap_verts_gd := [] #old to new
	remap_verts_gd.resize(arrays[Mesh.ARRAY_VERTEX].size())
	remap_verts_gd.fill(-1)
	
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var res: HumanAsset = _get_asset_by_name(child.name)
		if res != null:
			for entry in load(res.mhclo_path).delete_vertices:
				if entry.size() == 1:
					delete_verts_mh[entry[0]] = true
				else:
					for mh_id in range(entry[0], entry[1] + 1):
						delete_verts_mh[mh_id] = true
			
	for gd_id in arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		if delete_verts_mh[mh_id]:
			delete_verts_gd[gd_id] = true
	
	var new_gd_id = 0
	for old_gd_id in arrays[Mesh.ARRAY_VERTEX].size():
		if not delete_verts_gd[old_gd_id]:
			remap_verts_gd[old_gd_id] = new_gd_id
			new_gd_id += 1
	
	var new_mesh = ArrayMesh.new()
	var new_arrays := []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	new_arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	new_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	new_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	var lods := {}
	var fmt = body_mesh.mesh.surface_get_format(0)
	for gd_id in delete_verts_gd.size():
		if not delete_verts_gd[gd_id]:
			new_arrays[Mesh.ARRAY_VERTEX].append(arrays[Mesh.ARRAY_VERTEX][gd_id])
			new_arrays[Mesh.ARRAY_CUSTOM0].append(arrays[Mesh.ARRAY_CUSTOM0][gd_id])
			new_arrays[Mesh.ARRAY_TEX_UV].append(arrays[Mesh.ARRAY_TEX_UV][gd_id])
	for i in arrays[Mesh.ARRAY_INDEX].size()/3:
		var slice = arrays[Mesh.ARRAY_INDEX].slice(i*3,(i+1)*3)
		if delete_verts_gd[slice[0]] or delete_verts_gd[slice[1]] or delete_verts_gd[slice[2]]:
			continue
		slice = [remap_verts_gd[slice[0]], remap_verts_gd[slice[1]], remap_verts_gd[slice[2]]]
		new_arrays[Mesh.ARRAY_INDEX].append_array(slice)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays, [], lods, fmt)
	new_mesh = MeshOperations.generate_normals_and_tangents(new_mesh)
	_set_body_mesh(new_mesh)
	body_mesh.set_surface_override_material(0, skin_mat)

func set_shapekeys(shapekeys: Dictionary, override_zero: bool = false):
	var prev_sk = human_config.shapekeys.duplicate()
	if override_zero:
		for sk in prev_sk:
			prev_sk[sk] = 0

	for sk in shapekeys:
		var prev_val: float = prev_sk.get(sk, 0)
		if prev_val == shapekeys[sk]:
			continue
		for mh_id in shapekey_data.shapekeys[sk]:
			_helper_vertex[mh_id] += shapekey_data.shapekeys[sk][mh_id] * (shapekeys[sk] - prev_val)
				
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mesh: ArrayMesh = child.mesh

		var res: HumanAsset = _get_asset_by_name(child.name)
		if res != null:   # Body parts/clothes
			var mhclo: MHCLO = load(res.mhclo_path)
			var new_mesh = MeshOperations.build_fitted_mesh(mesh, _helper_vertex, mhclo)
			child.mesh = new_mesh
		else:             # Base mesh
			if child.name != _BASE_MESH_NAME:
				printerr('Failed to match asset resource for mesh ' + child.name + ' which is not the base mesh.')
				return
			var surf_arrays = (mesh as ArrayMesh).surface_get_arrays(0)
			var fmt = mesh.surface_get_format(0)
			var lods = {}
			var vtx_arrays = surf_arrays[Mesh.ARRAY_VERTEX]
			surf_arrays[Mesh.ARRAY_VERTEX] = _helper_vertex.slice(0, vtx_arrays.size())
			for gd_id in surf_arrays[Mesh.ARRAY_VERTEX].size():
				var mh_id = surf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
				surf_arrays[Mesh.ARRAY_VERTEX][gd_id] = _helper_vertex[mh_id]
			mesh.clear_surfaces()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf_arrays, [], lods, fmt)
	
	for sk in shapekeys:
		human_config.shapekeys[sk] = shapekeys[sk]
	if main_collider != null:
		_adjust_main_collider()

#region Materials
func set_skin_texture(name: String) -> void:
	var base_texture: String
	if not HumanizerRegistry.skin_textures.has(name):
		human_config.body_part_materials['skin'] = ''
	else:
		human_config.body_part_materials['skin'] = name
		base_texture = HumanizerRegistry.skin_textures[name].albedo
	body_mesh.material_config.set_base_textures(HumanizerOverlay.from_dict({'name': name, 'albedo': base_texture, 'color': skin_color}))
	body_mesh.update_material()

func set_body_part_material(set_slot: String, texture: String) -> void:
	print('setting material ' + texture + ' on ' + set_slot)
	var bp = human_config.body_parts[set_slot]
	human_config.body_part_materials[set_slot] = texture
	var mesh = get_node(bp.resource_name)
	if mesh is HumanizerMeshInstance:
		var base = mesh.material_config.overlays[0]
		base.albedo_texture_path = bp.textures[texture]
		mesh.material_config.set_base_textures(base)
	else:
		var mat: BaseMaterial3D = (mesh as MeshInstance3D).get_surface_override_material(0)
		mat.albedo_texture = load(bp.textures[texture])

func set_clothes_material(cl_name: String, texture: String) -> void:
	print('setting material ' + texture + ' on ' + cl_name)
	var cl: HumanClothes = HumanizerRegistry.clothes[cl_name]
	for child in get_children():
		if child.name == name:
			var base = child.material_config.overlays[0]
			base.albedo_texture_path = cl.textures[texture]
			child.material_config.set_base_textures(base)
#endregion

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

	# Load bone and weight arrays for base mesh
	var mesh_arrays = basemesh.surface_get_arrays(0)
	var lods := {}
	var flags := basemesh.surface_get_format(0)
	var weights = rig.load_bone_weights()
	var helper_mesh = load("res://addons/humanizer/data/resources/base_helpers.res")
	var mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(helper_mesh)
	var mh_bone_array = []
	var mh_weight_array = []
	var len = mesh_arrays[Mesh.ARRAY_VERTEX].size()
	mh_bone_array.resize(len)
	mh_weight_array.resize(len)
	# Read mh skeleton weights
	for bone_name in weights:
		var bone_id = skeleton.find_bone(bone_name)
		for bw_pair in weights[bone_name]:
			var mh_id = bw_pair[0]
			if mh_id >= len:  # Helper verts
				continue
			var weight = bw_pair[1]
			if mh_bone_array[mh_id] == null:
				mh_bone_array[mh_id] = PackedInt32Array()
				mh_weight_array[mh_id] = PackedFloat32Array()
			mh_bone_array[mh_id].append(bone_id)
			mh_weight_array[mh_id].append(weight)
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
	mesh_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	mesh_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	for gd_id in mesh_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = mesh_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		mesh_arrays[Mesh.ARRAY_BONES].append_array(mh_bone_array[mh_id])
		mesh_arrays[Mesh.ARRAY_WEIGHTS].append_array(mh_weight_array[mh_id])
	# Build new mesh
	var skinned_mesh = ArrayMesh.new()
	skinned_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for bs in basemesh.get_blend_shape_count():
		skinned_mesh.add_blend_shape(basemesh.get_blend_shape_name(bs))
	skinned_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays, [], lods, flags)
	
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
	body_mesh.skeleton = skeleton.get_path()

	adjust_skeleton()
	set_shapekeys(human_config.shapekeys)
	
func _add_bone_weights(asset: HumanAsset) -> void:
	var rig = human_config.rig.split('-')[0]
	var bone_weights = HumanizerUtils.read_json(HumanizerRegistry.rigs[rig].bone_weights_json_path)
	var bone_count = bone_weights.bones[0].size()
	var mhclo: MHCLO = load(asset.mhclo_path) 
	var mh2gd_index = mhclo.mh2gd_index
	var mesh: ArrayMesh
	var mi: MeshInstance3D
	for child in get_children():
		if child is MeshInstance3D and child.name == asset.resource_name:
			mi = child
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
				for j in bone_count:
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
						
		# only 4 bone weights, this may cause problems later
		# also, should probably normalize weights array, but tested weights were close enough to 1				
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
	mi.skeleton = skeleton.get_path()
	mi.skin = skeleton.create_skin_from_rest_transforms()

func adjust_skeleton() -> void:
	var shapekey_data = HumanizerUtils.get_shapekey_data()
	skeleton.reset_bone_poses()
	var rig = human_config.rig.split('-')[0]
	var skeleton_config = HumanizerUtils.read_json(HumanizerRegistry.rigs[rig].config_json_path)
	for bone_id in skeleton.get_bone_count():
		var bone_data = skeleton_config[bone_id]
		var bone_pos = Vector3.ZERO
		for vid in bone_data.head.vertex_indices:
			var mh_id = int(vid)
			var coords = shapekey_data.basis[mh_id]
			for sk_name in human_config.shapekeys:
				var sk_value = human_config.shapekeys[sk_name]
				if sk_value != 0:
					if mh_id in shapekey_data.shapekeys[sk_name]:
						coords += sk_value * shapekey_data.shapekeys[sk_name][mh_id]
			bone_pos += coords
		bone_pos /= bone_data.head.vertex_indices.size()

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
	
	skeleton.motion_scale = _base_motion_scale * _helper_vertex[hips_id].y / _base_hips_height
	print('Fit skeleton to mesh')

func _reset_animator() -> void:
	for child in get_children():
		if child is AnimationTree or child is AnimationPlayer:
			_delete_child_node(child)
	var animator: PackedScene = _animator
	if animator == null:
		animator = HumanizerConfig.default_animation_tree
	if animator != null:
		var tree := animator.instantiate() as AnimationTree
		if tree == null:
			printerr('Default animation tree scene does not have an AnimationTree as its root node')
			return
		_add_child_node(tree)
		tree.active = true
		set_editable_instance(tree, true)
		var root_bone = skeleton.get_bone_name(0)
		if root_bone in ['Root']:
			tree.root_motion_track = NodePath(str(skeleton.get_path()) + ":" + root_bone)

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
	var layers = _ragdoll_layers
	var mask = _ragdoll_mask
	if layers == null:
		layers = HumanizerConfig.default_physical_bone_layers
	if mask == null:
		mask = HumanizerConfig.default_physical_bone_mask
	HumanizerPhysicalSkeleton.new(skeleton, _helper_vertex, layers, mask).run()
	skeleton.physical_bones_start_simulation()

func _adjust_main_collider():
	var height = _helper_vertex[14570].y
	main_collider.shape.height = height
	main_collider.position.y = height/2

	var width_ids = [shoulder_id,waist_id,hips_id]
	var max_width = 0
	for mh_id in width_ids:
		var vertex_position = _helper_vertex[mh_id]
		var distance = Vector2(vertex_position.x,vertex_position.z).distance_to(Vector2.ZERO)
		if distance > max_width:
			max_width = distance
	main_collider.shape.radius = max_width * 1.5
