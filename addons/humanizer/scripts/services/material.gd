extends Resource
class_name HumanizerMaterialService

static func search_for_materials(path:String):
	#print(path)
	var materials = {}
	var overlays = {}
	var files = OSPath.get_files_recursive(path)
	#print(files)
	#import images first
	for file:String in files:
		if file.get_extension() in ["png","jpg","jpeg"]:
			HumanizerResourceService.load_resource(file)
	
	for file:String in files:
		if file.get_extension()=="res":
			var mat_res = HumanizerResourceService.load_resource(file)
			var mat_id = file.get_file().get_basename()
			if mat_res is HumanizerMaterial:
				if mat_res.base_material == "":
					overlays[mat_id] = mat_res
				else:
					materials[mat_id] = mat_res 
			elif mat_res is StandardMaterial3D:
				materials[mat_id] = mat_res
		
	return {materials=materials,overlays=overlays}
