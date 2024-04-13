@tool
class_name HumanizerGlobalConfig
extends Node

static var Instance: HumanizerGlobalConfig
@export var _config: HumanizerConfig


static var config:
	get:
		if Instance != null:
			return Instance._config
		
func _enter_tree() -> void:
	## Not enforcing singleton pattern, but shouldn't be a problem.
	## Just using this to have a static variable which is also exported.
	Instance = self

