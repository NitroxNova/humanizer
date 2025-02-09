@tool
class_name HumanizerRegistry
extends Node

static var equipment := {}
static var skin_normals := {}
static var overlays := {}
static var rigs := {}

func _init() -> void:
	load_all()

static func load_all() -> void:
	HumanizerLogger.profile("HumanizerRegistry", func():
		_get_rigs()
		_load_equipment()
		_get_materials()
	)
	
static func _get_materials():
	for equip_type in equipment.values():
		var mats = HumanizerMaterialService.search_for_materials(equip_type.mhclo_path)
		equip_type.textures = mats.materials
		equip_type.overlays = mats.overlays	
		
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
				elif (file.get_extension() == 'tscn' or file.ends_with(".tscn.remap")) and file.get_file().begins_with('general'):
					rigs[name].skeleton_retargeted_path = file.trim_suffix('.remap')
				elif file.get_extension() == 'tscn' or file.ends_with(".tscn.remap"):
					rigs[name].skeleton_path  = file.trim_suffix('.remap')
				elif file.get_extension() == 'res':
					rigs[name].rigged_mesh_path = file

static func _load_equipment() -> void:
	equipment={}
	for path in HumanizerGlobalConfig.config.asset_import_paths:
		for dir in OSPath.get_dirs(path.path_join('equipment')):
			_scan_dir(dir)

static func _scan_dir(path: String) -> void:
	var contents := OSPath.get_contents(path)
	for folder in contents.dirs:
		_scan_dir(folder)
	for file in contents.files:
		if file.get_extension() not in ['tres', 'res']: # only use .res  , .tres is renamed to .tres.remap on export (same for .tscn)
			continue
		var suffix: String = file.get_basename().get_extension()
		if suffix in ['material', 'mhclo']:
			continue
		var equip = HumanizerResourceService.load_resource(file)
		if equip is HumanizerEquipmentType:
			add_equipment_type(equip)
		else:
			printerr("unexpected resource type " + file)
