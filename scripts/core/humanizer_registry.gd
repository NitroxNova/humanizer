@tool
class_name HumanizerRegistry
extends Node

static var body_parts := {}
static var clothes := {}
static var skin_textures := {}
static var skin_normals := {}
static var overlays := {}
static var rigs := {}

enum AssetType {
	BodyPart,
	Clothes
}


func _enter_tree() -> void:
	load_all()

static func load_all() -> void:
	_get_rigs()
	_load_body_parts()
	_load_clothes()
	_get_skin_textures()

static func add_body_part_asset(asset: HumanBodyPart) -> void:
	#print('Registering body part ' + asset.resource_name)
	if not body_parts.has(asset.slot):
		body_parts[asset.slot] = {}
	if body_parts[asset.slot].has(asset.resource_name):
		body_parts[asset.slot].erase(asset.resource_name)
	body_parts[asset.slot][asset.resource_name] = asset

static func add_clothes_asset(asset: HumanClothes) -> void:
	#print('Registering clothes ' + asset.resource_name)
	if clothes.has(asset.resource_name):
		clothes.erase(asset.resource_name)
	clothes[asset.resource_name] = asset

static func filter_clothes(filter: Dictionary) -> Array[HumanClothes]:
	var filtered_clothes: Array[HumanClothes]
	for cl in clothes.values():
		for key in filter:
			if key == &'slot':
				if filter[key] in cl.slots:
					filtered_clothes.append(cl)
	return filtered_clothes

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
					if file.get_extension() == 'png':
						if 'diffuse' in file.get_file().to_lower():
							filename = file.get_file().get_basename().replace('_diffuse', '')
							skin_textures[filename] = file
		for fl in OSPath.get_files(path.path_join('skin_normals')):
			if fl.get_extension() == 'png':
				skin_normals[fl.get_file().get_basename()] = fl

static func _load_body_parts() -> void:
	body_parts = {}
	for path in HumanizerGlobalConfig.config.asset_import_paths:
		for dir in OSPath.get_dirs(path.path_join('body_parts')):
			_scan_dir(dir, AssetType.BodyPart)
			
static func _load_clothes() -> void:
	clothes = {}
	for path in HumanizerGlobalConfig.config.asset_import_paths:
		for dir in OSPath.get_dirs(path.path_join('clothes')):
			_scan_dir(dir, AssetType.Clothes)

static func _scan_dir(path: String, asset_type: AssetType) -> void:
	var contents := OSPath.get_contents(path)
	for folder in contents.dirs:
		_scan_dir(folder, asset_type)
	for file in contents.files:
		if file.get_extension() not in ['tres', 'res']:
			continue
		var suffix: String = file.get_file().rsplit('.', true, 1)[0].split('_')[-1]
		if suffix in ['material', 'mhclo', 'mesh']:
			continue
		if asset_type == AssetType.BodyPart:
			var asset = load(file)
			if asset is HumanClothes:
				printerr(file.get_file() + ' was imported as clothes but should be a body part.  Please Re-import.')
				continue
			add_body_part_asset(asset)
		else:
			add_clothes_asset(load(file))
