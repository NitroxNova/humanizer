@tool
extends Resource
class_name HumanizerTargetService

static var cache = {}
static var data: Dictionary[String,PackedVector4Array] = {}#loaded in the humanizer global
static var basis : PackedVector3Array

static func exit():
	# todo mutex
	cache.clear()
	HumanizerLogger.debug("target service shutdown")

static func load_data():
	var target_files = OSPath.get_files_recursive("res://humanizer/target/")
	for file_path in target_files:
		var tar_file = FileAccess.open(file_path,FileAccess.READ)
		data.merge(tar_file.get_var())
	var basis_file = FileAccess.open("res://addons/humanizer/data/resources/basis.data",FileAccess.READ)
	basis = basis_file.get_var()

static func init_helper_vertex(target_data = {combo={},single={}}) -> PackedVector3Array:
	var helper_vertex = basis.duplicate()
	for target_name in target_data.single:
		update_helper_from_single_target(target_name,target_data.single[target_name],0,helper_vertex)
	for combo_name in target_data.combo:
		for target_name in target_data.combo[combo_name]:
			update_helper_from_single_target(target_name,target_data.combo[combo_name][target_name],0,helper_vertex)
	return helper_vertex

static func set_targets(target_input: Dictionary, current_targets: Dictionary, helper_vertex: PackedVector3Array=[]):
	var macros = {}
	var new_targets = {combo={},single={}}
	for target_name in target_input.keys():
		if target_name in HumanizerMacroService.macro_options or target_name in HumanizerMacroService.race_options:
			macros[target_name] = target_input[target_name]
		else:
			new_targets.single[target_name] = target_input[target_name]
	if not macros.is_empty():
		var new_combos = HumanizerMacroService.set_macros(macros, current_targets)
		for combo_name in new_combos:
			new_targets.combo[combo_name] = new_combos[combo_name]
	set_targets_raw(new_targets, helper_vertex, current_targets)

static func set_targets_raw(new_targets: Dictionary, helper_vertex: PackedVector3Array, current_targets:Dictionary = {single={},combo={}}):
	#print(current_targets)
	for target_name in new_targets.single:
		var new_value = new_targets.single[target_name]
		update_helper_from_single_target(target_name,new_value,current_targets.single.get(target_name,0),helper_vertex)		
		current_targets.single[target_name] = new_targets.single[target_name]
		if new_value == 0:
			current_targets.single.erase(target_name)
		else:
			current_targets.single[target_name] = new_targets.single[target_name]
	
	for combo_name in new_targets.combo:
		if combo_name not in current_targets.combo:
			current_targets.combo[combo_name] = {}
		for target_name in new_targets.combo[combo_name]:
			var new_value = new_targets.combo[combo_name][target_name]
			update_helper_from_single_target(target_name,new_value,current_targets.combo[combo_name].get(target_name,0),helper_vertex)		
			if new_value == 0:
				current_targets.combo[combo_name].erase(target_name)
			else:
				current_targets.combo[combo_name][target_name] = new_targets.combo[combo_name][target_name]
	if not helper_vertex.is_empty():	
		var foot_offset = HumanizerBodyService.get_foot_offset(helper_vertex)
		if foot_offset != 0:
			for mh_id in helper_vertex.size():
				helper_vertex[mh_id].y -= foot_offset

static func update_helper_from_single_target(target_name,new_value,prev_value,helper_vertex):
	if (not helper_vertex.is_empty()) and (target_name in data):
		var curr_tar_data : PackedVector4Array = data[target_name]
		for ref_id in curr_tar_data.size():
			var curr_line : Vector4 = curr_tar_data[ref_id]
			var mh_id:int  = curr_line.w
			var coords = Vector3(curr_line.x,curr_line.y,curr_line.z)
			helper_vertex[mh_id] += coords * (new_value - prev_value)
			
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
	for raw_name in data:
		var name = raw_name.to_lower()
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
