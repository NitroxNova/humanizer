extends Resource
class_name HumanizerMaterialService

static func import_materials(folder:String):
	for subfolder in OSPath.get_dirs(folder):
		import_materials(subfolder)
	for file_name in OSPath.get_files(folder):
		if file_name.get_extension() == "mhmat":
			var new_mat = HumanizerMaterialService.mhmat_to_material(file_name)
			var mat_path = file_name.get_base_dir().path_join( new_mat.resource_name + '_material.res')
			new_mat.take_over_path(mat_path)
			ResourceSaver.save(new_mat, mat_path)

static func search_for_generated_materials(folder:String)->Dictionary:
	var materials = {}
	for subfolder in OSPath.get_dirs(folder):
		materials.merge(search_for_generated_materials(subfolder))	
	# top folder should override if conflicts
	for file_name in OSPath.get_files(folder):
		if file_name.get_extension() == "res":
			var mat_res = HumanizerAPI.load_resource(file_name)
			if mat_res is StandardMaterial3D:
				materials[mat_res.resource_name] = file_name
	return materials

static func mhmat_to_material(path:String)->StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var file = FileAccess.open(path,FileAccess.READ)
	while file.get_position() < file.get_length():
		var line :String = file.get_line()
		if line.begins_with("name "):
			material.resource_name = line.split(" ",false,1)[1]
		elif line.begins_with("diffuseColor "):
			var color_f = line.split_floats(" ",false)
			var color = Color(color_f[1],color_f[2],color_f[3])
			material.albedo_color = color
		elif line.begins_with("shininess "):
			material.roughness = 1-(line.split_floats(" ",false)[1]*.5) 
		elif line.begins_with("transparent "):
			if line.split(" ")[1] == "True":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		elif line.begins_with("backfaceCull "):
			if line.split(" ")[1] == "False":
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
		elif line.begins_with("diffuseTexture "):
			var diffuse_path = line.split(" ")[1].strip_edges()
			diffuse_path = path.get_base_dir().path_join(diffuse_path)
			material.albedo_texture = HumanizerAPI.load_resource(diffuse_path)
		elif line.begins_with("normalmapTexture "):
			var normal_path = line.split(" ")[1].strip_edges()
			normal_path = path.get_base_dir().path_join(normal_path)
			material.normal_texture = HumanizerAPI.load_resource(normal_path)
			material.normal_enabled = true
		elif line.begins_with("bumpTexture "):
			var bump_path = line.split(" ")[1].strip_edges()
			bump_path = path.get_base_dir().path_join(bump_path)
			var normal_texture : Image = HumanizerAPI.load_resource(bump_path).get_image()
			normal_texture.bump_map_to_normal_map()
			bump_path = bump_path.replace('.png', '_normal.png')
			normal_texture.save_png( bump_path)
			material.normal_texture = HumanizerAPI.load_resource(bump_path)
			material.normal_enabled = true
		elif line.begins_with("aomapTexture "):
			var ao_path = line.split(" ")[1].strip_edges()
			ao_path = path.get_base_dir().path_join(ao_path)
			material.ao_texture = HumanizerAPI.load_resource(ao_path)
			material.ao_enabled = true
		elif line.begins_with("specularTexture "):
			var spec_path = line.split(" ")[1].strip_edges()
			spec_path = path.get_base_dir().path_join(spec_path)
			material.metallic = 1
			material.metallic_texture = HumanizerAPI.load_resource(spec_path)
			printerr("specular texture not supported by Godot, using as metallic texture instead. You can manually create materials by adding them to the assets/materials/%asset_name% folder")
		elif line.begins_with("normalmapIntensity "):
			material.normal_scale = line.split_floats(" ",false,)[1]
		elif line.begins_with("aomapIntensity "):
			material.ao_light_affect = line.split_floats(" ",false,)[1]
		elif line.begins_with("shaderConfig "):
			pass
	return material
	
