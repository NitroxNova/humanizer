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
	var type_class = get_type()
	if type_class == null:
		return
	if _texture_name == null: #use random material. if a blank texture is desired, set to "" empty string
		if get_type().textures.size() > 0:
			texture_name = Random.choice(get_type().textures.keys())
		else:
			texture_name = ""  
	else:
		texture_name = _texture_name
	material_config = _material_config

func get_type():
	if type in HumanizerRegistry.equipment:
		return HumanizerRegistry.equipment[type]
	printerr("Unkown equipment type: " + type)
