@tool
class_name HumanizerGlobalConfig
extends Node

static var Instance: HumanizerGlobalConfig
@export var _config: HumanizerConfig


static var config:
	get:
		if Instance != null:
			return Instance._config
		
func _init() -> void:
	## Just using this to have a static variable which is also exported.
	if Instance == null:
		Instance = self

