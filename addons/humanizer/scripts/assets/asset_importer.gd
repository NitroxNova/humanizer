@tool
class_name HumanizerAssetImporter 
extends Node

@export_dir var _asset_path = ''

var slot: String
var clothing_slots := []
var busy: bool = false
var asset_type: HumanizerRegistry.AssetType
var basis: Array

func run(clean_only: bool = false) -> void:
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
		if not clean_only:
			print('Bulk asset import')
		else:
			print('Purging assets')
		for path in HumanizerConfig.asset_import_paths:
			for dir in OSPath.get_dirs(path.path_join('body_parts')):
				_clean_recursive(dir)
				if not clean_only:
					_scan_recursive(dir)
			for dir in OSPath.get_dirs(path.path_join('clothes')):
				_clean_recursive(dir)
				if not clean_only:
					_scan_recursive(dir)
	print('Done')
	
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
			var _mhclo := MHCLO.new(file_name)
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
				textures['overlay'] = {'albedo': file_name}
			if file_name.rsplit('.', true, 1)[-2].ends_with('normal'):
				textures['normal'] = file_name
			elif file_name.rsplit('.', true, 1)[-2].ends_with('ao'):
				textures['ao'] = file_name
			else:
				textures[file_name.get_file()] = file_name
	_generate_material(path, textures)
	
	for asset in asset_data:
		asset_data[asset].textures = textures
		_import_asset(path, asset, asset_data[asset])

func _generate_material(path: String, textures: Dictionary) -> void:
	# Create material
	print('Generating material for ' + path.get_file())
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		if 'eyelash' in path.to_lower() or 'eyebrow' in path.to_lower() or 'hair' in path.to_lower():
			# For eyebrows/eyelashes alpha looks better but scissor is cheaper
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if 'hair' in path.to_lower():
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			#mat.grow = true
			#mat.grow_amount = 0.0005
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			#mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	
	if textures.size() > 0:
		var albedo := ''
		var normal := ''
		var ao := ''
		for t in textures:
			if t == 'normal':
				normal = textures[t]
			elif t == 'ao':
				ao = textures[t]
			elif albedo == '' and t != 'overlay': # Get first albedo as default
				albedo = textures[t]

		# Create normal map from albedo as bump map for eyebrows
		if 'eyebrow' in path.to_lower() and normal == '':
			print('Generating normal')
			var normal_texture = load(albedo) as Texture2D
			normal_texture = normal_texture.get_image()
			normal_texture.bump_map_to_normal_map()
			normal_texture = ImageTexture.create_from_image(normal_texture)
			normal = albedo.replace('.png', '_normal.png')
			ResourceSaver.save(normal_texture, normal)
		
		# Set material textures
		if albedo != '':
			mat.albedo_texture = load(albedo)
		if normal != '':
			mat.normal_texture = load(normal)
		if ao != '':
			mat.ao_texture = load(ao)
	
	# For the list of textures in the asset resource we only keep albedo textures
	# Normal/AO maps should not change I think
	if textures.has('normal'):
		textures.erase("normal")
	if textures.has('ao'):
		textures.erase('ao')
		
	var mat_path = path.path_join(path.get_file() + '_material.tres')
	ResourceSaver.save(mat, mat_path)

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
	
	# Set slot(s)
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		slot = asset_name.split('-')[0].split('_')[0]
		if slot not in HumanizerConfig.body_part_slots:
			printerr('File should be named {slot}-{asset}.mhclo.  Slot not recognized : ' + slot)
			return
		if HumanizerRegistry.body_parts.has(slot):
			if HumanizerRegistry.body_parts[slot].has(asset_name):
				HumanizerRegistry.body_parts[slot].erase(asset_name)
		resource.slot = slot
	elif asset_type == HumanizerRegistry.AssetType.Clothes:
		for slot in clothing_slots:
			if slot not in HumanizerConfig.clothing_slots:
				printerr('clothing slot not recognized : ' + slot)
				return
		# TODO SET CLOTHING SLOTS
		if asset_name.begins_with('Pants') or asset_name.begins_with('Shorts') or asset_name.begins_with('Skirt'):
			resource.slots.append('Legs')
		elif asset_name.begins_with('Shirt'):
			resource.slots.append('Torso')
		if HumanizerRegistry.clothes.has(asset_name):
			HumanizerRegistry.clothes.erase(asset_name)
	# Save resources
	mhclo.mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(mesh)
	resource.take_over_path(path.path_join(asset_name + '.tres'))
	ResourceSaver.save(mhclo, resource.mhclo_path)

	# Put main resource in registry for easy access later
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		HumanizerRegistry.add_body_part_asset(resource)
	elif asset_type == HumanizerRegistry.AssetType.Clothes:
		HumanizerRegistry.add_clothes_asset(resource)

	# Create packed scene
	var mi = MeshInstance3D.new()
	var scene = PackedScene.new()
	var mat = load(resource.material_path)
	mi.mesh = mesh
	mi.name = asset_name
	mi.set_surface_override_material(0, mat)
	add_child(mi)
	mi.owner = self
	
	if data.textures.has('overlay'):
		resource.default_overlay = HumanizerOverlay.from_dict(data.textures.overlay)	
	ResourceSaver.save(resource, resource.resource_path)
	mesh.take_over_path(resource.mesh_path)
	scene.pack(mi)
	ResourceSaver.save(mesh, resource.mesh_path)
	ResourceSaver.save(scene, resource.scene_path)
	ResourceSaver.save(resource, resource.resource_path)
	mi.queue_free()

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
	var new_sf_arrays = MeshOperations.build_fitted_arrays(mesh, basis, mhclo)
	var flags = mesh.surface_get_format(0)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays,[],{},flags)
	var shaded_mesh: ArrayMesh = MeshOperations.generate_normals_and_tangents(new_mesh)
	mhclo.mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(shaded_mesh)
	return shaded_mesh
