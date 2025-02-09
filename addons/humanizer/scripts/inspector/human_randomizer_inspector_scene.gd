@tool
extends MarginContainer

var human_rnd: HumanRandomizer
var human_config : HumanConfig
var shapekeys := {}
var enabled_cats := {}
var rand_sliders := {}
var asym_sliders := {}

func setup(_human_rnd: HumanRandomizer, _human_config:HumanConfig):
	human_rnd = _human_rnd
	human_config = _human_config
	var hbox = %VBoxContainer/HBoxContainer
	if human_rnd.human == null:
		hbox.queue_free()
		return
	%RandomizeShapekeysButton.pressed.connect(_randomize_shapekeys)
	%RandomizeBodyPartsButton.pressed.connect(human_rnd.randomize_body_parts)
	%RandomizeClothesButton.pressed.connect(human_rnd.randomize_clothes)
	shapekeys = HumanizerTargetService.get_shapekey_categories()
	for cat in shapekeys:
		if shapekeys[cat].size() == 0:
			continue
		var cat_box = hbox.duplicate(true)
		enabled_cats[cat] = cat_box.get_node('CheckBox') as CheckBox
		rand_sliders[cat] = cat_box.get_node('RandSlider') as HSlider
		asym_sliders[cat] = cat_box.get_node('AsymSlider') as HSlider
		rand_sliders[cat].drag_ended.connect(_on_rand_slider_value_changed.bind(rand_sliders[cat], cat))
		asym_sliders[cat].drag_ended.connect(_on_asym_slider_value_changed.bind(asym_sliders[cat], cat))
		if human_rnd.randomization.has(cat):
			rand_sliders[cat].value = human_rnd.randomization[cat]
		if human_rnd.asymmetry.has(cat):
			asym_sliders[cat].value = human_rnd.asymmetry[cat]
		enabled_cats[cat].text = cat
		if cat == 'Macro' or cat == 'Race':
			(enabled_cats[cat] as CheckBox).button_pressed = false
		else:
			(enabled_cats[cat] as CheckBox).button_pressed = true
		%VBoxContainer.add_child(cat_box)
		cat_box.owner = self
	hbox.queue_free()

func _randomize_shapekeys() -> void:
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
	human_rnd.randomize_shapekeys(human_config)

func _on_rand_slider_value_changed(changed: bool, slider: HSlider, cat: String) -> void:
	human_rnd.randomization[cat] = slider.value
	
func _on_asym_slider_value_changed(changed: bool, slider: HSlider, cat: String) -> void:
	human_rnd.asymmetry[cat] = slider.value
	
