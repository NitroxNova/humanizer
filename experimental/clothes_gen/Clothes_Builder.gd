extends Resource
class_name Clothes_Builder

var clothes_path : String  #"clothes/fedora01"

var import_mesh : ArrayMesh
var clothes_data : Clothes_Data

const INPUT_FOLDER = "res://experimental/mpfb2_plugin/assets/"
const OUTPUT_FOLDER = "res://experimental/generated_assets/"
const SHAPEKEY_DATA = preload("res://experimental/process_shapekeys/shapekey_data.res")
var BONE_WEIGHTS = Utils.read_json("res://experimental/build_skeleton/bone_weights.json")
const BONE_COUNT = 8
var ST = SurfaceTool.new()

func _init(_clothes_path:String):
	print(clothes_path)
	clothes_path = _clothes_path
	clothes_data = load(OUTPUT_FOLDER.path_join(clothes_path).path_join("clothes_data.res"))
	import_mesh = load(OUTPUT_FOLDER.path_join(clothes_path).path_join("import_mesh.res"))

func build_complete_shapekey_mesh():
	var new_mesh = ArrayMesh.new()
	new_mesh.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	var blend_arrays = []
	for shape_name in SHAPEKEY_DATA.shapekeys:
		new_mesh.add_blend_shape(shape_name)
		blend_arrays.append(build_shapekey_arrays(shape_name))
	var flags = import_mesh.surface_get_format(0)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,import_mesh.surface_get_arrays(0),blend_arrays,{},flags)
	var shaded_mesh = Utils.generate_normals_tangents(new_mesh)
	shaded_mesh.surface_set_material(0,load(OUTPUT_FOLDER.path_join(clothes_path).path_join("default_material.res")))
	ResourceSaver.save(shaded_mesh,OUTPUT_FOLDER.path_join(clothes_path).path_join("mesh.res"))
	return new_mesh
	
 #these get compiled into the "blend_shapes" array in the ArrayMesh
func build_shapekey_arrays(shape_name:String):
	var helper_vertex_array = SHAPEKEY_DATA.basis.duplicate(true)
	for mh_id in SHAPEKEY_DATA.shapekeys[shape_name]:
		helper_vertex_array[mh_id] += SHAPEKEY_DATA.shapekeys[shape_name][mh_id]
	var fitted_arrays = build_fitted_arrays(helper_vertex_array,false)
	var new_sf_arrays = []
	new_sf_arrays.resize(Mesh.ARRAY_MAX)
	new_sf_arrays[Mesh.ARRAY_VERTEX] = fitted_arrays[Mesh.ARRAY_VERTEX]
	return new_sf_arrays

func build_fitted_mesh(helper_vertex_array:PackedVector3Array,bone_weights=false): #the static mesh with no shapekeys
	var new_mesh = ArrayMesh.new()
	var new_sf_arrays = build_fitted_arrays(helper_vertex_array,bone_weights)
	var flags = import_mesh.surface_get_format(0)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays,[],{},flags)
	new_mesh.surface_set_material(0,load(OUTPUT_FOLDER.path_join(clothes_path).path_join("default_material.res")))
	return new_mesh

func build_fitted_arrays(helper_vertex_array:PackedVector3Array,bone_weights_enabled=false): #the static mesh with no shapekeys
	var mh2gd_index = clothes_data.mh2gd_index
	var new_sf_arrays = import_mesh.surface_get_arrays(0)
	var clothes_scale = Vector3.ZERO
	clothes_scale.x = calculate_scale("x",helper_vertex_array)
	clothes_scale.y = calculate_scale("y",helper_vertex_array)
	clothes_scale.z = calculate_scale("z",helper_vertex_array)
	for mh_id in clothes_data.vertex.size():
		var vertex_line = clothes_data.vertex[mh_id]
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
		var g_id_array = mh2gd_index[mh_id]
		for g_id in g_id_array:
			new_sf_arrays[Mesh.ARRAY_VERTEX][g_id] = new_coords
			
	if bone_weights_enabled:
		add_bone_weights(new_sf_arrays)		
	return new_sf_arrays

func calculate_scale(axis:String,helper_vertex_array:Array): # axis = x y or z
	var scale_data = clothes_data.scale_config[axis]
	var start_coords = helper_vertex_array[scale_data.start]
	var end_coords = helper_vertex_array[scale_data.end]
	var basemesh_dist = absf(end_coords[axis] - start_coords[axis])
	var scale = basemesh_dist/scale_data.length
	#print(scale)
	return scale
	
			
func build_import_mesh(): # build basis from obj file
	var mhclo = MHCLO_Reader.new(find_mhclo())
	var obj_path = INPUT_FOLDER.path_join(clothes_path).path_join(mhclo.obj_file_name)
	var obj_data = OBJ_to_Mesh.new(obj_path).run()
	import_mesh = obj_data.mesh
	
	var mh2gd_index = obj_data.mh2gd_index
	var vertex = mhclo.vertex_data
	var delete_vertex = mhclo.delete_vertices
	var scale_config = mhclo.scale_config
	clothes_data = Clothes_Data.new(mh2gd_index,vertex,delete_vertex,scale_config) 
	#so i dont have to parse the mhclo file at runtime if building from the data (not using blendshapes)
	
	import_mesh = build_fitted_mesh(SHAPEKEY_DATA.basis,true)
	var shaded_mesh = Utils.generate_normals_tangents(import_mesh)
	ResourceSaver.save(shaded_mesh,OUTPUT_FOLDER.path_join(clothes_path).path_join("/import_mesh.res"))
	
	clothes_data.mh2gd_index = Utils.get_mh2gd_index_from_mesh(shaded_mesh)
	ResourceSaver.save(clothes_data,OUTPUT_FOLDER.path_join(clothes_path).path_join("clothes_data.res"))


func add_bone_weights(sf_arrays:Array):
	var new_mesh = ArrayMesh.new()
	var new_sf_arrays = sf_arrays.duplicate(true)
	#mh2gd_index = Utils.create_unique_index(new_sf_arrays[Mesh.ARRAY_VERTEX])
	sf_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	sf_arrays[Mesh.ARRAY_BONES].resize(BONE_COUNT * sf_arrays[Mesh.ARRAY_VERTEX].size())
	sf_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	sf_arrays[Mesh.ARRAY_WEIGHTS].resize(BONE_COUNT * sf_arrays[Mesh.ARRAY_VERTEX].size())
	
	#print(new_sf_arrays[Mesh.ARRAY_BONES].size())
	for mh_id in clothes_data.vertex.size():
		var vertex_line = clothes_data.vertex[mh_id]
		var vertex_data = process_bone_weight_line(vertex_line)
		var g_id_array = clothes_data.mh2gd_index[mh_id]
		for g_id in g_id_array:
			for i in BONE_COUNT:
				sf_arrays[Mesh.ARRAY_BONES][g_id * BONE_COUNT + i] = vertex_data.bones[i]
				sf_arrays[Mesh.ARRAY_WEIGHTS][g_id * BONE_COUNT + i] = vertex_data.weights[i]

	return sf_arrays

func process_bone_weight_line(vertex_line):
	var output = {bones=PackedInt32Array(),weights=PackedFloat32Array()}
	if vertex_line.format == "single":
		var mh_id = vertex_line.vertex[0]
		output.bones = BONE_WEIGHTS.bones[mh_id]
		output.weights = BONE_WEIGHTS.weights[mh_id]
	else:
		for i in 3:
			var mh_id = vertex_line.vertex[i]
			var vertex_weight = vertex_line.weight[i]
			var merge = {bones=BONE_WEIGHTS.bones[mh_id],weights=BONE_WEIGHTS.weights[mh_id]}
			merge_bone_weights(output,merge,vertex_weight)
			
	var total_weight = 0
	for i in output.weights:
		total_weight += i
	var ratio = 1/total_weight
	for i in output.weights.size():
		output.weights[i] *= ratio
	if output.bones.size() > 8:
		print("more than 8 bones!")
	while output.bones.size()<8:
		output.bones.append(0)
		output.weights.append(0)
	#output.bones.resize(8)
	#output.weights.resize(8)
	return output

func merge_bone_weights(existing:Dictionary,merge:Dictionary,vertex_weight:float):
	for j in BONE_COUNT:
		var weight = merge.weights[j]
		if not weight == 0:
			var bone_id = merge.bones[j]
			weight *= vertex_weight
			if bone_id in existing.bones:
				var array_id = existing.bones.find(bone_id)
				existing.weights[array_id] += weight
			else:
				existing.bones.append(bone_id)
				existing.weights.append(weight)
	
	
func find_mhclo():
	var path = INPUT_FOLDER.path_join(clothes_path)
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				pass
				#print("Found directory: " + file_name)
			elif file_name.get_extension() == "mhclo":
				#print("Found file: " + file_name)
				return path.path_join(file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return null
