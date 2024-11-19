extends Node
class_name HumanizerAPI

## todo
## release threads when quit is requested or sigkill
## document usage as a node
## generate from config easier
## 

var thread_count = 1
var task_semaphore: Semaphore = Semaphore.new()
var task_mutex: Mutex = Mutex.new()
var tasks: Array[Callable] = []
var threads: Array[Thread] = []
var thread_exit = false
static var resource_mutex: Mutex = Mutex.new()
static var resources = {}

func setup():
    if not threads.is_empty(): return
    for i in range(0, thread_count):
        var thread = Thread.new()
        threads.append(thread)
        thread.start(_worker_thread)

    HumanizerLogger.debug("Setup thread pool with " + str(thread_count) + " threads")

func add_thread_task(callable: Callable):
    task_mutex.lock()
    tasks.push_back(callable)
    task_mutex.unlock()
    task_semaphore.post()

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

func _worker_thread():
    while true:
        task_semaphore.wait()
        task_mutex.lock()
        if thread_exit:
            break
        if len(tasks) > 0:
            var task = tasks[0]
            tasks.remove_at(0)
            task_mutex.unlock()
            task.call()
            continue
        else:
            task_mutex.unlock()

func humanizer_cleanup() -> void:
    print("run")
    task_mutex.lock()
    thread_exit = true
    task_mutex.unlock()
    for thread in threads:
        task_semaphore.post()
        thread.wait_to_finish()
        threads.erase(thread)

func generate_random_human(callback: Callable):
    setup()
    add_thread_task(func():
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
