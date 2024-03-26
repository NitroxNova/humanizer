@tool
extends MarginContainer

var human_rnd: HumanRandomizer
var shapekeys := {}
var enabled_cats := {}
var rand_sliders := {}
var asym_sliders := {}

func setup(_human_rnd: HumanRandomizer):
	human_rnd = _human_rnd
	var hbox = %VBoxContainer/HBoxContainer
	if human_rnd.human == null:
		hbox.queue_free()
		return
	%RandomizeButton.pressed.connect(_randomize_sliders)
	shapekeys = HumanizerUtils.get_shapekey_categories(human_rnd.human.shapekey_data)
	for cat in shapekeys:
		if shapekeys[cat].size() == 0:
			continue
		var cat_box = hbox.duplicate(true)
		enabled_cats[cat] = cat_box.get_node('CheckBox') as CheckBox
		rand_sliders[cat] = cat_box.get_node('RandSlider') as HSlider
		asym_sliders[cat] = cat_box.get_node('AsymSlider') as HSlider
		enabled_cats[cat].text = cat
		if cat == 'Macro' or cat == 'Race':
			(enabled_cats[cat] as CheckBox).button_pressed = false
		else:
			(enabled_cats[cat] as CheckBox).button_pressed = true
		%VBoxContainer.add_child(cat_box)
		cat_box.owner = self
	hbox.queue_free()

func _randomize_sliders() -> void:
	var categories := {}
	var randomization := {}
	var asymmetry := {}
	for cat in enabled_cats:
		categories[cat] = enabled_cats[cat].button_pressed
		randomization[cat] = rand_sliders[cat].value
		asymmetry[cat] = asym_sliders[cat].value
	human_rnd.shapekeys = shapekeys
	human_rnd.categories = categories
	human_rnd.randomization = randomization
	human_rnd.asymmetry = asymmetry
	human_rnd.randomize()
