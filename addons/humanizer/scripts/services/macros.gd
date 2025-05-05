@tool
extends Resource
class_name HumanizerMacroService
static var debug = false

static func set_macros(new_macros:Dictionary,current_targets:Dictionary):
	#generate new dictionary to return
	var new_combo_data={}
	#Loop through all registered targets.
	for target in HumanizerRegistry.registered_macros.keys():
		#initialize mix value to 1.0
		var value = 1.0
		#tracking if anything is different than default
		var changed = false
		for macro in HumanizerRegistry.registered_macros[target]:
			#gets the default for the current macro.
			var macro_value = HumanizerRegistry.macro_defaults[macro]
			#checks if we changed the macro in the new keys.
			if macro in new_macros.keys():
				changed = true
				macro_value = new_macros[macro]
			#checks if it is in the old values. but does not note changes
			elif macro in current_targets.macro.keys():
				macro_value = current_targets.macro[macro]
			#performs linear intripelation between set points in the macro defintion for the target
			value *= expand_macro(HumanizerRegistry.registered_macros[target][macro], macro_value)
		#if there was a change in any of the macros the current target is registered against
		if changed:
			#See if it was changed from the previous values
			if target in current_targets.combo.keys():
				if current_targets.combo[target] != value:
					new_combo_data[target] = value
				else:
					#If both the values of the current target and the old target are 0 stop carrying it around
					if current_targets.combo[target] == 0.0:
						current_targets.combo[target].erase()
			else:
				#see if it is bigger than a rounding error.
				if value >0.001:
					new_combo_data[target] = value
	return new_combo_data

static func get_default_macros():
	#returns the defualt macros from registry
	return HumanizerRegistry.macro_defaults

static func expand_macro(table:Dictionary,macro_input:float):
	#generate a dictionary to keep the itripelation data
	var min = {"x_point":10.0,"score":10.0,"y_value":0.0}
	var max = {"x_point":-10.0,"score":10.0,"y_value":0.0}
	for key in table.keys():
		#calculates the "difference from point as a "score"
		var xVal = float(key)
		var score = abs(macro_input-xVal)
		#checks if it is less than our tartet point and a better score
		if xVal <= macro_input and score < min["score"]:
			min["score"] = score
			min["x_point"] = xVal
			min["y_value"] = table[key]
		#checks if it is more than our target point and a better score
		if xVal >= macro_input and score < max["score"]:
			max["score"] = score
			max["x_point"] = xVal
			max["y_value"] = table[key]
	# if our points are not the same point
	if min["x_point"]!=max["x_point"]:
		#linear intripelate between the 2 points
		var slope = (max["y_value"] - min["y_value"]) / (max["x_point"] - min["x_point"])
		return (macro_input - min["x_point"]) * slope + min["y_value"]
	else:
		#if they are the same... take the average... if someone puts a step, this will provide a single point of blending..
		return (min["y_value"]+max["y_value"])/2
	
