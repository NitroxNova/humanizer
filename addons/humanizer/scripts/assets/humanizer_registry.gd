@tool
class_name HumanizerRegistry
extends Node

static var body_parts := {}
static var clothes := {}
static var skin_textures := {}
static var overlays := {}
static var rigs := {}

enum AssetType {
	BodyPart,
	Clothes
}


func _ready():
	if Engine.is_editor_hint():
		load_all()

static func load_all() -> void:
	_get_rigs()
	_load_body_parts()
	_load_clothes()
	_get_skin_textures()

static func add_body_part_asset(asset: HumanBodyPart) -> void:
	print('Registering body part ' + asset.resource_name)
	if not body_parts.has(asset.slot):
		body_parts[asset.slot] = {}
	if body_parts[asset.slot].has(asset.resource_name):
		body_parts[asset.slot].erase(asset.resource_name)
	body_parts[asset.slot][asset.resource_name] = asset

static func add_clothes_asset(asset: HumanClothes) -> void:
	print('Registering clothes ' + asset.resource_name)
	if clothes.has(asset.resource_name):
		clothes.erase(asset.resource_name)
	clothes[asset.resource_name] = asset

static func _get_rigs() -> void:
	#  Create and/or cache rig resources
	for folder in HumanizerConfig.asset_import_paths:
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
	for path in HumanizerConfig.asset_import_paths:
		for dir in OSPath.get_dirs(path.path_join('skins')):
			if dir.get_file() == '_overlays':
				for file in OSPath.get_files(dir):
					overlays['skin'][file.get_basename()] = file
			else:
				var filename: String
				var mat := {}
				for file in OSPath.get_files(dir):
					if file.get_extension() == 'png':
						if 'diffuse' in file.get_file().to_lower():
							mat.albedo = file
							filename = file.get_file().replace('_diffuse', '').replace('.png', '')
				if mat.size() > 0:
					skin_textures[filename] = mat

static func _load_body_parts() -> void:
	for path in HumanizerConfig.asset_import_paths:
		for dir in OSPath.get_dirs(path.path_join('body_parts')):
			_scan_dir(dir, AssetType.BodyPart)
			
static func _load_clothes() -> void:
	for path in HumanizerConfig.asset_import_paths:
		for dir in OSPath.get_dirs(path.path_join('clothes')):
			_scan_dir(dir, AssetType.Clothes)

static func _scan_dir(path: String, asset_type: AssetType) -> void:
	var contents := OSPath.get_contents(path)
	for folder in contents.dirs:
		_scan_dir(folder, asset_type)
	for file in contents.files:
		if 'mhclo' not in file.get_file() and file.get_extension() == 'tres':
			print(file)
			if asset_type == AssetType.BodyPart:
				var asset = load(file)
				if asset is HumanClothes:
					printerr(file.get_file() + ' was imported as clothes but should be a body part.  Please Re-import.')
					continue
				add_body_part_asset(asset)
			else:
				add_clothes_asset(load(file))
