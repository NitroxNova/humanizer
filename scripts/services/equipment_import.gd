extends Resource
class_name HumanizerEquipmentImportService

static func import(json_path:String,import_materials:=true):
	#load settings
	var settings = HumanizerUtils.read_json(json_path)
	var folder = json_path.get_base_dir()
	if import_materials:
		#generate material files
		HumanizerMaterialService.import_materials(folder)
	#load mhclo
	var mhclo := MHCLO.new()
	mhclo.parse_file(settings.mhclo)
	print('Importing asset ' + mhclo.resource_name)
	# Build resource object
	var resource := HumanizerEquipmentType.new()
	# Mesh operations
	_build_import_mesh(folder, mhclo)
		
	resource.path = folder
	resource.resource_name = mhclo.resource_name
	resource.textures = HumanizerMaterialService.search_for_generated_materials(folder)
	var save_path = folder.path_join(resource.resource_name + '.res')
	
	resource.display_name = settings.display_name
	
	resource.slots.clear()
	for slot in settings.slots:
		resource.slots.append(slot)
	if resource.slots.is_empty():
		printerr("Warning - " + resource.resource_name + " has no equipment slots, you can manually add them to the resource file.")
	
	_calculate_bone_weights(mhclo,settings)
	
	resource.take_over_path(save_path)
	ResourceSaver.save(resource, resource.resource_path)
	#build rigged equipment
	if settings.rigged_glb != "":
		var rigged_resource = resource.duplicate()
		rigged_resource.rigged = true
		rigged_resource.display_name = resource.display_name + " (Rigged)"
		rigged_resource.resource_name = resource.resource_name + "_Rigged"
		var rigged_fl = resource.resource_path.get_basename() + "_Rigged.res"
		rigged_resource.take_over_path(rigged_fl)
		ResourceSaver.save(rigged_resource, rigged_fl)
		HumanizerRegistry.add_equipment_type(rigged_resource)
		
	#save after adding bone/weights to mhclo
	mhclo.take_over_path(resource.mhclo_path)
	ResourceSaver.save(mhclo, mhclo.resource_path)
	#add main resource to registry
	HumanizerRegistry.add_equipment_type(resource)	

static func get_import_settings_path(mhclo_path)->String:
	var json_path = mhclo_path.get_basename()
	json_path += ".import_settings.json"
	#print(save_file)
	return json_path

static func get_equipment_resource_path(mhclo_path)->String:
	var res_path = mhclo_path.get_basename()
	res_path += ".res"
	return res_path

static func load_import_settings(mhclo_path:String):
	var json_path = get_import_settings_path(mhclo_path)
	var settings := {}
	if FileAccess.file_exists(json_path):
		#print("loading json") 
		#if you already know the json path just use this line 
		settings = HumanizerUtils.read_json(json_path)
	else:
		settings.mhclo_path = mhclo_path
		settings.slots = []
		settings.attach_bones = []
		var mhclo := MHCLO.new()
		mhclo.parse_file(mhclo_path)
		#print("loading resource")
		#try new resource naming convention first
		var res_path = get_equipment_resource_path(mhclo_path)
		if not FileAccess.file_exists(res_path):
			#old naming convention has to be loaded from mhclo
			res_path = mhclo_path.get_base_dir()
			res_path = res_path.path_join(mhclo.display_name + ".res")
		#print(res_path)
		if FileAccess.file_exists(res_path):
			var equip_res : HumanizerEquipmentType = load(res_path)
			for slot in equip_res.slots:
				settings.slots.append(slot)
			
		settings.display_name = mhclo.display_name
		settings.rigged_glb = search_for_rigged_glb(mhclo_path)
		for tag in mhclo.tags:
			if tag.begins_with("bone_name "):
				settings.attach_bones.append(tag.split(" ")[1])
				
	#override the slots from the folder - so if config changes they all update
	var slots_ovr = HumanizerGlobalConfig.config.get_folder_override_slots(mhclo_path)
	#print(slots_ovr)
	if not slots_ovr.is_empty():
		settings.slots = []
		settings.slots.append_array(slots_ovr)
		
	return settings
	
static func search_for_rigged_glb(mhclo_path:String)->String:
	var glb_path = mhclo_path.get_basename() + ".glb"
	#print(glb_path)
	if FileAccess.file_exists(glb_path):
		return glb_path
	return ""
	
static func import_all():
	print("TODO rewrite import all")

#static func import_all() -> void:
	##if _asset_path != '':  # User operating from scene
		##pass
		###dont really want to delete resources, just save over them..
		###for fl in OSPath.get_files(_asset_path):
			###if fl.get_extension() in ['res', 'tscn', 'tres']:
				###DirAccess.remove_absolute(fl)
		###_scan_path_for_assets(_asset_path)
	##else:                  # Bulk import task
		##if not clean_only:
			##print('Bulk asset import')
		##else:
			##print('Purging assets')
	#for path in HumanizerGlobalConfig.config.asset_import_paths:
		#for dir in OSPath.get_dirs(path.path_join('equipment')):
			##_clean_recursive(dir)
			#_scan_recursive(dir)
	#print("Reloading Registry")
	#HumanizerRegistry.load_all()
	#print('Done')
	
func _clean_recursive(path: String) -> void:
	for dir in OSPath.get_dirs(path):
		_clean_recursive(dir)
	for fl in OSPath.get_files(path):
		if fl.get_extension() in ['res', 'tscn', 'tres']:
			DirAccess.remove_absolute(fl)
	
#static func _scan_recursive(path: String) -> void:
	#for dir in OSPath.get_dirs(path):
		#_scan_recursive(dir)
	#_scan_path_for_assets(path)
	#
##static func _scan_path_for_assets(path: String) -> void:
	##var materials := {}
	##var obj_data = null
	##var contents = OSPath.get_contents(path)
	##var asset_data := {}
	###var overlay = {}
	##
	##for file_name in OSPath.get_files(path):
		##if file_name.get_extension() == "mhclo":
			##var fl = file_name.get_file().get_basename()
			##var _mhclo := MHCLO.new()
			##_mhclo.parse_file(file_name)
			##asset_data[fl] = {}
			##asset_data[fl]['mhclo'] = _mhclo
			##var rigged: String = path.path_join(asset_data[fl]['mhclo'].obj_file_name.get_basename() + '.glb')
			##if FileAccess.file_exists(rigged):
				##asset_data[fl]['rigged'] = rigged
	##
	##if asset_data.size() == 0:
		##return
	##
	##for dir in contents.dirs:
		##contents.files.append_array(OSPath.get_files(dir))
		##
	### Get textures
	##for file_name in contents.files:
		##if file_name.get_extension() == "mhmat":
			##var new_mat = HumanizerMaterialService.mhmat_to_material(file_name)
			##var mat_path = file_name.get_base_dir().path_join( new_mat.resource_name + '_material.res')
			##ResourceSaver.save(new_mat, mat_path)
			##materials[new_mat.resource_name] = mat_path


static func _calculate_bone_weights(mhclo:MHCLO,import_settings:Dictionary):
	var rigged_bone_weights
	if import_settings.rigged_glb != "":
		rigged_bone_weights = _build_rigged_bone_arrays(mhclo,import_settings.rigged_glb)
	for rig_name in HumanizerRegistry.rigs:
		var rig : HumanizerRig = HumanizerRegistry.rigs[rig_name]
		var skeleton_data = HumanizerRigService.init_skeleton_data(rig,false)
		HumanizerEquipmentService.interpolate_weights( mhclo,rig,skeleton_data)
		if import_settings.rigged_glb != "":
			for bone in mhclo.rigged_config:
				if bone.name != "neutral_bone":
					skeleton_data[bone.name] = {}
			HumanizerEquipmentService.interpolate_rigged_weights(mhclo,rigged_bone_weights,skeleton_data,rig_name)
			
static func _build_import_mesh(path: String, mhclo: MHCLO) -> ArrayMesh: 
	# build basis from obj file
	var obj_path = path.path_join(mhclo.obj_file_name)
	var obj_mesh := ObjToMesh.new(obj_path).run()
	var mesh = obj_mesh.mesh
	mhclo.mh2gd_index = obj_mesh.mh2gd_index
	mhclo.uv_array = obj_mesh.sf_arrays[Mesh.ARRAY_TEX_UV]
	mhclo.index_array = obj_mesh.sf_arrays[Mesh.ARRAY_INDEX]
	mhclo.custom0_array = obj_mesh.sf_arrays[Mesh.ARRAY_CUSTOM0]
	return mesh

static func _build_rigged_bone_arrays(mhclo:MHCLO,glb:String) -> Dictionary:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var error = gltf.append_from_file(glb, state)
	if error != OK:
		push_error('Failed to load glb : ' + glb)
		return {}
	var root = gltf.generate_scene(state)
	var skeleton:Skeleton3D = root.get_child(0).get_child(0)
	var glb_arrays = (skeleton.get_child(0) as ImporterMeshInstance3D).mesh.get_surface_arrays(0)
	
	var mh_to_glb_idx = []
	mh_to_glb_idx.resize(mhclo.mh2gd_index.size())
	
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
	weights_override.resize(mhclo.mh2gd_index.size())
	var bones_override = []
	bones_override.resize(mhclo.mh2gd_index.size())
	var bones_per_vtx = glb_arrays[Mesh.ARRAY_BONES].size()/glb_arrays[Mesh.ARRAY_VERTEX].size()

	for mh_id in mh_to_glb_idx.size():
		var glb_id = mh_to_glb_idx[mh_id][0]
		bones_override[mh_id] = glb_arrays[Mesh.ARRAY_BONES].slice(glb_id*bones_per_vtx,(glb_id+1) * bones_per_vtx)
		weights_override[mh_id] = glb_arrays[Mesh.ARRAY_WEIGHTS].slice(glb_id*bones_per_vtx,(glb_id+1) * bones_per_vtx)
	
	mhclo.rigged_config = bone_config
	var rigged_bone_weights = {}
	rigged_bone_weights.bones = bones_override
	rigged_bone_weights.weights = weights_override
	return rigged_bone_weights
