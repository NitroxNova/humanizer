extends Node

var task_semaphore: Semaphore = Semaphore.new()
var task_mutex: Mutex = Mutex.new()
var tasks: Array[Callable] = []
var threads: Array[Thread] = []

func create_thread(callable: Callable):
	task_mutex.lock()
	tasks.push_back(callable)
	task_mutex.unlock()
	task_semaphore.post()

func _ready() -> void:
	for i in range(0, OS.get_processor_count()):
		var thread = Thread.new()
		threads.append(thread)
		thread.start(_worker_thread)

func _worker_thread():
	while true:
		task_semaphore.wait()
		task_mutex.lock()
		if len(tasks) > 0:
			var task = tasks[0]
			tasks.erase(task)
			task_mutex.unlock()
			task.call()
			continue
		else:
			task_mutex.unlock()
		

func _exit_tree() -> void:
	for thread in threads:
		thread.wait_to_finish()
		threads.erase(thread)

# todo: generate from config
# bugs: they're eyeless, race conditions on resource loading?, 
func generate_random_human(callback: Callable):
	create_thread(func():
		var randomizer = HumanRandomizer.new()
		randomizer.shapekeys = HumanizerTargetService.get_shapekey_categories()
		randomizer.randomization = {}
		randomizer.categories = {}
		randomizer.asymmetry = {}

		for cat in randomizer.shapekeys:
			randomizer.randomization[cat] = 0.5
			randomizer.asymmetry[cat] = 0.1 
			randomizer.categories[cat] = true

		var human_config: HumanConfig = HumanConfig.new()
		human_config.rig = HumanizerGlobalConfig.config.default_skeleton
		human_config.init_macros()

		randomizer.human = human_config
		randomizer.randomize_body_parts()
		randomizer.randomize_clothes()
		randomizer.randomize_shapekeys()

		var humanizer: Humanizer = Humanizer.new()
		humanizer.load_config_async(human_config)
		var character = humanizer.get_CharacterBody3D(false)
		callback.call_deferred(character)
	);

