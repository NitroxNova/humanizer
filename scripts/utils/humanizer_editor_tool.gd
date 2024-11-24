@tool
class_name HumanizerEditorTool
extends Node3D

## editor tool for creating new humans

var humanizer := Humanizer.new()
var skeleton: Skeleton3D
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

signal done_loading

func _ready() -> void:
	humanizer.material_updated.connect(on_material_updated)
	for child in get_children():
		if child.name.begins_with('Baked-'):
			baked = true
	if not baked:
		load_human()
	scene_loaded = true
	
## For use in character editor scenes where the character should be 
## continuously updated with every change

func on_material_updated(equip):
	#print("material updated " + equip.type)
	if has_node(equip.type): #otherwise it will load with the correct texture
		var equip_node : HumanizerMeshInstance = get_node(equip.type)
		equip_node.set_surface_override_material(0,humanizer.materials[equip.type])
		equip_node.material_config = equip.material_config
		
func reset():
	#print("reseting")
	var new_config = HumanConfig.new()
	new_config.init_macros()
	new_config.rig = HumanizerGlobalConfig.config.default_skeleton
	new_config.add_equipment(HumanizerEquipment.new("DefaultBody"))
	new_config.add_equipment(HumanizerEquipment.new("RightEyeball-LowPoly"))
	new_config.add_equipment(HumanizerEquipment.new("LeftEyeBall-LowPoly"))
	human_config = new_config
	
func set_human_config(config: HumanConfig) -> void:
	human_config = config
	
func set_hair_color(color: Color) -> void:
	humanizer.set_hair_color(color)

func set_eyebrow_color(color: Color) -> void:
	humanizer.set_eyebrow_color(color)

func set_skin_color(color: Color) -> void:
	humanizer.set_skin_color(color)
	
func set_eye_color(color: Color) -> void:
	humanizer.set_eye_color(color)

func set_shapekeys(shapekeys: Dictionary) -> void:
	_set_shapekey_data(shapekeys)
	_fit_all_meshes()
	_adjust_skeleton()

	if main_collider != null:
		_adjust_main_collider()
	
	## HACK shapekeys mess up mesh
	## Face bones mess up the mesh when shapekeys applied.  This fixes it
	if animator != null:
		animator.active = not animator.active
		animator.active = not animator.active


####  HumanConfig Resource and Scene Management ####
func reset_scene() -> void:
	#print("resetting scene")
	if has_node('MorphDriver'):
		_delete_child_node($MorphDriver)
	baked = false
	#if human_config.rig == '':
		#human_config.rig = HumanizerGlobalConfig.config.default_skeleton
	for child in get_children():
		if child is MeshInstance3D or child is Skeleton3D:
			_delete_child_node(child)
	#set_component_state(true, &'main_collider')
	if has_node('Saccades'):
		_delete_child_by_name('Saccades')
	_new_shapekeys = {}
	notify_property_list_changed()

func load_human() -> void:
	#print("loading human")
	baked = false
	humanizer.load_config_async(human_config)
	reset_scene()
	_deserialize()
	notify_property_list_changed()
	done_loading.emit()

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
		root_node.set_script(HumanizerResourceService.load_resource(_character_script))
	elif script != '':
		root_node.set_script(HumanizerResourceService.load_resource(script))
		
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

	if human_config.components.has(&'main_collider') and main_collider != null and not root_node is StaticBody3D:
		var coll = main_collider.duplicate(true)
		root_node.add_child(coll)
		coll.owner = root_node
	if human_config.components.has(&'saccades'):
		var saccades : Node = HumanizerResourceService.load_resource("res://addons/humanizer/scenes/subscenes/saccades.tscn").instantiate()
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
	if FileAccess.file_exists(save_path.path_join('scene_' + human_name + '.tscn')):
		printerr(" Human already exists at " + save_path)
		return
	var scene_root_node = create_human_branch()
	var mi: MeshInstance3D = scene_root_node.get_node('Avatar')
	var scene = PackedScene.new()
	scene.pack(scene_root_node)
	DirAccess.make_dir_recursive_absolute(save_path)
	var config_path = save_path.path_join('config_' + human_name + '.res')
	ResourceSaver.save(human_config, config_path)
	ResourceSaver.save(scene, save_path.path_join('scene_' + human_name + '.tscn'))
	print('Saved human to : ' + save_path)
	HumanizerJobQueue.add_job(HumanizerMeshService.compress_material.bind(mi.mesh))
	print("tesetasetaset")
	
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

func _get_asset_by_name(mesh_name: String) -> HumanizerEquipment:
	var res: HumanizerEquipment = null
	if mesh_name in human_config.equipment:
		res = human_config.equipment[mesh_name]
	return res

func _deserialize() -> void:
	## set rig
	init_rig()

	## Load Assets
	for equip: HumanizerEquipment in human_config.equipment.values():
		init_equipment(equip)

	### Load components
	#for component in human_config.components:
		#if component in [&'root_bone', &'ragdoll']:
			#continue  # These are already set in set_rig
		#set_component_state(true, component)
	pass

#### Mesh Management ####
func add_equipment_type(equip_type:HumanizerEquipmentType)->void:
	#print("adding equipment " + equip_type.resource_name)
	var equip := HumanizerEquipment.new(equip_type.resource_name)
	add_equipment(equip)

func trigger_material_update(equip_type:String):
	humanizer.update_material(equip_type)

func init_equipment(equip: HumanizerEquipment) -> void:
	if baked:
		push_warning("Can't change equipment.  Already baked")
		notify_property_list_changed()
		return
	
	var equip_type = equip.get_type()
	var mesh_inst = HumanizerMeshInstance.new()
	mesh_inst.trigger_material_update.connect(humanizer.update_material)
	mesh_inst.name = equip.type
	mesh_inst.mesh = humanizer.get_mesh(equip.type)
	var sf_material :StandardMaterial3D = humanizer.materials[equip.type]
	sf_material.resource_local_to_scene = true
	mesh_inst.set_surface_override_material(0,sf_material)
	mesh_inst.material_config = equip.material_config
	if human_config.transforms.has(equip_type.resource_name):
		mesh_inst.transform = Transform3D(human_config.transforms[equip.resource_name])
	_add_child_node(mesh_inst)
	
	if equip_type.rigged:
		rebuild_skeleton() #update rig with additional asset bones, and remove any from previous asset
	mesh_inst.skeleton = '../' + skeleton.name
	mesh_inst.skin = skeleton.create_skin_from_rest_transforms()
	notify_property_list_changed()

func add_equipment(equip: HumanizerEquipment) -> void:
	#print("Adding equipment")
	if baked:
		push_warning("Can't change equipment.  Already baked")
		notify_property_list_changed()
		return
	
	var equip_type = equip.get_type()
	for prev_equip in human_config.get_equipment_in_slots(equip_type.slots):
		remove_equipment(prev_equip)
	humanizer.add_equipment(equip)	
	init_equipment(equip)
	
func remove_equipment(equip: HumanizerEquipment) -> void:
	#print("removing equipment")
	if baked:
		push_warning("Can't change equipment.  Already baked")
		notify_property_list_changed()
		return
	var equip_type = equip.get_type()
	_delete_child_by_name(equip_type.resource_name)
	humanizer.remove_equipment(equip)
	if equip_type.rigged:
		set_rig(human_config.rig) #remove bones from previous asset

func remove_equipment_in_slot(slot: String) -> void:
	if baked:
		push_warning("Can't change clothes.  Already baked")
		notify_property_list_changed()
		return
	var equip = human_config.get_equipment_in_slot(slot)
	if equip != null:
		remove_equipment(equip)	

func hide_clothes_vertices():
	if baked:
		push_warning("Can't alter meshes.  Already baked")
		return
	humanizer.hide_clothes_vertices()
	_fit_all_meshes()

func unhide_clothes_vertices() -> void:
	if baked:
		push_warning("Can't alter meshes.  Already baked")
		return
	humanizer.show_clothes_vertices()
	_fit_all_meshes()

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
	var bake_mesh_names = PackedStringArray()
	for node in _bake_meshes:
		bake_mesh_names.append(node.name)
		if not node.transform == Transform3D.IDENTITY:
			human_config.transforms[node.name] = Transform3D(node.transform)
		# if node is HumanizerMeshInstance:
		# 	var mesh_instance := node as HumanizerMeshInstance
		# 	if mesh_instance.material_config != null:
		# 		mesh_instance.material_config.update_material()

	if human_config.components.has(&'size_morphs') or human_config.components.has(&'age_morphs'):
		
		if not baked or bake_in_progress:
			if _new_shapekeys.size() > 1:
				push_error('Age and Size morphs can not be mixed with more than 1 custom shape')
				return
			
			HumanizerMorphService.prepare_shapekeys_for_baking(human_config, _new_shapekeys)
			_set_shapekey_data(human_config.targets.duplicate()) ## To get correct shapes on basis
			_fit_all_meshes()
		
	if atlas_resolution == 0:
		atlas_resolution = HumanizerGlobalConfig.config.atlas_resolution

	var baked_surface :ArrayMesh = humanizer.combine_surfaces_to_mesh(bake_mesh_names, ArrayMesh.new(), atlas_resolution)
	#cant regenerate normals and tangents after baking, because it reorders the vertices, and in some cases resizes, which makes absolutely no sense, but it then breaks the exported morph shapekeys  
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = baked_surface
	mi.name = 'Baked-' + bake_surface_name

	# Add new shapekeys to mesh arrays, collect metadata for skeleton/collider
	if not _new_shapekeys.is_empty():
		morph_data = HumanizerMorphService.get_morph_data(humanizer,_new_shapekeys,bake_mesh_names,mi)
	
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
			morph_driver = HumanizerResourceService.load_resource("res://addons/humanizer/scenes/subscenes/morph_driver.tscn").instantiate()
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

func _fit_all_meshes() -> void:
	for equip in human_config.equipment.values():
		_fit_equipment_mesh(equip)

func _fit_equipment_mesh(equipment: HumanizerEquipment) -> void:
	get_node(equipment.type).mesh = humanizer.get_mesh(equipment.type)
	
func _combine_meshes() -> ArrayMesh:
	var new_mesh = ImporterMesh.new()
	new_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var material: BaseMaterial3D
		if child.get_surface_override_material(0) != null:
			material = child.get_surface_override_material(0)
		else:
			material = child.mesh.surface_get_material(0)
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
	print("Adding shapekey")
	if new_shapekey_name in ['', null]:
		printerr('Invalid shapekey name')
		return
	if _new_shapekeys.has(new_shapekey_name):
		printerr('A new shape with this name already exists')
		return
	_new_shapekeys[new_shapekey_name] = human_config.targets.duplicate(true)
	notify_property_list_changed()

#### Materials ####
	
func set_skin_normal_texture(texture_name: String) -> void:
	if baked:
		printerr('Cannot change skin textures. Alrady baked.')
		notify_property_list_changed()
		return
	#print('setting skin normal texture')
	var body_equip = human_config.get_equipment_in_slot("Body")
	var texture_path = ''
	if texture_name != "None":
		texture_path = HumanizerRegistry.skin_normals[texture_name]
	if body_equip != null:
		body_equip.material_config.overlays[0].normal_texture_path = texture_path
		body_equip.material_config.overlays[0].normal_strength = .2
	body_equip.material_config.update_standard_material_3D(humanizer.materials[body_equip.type])

func set_equipment_texture_by_slot(slot_name:String, texture: String):
	var equip = human_config.get_equipment_in_slot(slot_name)
	if equip != null:
		set_equipment_material(equip,texture)

func set_equipment_texture_by_name(equip_name:String, texture:String):
	if equip_name in human_config.equipment:
		var equip = human_config.equipment[equip_name]
		set_equipment_material(equip,texture)

func set_equipment_material(equip:HumanizerEquipment, texture: String) -> void:
	if baked:
		printerr('Cannot change materials. Already baked.')
		return
	humanizer.set_equipment_material(equip,texture)
	get_node(equip.type).set_surface_override_material(0,humanizer.materials[equip.type])
	notify_property_list_changed()
	
func init_rig() -> void:
	skeleton = humanizer.get_skeleton()
	_add_child_node(skeleton)
	_reset_animator()
	
	if human_config.components.has(&'ragdoll'):
		set_component_state(true, &'ragdoll')
	if human_config.components.has(&'saccades'):
		if human_config.rig != &'default-RETARGETED':
			set_component_state(false, &'saccades')

#### Animation ####
func set_rig(rig_name: String) -> void:
	if baked:
		printerr('Cannot change rig on baked mesh.  Reset the character.')
		return
	
	 #Delete existing skeleton
	for child in get_children():
		if child is Skeleton3D:
			_delete_child_node(child)
	if rig_name == '':
		return
		
	humanizer.set_rig(rig_name)
	init_rig()
	update_bone_weights()

func _adjust_skeleton() -> void:
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	humanizer.adjust_skeleton(skeleton)	
	skeleton.reset_bone_poses()
	update_skeleton_skins()
	
func update_skeleton_skins():
	for child in get_children():
		if child is MeshInstance3D:
			child.skin = skeleton.create_skin_from_rest_transforms()

func update_bone_weights():
	for equip in human_config.equipment.values():
		_add_bone_weights(equip)	
		
func _add_bone_weights(asset: HumanizerEquipment) -> void:
	var equip_type = asset.get_type()
	var mi: MeshInstance3D = get_node(asset.type)
	mi.mesh = humanizer.get_mesh(asset.type)
	mi.skeleton = &'../' + skeleton.name
	mi.skin = skeleton.create_skin_from_rest_transforms()

func _reset_animator() -> void:
	for child in get_children():
		if child is AnimationTree or child is AnimationPlayer:
			_delete_child_node(child)
	animator = humanizer.get_animation_tree()
	if animator == null:
		return
	_add_child_node(animator)
	animator.active = true
	set_editable_instance(animator, true)
	if human_config.rig == 'default-RETARGETED':
		reset_face_pose()

func reset_face_pose() -> void:
	var face_poses: AnimationLibrary = HumanizerResourceService.load_resource("res://addons/humanizer/data/animations/face_poses.glb")
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
				set_rig(human_config.rig)

func _add_main_collider() -> void:
	if has_node('MainCollider'):
		main_collider = $MainCollider
	else:
		main_collider = humanizer.get_main_collider()
		_add_child_node(main_collider)

func _add_physical_skeleton() -> void:
	if skeleton == null:
		return
	animator.active = false
	humanizer.add_ragdoll_colliders(skeleton,_ragdoll_layers,_ragdoll_mask)
	animator.active = true
	skeleton.animate_physical_bones = true

func _adjust_main_collider():
	humanizer.adjust_main_collider(main_collider)

func _add_saccades() -> void:
	if human_config.rig == 'default-RETARGETED':
		var saccades : Node = get_node_or_null('Saccades')
		if saccades != null:
			saccades.human = self
			saccades.enabled = true
			return
		saccades = HumanizerResourceService.load_resource("res://addons/humanizer/scenes/subscenes/saccades.tscn").instantiate()
		saccades.skeleton = skeleton
		_add_child_node(saccades)
		move_child(saccades, 0)
		## So you can see the effect without the animation tree overriding
		animator.active = false 
	else:
		printerr('Saccades are not compatible with the selected rig')
		set_component_state(false, &'saccades')
	
func rebuild_skeleton():
	##TODO figure out why this only works when adding bones and not for removing. something about bone count on the skin
	humanizer.rebuild_skeleton(skeleton)
	skeleton.reset_bone_poses()
	reskin_skeleton_meshes()
	
func reskin_skeleton_meshes():
	for child in get_children():
		if child is MeshInstance3D:
			child.skin = skeleton.create_skin_from_rest_transforms()
	
