extends Node
class_name HumanizerResourceService

static var resource_mutex: Mutex = null
static var resources = null
static var exited = false

static func start():
	if resources == null:
		resources = {}
		resource_mutex = Mutex.new()

static func exit():
	resource_mutex.lock()
	exited = true
	resources.clear()
	resource_mutex.unlock()
	HumanizerLogger.debug("resource service shutdown")

static func clear_cache():
	resource_mutex.lock()
	resources.clear()
	resource_mutex.unlock()
	HumanizerLogger.debug("cleared resource cache")
	
static func assert_started():
	if exited:
		assert(false, "This should not happen.")
	start()
	if resource_mutex == null:
		resource_mutex = Mutex.new() # need a mutex for this mutex =]
	
#resource can be a Resource or Dictionary if json	
static func save_resource(path:String,resource) -> void:
	assert_started()
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if path.get_extension().to_lower() == "json":
		OSPath.save_json(path,resource)
	else:
		resource.take_over_path(path)
		ResourceSaver.save(resource,path)
	_set_resource(path,resource)
	
static func _set_resource(path:String,resource)->void:
	assert_started()
	resource_mutex.lock()
	resources[path] = resource
	resource_mutex.unlock()
		
static func load_resource(path:String): #can return Resource or Dictionary
	assert_started()
	var resource #can be resource or dictionary from json
	if resources.has(path):
		return resources[path]

	if path.get_extension().to_lower() == "json":
		resource = OSPath.read_json(path)
	else:
		resource = load(path)
		if resource == null and path.get_extension() in ["png","jpg","jpeg"]:
			#to load image at runtime if the .import file doesnt exist
			var image = Image.load_from_file(path)
			resource = ImageTexture.create_from_image(image)
			resource.resource_path = path
	
	_set_resource(path,resource)
	HumanizerLogger.debug("Resource loaded: " + path)
	return resource
