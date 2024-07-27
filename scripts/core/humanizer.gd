@tool
extends Resource
class_name Humanizer

var human_config:HumanConfig
var helper_vertex:PackedVector3Array = []
var mesh_arrays : Dictionary = {}

func _init(_human_config = null):
	if _human_config == null:
		human_config = HumanConfig.new()
		human_config.targets.init_macros()
	else:	
		human_config = _human_config
	helper_vertex = HumanizerTargetService.init_helper_vertex(human_config.targets)
	#mesh_arrays.body = HumanizerBodyService.load_mesh_arrays("rig",helper_vertex)

func set_targets(target_data:Dictionary):
	HumanizerTargetService.set_targets(target_data,human_config.targets,helper_vertex)

func get_foot_offset()->float:
	return HumanizerBodyService.get_foot_offset(helper_vertex)
	
func get_hips_height()->float:
	return HumanizerBodyService.get_hips_height(helper_vertex)

func get_head_height()->float:
	return HumanizerBodyService.get_head_height(helper_vertex)
	
func get_max_width()->float:
	return HumanizerBodyService.get_max_width(helper_vertex)
