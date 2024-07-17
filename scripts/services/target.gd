@tool
extends Resource
class_name HumanizerTargetService

static var data: HumanizerTargetData = load("res://addons/humanizer/data/resources/target_data.res")

static func set_targets(new_targets:Dictionary,target_config:HumanTargetConfig,helper_vertex:PackedVector3Array):
	#print(new_targets)
	var macros = {}
	for target_name in new_targets.keys():
		if target_name in HumanizerMacroService.macro_options or target_name in HumanizerMacroService.race_options:
			macros[target_name] = new_targets[target_name]
			new_targets.erase(target_name)
	if not macros.is_empty():
		HumanizerMacroService.set_macros(macros,target_config,helper_vertex)
	set_targets_raw(new_targets,target_config,helper_vertex)

static func set_targets_raw(new_targets:Dictionary,target_config:HumanTargetConfig,helper_vertex:PackedVector3Array):
	for target_name in new_targets:
		if target_name in data.names:
			var offset = data.names[target_name]
			for ref_id in range(offset[0],offset[1]):
				var mh_id =  data.index[ref_id]
				var coords = data.coords[ref_id]
				#print(mh_id)
				helper_vertex[mh_id] += coords * (new_targets[target_name] - target_config.raw.get(target_name,0))
			if new_targets[target_name] == 0:
				target_config.raw.erase(target_name)
			else:
				target_config.raw[target_name] = new_targets[target_name]
	var foot_offset = HumanizerBodyService.get_foot_offset(helper_vertex)
	if foot_offset != 0:
		for mh_id in helper_vertex.size():
			helper_vertex[mh_id].y -= foot_offset

static func get_shapekey_categories() -> Dictionary:
	var categories := {
		'Macro': [],
		'Race': [],
		'BodyShape': [],
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
		if 'penis' in name:# or name.ends_with('firmness'):
			continue
		if name in data.macros:
			continue
		elif name.begins_with('custom'):
			categories['Custom'].append(raw_name)
		elif 'bodyshape' in name:
			categories['BodyShape'].append(raw_name)
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
