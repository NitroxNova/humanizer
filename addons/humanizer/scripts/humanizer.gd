@tool
class_name Humanizer
extends Node3D

const humanizer_mesh_instance = preload('res://addons/humanizer/scripts/assets/humanizer_mesh_instance.gd')
const _BASE_MESH_NAME: String = 'Human'
var skeleton: Skeleton3D
var animator: AnimationPlayer
var mesh: MeshInstance3D
var baked := false
var scene_loaded: bool = false
var _shapekey_data: Dictionary = {}
var shapekey_data: Dictionary:
	get:
		if _shapekey_data.size() == 0:
			_shapekey_data = HumanizerUtils.get_shapekey_data()
		return _shapekey_data
var _helper_vertex: PackedVector3Array = []

@export var human_config: HumanConfig:
	set(value):
		human_config = value
		# This gets set before _ready causing issues so make sure we're loaded
		if scene_loaded:
			load_human()

signal on_bake_complete
signal on_human_reset
signal on_clothes_removed(clothes: HumanClothes)


func _ready() -> void:
	scene_loaded = true
	if baked:
		load_human()
	else:  # Due to godot bug on empty dict 
		reset_human()
	
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
			set_rig(human_config.rig)
			deserialize()
		notify_property_list_changed()

func reset_human() -> void:
	_helper_vertex = shapekey_data.basis.duplicate(true)
	baked = false
	human_config = HumanConfig.new()
	set_rig(HumanizerConfig.default_skeleton)
	on_human_reset.emit()
	notify_property_list_changed()
	print_debug('Reset human')
	
func deserialize() -> void:
	for slot in human_config.body_parts:
		var bp = human_config.body_parts[slot]
		var mat = human_config.body_part_materials[slot]
		set_body_part(bp)
		set_body_part_material(bp.slot, mat)
	for clothes in human_config.clothes:
		apply_clothes(clothes)
		set_clothes_material(clothes.resource_name, human_config.clothes_materials[clothes.resource_name])
	set_shapekeys(human_config.shapekeys)

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
	ResourceSaver.save(mesh.mesh, path.path_join('mesh.res'))
	print_debug('Saved human to : ' + path)
	notify_property_list_changed()

func _set_mesh(meshdata: ArrayMesh) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			remove_child(child)
			child.queue_free()
	mesh = MeshInstance3D.new()
	mesh.name = _BASE_MESH_NAME
	mesh.mesh = meshdata
	mesh.set_script(humanizer_mesh_instance)
	add_child(mesh)
	if Engine.is_editor_hint():
		mesh.owner = EditorInterface.get_edited_scene_root()
	
func set_rig(rig_name: String, basemesh: ArrayMesh = null) -> void:
	# Delete existing skeleton
	for child in get_children():
		if child is Skeleton3D:
			remove_child(child)
			child.queue_free()
			
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
	var blendshapes = basemesh.surface_get_blend_shape_arrays(0)
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
	skinned_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays, blendshapes, lods, flags)
	
	# Set rig in scene
	if retargeted:
		skeleton = rig.load_retargeted_skeleton()
	add_child(skeleton)
	skeleton.unique_name_in_owner = true
	if Engine.is_editor_hint():
		skeleton.owner = EditorInterface.get_edited_scene_root()
	# Set new mesh
	_set_mesh(skinned_mesh)
	mesh.skeleton = skeleton.get_path()
	_reset_animator()
	adjust_skeleton()

func _reset_animator() -> void:
	for child in get_children():
		if child is AnimationPlayer:
			remove_child(child)
			child.queue_free()
	animator = AnimationPlayer.new()
	animator.name = 'AnimationPlayer'
	add_child(animator)
	if Engine.is_editor_hint():
		animator.owner = EditorInterface.get_edited_scene_root()
	if HumanizerConfig.default_animation_tree != null:
		var tree := HumanizerConfig.default_animation_tree.instantiate() as AnimationTree
		if tree == null:
			printerr('Default animation tree scene does not have an animation Tree as its root node')
			return
		add_child(tree)
		if Engine.is_editor_hint():
			tree.owner = EditorInterface.get_edited_scene_root()
		tree.anim_player = animator.get_path()

func set_skin_texture(name: String) -> void:
	if not HumanizerRegistry.skin_textures.has(name):
		human_config.body_part_materials['skin'] = ''
		return
	var base_texture = HumanizerRegistry.skin_textures[name].albedo
	mesh.material_config.set_base_textures(HumanizerOverlay.from_dict({'name': name, 'albedo': base_texture}))

func set_body_part(bp: HumanBodyPart) -> void:
	if human_config.body_parts.has(bp.slot):
		var current = human_config.body_parts[bp.slot]
		_clear_mesh(current.resource_name)
	human_config.body_parts[bp.slot] = bp
	var bp_scene = load(bp.scene_path).instantiate() as MeshInstance3D
	add_child(bp_scene)
	if Engine.is_editor_hint():
		bp_scene.owner = EditorInterface.get_edited_scene_root()
	_add_bone_weights(bp)
	set_shapekeys(human_config.shapekeys)
	#notify_property_list_changed()

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
						
		bones.resize(8)
		weights.resize(8)
		
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

func clear_body_part(clear_slot: String) -> void:
	for slot in human_config.body_parts:
		if slot == clear_slot:
			var res = human_config.body_parts[clear_slot]
			_clear_mesh(res.resource_name)
			human_config.body_parts.erase(clear_slot)
			return

func _clear_mesh(name: String) -> void:
	for child in get_children():
		if child.name == name:
			remove_child(child)
			child.queue_free()
	
func set_body_part_material(set_slot: String, texture: String) -> void:
	#print('setting material ' + texture + ' on ' + set_slot)
	var bp = human_config.body_parts[set_slot]
	human_config.body_part_materials[set_slot] = texture
	for child in get_children():
		if child.name == bp.resource_name:
			var base = child.material_config.overlays[0]
			base.albedo_texture_path = bp.textures[texture]
			child.material_config.set_base_textures(base)

func apply_clothes(cl: HumanClothes) -> void:
	for wearing in human_config.clothes:
		for slot in cl.slots:
			if slot in wearing.slots:
				remove_clothes(wearing)
	print('applying ' + cl.resource_name + ' clothes')
	if not cl in human_config.clothes:
		human_config.clothes.append(cl)
	var mi = load(cl.scene_path).instantiate()
	add_child(mi)
	if Engine.is_editor_hint():
		mi.owner = EditorInterface.get_edited_scene_root()
	_add_bone_weights(cl)
	set_shapekeys(human_config.shapekeys)

func clear_clothes_in_slot(slot: String) -> void:
	for cl in human_config.clothes:
		if slot in cl.slots:
			print('clearing ' + cl.resource_name + ' clothes')
			remove_clothes(cl)
					
func remove_clothes(cl: HumanClothes) -> void:
	for child in get_children():
		if child.name == cl.resource_name:
			#print('removing ' + cl.resource_name + ' clothes')
			remove_child(child)
			child.queue_free()
			on_clothes_removed.emit(cl)
	human_config.clothes.erase(cl)
	
func set_clothes_material(cl_name: String, texture: String) -> void:
	print('setting material ' + texture + ' on ' + cl_name)
	var cl: HumanClothes = HumanizerRegistry.clothes[cl_name]
	for child in get_children():
		if child.name == name:
			var base = child.material_config.overlays[0]
			base.albedo_texture_path = cl.textures[texture]
			child.material_config.set_base_textures(base)

func _get_asset(mesh_name: String) -> HumanAsset:
	var res: HumanAsset = null
	for slot in human_config.body_parts:
		if human_config.body_parts[slot].resource_name == mesh_name:
			res = human_config.body_parts[slot] as HumanBodyPart
	if res == null:
		for cl in human_config.clothes:
			if cl.resource_name == mesh_name:
				res = cl as HumanClothes
	return res

func set_shapekeys(shapekeys: Dictionary):
	var prev_sk = human_config.shapekeys
	if _helper_vertex.size() == 0:
		_helper_vertex = shapekey_data.basis.duplicate(true)
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

		var res: HumanAsset = _get_asset(child.name)
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
	print('Fit skeleton to mesh')

func bake() -> void:
	if baked:
		printerr('Already baked.  Reset human to start over or load another config.')
		return
	_combine_meshes()
	adjust_skeleton()
	_bake_shapekeys()
	baked = true
	on_bake_complete.emit()
	notify_property_list_changed()
	
func _combine_meshes() -> void:
	var new_mesh = ArrayMesh.new()
	new_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for shape_id in mesh.get_blend_shape_count():
		var shape_name = mesh.mesh.get_blend_shape_name(shape_id)
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
	_set_mesh(new_mesh)
	set_shapekeys(human_config.shapekeys)
	
func _bake_shapekeys() -> void:
	var newmesh = ArrayMesh.new()
	newmesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	
	for surface in mesh.mesh.get_surface_count():
		var meshdata = mesh.mesh.surface_get_arrays(surface)
		var newarrays = meshdata.duplicate(true)
		var blendarrays = mesh.mesh.surface_get_blend_shape_arrays(surface)

		for sk in mesh.get_blend_shape_count():
			var value = mesh.get_blend_shape_value(sk)
			if value == 0:
				continue
			for vtx in meshdata[Mesh.ARRAY_VERTEX].size():
				newarrays[Mesh.ARRAY_VERTEX][vtx] += value * (blendarrays[sk][Mesh.ARRAY_VERTEX][vtx] - meshdata[Mesh.ARRAY_VERTEX][vtx])
			for vtx in meshdata[Mesh.ARRAY_NORMAL].size():
				newarrays[Mesh.ARRAY_NORMAL][vtx] += value * (blendarrays[sk][Mesh.ARRAY_NORMAL][vtx] - meshdata[Mesh.ARRAY_NORMAL][vtx])
			for vtx in meshdata[Mesh.ARRAY_TANGENT].size():
				newarrays[Mesh.ARRAY_TANGENT][vtx] += value * (blendarrays[sk][Mesh.ARRAY_TANGENT][vtx] - meshdata[Mesh.ARRAY_TANGENT][vtx])
	
		newmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, newarrays)
		newmesh.surface_set_name(surface, mesh.mesh.surface_get_name(surface))
		newmesh.surface_set_material(surface, mesh.mesh.surface_get_material(surface))
	
	_set_mesh(newmesh)
