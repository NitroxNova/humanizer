extends Node
class_name HumanizerAPI

## todo
## release threads when quit is requested or sigkill
## document usage as a node
## generate from config easier
## 


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



func generate_random_human(callback: Callable):
    HumanizerJobQueue.add_job(func():
        HumanizerLogger.debug("### Generating Human ###")
        HumanizerLogger.profile("generate_random_human", func():
            var human_config: HumanConfig = HumanConfig.new()
            human_config.rig = HumanizerGlobalConfig.config.default_skeleton

            var randomizer = HumanRandomizer.new()
            randomizer.shapekeys = HumanizerTargetService.get_shapekey_categories()
            randomizer.randomization = {}
            randomizer.categories = {}
            randomizer.asymmetry = {}

            for cat in randomizer.shapekeys:
                randomizer.randomization[cat] = 0.5
                randomizer.asymmetry[cat] = 0.1 
                randomizer.categories[cat] = true
            randomizer.human = human_config

            HumanizerLogger.profile("randomize", func():
                randomizer.randomize_body_parts()
                randomizer.randomize_clothes()
                randomizer.randomize_shapekeys()
            )

            human_config.init_macros()
            var humanizer: Humanizer = Humanizer.new()

            HumanizerLogger.profile("load human config", func():
                humanizer.load_config_async(human_config)
            )

            var character = HumanizerLogger.profile("load human config", func():
                return humanizer.get_CharacterBody3D(false) # there are race conditions in this function
            )

            if OS.get_thread_caller_id() == OS.get_main_thread_id():
                printerr("main thread is building a humanizer character!")
            callback.call_deferred(character)
        )
    );
