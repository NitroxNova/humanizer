class_name HumanRandomizerInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(human_rnd):
	return human_rnd is HumanRandomizer
	
func _parse_category(human_rnd, category):
	if category != 'human_randomizer.gd':
		return
	var scene = load("res://addons/humanizer/scenes/inspector/human_randomizer_inspector.tscn").instantiate()
	add_custom_control(scene)
	scene.setup(human_rnd)
