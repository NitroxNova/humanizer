extends Node

func generate_random_human() -> CharacterBody3D:
	var randomizer: HumanRandomizer = HumanRandomizer.new()
	## You have to feed in the following randomization parameters to the randomizer
	randomizer.shapekeys = HumanizerTargetService.get_shapekey_categories()
	randomizer.randomization = {}
	randomizer.categories = {}
	randomizer.asymmetry = {}
	for cat in randomizer.shapekeys:
		randomizer.randomization[cat] = 0.5
		randomizer.asymmetry[cat] = 0.1 
		randomizer.categories[cat] = true
	print('starting new human')
	var human_config: HumanConfig = HumanConfig.new()
	human_config.rig = HumanizerGlobalConfig.config.default_skeleton
	#human_config.enable_component(&'ragdoll')
	print('randomizing')
	randomizer.human = human_config
	#human_config.set_component_state(true, &'ragdoll')
	randomizer.randomize_body_parts()
	randomizer.randomize_clothes()
	randomizer.randomize_shapekeys()
	human_config.init_macros()
	var humanizer2: Humanizer = Humanizer.new()
	await humanizer2.load_config_async(human_config)
	var new_human = humanizer2.get_CharacterBody3D(false)
	return new_human