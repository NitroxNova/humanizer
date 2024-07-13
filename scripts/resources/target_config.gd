@tool
extends Resource
class_name HumanTargetConfig

@export var raw:Dictionary #shapekey name and percent pairs
@export var macro:Dictionary #age, weight height ect
@export var combo:Dictionary #arrays of used targets for each macro combination  

func _init():
	for combo_name in HumanizerMacroService.macro_combos:
		combo[combo_name] = []
