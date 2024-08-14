@tool
class_name HumanRandomizer
extends Node

@export var human: HumanizerEditorTool
var categories: Dictionary
var randomization: Dictionary
var asymmetry: Dictionary
var shapekeys: Dictionary
var rng := RandomNumberGenerator.new()

func randomize_body_parts() -> void:
	randomize_skin()
	randomize_eyebrows()
	randomize_eyelashes()
	randomize_eyes()
	randomize_hair()

func randomize_clothes() -> void:
	var torso = Random.choice(HumanizerRegistry.filter_equipment({'slot': 'Torso'}))
	var legs = Random.choice(HumanizerRegistry.filter_equipment({'slot': 'Legs'}))
	var feet = Random.choice(HumanizerRegistry.filter_equipment({'slot': 'Feet'}))
	human.apply_clothes(torso)
	human.apply_clothes(legs)
	human.apply_clothes(feet)
	human.set_clothes_material(torso.resource_name, Random.choice(torso.textures.keys()))
	human.set_clothes_material(legs.resource_name, Random.choice(legs.textures.keys()))
	human.set_clothes_material(feet.resource_name, Random.choice(feet.textures.keys()))

func randomize_skin() -> void:
	human.set_skin_texture(Random.choice(HumanizerRegistry.skin_textures.keys()))

func randomize_eyebrows() -> void:
	## Assumes left and right eyebrow slots
	## Assumes same number of entries for both slots
	var eyebrow_name = Random.choice(HumanizerRegistry.filter_equipment({'slot': 'LeftEyebrow'}))
	human.set_body_part(HumanizerRegistry.equipment[eyebrow_name])
	human.set_body_part(HumanizerRegistry.equipment[eyebrow_name.replace('Left', 'Right')])

func randomize_eyes() -> void:
	var color: Color = Color.BLACK
	color.r += rng.randf()
	color.g += rng.randf()
	color.b += rng.randf()
	human.set_body_part(Random.choice(HumanizerRegistry.equipment[&'LeftEye']))
	human.set_body_part(Random.choice(HumanizerRegistry.equipment[&'RightEye']))
	if Engine.is_editor_hint():
		## This wil update the material immediately
		human.set_eye_color(color)
	else:
		human.eye_color = color

func randomize_eyelashes() -> void:
	var left = HumanizerRegistry.equipment[&'LeftEyelash']
	var right = HumanizerRegistry.equipment[&'RightEyelash']
	human.set_body_part(left)
	human.set_body_part(right)

func randomize_hair() -> void:
	var color: Color = Color.BLACK
	color.r += rng.randf()
	color.g += rng.randf()
	color.b += rng.randf()
	human.set_equipment_type(Random.choice(HumanizerRegistry.filter_equipment({'slot': 'Hair'})))
	human.hair_color = color
	
func randomize_shapekeys() -> void:
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
			value = abs(value)
			value = clamp(value, minval, maxval)
			values[sk] = value
			
	human.set_shapekeys(values)
