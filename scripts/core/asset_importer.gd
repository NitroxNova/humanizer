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
		_scan_path_for_assets(_asset_path)
	else:                  # Bulk import task
		if not clean_only:
			print('Bulk asset import')
		else:
			print('Purging assets')
		for path in HumanizerGlobalConfig.config.asset_import_paths:
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
	_scan_path_for_assets(path)
	
func _scan_path_for_assets(path: String) -> void:
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
			var fl = file_name.get_file().get_basename()
			var _mhclo := MHCLO.new()
			_mhclo.parse_file(file_name)
			asset_data[fl] = {}
			asset_data[fl]['mhclo'] = _mhclo
	if asset_data.size() == 0:
		return
	
	# Look for rigged meshes
	for fl in asset_data:
		var rigged_mesh = path.path_join(fl + '_rigged.glb')
		if FileAccess.file_exists(rigged_mesh):
			asset_data[fl]['rigged'] = rigged_mesh
	
	for dir in contents.dirs:
		contents.files.append_array(OSPath.get_files(dir))
		
	# Get textures
	for file_name in contents.files:
		if file_name.get_extension() in ["png"]:
			# Eyes come with two textures for coloring iris, base and overlay
			if 'overlay' in file_name.get_file():
				textures['overlay'] = {'albedo': file_name}
			elif file_name.rsplit('.', true, 1)[-2].ends_with('normal'):
				textures['normal'] = file_name
			elif file_name.rsplit('.', true, 1)[-2].ends_with('ao'):
				textures['ao'] = file_name
			else:
				textures[file_name.get_file()] = file_name
	_generate_material(path, textures)
	
	for asset in asset_data.values():
		asset.textures = textures
		_import_asset(path, asset, false)
		#if asset.mhclo.tags.has('Hair') and asset.mhclo.tags.has('Long'):
		#	_import_asset(path, asset, true)

func _generate_material(path: String, textures: Dictionary) -> void:
	# Create material
	print('Generating material for ' + path.get_file())
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		if 'eyelash' in path.to_lower() or 'eyebrow' in path.to_lower() or 'hair' in path.to_lower():
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	
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
			mat.normal_enabled = true
			mat.normal_texture = load(normal)
		if ao != '':
			mat.ao_enabled = true
			mat.ao_texture = load(ao)
	
	# For the list of textures in the asset resource we only keep albedo textures
	# Normal/AO maps should not change I think
	if textures.has('normal'):
		textures.erase("normal")
	if textures.has('ao'):
		textures.erase('ao')
		
	var mat_path = path.path_join(path.get_file() + '_material.res')
	ResourceSaver.save(mat, mat_path)

func _import_asset(path: String, data: Dictionary, softbody: bool = false):
	# Build resource object
	var resource: HumanAsset
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		resource = HumanBodyPart.new()
	elif asset_type == HumanizerRegistry.AssetType.Clothes:
		resource = HumanClothes.new()

	# Mesh operations
	data.mesh = _build_import_mesh(path, data.mhclo)
	
	if data.has('rigged'):
		_build_bone_arrays(data)
	
	resource.path = path
	resource.resource_name = data.mhclo.resource_name
	print('Importing asset ' + resource.resource_name)
	
	resource.textures = data.textures.duplicate()
	if data.has('overlay'):
		HumanizerRegistry.overlays[resource.resource_name] = HumanizerOverlay.from_dict(data.overlay)
	if resource.scene_path in EditorInterface.get_open_scenes():
		printerr('Cannot process ' + resource.resource_name + ' because its scene is open in the editor')
		return
	
	
	# Set slot(s)
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		for tag in data.mhclo.tags:
			if tag in HumanizerGlobalConfig.config.body_part_slots:
				resource.slot = tag
		if resource.slot in ['', null]:
			printerr('Slot not recognized.  Check your mhclo tags.')
			return
		if HumanizerRegistry.body_parts.has(slot):
			if HumanizerRegistry.body_parts[slot].has(resource.resource_name):
				HumanizerRegistry.body_parts[slot].erase(resource.resource_name)
	elif asset_type == HumanizerRegistry.AssetType.Clothes:
		if HumanizerRegistry.clothes.has(resource.resource_name):
			HumanizerRegistry.clothes.erase(resource.resource_name)
		for tag in data.mhclo.tags:
			if tag in HumanizerGlobalConfig.config.clothing_slots:
				resource.slots.append(tag)
		if resource.slots.size() == 0:
			printerr('No slots found for clothes.  Check your mhclo tags.')
			return

	# Save resources
	data.mhclo.mh2gd_index = HumanizerUtils.get_mh2gd_index_from_mesh(data.mesh)
	resource.take_over_path(path.path_join(resource.resource_name + '.tres'))
	ResourceSaver.save(data.mhclo, resource.mhclo_path)

	# Put main resource in registry for easy access later
	if asset_type == HumanizerRegistry.AssetType.BodyPart:
		HumanizerRegistry.add_body_part_asset(resource)
	elif asset_type == HumanizerRegistry.AssetType.Clothes:
		HumanizerRegistry.add_clothes_asset(resource)

	# Create packed scene
	var mi: MeshInstance3D
	if softbody:
		mi = SoftBody3D.new()
	else:
		mi = MeshInstance3D.new()
	var scene = PackedScene.new()
	var mat = load(resource.material_path)
	mi.mesh = data.mesh
	mi.name = resource.resource_name
	mi.set_surface_override_material(0, mat)
	add_child(mi)
	mi.owner = self
	
	if resource.textures.has('overlay'):
		resource.default_overlay = HumanizerOverlay.from_dict(data.textures.overlay)	
		resource.textures.erase('overlay')

	data.mesh.take_over_path(resource.mesh_path)
	scene.pack(mi)
	ResourceSaver.save(data.mesh, resource.mesh_path)
	if softbody:
		ResourceSaver.save(resource, resource.resource_path + '_SoftBody')
		ResourceSaver.save(scene, resource.softbody_scene_path)
	else:
		ResourceSaver.save(resource, resource.resource_path)
		ResourceSaver.save(scene, resource.scene_path)

	ResourceSaver.save(resource, resource.resource_path)
	if data.has('rigged'):
		var rigged_resource = resource.duplicate()
		rigged_resource.rigged = true
		rigged_resource.resource_name = resource.resource_name + "_Rigged"
		ResourceSaver.save(rigged_resource, resource.resource_path.get_basename() + "_Rigged.tres")
		if asset_type == HumanizerRegistry.AssetType.BodyPart:
			HumanizerRegistry.add_body_part_asset(rigged_resource)
		elif asset_type == HumanizerRegistry.AssetType.Clothes:
			HumanizerRegistry.add_clothes_asset(rigged_resource)
	
	mi.queue_free()

func _build_import_mesh(path: String, mhclo: MHCLO) -> ArrayMesh: 
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

func _build_bone_arrays(data: Dictionary) -> void:
	var obj_arrays = (data.mesh as ArrayMesh).surface_get_arrays(0)
	var glb = data.rigged
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var error = gltf.append_from_file(glb, state)
	if error != OK:
		push_error('Failed to load glb : ' + glb)
		return
	var root = gltf.generate_scene(state)
	var skeleton:Skeleton3D = root.get_child(0).get_child(0)
	var glb_arrays = (skeleton.get_child(0) as ImporterMeshInstance3D).mesh.get_surface_arrays(0)
	
	#var glb_to_obj_idx := {}
	#var tol := 1e-4
	var mh_to_glb_idx = []
	mh_to_glb_idx.resize(data.mhclo.mh2gd_index.size())
	
	var max_id = roundi(1 / glb_arrays[Mesh.ARRAY_TEX_UV2][0].y) 
	for glb_id in glb_arrays[Mesh.ARRAY_TEX_UV2].size():
		var uv2 = glb_arrays[Mesh.ARRAY_TEX_UV2][glb_id]
		var mh_id = roundi(uv2.x * max_id)
		if mh_to_glb_idx[mh_id] == null:
			mh_to_glb_idx[mh_id] = []
		mh_to_glb_idx[mh_id].append(glb_id)
	
	var bone_config = []
	bone_config.resize(skeleton.get_bone_count())
	for bone_id in skeleton.get_bone_count():
		bone_config[bone_id] = {}
		bone_config[bone_id].name = skeleton.get_bone_name(bone_id)
		bone_config[bone_id].transform = skeleton.get_bone_rest(bone_id) #for local bone rotation
		bone_config[bone_id].parent = skeleton.get_bone_parent(bone_id)
		
		# This is ugly but it should work
		bone_config[bone_id].vertices = {'ids': []}

		## Find nearest vertex to bone and then nearest vertex in opposite direction
		var vtx1: Vector3
		var vtx2: Vector3
		var min_distancesq: float = 1e11
		var min_id: int = -1
		var bone_pos: Vector3 = skeleton.get_bone_global_rest(bone_id).origin
		if bone_pos == Vector3.ZERO:
			# IDK what neutral bone is for but we don't need it
			continue
		
		# Find closest distance squared
		for vtx in glb_arrays[Mesh.ARRAY_VERTEX].size():
			var distsq: float = bone_pos.distance_squared_to(glb_arrays[Mesh.ARRAY_VERTEX][vtx])
			if distsq < min_distancesq:
				min_distancesq = distsq
		# Now find vertex mh_id which is that far away
		for vtx in glb_arrays[Mesh.ARRAY_VERTEX].size():
			var distsq: float = bone_pos.distance_squared_to(glb_arrays[Mesh.ARRAY_VERTEX][vtx])
			if distsq == min_distancesq:  # Equal should be okay.  float math is deterministic on the same platform i think
				for mh_id in mh_to_glb_idx.size():
					if vtx in mh_to_glb_idx[mh_id]:
						min_id = mh_id
						vtx1 = glb_arrays[Mesh.ARRAY_VERTEX][vtx]
						break
			if min_id != -1:
				break
		# Add this id to the config
		bone_config[bone_id].vertices['ids'].append(min_id)
		
		min_distancesq = 1e11
		min_id = -1
		var opposite_side = bone_pos + (bone_pos - vtx1)
		for vtx in glb_arrays[Mesh.ARRAY_VERTEX].size():
			var distsq: float = opposite_side.distance_squared_to(glb_arrays[Mesh.ARRAY_VERTEX][vtx])
			if distsq < min_distancesq:
				min_distancesq = distsq
		for vtx in glb_arrays[Mesh.ARRAY_VERTEX].size():
			var distsq: float = opposite_side.distance_squared_to(glb_arrays[Mesh.ARRAY_VERTEX][vtx])
			if distsq == min_distancesq:
				for mh_id in mh_to_glb_idx.size():
					if vtx in mh_to_glb_idx[mh_id]:
						min_id = mh_id
						vtx2 = glb_arrays[Mesh.ARRAY_VERTEX][vtx]
						break
			if min_id != -1:
				break
				
		bone_config[bone_id].vertices['ids'].append(min_id)
		bone_config[bone_id].vertices['offset'] = bone_pos - 0.5 * (vtx1 + vtx2)
		# Now when we build the skeleton we just set the global bone position to
		# 0.5 * (v1 + v2) + offset
	
	var weights_override = []
	weights_override.resize(data.mhclo.mh2gd_index.size())
	var bones_override = []
	bones_override.resize(data.mhclo.mh2gd_index.size())
	var bones_per_vtx = glb_arrays[Mesh.ARRAY_BONES].size()/glb_arrays[Mesh.ARRAY_VERTEX].size()

	for mh_id in mh_to_glb_idx.size():
		var glb_id = mh_to_glb_idx[mh_id][0]
		bones_override[mh_id] = glb_arrays[Mesh.ARRAY_BONES].slice(glb_id*bones_per_vtx,(glb_id+1) * bones_per_vtx)
		weights_override[mh_id] = glb_arrays[Mesh.ARRAY_WEIGHTS].slice(glb_id*bones_per_vtx,(glb_id+1) * bones_per_vtx)
	
	data.mhclo.rigged_config = bone_config
	data.mhclo.rigged_bones = bones_override
	data.mhclo.rigged_weights = weights_override
		
