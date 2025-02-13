class_name HumanizerDebugUtils

static func generate_random_human(callback: Callable):
	HumanizerJobQueue.add_job(func():
		HumanizerLogger.debug("### Generating Human ###")
		HumanizerLogger.profile("generate_random_human", func():
			var human_config: HumanConfig = HumanConfig.new()
			var randomizer = HumanRandomizer.new()
			var humanizer: Humanizer = Humanizer.new()

			HumanizerLogger.profile("generate_random_human preamble", func():
				human_config.rig = ProjectSettings.get_setting("addons/humanizer/default_skeleton")

				randomizer.shapekeys = HumanizerTargetService.get_shapekey_categories()
				randomizer.randomization = {}
				randomizer.categories = {}
				randomizer.asymmetry = {}

				for cat in randomizer.shapekeys:
					randomizer.randomization[cat] = 0.5
					randomizer.asymmetry[cat] = 0.1 
					randomizer.categories[cat] = true
				randomizer.human = human_config
			)

			HumanizerLogger.profile("generate_random_human randomize", func():
				randomizer.randomize_body_parts(human_config)
				randomizer.randomize_clothes(human_config)
				randomizer.randomize_shapekeys(human_config)
			)

			human_config.init_macros()

			HumanizerLogger.profile("generate_random_human load human config", func():
				humanizer.load_config_async(human_config)
			)

			var character = humanizer.get_CharacterBody3D(false)

			if OS.get_thread_caller_id() == OS.get_main_thread_id():
				printerr("main thread is building a humanizer character!")
			HumanizerJobQueue.add_job_main_thread(callback.bind(character))
		)
	);
