extends Resource
class_name MHMAT_Reader

var data = {}
var input_folder = "res://experimental/mpfb2_plugin/assets/"
var output_folder = "res://experimental/generated_assets/"

func _init(filename:String):
	input_folder = input_folder.path_join(filename.get_base_dir()) 
	output_folder = output_folder.path_join(filename.get_base_dir()) 
	data.shaderConfig = {}
	data.shaderParam = {}
	var file = FileAccess.open(input_folder.path_join(filename.get_file()),FileAccess.READ)
	while file.get_position() < file.get_length():
		var line = file.get_line()
		if not line.begins_with("#") and not line == "":
			var var_name = line.get_slice(" ", 0)
			if var_name == "shaderParam" or var_name == "shaderConfig":
				data[var_name][line.get_slice(" ",1)] = line.get_slice(" ",2)
			else:
				data[var_name] = line.get_slice(" ",1)
	#print(data)
	
func move_texture_files():
	print(output_folder)
	DirAccess.make_dir_recursive_absolute(output_folder)
	if "diffuseTexture" in data:
		var in_path = input_folder.path_join(data.diffuseTexture)
		var out_path = output_folder.path_join(data.diffuseTexture)
		DirAccess.copy_absolute(in_path,out_path)
	if "normalmapTexture" in data:
		var in_path = input_folder.path_join(data.normalmapTexture)
		var out_path = output_folder.path_join(data.normalmapTexture)
		DirAccess.copy_absolute(in_path,out_path)
	if "aomapTexture" in data:
		var in_path = input_folder.path_join(data.aomapTexture)
		var out_path = output_folder.path_join(data.aomapTexture)
		DirAccess.copy_absolute(in_path,out_path)
		
		
	
func make_material():
	var new_mat = StandardMaterial3D.new()
	#new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if "diffuseTexture" in data:
		var out_path = output_folder.path_join(data.diffuseTexture)
		new_mat.albedo_texture = load(out_path)
	if "normalmapTexture" in data:
		var out_path = output_folder.path_join(data.normalmapTexture)
		new_mat.normal_enabled = true
		new_mat.normal_texture = load(out_path)
		new_mat.normal_scale = float(data.normalmapIntensity)
	if "aomapTexture" in data:
		var out_path = output_folder.path_join(data.aomapTexture)
		new_mat.ao_enabled = true
		new_mat.ao_texture = load(out_path)
		new_mat.ao_light_affect = float(data.aomapIntensity)
		
	var save_path = output_folder.path_join("default_material.res")
	ResourceSaver.save(new_mat,save_path)
	return save_path
	
