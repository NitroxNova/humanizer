@tool
extends MarginContainer

var shapekeys
var human: Humanizer

func _ready() -> void:
	if shapekeys == null:
		return
		
	# Connect randomization controls
	%RandomizeButton.pressed.connect(_on_randomize_sliders.bind(human, %RandomizationSlider, %AsymmetrySlider))
	%ResetButton.pressed.connect(_on_reset_sliders.bind(human))

	for key in shapekeys:
		var label = Label.new()
		label.text = key.replace('custom_', '').replace('Custom_', '').replace('custom-', '').replace('Custom-', '')
		%GridContainer.add_child(label)
		
		var slider := HSlider.new()
		slider.name = key
		slider.editable = true
		slider.min_value = -1
		slider.max_value = 1
		if name.begins_with('Macro') or name.begins_with('Race') or key in ['cupsize', 'firmness']:
			slider.min_value = 0

		slider.step = 0.01
		if human.human_config != null and human.human_config.shapekeys.has(key):
			slider.value = human.human_config.shapekeys[key]
		else:
			slider.value = 0

		slider.custom_minimum_size = Vector2i(150, 10)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%GridContainer.add_child(slider)
		slider.drag_ended.connect(_on_value_changed.bind(slider))
		slider.owner = self
		slider.unique_name_in_owner = true

		#var line_edit = LineEdit.new()
		#line_edit.text = str(0)
		#line_edit.text_changed.connect(_on_value_changed.bind(key))
		#line_edit.text_changed.connect(set_shapekey.bind(key))

func _on_value_changed(changed: bool, slider: HSlider) -> void:
	var key = slider.name
	var value = slider.value
	if name == 'RaceContainer':
		# Do some normalization so race shapekeys always sum to 1
		var sliders := {}
		for sk in shapekeys:
			sliders[sk] = get_node('%' + sk) as HSlider
		# Get sum of other races
		var other_total: float = 0
		for sk in sliders:
			if sk != key:
				other_total += sliders[sk].value
		# Set new values on other races in same ratio, but everything sums to 1
		for sk in sliders:
			if sk != key:
				sliders[sk].value *= (1 - value) / other_total
		# Send all results back to human
		var values := {}
		for sk in sliders:
			values[sk] = sliders[sk].value
		human.set_shapekeys(values)
	else:
		human.set_shapekeys({key: float(value)})
	
func _on_reset_sliders(human: Humanizer) -> void:
	var values := {}
	for sk in shapekeys:
		var slider: HSlider = get_node('%' + sk)
		var value = (slider.min_value + slider.max_value) * 0.5
		slider.value = value
		values[sk] = value
	human.set_shapekeys(values)
	print('Reset ' + name + ' sliders')
	
func _on_randomize_sliders(human: Humanizer, randomization: HSlider, asymmetry: HSlider) -> void:
	var rng = RandomNumberGenerator.new()
	var values := {}
	for sk in shapekeys:
		var slider: HSlider = get_node('%' + sk)
		var value: float
		var mean = (slider.min_value + slider.max_value) * 0.5
		# Explicitly asymmetric shapekeys
		if 'asym' in sk or sk.ends_with('-in') or sk.ends_with('-out'):
			value = rng.randfn(mean, 0.5 * asymmetry.value)
		else:
			# Check for l- and r- versions and apply asymmetry
			var lkey = ''
			if sk.begins_with('r-'):
				lkey = 'l-' + sk.split('r-', true, 1)[1]
			if lkey in values:
				value = values[lkey] + rng.randfn(mean, 0.5 * asymmetry.value)
			else:
				# Should be symmetric shapekey
				value = rng.randfn(mean, 0.5 * randomization.value)
		value = clamp(value, slider.min_value, slider.max_value)
		value = abs(value)
		get_node('%' + sk).value = value
		values[sk] = value
	human.set_shapekeys(values)
	print('Randomized ' + name.replace('Container', '') + ' sliders')
