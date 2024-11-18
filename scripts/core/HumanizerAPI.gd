extends Node

var threads: Array[Thread] = []
var randomizer: HumanRandomizer = null

func create_thread(callable: Callable):
	var thread = Thread.new()
	threads.push_back(thread)
	thread.start(callable)

func _ready() -> void:
	for i in range(0, 6):
		threads.append(Thread.new())

func _process(delta: float) -> void:
	var remove_threads = []
	for thread in threads:
		if thread.is_started() and not thread.is_alive():
			remove_threads.append(thread)
	for thread in remove_threads:
		thread.wait_to_finish()
		threads.erase(thread)

func _exit_tree() -> void:
	for thread in threads:
		thread.wait_to_finish()
		threads.erase(thread)

# todo: generate from config
# bugs: they're eyeless
func generate_random_human(callback: Callable):
	create_thread(func():
		var start = Time.get_ticks_msec()
		if randomizer == null:
			randomizer = HumanRandomizer.new()
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
		print("Created human in " + str(round(Time.get_ticks_msec() - start)) + "ms")
	)
