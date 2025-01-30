extends Resource
class_name HumanizerMaterialService

static func import_materials(folder:String):
	for subfolder in OSPath.get_dirs(folder):
		import_materials(subfolder)
	for file_name in OSPath.get_files(folder):
		if file_name.get_extension() == "mhmat":
			var new_mat = HumanizerMaterialService.mhmat_to_material(file_name)
			var mat_path = file_name.get_base_dir().path_join( file_name.get_file().replace('.mhmat','.material.res'))
			HumanizerResourceService.save_resource(mat_path,new_mat)

static func search_for_materials(mhclo_path:String):
	var materials = {}
	var overlays = {}
	var equip_type = mhclo_path.get_file().get_basename().get_basename() #get rid of both .mhclo.res extensions
	var sub_mats = get_manual_materials(mhclo_path.get_base_dir())
	materials.merge(sub_mats.materials)
	overlays.merge(sub_mats.overlays)
	#search for the generated materials after, so custom materials are first in the list
	materials.merge(search_for_generated_materials(mhclo_path.get_base_dir()))
	return {materials=materials,overlays=overlays}	

static func get_manual_materials(mhclo_folder):
	var materials = {}
	var overlays = {}
	var sub_folder = ""
	#print("search for manual materials")
	for asset_folder in HumanizerGlobalConfig.config.asset_import_paths:
		if mhclo_folder.begins_with(asset_folder):
			asset_folder = asset_folder.path_join("equipment")
			sub_folder = mhclo_folder.replace(asset_folder,"")
	#print(sub_folder)
	if sub_folder == "":
		#this shouldnt happen, since we're only searching in the defined folders
		printerr("couldnt find base asset folder for " + mhclo_folder)
		return
	for asset_folder in HumanizerGlobalConfig.config.asset_import_paths:
		var materials_path = asset_folder.path_join('materials')
		materials_path = materials_path.path_join(sub_folder)
		var sub_mats = recursive_search_for_manual_materials(materials_path)
		#merge is not recursive
		materials.merge(sub_mats.materials)
		overlays.merge(sub_mats.overlays)
	return {materials=materials,overlays=overlays}
	
static func recursive_search_for_manual_materials(path:String):
	var materials = {}
	var overlays = {}
	for subfolder in OSPath.get_dirs(path):
		var sub_mats = recursive_search_for_manual_materials(subfolder)
		materials.merge(sub_mats.materials)	
		overlays.merge(sub_mats.overlays)	
	# top folder should override if conflicts
	for mat_file in OSPath.get_files(path):
		if mat_file.get_extension() == "res":
			var mat_res = HumanizerResourceService.load_resource(mat_file)
			if mat_res is HumanizerMaterial or mat_res is StandardMaterial3D:
				materials[mat_file.get_file().get_basename().get_basename()] = mat_file
			elif mat_res is HumanizerOverlay:
				overlays[mat_file.get_file().get_basename()] = mat_file
	return {materials=materials,overlays=overlays}		

static func search_for_generated_materials(folder:String)->Dictionary:
	var materials = {}
	for subfolder in OSPath.get_dirs(folder):
		materials.merge(search_for_generated_materials(subfolder))	
	# top folder should override if conflicts
	for file_name in OSPath.get_files(folder):
		if file_name.ends_with(".material.res"):
			materials[file_name.get_file().trim_suffix(".material.res")] = file_name
	print(materials)
	return materials

static func default_material_from_mhclo(mhclo:MHCLO):
	var default_material = ""
	var material_path = mhclo.mhclo_path.get_base_dir().path_join(mhclo.default_material)
	if FileAccess.file_exists(material_path):
		default_material = mhclo.default_material.replace(".mhmat","")
	else:
		printerr(" warning - mhmat does not exist - " + material_path)
	#if default material is not set in mhclo (or if the name is invalid - most likely)
	#just fill in with the first material in the list, starting with manually defined materials at the top
	#its much easier for them to change it in the dropdown than to find the file and edit the text
	if default_material == "":
		var mat_list = search_for_materials(mhclo.mhclo_path)
		if mat_list.size() > 0:
			default_material = mat_list.keys()[0]
	return default_material

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
			material.albedo_texture = HumanizerResourceService.load_resource(diffuse_path)
		elif line.begins_with("normalmapTexture "):
			var normal_path = line.split(" ")[1].strip_edges()
			normal_path = path.get_base_dir().path_join(normal_path)
			material.normal_texture = HumanizerResourceService.load_resource(normal_path)
			material.normal_enabled = true
		elif line.begins_with("bumpTexture "):
			var bump_path = line.split(" ")[1].strip_edges()
			bump_path = path.get_base_dir().path_join(bump_path)
			var normal_texture : Image = HumanizerResourceService.load_resource(bump_path).get_image().duplicate()
			normal_texture.bump_map_to_normal_map()
			bump_path = bump_path.replace('.png', '_normal.png')
			normal_texture.save_png( bump_path)
			material.normal_texture = HumanizerResourceService.load_resource(bump_path)
			material.normal_enabled = true
		elif line.begins_with("aomapTexture "):
			var ao_path = line.split(" ")[1].strip_edges()
			ao_path = path.get_base_dir().path_join(ao_path)
			material.ao_texture = HumanizerResourceService.load_resource(ao_path)
			material.ao_enabled = true
		elif line.begins_with("specularTexture "):
			var spec_path = line.split(" ")[1].strip_edges()
			spec_path = path.get_base_dir().path_join(spec_path)
			material.metallic = 1
			material.metallic_texture = HumanizerResourceService.load_resource(spec_path)
			printerr("specular texture not supported by Godot, using as metallic texture instead. You can manually create materials by adding them to the assets/materials/%asset_name% folder")
		elif line.begins_with("normalmapIntensity "):
			material.normal_scale = line.split_floats(" ",false,)[1]
		elif line.begins_with("aomapIntensity "):
			material.ao_light_affect = line.split_floats(" ",false,)[1]
		elif line.begins_with("shaderConfig "):
			pass
	return material
	
