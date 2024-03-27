@tool
class_name HumanRandomizer
extends Node

@export var human: Humanizer
var categories: Dictionary
var randomization: Dictionary
var asymmetry: Dictionary
var shapekeys: Dictionary


func randomize_body_parts() -> void:
	randomize_eyebrows()

func randomize_eyebrows() -> void:
	## Assumes left and right eyebrow slots
	## Assumes same number of entries for both slots
	var rng = RandomNumberGenerator.new()
	var i := rng.randi_range(0, HumanizerRegistry.body_parts[&'LeftEyebrow'].size() - 1)
	var eyebrow_name = HumanizerRegistry.body_parts[&'LeftEyebrow'].keys()[i]
	human.set_body_part(HumanizerRegistry.body_parts[&'LeftEyebrow'][eyebrow_name])
	human.set_body_part(HumanizerRegistry.body_parts[&'RightEyebrow'][eyebrow_name.replace('Left', 'Right')])

func randomize_shapekeys() -> void:
	var rng = RandomNumberGenerator.new()
	var values := {}
	for cat in categories:
		if not categories[cat]:
			continue
		for sk in shapekeys[cat]:
			var minval := -1.
			var maxval := 1.
			if cat in ['Macro', 'Race']:
				minval = 0
				maxval = 1
			var mean := (minval + maxval) * 0.5
			var value := 0.
			# Explicitly asymmetric shapekeys
			if 'asym' in sk or sk.ends_with('-in') or sk.ends_with('-out'):
				value = rng.randfn(mean, 0.5 * asymmetry[cat])
			else:
				# Check for l- and r- versions and apply asymmetry
				var lkey = ''
				if sk.begins_with('r-'):
					lkey = 'l-' + sk.split('r-', true, 1)[1]
				if lkey in values:
					value = values[lkey] + rng.randfn(mean, 0.5 * asymmetry[cat])
				else:
					# Should be symmetric shapekey
					value = rng.randfn(mean, 0.5 * randomization[cat])
			value = clamp(value, minval, maxval)
			values[sk] = value
			
	human.set_shapekeys(values)
	human.adjust_skeleton()
	human.recalculate_normals()
