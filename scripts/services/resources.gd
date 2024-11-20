@tool
extends Resource
class_name HumanizerResourceService

static var resource_mutex: Mutex = Mutex.new()
static var resources = {}

static func load_resource(path) -> Resource:
    if resources == null:
        resources = {}

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