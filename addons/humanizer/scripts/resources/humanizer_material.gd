@tool
extends Resource
class_name HumanizerMaterial

@export var base_material:String # "equip_id/material_id" 
@export var texture_overlays = {} #albedo, normal, ao..
static var material_property_names = get_standard_material_properties()

signal done_generating
var is_generating = false

static func create_from_standard_material(material:StandardMaterial3D)->HumanizerMaterial:
	var hu_mat = HumanizerMaterial.new()
	hu_mat.base_material = strip_texture_path(material.resource_path)
	for prop_name in material_property_names:
		if prop_name.ends_with("_texture") and material[prop_name] is Texture2D:
			var texture_name = prop_name.trim_suffix("_texture")
			if material[prop_name] != null:
				var data = {}
				data.texture=strip_texture_path(material[prop_name].resource_path)
				if texture_name == "normal":
					data.strength = material.normal_scale
				hu_mat.add_overlay(texture_name,data)	
	if not "albedo" in hu_mat.texture_overlays:
		hu_mat.add_overlay("albedo",{})
	hu_mat.texture_overlays.albedo[0].color = material.albedo_color
	return hu_mat

static func strip_texture_path(path:String)->String:
	path = path.trim_prefix("res://humanizer/material/")
	path = path.trim_suffix(".res")
	path = path.trim_suffix(".image")
	return path

static func full_texture_path(path:String,image:bool)->String:
	path = "res://humanizer/material".path_join(path)
	if image:
		path += ".image"
	path += ".res"
	return path

func add_overlay(layer_name:String,overlay_properties:Dictionary):
	if not layer_name in texture_overlays:
		texture_overlays[layer_name] = []
	# valid properties are name (required), texture ("equip_id/image_name"), offset : Vector2, 
	# color, gradient : Gradient2D, strength	
	texture_overlays[layer_name].append(overlay_properties)

func generate_material_3D(material:StandardMaterial3D=StandardMaterial3D.new()):
	is_generating = true
			
	## awaiting outside the main thread will switch to the main thread if the signal awaited is emitted by the main thread		
	HumanizerJobQueue.add_job_main_thread(func():
		var base_mat:StandardMaterial3D
		if base_material == "":
			base_mat = StandardMaterial3D.new()
		else:
			base_mat = load(full_texture_path(base_material,false))
		for prop_name in material_property_names:
			if prop_name.ends_with("_texture") and prop_name.trim_suffix("_texture") in texture_overlays:
				continue
			material[prop_name] = base_mat[prop_name]
	
		for texture_name in texture_overlays:
			if texture_overlays[texture_name].size() == 1: 
				var overlay = texture_overlays[texture_name][0]
				if "texture" in overlay:
					material[texture_name+"_texture"] = load(full_texture_path(overlay.texture,true))
				if texture_name == "albedo":
					if "color" in overlay:
						material.albedo_color = overlay.color
					else:
						material.albedo_color = Color.WHITE
			else:
				if texture_name == "albedo":		
					material.albedo_color = Color.WHITE
				elif texture_name == "normal":
					material.normal_scale = 1
				material[texture_name+"_texture"] = await HumanizerAPI.render_overlay_texture(texture_overlays[texture_name],texture_name)
		is_generating = false
		done_generating.emit()	
	)			
	return material
	
static func get_standard_material_properties() -> PackedStringArray:
	var prop_names = PackedStringArray()
	#only get properties unique to material, so we can copy those onto existing material instead of gernating a new material and using signals
	
	var base_props = []
	for prop in Material.new().get_property_list():
		base_props.append(prop.name)
	
	for prop in StandardMaterial3D.new().get_property_list():
		var flags = PROPERTY_USAGE_SCRIPT_VARIABLE
		#if prop.name not in base_props and (prop.usage & flags > 0):
		if prop.name not in base_props and prop.usage < 64:
			prop_names.append(prop.name) 
			#print(str(prop.usage) + " " + prop.name)
	if not ProjectSettings.get("rendering/lights_and_shadows/use_physical_light_units"):
		prop_names.remove_at( prop_names.find("emission_intensity"))

	return prop_names
#
