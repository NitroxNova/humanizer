@tool
class_name HumanRandomizer
extends Node

@export var human: HumanConfig
var categories: Dictionary
var randomization: Dictionary
var asymmetry: Dictionary
var shapekeys: Dictionary
var rng := RandomNumberGenerator.new()

static func get_random_equipment_for_slot(slot_name):
	var equip_type = Random.choice(HumanizerRegistry.filter_equipment({'slot': slot_name}))
	var texture = Random.choice(equip_type.textures.keys())
	var equipment = HumanizerEquipment.new(equip_type.resource_name,texture)
	
	return equipment
	
func randomize_body_parts() -> void:
	randomize_skin()
	randomize_eyebrows()
	randomize_eyelashes()
	randomize_eyes()
	randomize_hair()

func randomize_clothes() -> void:
	human.add_equipment(get_random_equipment_for_slot("TorsoClothes"))
	human.add_equipment(get_random_equipment_for_slot("LegsClothes"))
	human.add_equipment(get_random_equipment_for_slot("FeetClothes"))

func randomize_skin() -> void:
	human.set_skin_texture(Random.choice(HumanizerRegistry.skin_textures.keys()))

func randomize_eyebrows() -> void:
	## Assumes left and right eyebrow slots
	## Assumes same number of entries for both slots
	var left_eyebrow = get_random_equipment_for_slot("LeftEyebrow")
	human.add_equipment(left_eyebrow )
	var right_eyebrow_name = left_eyebrow.type.replace('Left', 'Right')
	human.add_equipment( HumanizerEquipment.new( right_eyebrow_name,left_eyebrow.texture_name))

func randomize_eyes() -> void:
	var color: Color = Color.BLACK
	color.r += rng.randf()
	color.g += rng.randf()
	color.b += rng.randf()
	human.add_equipment(HumanizerEquipment.new("LeftEyeBall-LowPoly"))
	human.add_equipment(HumanizerEquipment.new("RightEyeball-LowPoly"))
	human.eye_color = color

func randomize_eyelashes() -> void:
	human.add_equipment(HumanizerEquipment.new("LeftEyelash"))
	human.add_equipment(HumanizerEquipment.new("RightEyelash"))

func randomize_hair() -> void:
	var color: Color = Color.BLACK
	color.r += rng.randf()
	color.g += rng.randf()
	color.b += rng.randf()
	human.add_equipment(get_random_equipment_for_slot("Hair"))
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
			if cat == 'Body':
				value *= randf()
			value = abs(value)
			value = clamp(value, minval, maxval)
			values[sk] = value
			
	human.targets = values
