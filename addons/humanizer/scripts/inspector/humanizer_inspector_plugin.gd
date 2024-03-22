class_name HumanizerEditorInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(human):
	return human is Humanizer
	
func _parse_category(human, category):
	if category != 'humanizer.gd':
		return
	var scene = load("res://addons/humanizer/scenes/inspector/humanizer_inspector.tscn").instantiate()
	add_custom_control(scene)
	scene.human = human
