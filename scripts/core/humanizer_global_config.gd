@tool
class_name HumanizerGlobalConfig
extends Node

static var Instance: HumanizerGlobalConfig
@export var _config: HumanizerConfig:
	set(value):
		_config = value
		if Instance != null and Instance != self:
			Instance._config = value

static var config:
	get:
		if Instance != null:
			return Instance._config
		
func _init() -> void:
	## Just using this to have a static variable which is also exported.
	if Instance == null:
		Instance = self

func _ready():
	var config_path = "res://humanizer_global_config.res"
	if FileAccess.file_exists(config_path):
		_config = load(config_path)
	if _config == null:
		_config = HumanizerConfig.new()
