extends Node
class_name HumanizerAPI

var task_semaphore: Semaphore = Semaphore.new()
var task_mutex: Mutex = Mutex.new()
var tasks: Array[Callable] = []
var threads: Array[Thread] = []
static var resource_mutex: Mutex = Mutex.new()

func setup():
    if not threads.is_empty(): return
    for i in range(0, 4):
        var thread = Thread.new()
        threads.append(thread)
        thread.start(_worker_thread)

func add_thread_task(callable: Callable):
    task_mutex.lock()
    tasks.push_back(callable)
    task_mutex.unlock()
    task_semaphore.post()

static func load_resource(path) -> Resource:
    # if OS.get_thread_caller_id() == OS.get_main_thread_id():
    #     printerr("main thread load_res")
    #     print_stack()
    if resource_mutex == null: # idk anymore
        return load(path)
    resource_mutex.lock()
    var resource = load(path)
    resource_mutex.unlock()
    return resource

func _worker_thread():
    while true:
        task_semaphore.wait()
        task_mutex.lock()
        if len(tasks) > 0:
            var task = tasks[0]
            tasks.remove_at(0)
            task_mutex.unlock()
            task.call()
            continue
        else:
            task_mutex.unlock()

func _exit_tree() -> void:
    for thread in threads: # todo cleanup not running probably
        thread.wait_to_finish()
        threads.erase(thread)

# todo: generate from config
# bugs: race conditions on resource loading
func generate_random_human(callback: Callable):
    setup()
    add_thread_task(func():
        var start = Time.get_ticks_msec()
        var randomizer = HumanRandomizer.new()
        randomizer.shapekeys = HumanizerTargetService.get_shapekey_categories()
        randomizer.randomization = {}
        randomizer.categories = {}
        randomizer.asymmetry = {}

        for cat in randomizer.shapekeys:
            randomizer.randomization[cat] = 0.5
            randomizer.asymmetry[cat] = 0.1 
            randomizer.categories[cat] = true

        var timer = Time.get_ticks_msec()

        var human_config: HumanConfig = HumanConfig.new()
        human_config.rig = HumanizerGlobalConfig.config.default_skeleton
        human_config.init_macros()

        randomizer.human = human_config
        randomizer.randomize_body_parts()
        randomizer.randomize_clothes()
        randomizer.randomize_shapekeys()

        var humanizer: Humanizer = Humanizer.new()
        humanizer.load_config_async(human_config)
        print("took " + str(Time.get_ticks_msec() - timer) + "ms to load config")

        timer = Time.get_ticks_msec()
        var character = humanizer.get_CharacterBody3D(false)
        print("took " + str(Time.get_ticks_msec() - timer) + "ms to get character body 3d")

        if OS.get_thread_caller_id() == OS.get_main_thread_id():
            printerr("main thread is building a humanizer character!")
        callback.call_deferred(character)
        print("Generated human in " + str(Time.get_ticks_msec() - start) + "ms")
    );
