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

static func load_resource(path) -> Resource:
	if exited:
		assert(false, "This should not happen.")

	start()
	var resource: Resource
	if resources.has(path):
		resource = resources[path]
	else:
		resource = load(path)
		if resource_mutex == null:
			resource_mutex = Mutex.new() # need a mutex for this mutex =]
		resource_mutex.lock()
		resources[path] = resource
		resource_mutex.unlock()

		HumanizerLogger.debug("Resource loaded: " + path)
	return resource
