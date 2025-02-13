@tool
class_name HumanRandomizer
extends Node

#@export var human: HumanConfig
var categories: Dictionary
var randomization: Dictionary
var asymmetry: Dictionary
var shapekeys: Dictionary
var rng := RandomNumberGenerator.new()

static func get_random_equipment_for_slot(slot_name):
	var equip_type = HumanizerRegistry.filter_equipment({'slot': slot_name}).pick_random()
	var texture = equip_type.textures.keys().pick_random()
	var equipment = HumanizerEquipment.new(equip_type.resource_name,texture)
	
	return equipment
	
func randomize_body_parts(human:HumanConfig) -> void:
	human.add_equipment(HumanizerEquipment.new("Body-Default"))
	randomize_eyebrows(human)
	randomize_eyelashes(human)
	randomize_eyes(human)
	randomize_hair(human)

func randomize_clothes(human:HumanConfig) -> void:
	human.add_equipment(get_random_equipment_for_slot("torsoclothes"))
	human.add_equipment(get_random_equipment_for_slot("legsclothes"))
	human.add_equipment(get_random_equipment_for_slot("feetclothes"))

func randomize_eyebrows(human:HumanConfig) -> void:
	## Assumes left and right eyebrow slots
	## Assumes same number of entries for both slots
	var left_eyebrow = get_random_equipment_for_slot("lefteyebrow")
	human.add_equipment(left_eyebrow )
	var right_eyebrow_name = left_eyebrow.type.replace('left', 'right')
	human.add_equipment( HumanizerEquipment.new( right_eyebrow_name,left_eyebrow.texture_name))

func randomize_eyes(human:HumanConfig) -> void:
	var color: Color = Color.BLACK
	color.r += rng.randf()
	color.g += rng.randf()
	color.b += rng.randf()
	human.add_equipment(HumanizerEquipment.new("LeftEye-LowPolyEyeball"))
	human.add_equipment(HumanizerEquipment.new("RightEye-LowPolyEyeball"))
	human.eye_color = color

func randomize_eyelashes(human:HumanConfig) -> void:
	human.add_equipment(HumanizerEquipment.new("LeftEyelash"))
	human.add_equipment(HumanizerEquipment.new("RightEyelash"))

func randomize_hair(human:HumanConfig) -> void:
	var color: Color = Color.BLACK
	color.r += rng.randf()
	color.g += rng.randf()
	color.b += rng.randf()
	human.add_equipment(get_random_equipment_for_slot("hair"))
	human.hair_color = color
	
func randomize_shapekeys(human:HumanConfig) -> void:
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
			if cat == 'Body':
				value **= 4
			value = abs(value)
			value = clamp(value, minval, maxval)
			values[sk] = value
			
	human.targets = values
