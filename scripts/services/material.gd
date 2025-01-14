extends Resource
class_name HumanizerMaterialService

static func search_for_materials(path:String):
	var materials = {}
	var overlays = {}
	var files = OSPath.get_files_recursive(path)
	for file:String in files:
		if file.get_file()=="standard_material.json":
			var mat_id = file.get_base_dir().get_file() #folder name above
			var material = StandardMaterial3D.new()
			var mat_props = OSPath.read_json(file) #dont want to cache this so load directly
			for prop_name:String in mat_props:
				var prop_value = mat_props[prop_name]
				if material[prop_name] is Color:
					var color = Color()
					var rgb = prop_value.split_floats(",")
					color.r = rgb[0]
					color.g = rgb[1]
					color.b = rgb[2]
					material.set(prop_name,color)
				elif prop_name.ends_with("_texture"):
					var texture = HumanizerResourceService.load_resource(prop_value)
					material.set(prop_name,texture)
				else:
					material.set(prop_name,prop_value)
			materials[mat_id] = material	
	return {materials=materials,overlays=overlays}
