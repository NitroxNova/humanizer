@tool
extends Resource
class_name HumanizerTargetService

static var cache = {}
static var data: HumanizerTargetData #loaded in the humanizer global
static var basis : PackedVector3Array

static func exit():
	# todo mutex
	cache.clear()
	HumanizerLogger.debug("target service shutdown")

static func load_data():
	data = load("res://humanizer/target/base_targets.res")
	var basis_file = FileAccess.open("res://addons/humanizer/data/resources/basis.data",FileAccess.READ)
	basis = basis_file.get_var()

static func init_helper_vertex(target_data = null) -> PackedVector3Array:
	var helper_vertex = basis.duplicate()

	HumanizerLogger.profile("init_helper_vertex", func():
		if target_data != null:
			#var hash = hash([data.basis, target_data])
			#if cache.has(hash):
				#return cache[hash]
			set_targets_raw(target_data, helper_vertex) # took 578ms to init_helper_vertex 703 19158
			#cache[hash] = helper_vertex
	)

	return helper_vertex

static func set_targets(new_targets: Dictionary, current_targets: Dictionary, helper_vertex: PackedVector3Array):
	var macros = {}
	for target_name in new_targets.keys():
		if target_name in HumanizerMacroService.macro_options or target_name in HumanizerMacroService.race_options:
			macros[target_name] = new_targets[target_name]
			new_targets.erase(target_name)
	if not macros.is_empty():
		HumanizerMacroService.set_macros(macros, current_targets, helper_vertex)
	set_targets_raw(new_targets, helper_vertex, current_targets)

static func set_targets_raw(new_targets: Dictionary, helper_vertex: PackedVector3Array, current_targets = null):

	# this branch duplicates the code but the top one is more optimized for the critical path
	# todo move this loop to a c++ module and optimize it
	if current_targets == null:
		for target_name in new_targets:
			if target_name in data.names:
				var offset = data.names[target_name]
				var range = range(offset[0], offset[1])
				for ref_id in range:
					var mh_id = data.index[ref_id]
					var coords = data.coords[ref_id]
					var prev_value = 0
					helper_vertex[mh_id] += coords * (new_targets[target_name] - prev_value)
	else:
		for target_name in new_targets:
			if target_name in data.names:
				var offset = data.names[target_name]
				for ref_id in range(offset[0], offset[1]):
					var mh_id = data.index[ref_id]
					var coords = data.coords[ref_id]
					var prev_value = 0
					if current_targets != null:
						prev_value = current_targets.get(target_name, 0)
					helper_vertex[mh_id] += coords * (new_targets[target_name] - prev_value)
				if current_targets != null:
					if new_targets[target_name] == 0:
						current_targets.erase(target_name)
					else:
						current_targets[target_name] = new_targets[target_name]

	var foot_offset = HumanizerBodyService.get_foot_offset(helper_vertex)
	if foot_offset != 0:
		for mh_id in helper_vertex.size():
			helper_vertex[mh_id].y -= foot_offset

static func get_shapekey_categories() -> Dictionary:
	var categories := {
		'Macro': [],
		'Race': [],
		'Body': [],
		'Head': [],
		'Eyes': [],
		'Mouth': [],
		'Nose': [],
		'Ears': [],
		'Face': [],
		'Neck': [],
		'Chest': [],
		'Breasts': [],
		'Hips': [],
		'Arms': [],
		'Legs': [],
		'Misc': [],
		'Custom': [],
	}
	for raw_name in data.names:
		var name = raw_name.to_lower()
		if 'penis' in name: # or name.ends_with('firmness'):
			continue
		#macros
		if name.begins_with('african') or name.begins_with('asian') or name.begins_with('caucasian') or name.begins_with('female') or name.begins_with('male') or name.begins_with('universal'):
			continue
		elif name.begins_with('custom'):
			categories['Custom'].append(raw_name)
		elif 'bodyshape' in name:
			categories['Body'].append(raw_name)
		elif 'head' in name or 'brown' in name or 'top' in name:
			categories['Head'].append(raw_name)
		elif 'eye' in name:
			categories['Eyes'].append(raw_name)
		elif 'mouth' in name:
			categories['Mouth'].append(raw_name)
		elif 'nose' in name:
			categories['Nose'].append(raw_name)
		elif 'ear' in name:
			categories['Ears'].append(raw_name)
		elif 'jaw' in name or 'cheek' in name or 'temple' in name or 'chin' in name:
			categories['Face'].append(raw_name)
		elif 'arm' in name or 'hand' in name or 'finger' in name or 'wrist' in name:
			categories['Arms'].append(raw_name)
		elif 'leg' in name or 'calf' in name or 'foot' in name or 'butt' in name or 'ankle' in name or 'thigh' in name or 'knee' in name:
			categories['Legs'].append(raw_name)
		elif 'cup' in name or 'bust' in name or 'breast' in name or 'nipple' in name:
			categories['Breasts'].append(raw_name)
		elif 'torso' in name or 'chest' in name or 'shoulder' in name:
			categories['Chest'].append(raw_name)
		elif 'hip' in name or 'trunk' in name or 'pelvis' in name or 'waist' in name or 'pelvis' in name or 'stomach' in name or 'bulge' in name:
			categories['Hips'].append(raw_name)
		elif 'hand' in name or 'finger' in name:
			categories['Hands'].append(raw_name)
		elif 'neck' in name:
			categories['Neck'].append(raw_name)
		else:
			categories['Misc'].append(raw_name)
	
	categories['Macro'].append_array(HumanizerMacroService.macro_options)
	categories['Race'].append_array(HumanizerMacroService.race_options)
	categories['Macro'].erase('cupsize')
	categories['Macro'].erase('firmness')
	categories['Breasts'].append('cupsize')
	categories['Breasts'].append('firmness')
	return categories
