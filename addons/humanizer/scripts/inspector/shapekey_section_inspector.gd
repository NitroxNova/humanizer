@tool
extends MarginContainer

signal shapekey_value_changed(shapekeys: Dictionary)

var shapekeys
var human: Humanizer
var config: HumanConfig

func _ready() -> void:
	if shapekeys == null:
		return
		
	# Connect randomization controls
	%RandomizeButton.pressed.connect(_on_randomize_sliders.bind(human, %RandomizationSlider, %AsymmetrySlider))
		
	for key in shapekeys:
		var label = Label.new()
		label.text = key
		%GridContainer.add_child(label)
		
		var slider := HSlider.new()
		slider.name = key
		slider.editable = true
		slider.min_value = -1
		slider.max_value = 1
		slider.step = 0.01
		if config != null and config.shapekeys.has(key):
			slider.value = config.shapekeys[key]
		else:
			slider.value = 0
		slider.custom_minimum_size = Vector2i(150, 10)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%GridContainer.add_child(slider)
		slider.value_changed.connect(_on_value_changed.bind(key))
		slider.owner = self
		slider.unique_name_in_owner = true

		#var line_edit = LineEdit.new()
		#line_edit.text = str(0)
		#line_edit.text_changed.connect(_on_value_changed.bind(key))
		#line_edit.text_changed.connect(set_shapekey.bind(key))

func reset_sliders() -> void:
	for child in %GridContainer.get_children():
		if child is HSlider:
			child.value = 0
		
func _on_value_changed(value, key: String) -> void:
	shapekey_value_changed.emit({key: float(value)})

func _on_randomize_sliders(human: Humanizer, randomization: HSlider, asymmetry: HSlider) -> void:
	var rng = RandomNumberGenerator.new()
	for sk in shapekeys:
		var value: float
		if 'asym' in sk:
			value = rng.randfn(0, 0.5 * randomization.value)
		else:
			value = rng.randfn(0, 0.5 * asymmetry.value)
		human.set_shapekey(value, sk)
		get_node('%' + sk).value = value
	print('Randomized ' + name + ' sliders')
