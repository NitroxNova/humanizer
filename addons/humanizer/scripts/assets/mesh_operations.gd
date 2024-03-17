class_name MeshOperations


static func generate_normals_and_tangents(import_mesh:ArrayMesh):
	var ST = SurfaceTool.new()
	ST.clear()
	ST.create_from(import_mesh,0)
	ST.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	ST.generate_normals()
	ST.generate_tangents()
	var flags = import_mesh.surface_get_format(0)
	var new_mesh = ST.commit(null,flags)
	return new_mesh

static func build_fitted_mesh(mesh: ArrayMesh, helper_vertex_array: PackedVector3Array, mhclo: MHCLO) -> ArrayMesh: 
	# the static mesh with no shapekeys
	var new_mesh = ArrayMesh.new()
	var new_sf_arrays = build_fitted_arrays(mesh, helper_vertex_array, mhclo)
	var flags = mesh.surface_get_format(0)
	var lods := {}
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays, [], lods, flags)
	return new_mesh

static func build_fitted_arrays(mesh: ArrayMesh, helper_vertex_array: PackedVector3Array, mhclo: MHCLO) -> Array: 
	var new_sf_arrays = mesh.surface_get_arrays(0)
	var clothes_scale = Vector3.ZERO
	clothes_scale.x = _calculate_scale("x", helper_vertex_array, mhclo)
	clothes_scale.y = _calculate_scale("y", helper_vertex_array, mhclo)
	clothes_scale.z = _calculate_scale("z", helper_vertex_array, mhclo)
	for mh_id in mhclo.vertex_data.size():
		var vertex_line = mhclo.vertex_data[mh_id]
		var new_coords = Vector3.ZERO
		if vertex_line.format == "single":
			var vertex_id = vertex_line.vertex[0]
			new_coords = helper_vertex_array[vertex_id]
		else:
			for i in 3:
				var vertex_id = vertex_line.vertex[i]
				var v_weight = vertex_line.weight[i]
				var v_coords = helper_vertex_array[vertex_id]
				v_coords *= v_weight
				new_coords += v_coords
			new_coords += (vertex_line.offset * clothes_scale)
		var g_id_array = mhclo.mh2gd_index[mh_id]
		for g_id in g_id_array:
			new_sf_arrays[Mesh.ARRAY_VERTEX][g_id] = new_coords
			
	#if bone_weights_enabled:
	#	add_bone_weights(new_sf_arrays)
	return new_sf_arrays

static func _calculate_scale(axis: String, helper_vertex_array: Array, mhclo: MHCLO) -> float:
	# axis = x y or z
	var scale_data = mhclo.scale_config[axis]
	var start_coords = helper_vertex_array[scale_data.start]
	var end_coords = helper_vertex_array[scale_data.end]
	var basemesh_dist = absf(end_coords[axis] - start_coords[axis])
	var scale = basemesh_dist/scale_data.length
	return scale
	
static func skin_mesh(rig: HumanizerRig, skeleton: Skeleton3D, basemesh: ArrayMesh) -> ArrayMesh:
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
	return skinned_mesh


const macro_ranges :Dictionary = {
		age = [["baby",0],["child",.12],["young",.25],["old",1]],
		gender = [["female",0.0],["male",1.0]],
		height = [["minheight",0],["",.5],["maxheight",1]],
		muscle = [["minmuscle",0],["averagemuscle",0.5],["maxmuscle",1]],
		proportions = [["uncommonproportions",0],["",0.5],["idealproportions",1]],
		weight = [["minweight",0],["averageweight",0.5],["maxweight",1]],
		cupsize = [["mincup",0],["averagecup",0.5],["maxcup",1]],
		firmness = [["minfirmness",0],["averagefirmness",0.5],["maxfirmness",1]]
	}

const macro_combos : Dictionary = {
		"racegenderage": ["race", "gender", "age"],
		"genderagemuscleweight": ["universal", "gender", "age", "muscle", "weight"],
		"genderagemuscleweightproportions": ["gender", "age", "muscle", "weight", "proportions"],
		"genderagemuscleweightheight": ["gender", "age", "muscle", "weight", "height"],
		"genderagemuscleweightcupsizefirmness": ["gender", "age", "muscle", "weight", "cupsize", "firmness"]
	}

static func get_macro_options():
	return ["age","gender","height","weight","muscle","proportions","cupsize","firmness"]

static func get_race_options():
	return ["african","asian","caucasian"]

static func init_macro_shapekey_values(macros:Dictionary,race:Dictionary):
	var shapekeys = {}
	var macro_data = {}
	macro_data.race = normalize_race_values(race)
	for macro_name in macros:
		macro_data[macro_name] = get_macro_category_offset(macro_name,macros[macro_name])
	for combo_name in macro_combos:
		var combo_shapekeys = get_combination_shapekeys(combo_name,macro_data)
		for shapekey_name in combo_shapekeys:
			shapekeys[shapekey_name] = combo_shapekeys[shapekey_name]
	return shapekeys
		
#call this from the menu to get the new shapekeys
#this does not include reseting the previous shapekeys tho
#need to pass previous macro values as well	
static func get_macro_shapekey_values(prev_macros:Dictionary,prev_race:Dictionary,changed_values:Dictionary={}):
	var prev_shapekeys = {} #shapekey name / value pairs
	var new_shapekeys = {} #shapekey name / value pairs
	var new_macro_data = {}
	var prev_macro_data = {}
	prev_macro_data.race = normalize_race_values(prev_race)
	for macro_name in prev_macros:
		prev_macro_data[macro_name] = get_macro_category_offset(macro_name,prev_macros[macro_name])

	new_macro_data = prev_macro_data.duplicate()
	for macro_name in changed_values:
		if macro_name in MeshOperations.get_race_options():
			new_macro_data.race[macro_name] = changed_values[macro_name]
		else:
			new_macro_data[macro_name] = get_macro_category_offset(macro_name,changed_values[macro_name])
	
	new_macro_data.race = normalize_race_values(new_macro_data.race)
	
	for combo_name in macro_combos:
		var update_combo = false
		if changed_values.size() == 0:
			update_combo = true
		for changed_name in changed_values:
			if changed_name in macro_combos[combo_name]:
				update_combo = true
		if update_combo:
			var prev_combo_shapekeys = get_combination_shapekeys(combo_name,prev_macro_data)
			for shapekey_name in prev_combo_shapekeys:
				prev_shapekeys[shapekey_name] = prev_combo_shapekeys[shapekey_name]
			var new_combo_shapekeys = get_combination_shapekeys(combo_name,new_macro_data)
			for shapekey_name in new_combo_shapekeys:
				new_shapekeys[shapekey_name] = new_combo_shapekeys[shapekey_name]
	
				
	return _get_adjusted_shapekeys(prev_shapekeys,new_shapekeys)

static func _get_adjusted_shapekeys(prev_shapekeys:Dictionary,new_shapekeys:Dictionary):
	var output = {}
	for sk_name in new_shapekeys:
		output[sk_name] = new_shapekeys[sk_name]
	for sk_name in prev_shapekeys:
		if sk_name not in new_shapekeys:
			output[sk_name] = 0
	return output
	
static func normalize_race_values(race_data:Dictionary):
	var new_data = {}
	var total = 0
	for race in race_data:
		total += race_data[race]
	if total == 0:
		for race in race_data:
			new_data[race] = 1/race_data.size()
		return new_data
	else:
		var ratio = 1/total
		for race in race_data:
			new_data[race] = race_data[race] * ratio
		return new_data
		
	
	
static func get_combination_shapekeys(combo_name:String,data:Dictionary):
	var next_shapes = {}
	var combo_shapekeys = {""=1} # shapekey name / value pairs
	for macro_name in macro_combos[combo_name]:
		if macro_name == "universal":
			next_shapes = {"universal"=1}
		elif macro_name == "race":
			next_shapes = data.race.duplicate()
		else:
			var curr_macro = data[macro_name]
			for shape_name in combo_shapekeys:
				for offset_counter in curr_macro.offset.size():
					var offset_id = curr_macro.offset[offset_counter]
					var new_shape_name = shape_name 
					if not shape_name == "":
						new_shape_name += "-"
					new_shape_name += macro_ranges[macro_name][offset_id][0]
					var new_shape_value = combo_shapekeys[shape_name] * curr_macro.ratio[offset_counter]
					next_shapes[new_shape_name] = new_shape_value
		combo_shapekeys = next_shapes
		next_shapes = {}
		
	## cant check for missing shapekeys without the shapekey_data dictionary, it is expected that not all shapekeys are present
	## will have to ignore missing shapekeys elsewhere
	#for shape_name in curr_shapes.keys():
		#if not shape_name in shapekey_data.shapekeys:
			#curr_shapes.erase(shape_name)
	
	return combo_shapekeys
	
static func get_macro_category_offset(macro_name,macro_value):
	var category = macro_ranges[macro_name]
	var offset : Array = [] # low and high offset
	var ratio : Array = [] #ratio between low (0) and high (1)
	
	var counter = 0
	for i in category.size():
		if macro_value == category[i][1]:
			offset = [i]
			ratio = [1]
			break
		elif macro_value < category[i][1]:
			offset = [i-1,i]
			ratio = []
			var high_ratio = (macro_value-category[i-1][1])/(category[i][1]-category[i-1][1])
			ratio.append(1-high_ratio)
			ratio.append(high_ratio)
			break
	for i in range(offset.size()-1,-1,-1): #loop backwards so it doesnt skip any when removing
		if category[offset[i]][0] == "":
			offset.remove_at(i)
			ratio.remove_at(i)
	
	return {offset=offset,ratio=ratio}
	
