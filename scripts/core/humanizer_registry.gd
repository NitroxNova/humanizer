@tool
class_name HumanizerRegistry
extends Node

static var equipment := {}
static var skin_textures := {}
static var skin_normals := {}
static var overlays := {}
static var rigs := {}

func _init() -> void:
	load_all()

static func load_all() -> void:
	_get_rigs()
	_load_equipment()
	_get_skin_textures()

static func add_equipment_type(equip:HumanizerEquipmentType):
	#print('Registering equipment ' + equip.resource_name)
	if equipment.has(equip.resource_name):
		equipment.erase(equip.resource_name)
	equipment[equip.resource_name] = equip

static func filter_equipment(filter: Dictionary) -> Array[HumanizerEquipmentType]:
	var filtered: Array[HumanizerEquipmentType]
	for equip in equipment.values():
		for key in filter:
			if key == &'slot':
				if filter[key] in equip.slots:
					filtered.append(equip)
	return filtered

static func _get_rigs() -> void:
	#  Create and/or cache rig resources
	for folder in HumanizerGlobalConfig.config.asset_import_paths:
		var rig_path = folder.path_join('rigs')
		for dir in OSPath.get_dirs(rig_path):
			var name = dir.get_file()
			rigs[name] = HumanizerRig.new()
			rigs[name].resource_name = name
			for file in OSPath.get_files(dir):
				if file.get_extension() == 'json' and file.get_file().begins_with('rig'):
					rigs[name].mh_json_path = file
				elif file.get_extension() == 'json' and file.get_file().begins_with('weights'):
					rigs[name].mh_weights_path = file
				elif file.get_file() == 'skeleton_config.json':
					rigs[name].config_json_path = file
				elif file.get_file() == 'bone_weights.json':
					rigs[name].bone_weights_json_path = file
				elif file.get_extension() == 'tscn' and file.get_file().begins_with('general'):
					rigs[name].skeleton_retargeted_path = file
				elif file.get_extension() == 'tscn':
					rigs[name].skeleton_path = file
				elif file.get_extension() == 'res':
					rigs[name].rigged_mesh_path = file

static func _get_skin_textures() -> void:
	## load texture paths
	overlays['skin'] = {}
	skin_textures = {}
	for path in HumanizerGlobalConfig.config.asset_import_paths:
		for dir in OSPath.get_dirs(path.path_join('skins')):
			if dir.get_file() == '_overlays':
				for file in OSPath.get_files(dir):
					overlays['skin'][file.get_basename()] = file
			else:
				var filename: String
				for file in OSPath.get_files(dir):
					if file.get_extension() in ['png']:
						filename = file.get_file().get_basename()
						if 'diffuse' in filename.to_lower():
							filename = filename.replace('_diffuse', '')
						if filename.ends_with('_normal'):
							continue
						skin_textures[filename] = file
		for fl in OSPath.get_files(path.path_join('skin_normals')):
			if fl.get_extension() in ['png', 'jpg']:
				skin_normals[fl.get_file().get_basename()] = fl

static func _load_equipment() -> void:
	equipment={}
	for path in HumanizerGlobalConfig.config.asset_import_paths:
		for dir in OSPath.get_dirs(path.path_join('body_parts')):
			_scan_dir(dir)
		for dir in OSPath.get_dirs(path.path_join('clothes')):
			_scan_dir(dir)

static func _scan_dir(path: String) -> void:
	var contents := OSPath.get_contents(path)
	for folder in contents.dirs:
		_scan_dir(folder)
	for file in contents.files:
		if file.get_extension() not in ['tres', 'res']:
			continue
		var suffix: String = file.get_file().rsplit('.', true, 1)[0].split('_')[-1]
		if suffix in ['material', 'mhclo', 'mesh']:
			continue
		add_equipment_type(load(file))
