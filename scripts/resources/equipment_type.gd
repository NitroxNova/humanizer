@tool
extends Resource
class_name HumanizerEquipmentType #base equipment definition

@export var display_name : String
@export_dir var path: String #folder
@export var default_material: String
@export var material_override: String
@export var rig_config : HumanizerEquipmentRigConfig 
@export var textures: Dictionary
@export var overlays: Dictionary
@export var slots: Array[String]
#resource_name is already a variable, using for the equipment string id

var mhclo_path: String:
	get:
		return path.path_join(resource_name.replace("_Rigged","") + '.mhclo.res')

func get_import_settings():
		var json_path = path.path_join(resource_name.replace("_Rigged","") + '.import_settings.json')
		return HumanizerResourceService.load_resource(json_path)
		
func in_slot(slot_names:Array):
	for sl_name in slot_names:
		if sl_name in slots:
			return true
	return false

func is_rigged():
	if rig_config == null:
		return false
	return true
