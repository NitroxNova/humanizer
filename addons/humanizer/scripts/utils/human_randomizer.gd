@tool
class_name HumanRandomizer
extends Node

#@export var human: HumanConfig
var categories: Dictionary
var randomization: Dictionary
var asymmetry: Dictionary
var shapekeys: Dictionary
var rng := RandomNumberGenerator.new()

static func equip_random_for_slot(human:HumanConfig,slot_name,left_right=false):
	if left_right:
		slot_name = "left" + slot_name
	var equip_type = HumanizerRegistry.filter_equipment({'slot': slot_name}).pick_random()
	if equip_type == null: #no equipment for slot
		return null
	var texture = equip_type.textures.keys().pick_random()
	var equipment = HumanizerEquipment.new(equip_type.resource_name,texture)
	human.add_equipment(equipment)
	if left_right:
		slot_name = slot_name.replace("left","right")
		var right_equip_name = equipment.type.replace('left', 'right')
		right_equip_name = right_equip_name.replace('Left', 'Right')
		human.add_equipment( HumanizerEquipment.new( right_equip_name,texture))
	
	
func randomize_body_parts(human:HumanConfig) -> void:
	equip_random_for_slot(human,"body")
	equip_random_for_slot(human,"eyebrow",true)
	equip_random_for_slot(human,"eyelash",true)
	equip_random_for_slot(human,"eye",true)
	equip_random_for_slot(human,"hair")
	human.eye_color = random_color()
	human.hair_color = random_color()
	human.skin_color = random_color()	

func randomize_clothes(human:HumanConfig) -> void:
	equip_random_for_slot(human,"torsoclothes")
	equip_random_for_slot(human,"legsclothes")
	equip_random_for_slot(human,"feetclothes")

func random_color():
	var color: Color = Color.BLACK
	color.r += rng.randf()
	color.g += rng.randf()
	color.b += rng.randf()
	return color
	
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
