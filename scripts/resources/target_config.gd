@tool
extends Resource
class_name HumanTargetConfig

@export var raw:Dictionary #shapekey name and percent pairs
@export var macro:Dictionary #age, weight height ect
@export var combo:Dictionary #arrays of used targets for each macro combination  

func _init():
	for combo_name in HumanizerMacroService.macro_combos:
		combo[combo_name] = []

func init_macros():
	macro = HumanizerMacroService.get_default_macros()
	var new_macros = HumanizerMacroService.get_macro_shapekey_values(macro)
	raw.merge(new_macros.targets,true)
	combo = new_macros.combos
