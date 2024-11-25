@tool
extends Resource
class_name HumanizerEquipment

@export var type:String #base equipment definition, refers to the registry.equipment
@export var texture_name: String #currently selected texture name
@export var material_config: HumanizerMaterial

func _init(_type=null,_texture_name=null,_material_config=null): # https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html - Make sure that every parameter has a default value. Otherwise, there will be problems with creating and editing your resource via the inspector.
	#print("new equipment " + str(_type))
	if _type == null: 
		return #hasnt been loaded yet, due to the way godot creates resources, can be safely ignored
	type = _type
	var equip_type = get_type()
	if equip_type == null:
		return
	if _texture_name == null: #use default material. if a blank texture is desired, set to "" empty string
		if equip_type.default_material == "" or equip_type.default_material == null:
			#print("no default texture")
			if equip_type.textures.size() > 0:
				texture_name = Random.choice(equip_type.textures.keys())
			else:
				texture_name = ""
		else:
			texture_name = equip_type.default_material  
	else:
		texture_name = _texture_name
	material_config = _material_config
	if material_config == null:
		set_material(texture_name)

func set_material(material_name:String):
	var equip_type = get_type()
	var material
	var mat_path = ""
	if material_name in equip_type.textures:
		mat_path = equip_type.textures[material_name]
		material = HumanizerResourceService.load_resource(mat_path)
	else:
		material = StandardMaterial3D.new()
		mat_path = ""
	
	if material is StandardMaterial3D:
		material_config = HumanizerMaterial.new()
		material_config.base_material_path = mat_path
		material_config.add_overlay(HumanizerOverlay.from_material(material))
	elif material is HumanizerMaterial:
		material_config = material.duplicate(true)
		
	texture_name = material_name
		
func get_type():
	if type in HumanizerRegistry.equipment:
		return HumanizerRegistry.equipment[type]
	printerr("Unknown equipment type: " + type)
