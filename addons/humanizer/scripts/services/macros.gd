@tool
extends Resource
class_name HumanizerMacroService
##The
static var macro_options = ["age","gender","height","weight","muscle","proportions","cupsize","firmness"]

static var race_options = ["african","asian","caucasian"]

static func set_macros(new_macros:Dictionary,current_targets:Dictionary):
	var new_combo_data={}
	for macro in HumanizerRegistry.macro_registry.keys():
		var macro_value = new_macros.get(macro,#Gets the macro from the new_macros
										current_targets.get(macro,#or gets the current_targets
															0.5)) #or sets 0.5 
		for target in HumanizerRegistry.macro_registry[macro].keys():
			if target in new_combo_data.keys():
				new_combo_data[target] *= expand_macro(HumanizerRegistry.registered_macros[target][macro],macro_value)
			else:
				new_combo_data[target] = expand_macro(HumanizerRegistry.registered_macros[target][macro],macro_value)
	return new_combo_data
	
static func expand_macro(table:Dictionary,key_value:float):
	var setpoints = table.keys()
	var min = {"point":0,"score":1,"value":0}
	var max = {"point":1,"score":1,"value":0}
	for key in table.keys():
		var xVal = float(key)
		if xVal < key_value:
			if (key_value-xVal) < min["score"]:
				min["point"] = xVal
				min["score"] = (xVal-key_value)
				min["value"] = table[key]
		else:
			if (xVal-key_value)<max["score"]:
				max["point"] = xVal
				max["score"] = (xVal-key_value)
				max["value"] = table[key]
	return lerpf(min["value"],max["value"],key_value)
