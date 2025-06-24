@tool
extends Resource
class_name HumanizerRegistry

static var equipment := {}
static var skin_normals := {}
static var overlays := {}
static var rigs := {}

#func _init() -> void:
	#load_all()
	#_get_rigs()

static func load_all() -> void:
	HumanizerLogger.profile("HumanizerRegistry", func():
		HumanizerTargetService.load_data()
		_load_equipment()
		_get_materials()
		load_animations()
	)
	
static func _get_materials():
	for equip_id in equipment:
		var equip_type = equipment[equip_id]
		var mats = HumanizerMaterialService.search_for_materials("res://humanizer/material".path_join(equip_id))
		equip_type.textures = mats.materials
		equip_type.overlays = mats.overlays	
	#now populate shared materials
	for equip_id in equipment:
		var equip_type = equipment[equip_id]
		if equip_type.material_override != "":
			var override_equip = equipment[equip_type.material_override]
			equip_type.textures = override_equip.textures
			equip_type.overlays = override_equip.overlays
		
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

static func load_animations() -> void:
	pass
		

static func _get_rigs() -> void:
	#  Create and/or cache rig resources
	for rig_path in OSPath.get_files_recursive("res://humanizer/skeleton"):
		var rig = load(rig_path)
		if rig is HumanizerRig:
			var rig_name = rig_path.get_file().get_basename()
			rig.resource_name = rig_name
			rigs[rig_name] = rig
			#print(rig.resource_name)
			#print(rig.weights.size())

static func _load_equipment() -> void:
	equipment={}
	var equip_folder = "res://humanizer/equipment"
	for dir in DirAccess.get_directories_at(equip_folder):
		_scan_dir(equip_folder.path_join(dir))

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
			equip.path = path
			add_equipment_type(equip)
		else:
			printerr("unexpected resource type " + file)
