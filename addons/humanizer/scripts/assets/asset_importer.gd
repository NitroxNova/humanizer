@tool
class_name HumanizerAssetImporter 
extends Node

@export_dir var _asset_path = ''

var slot: String
var clothing_slots := []
var busy: bool = false
var asset_type: HumanizerRegistry.AssetType
var basis: Array

func run() -> void:
	if asset_type == HumanizerRegistry.AssetType.Clothes:
		if clothing_slots.size() == 0:
			printerr('Select clothing slots before processing clothes asset.')
			return

	basis = HumanizerUtils.get_shapekey_data().basis.duplicate(true)
	if _asset_path != '':  # User operating from scene
		for fl in OSPath.get_files(_asset_path):
			if fl.get_extension() in ['res', 'tscn', 'tres']:
				DirAccess.remove_absolute(fl)
		_scan_path(_asset_path)
	else:                  # Bulk import task
		print('Bulk asset import')
		for path in HumanizerConfig.asset_import_paths:
			for dir in OSPath.get_dirs(path.path_join('body_parts')):
				_clean_recursive(dir)
				_scan_recursive(dir)
			for dir in OSPath.get_dirs(path.path_join('clothes')):
				_clean_recursive(dir)
				_scan_recursive(dir)

func _clean_recursive(path: String) -> void:
	for dir in OSPath.get_dirs(path):
		_clean_recursive(dir)
	for fl in OSPath.get_files(path):
		if fl.get_extension() in ['res', 'tscn', 'tres']:
			DirAccess.remove_absolute(fl)
	
func _scan_recursive(path: String) -> void:
	for dir in OSPath.get_dirs(path):
		_scan_recursive(dir)
	_scan_path(path)
	
func _scan_path(path: String) -> void:
	if 'body_parts' in path:
		asset_type = HumanizerRegistry.AssetType.BodyPart
	elif 'clothes' in path:
		asset_type = HumanizerRegistry.AssetType.Clothes
	else:
		printerr("Couldn't infer asset type from path.")
		return
		
	var textures := {}
	var obj_data = null
	var contents = OSPath.get_contents(path)
	var asset_data := {}
	
	for file_name in OSPath.get_files(path):
		if file_name.get_extension() == "mhclo":
			var fl = file_name.get_file().rsplit('.', true, 1)[0]
			var _mhclo = MHCLO.new(file_name)
			var obj = _mhclo.obj_file_name
			obj_data = ObjToMesh.new(file_name.get_base_dir().path_join(obj)).run()
			asset_data[fl] = {}
			asset_data[fl]['mhclo'] = _mhclo
			asset_data[fl]['mesh'] = obj_data.mesh
			asset_data[fl]['mh2gd_index'] = obj_data.mh2gd_index
	if asset_data.size() == 0:
		return

	# Get textures
	for file_name in contents.files:
		if file_name.get_extension() in ["png"]:
			# Eyes come with two textures for coloring iris, base and overlay
			if 'overlay' in file_name.get_file():
				for k in asset_data:
					asset_data[k]['overlay'] = {'albedo': file_name}
				continue
			if file_name.rsplit('.', true, 1)[-2].ends_with('normal'):
				textures['normal'] = file_name
			elif file_name.rsplit('.', true, 1)[-2].ends_with('ao'):
				textures['ao'] = file_name
			else:
				textures[file_name.get_file()] = file_name

	for asset in asset_data:
		asset_data[asset]['textures'] = textures
		_import_asset(path, asset, asset_data[asset])
		
func _import_asset(path: String, asset_name: String, data: Dictionary):
	print('Importing asset ' + asset_name)
	# Build resource object
	var resource: HumanAsset
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		resource = HumanBodyPart.new()
	elif asset_type == HumanizerRegistry.AssetType.Clothes:
		resource = HumanClothes.new()
	else:
		printerr('Unrecognized slot type ' + str(slot))
	resource.path = path
	resource.resource_name = asset_name
	resource.textures = data.textures
	if data.has('overlay'):
		HumanizerRegistry.overlays[asset_name] = HumanizerOverlay.from_dict(data.overlay)
	if resource.scene_path in EditorInterface.get_open_scenes():
		printerr('Cannot process ' + asset_name + ' because its scene is open in the editor')
		return
	
	var mesh = data.mesh
	var mh2gd_index = data.mh2gd_index
	var mhclo = data.mhclo
	
	# Mesh operations
	var new_sf_arrays = mesh.surface_get_arrays(0)
	mesh = build_import_mesh(path, mhclo)
	
	# Create material
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		if 'Eyelash' in slot or 'Eyebrow' in slot or 'Hair' == slot:
			# For eyebrows alpha looks better but scissor is cheaper
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if 'Eyebrow' in slot:
			mat.grow = true
			mat.grow_amount = 0.001
		if slot == 'Hair':
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON

	# Set slot(s)
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		slot = asset_name.split('-')[0].split('_')[0]
		if slot not in HumanizerConfig.body_part_slots:
			printerr('File should be named {slot}-{asset}.mhclo.  Slot not recognized : ' + slot)
			return
		if HumanizerRegistry.body_parts[slot].has(asset_name):
			HumanizerRegistry.body_parts[slot].erase(asset_name)
		resource.slot = slot
	elif asset_type == HumanizerRegistry.AssetType.Clothes:
		for slot in clothing_slots:
			if slot not in HumanizerConfig.clothing_slots:
				printerr('clothing slot not recognized : ' + slot)
				return
			# TODO SET CLOTHING SLOTS
			#resource.slots.append(slot)
		if HumanizerRegistry.clothes.has(asset_name):
			HumanizerRegistry.clothes.erase(asset_name)
	# Save resources
	mhclo.mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(mesh)
	resource.resource_path = path.path_join(asset_name + '.tres')
	ResourceSaver.save(mhclo, resource.mhclo_path)
	ResourceSaver.save(resource, resource.resource_path)

	# Put main resource in registry for easy access later
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		HumanizerRegistry.add_body_part_asset(resource)
	elif asset_type == HumanizerRegistry.AssetType.Clothes:
		HumanizerRegistry.add_clothes_asset(resource)

	print('Creating packed scene for ' + asset_name)
	# Create packed scene
	var mi = MeshInstance3D.new()
	var scene = PackedScene.new()
	mi.mesh = mesh
	mi.name = asset_name
	mi.set_surface_override_material(0, mat)
	mi.set_script(load("res://addons/humanizer/scripts/assets/humanizer_mesh_instance.gd"))
	add_child(mi)
	mi.owner = self
	var mat_config = mi.material_config as HumanizerMaterial
	
	# Set textures
	if resource.textures.size() > 0:
		var albedo := ''
		var normal := ''
		var ao := ''
		for t in resource.textures:
			if t == 'normal':
				normal = resource.textures[t]
			elif t == 'ao':
				ao = resource.textures[t]
			elif albedo == '': # Get first albedo as default
				albedo = resource.textures[t]

		# Create normal map from albedo as bump map for eyebrows
		if 'Eyebrow' in slot and normal == '':
			print('Generating normal')
			var normal_texture = load(albedo) as Texture2D
			normal_texture = normal_texture.get_image()
			normal_texture.bump_map_to_normal_map()
			normal_texture = ImageTexture.create_from_image(normal_texture)
			normal = albedo.replace('.png', '_normal.png')
			ResourceSaver.save(normal_texture, normal)
	
		## Set textures on material config
		mat_config.set_base_textures(HumanizerOverlay.from_dict({'albedo': albedo, 'normal': normal, 'ao': ao}))
		if data.has('overlay'):
			mat_config.add_overlay(HumanizerOverlay.from_dict(data.overlay))

	mi.update_material()
	ResourceSaver.save(mat, resource.material_path)
	ResourceSaver.save(mesh, resource.mesh_path)
	# Scene material path still shows empty string, but the tscn file size is 
	# smaller than the material.res file so it must be working correctly
	mat.resource_path = resource.material_path
	mesh.resource_path = resource.mesh_path
	scene.pack(mi)
	ResourceSaver.save(scene, resource.scene_path)
	mi.queue_free()

	for key in ['ao', 'normal']:
		if resource.textures.has(key):
			resource.textures.erase(key)
	ResourceSaver.save(resource, resource.resource_path)

func build_import_mesh(path: String, mhclo: MHCLO) -> ArrayMesh: 
	# build basis from obj file
	var obj_path = path.path_join(mhclo.obj_file_name)
	var obj_mesh := ObjToMesh.new(obj_path).run()
	var mesh = obj_mesh.mesh
	mhclo.mh2gd_index = obj_mesh.mh2gd_index
	
	#= obj_data.mh2gd_index
	var vertex = mhclo.vertex_data
	var delete_vertex = mhclo.delete_vertices
	var scale_config = mhclo.scale_config
	
	var new_mesh = ArrayMesh.new()
	var new_sf_arrays = mhclo.build_fitted_arrays(mesh, basis)
	var flags = mesh.surface_get_format(0)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays,[],{},flags)
	var shaded_mesh: ArrayMesh = HumanizerUtils.generate_normals_and_tangents(new_mesh)
	mhclo.mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(shaded_mesh)
	return shaded_mesh
