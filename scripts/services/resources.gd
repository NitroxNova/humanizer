extends Node
class_name HumanizerResourceService

static var resource_mutex: Mutex = null
static var resources = null
static var exited = false
static var empty = Resource.new()

static func start():
    if resources == null:
        resources = {}
        resource_mutex = Mutex.new()

static func exit():
    resource_mutex.lock()
    exited = true
    resources.clear()
    resource_mutex.unlock()
    HumanizerLogger.info("Cleaned up resource service.")

static func load_resource(path) -> Resource:
    if exited:
        return empty
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