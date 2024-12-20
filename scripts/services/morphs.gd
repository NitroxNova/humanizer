@tool
extends Resource
class_name HumanizerMorphService

static func get_morph_data(humanizer:Humanizer,new_shapekeys:Dictionary,bake_mesh_names:PackedStringArray,mi:):
	var morph_data = {}
	morph_data.bone_positions = {}
	morph_data.motion_scale = {}
	morph_data.collider_shape = {}
	var initial_shapekeys = humanizer.human_config.targets.duplicate(true)
	var bs_arrays = []
	var baked_mesh = ArrayMesh.new()
	baked_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for shape_name in new_shapekeys:
		baked_mesh.add_blend_shape(shape_name)
		var new_bs_array = []
		new_bs_array.resize(Mesh.ARRAY_MAX)
		new_bs_array[Mesh.ARRAY_VERTEX] = PackedVector3Array()
		new_bs_array[Mesh.ARRAY_TANGENT] = PackedFloat32Array()
		new_bs_array[Mesh.ARRAY_NORMAL] = PackedVector3Array()
		humanizer.set_targets(new_shapekeys[shape_name])
		var skeleton = humanizer.get_skeleton()
		morph_data['bone_positions'][shape_name] = []
		for bone in skeleton.get_bone_count():
			morph_data['bone_positions'][shape_name].append(skeleton.get_bone_pose_position(bone))
		morph_data['motion_scale'][shape_name] = skeleton.motion_scale
		if humanizer.human_config.has_component(&'main_collider'):
			var main_collider = humanizer.get_main_collider()
			morph_data['collider_shape'][shape_name] = {&'center': main_collider.position.y, &'radius': main_collider.shape.radius, &'height': main_collider.shape.height}
		for mesh_name in bake_mesh_names:
			var sf_arrays = humanizer.get_mesh(mesh_name).surface_get_arrays(0)
			new_bs_array[Mesh.ARRAY_VERTEX].append_array(sf_arrays[Mesh.ARRAY_VERTEX])
			new_bs_array[Mesh.ARRAY_TANGENT].append_array(sf_arrays[Mesh.ARRAY_TANGENT])
			new_bs_array[Mesh.ARRAY_NORMAL].append_array(sf_arrays[Mesh.ARRAY_NORMAL])
		bs_arrays.append(new_bs_array)
	baked_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mi.mesh.surface_get_arrays(0),bs_arrays)
	baked_mesh.surface_set_material(0,mi.mesh.surface_get_material(0))
	mi.mesh = baked_mesh
	## then need to reset mesh to base shape
	humanizer.set_targets(initial_shapekeys)
	var skeleton = humanizer.get_skeleton()
	morph_data['bone_positions']['basis'] = []
	for bone in skeleton.get_bone_count():
		morph_data['bone_positions']['basis'].append(skeleton.get_bone_pose_position(bone))
	morph_data['motion_scale']['basis'] = skeleton.motion_scale
	if humanizer.human_config.has_component(&'main_collider'):
		var main_collider = humanizer.get_main_collider()
		morph_data['collider_shape']['basis'] = {&'center': main_collider.position.y, &'radius': main_collider.shape.radius, &'height': main_collider.shape.height}
	return morph_data
	
static func prepare_shapekeys_for_baking(human_config: HumanConfig, _new_shapekeys: Dictionary) -> void:
	# Add new shapekeys entries from shapekey components
	if human_config.components.has(&'size_morphs') and human_config.components.has(&'age_morphs'):
		# Use "average" as basis
		human_config.targets['muscle'] = 0.5
		human_config.targets['weight'] = 0.5
		human_config.targets['age'] = 0.25
		for sk in _new_shapekeys:
			_new_shapekeys[sk]['muscle'] = 0.5
			_new_shapekeys[sk]['weight'] = 0.5
			_new_shapekeys[sk]['age'] = 0.25
		var new_sks = _new_shapekeys.duplicate()
		for age in HumanizerMorphs.AGE_KEYS:
			for muscle in HumanizerMorphs.MUSCLE_KEYS:
				for weight in HumanizerMorphs.WEIGHT_KEYS:
					if muscle == 'avgmuscle' and weight == 'avgweight' and age == 'young':
						continue # Basis
					var key = '-'.join([muscle, weight, age])
					var shape = human_config.targets.duplicate(true)
					shape['muscle'] = HumanizerMorphs.MUSCLE_KEYS[muscle]
					shape['weight'] = HumanizerMorphs.WEIGHT_KEYS[weight]
					shape['age'] = HumanizerMorphs.AGE_KEYS[age]
					_new_shapekeys['base-' + key] = shape
					for sk_name in new_sks:
						shape = new_sks[sk_name].duplicate(true)
						shape['muscle'] = HumanizerMorphs.MUSCLE_KEYS[muscle]
						shape['weight'] = HumanizerMorphs.WEIGHT_KEYS[weight]
						shape['age'] = HumanizerMorphs.AGE_KEYS[age]
						_new_shapekeys[sk_name + '-' + key] = shape
	elif human_config.components.has(&'size_morphs'):
		human_config.targets['muscle'] = 0.5
		human_config.targets['weight'] = 0.5
		for sk in _new_shapekeys:
			_new_shapekeys[sk]['muscle'] = 0.5
			_new_shapekeys[sk]['weight'] = 0.5
		var new_sks = _new_shapekeys.duplicate()
		for muscle in HumanizerMorphs.MUSCLE_KEYS:
			for weight in HumanizerMorphs.WEIGHT_KEYS:
				if muscle == 'avgmuscle' and weight == 'avgweight':
					continue # Basis
				var key = '-'.join([muscle, weight])
				var shape = human_config.targets.duplicate(true)
				shape['muscle'] = HumanizerMorphs.MUSCLE_KEYS[muscle]
				shape['weight'] = HumanizerMorphs.WEIGHT_KEYS[weight]
				_new_shapekeys['base-' + key] = shape
				for sk_name in new_sks:
					shape = new_sks[sk_name].duplicate(true)
					shape['muscle'] = HumanizerMorphs.MUSCLE_KEYS[muscle]
					shape['weight'] = HumanizerMorphs.WEIGHT_KEYS[weight]
					_new_shapekeys[sk_name + '-' + key] = shape
	elif human_config.components.has(&'age_morphs'):
		human_config.set_targets({age=.25})
		var base_targets = human_config.targets.duplicate()
		#human_config.targets['age'] = 0.25
		for sk in _new_shapekeys:
			human_config.targets = _new_shapekeys[sk]
			human_config.set_targets({age=.25})
			_new_shapekeys[sk] = human_config.targets.duplicate()
		var new_sks = _new_shapekeys.duplicate()
		for age in HumanizerMorphs.AGE_KEYS:
			if age == 'young':
				continue #already added as basis shapes
			human_config.targets = base_targets.duplicate()
			human_config.set_targets({age=HumanizerMorphs.AGE_KEYS[age]})
			_new_shapekeys['base-' + age] = human_config.targets.duplicate(true)
			for sk_name in new_sks:
				human_config.targets = new_sks[sk_name].duplicate(true)
				human_config.set_targets({age=HumanizerMorphs.AGE_KEYS[age]})
				_new_shapekeys[sk_name + '-' + age] = human_config.targets.duplicate(true)
