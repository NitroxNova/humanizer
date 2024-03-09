class_name HumanizerEditorInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(human):
	return human is Humanizer
	
func _parse_category(human, category):
	if category != 'humanizer.gd':
		return
	var scene = load("res://addons/humanizer/scenes/inspector/humanizer_inspector.tscn").instantiate()
	add_custom_control(scene)
	
	# Action buttons
	scene.get_node('%ResetButton').pressed.connect(human.reset_human)
	scene.get_node('%AdjustSkeletonButton').pressed.connect(human.adjust_skeleton)
	scene.get_node('%BakeButton').pressed.connect(human.bake)
	scene.get_node('%SaveButton').pressed.connect(_save_human.bind(human, scene.get_node('%HumanName')))
	scene.get_node('%RigOptionButton').human = human
	scene.get_node('%HideVerticesButton').pressed.connect(human.update_hide_vertices)
	if human.baked:
		scene.get_node('%VBoxContainer').add_child(HSeparator.new())
		var delete = false
		for child in scene.get_node('VBoxContainer').get_children():
			if delete:
				child.queue_free()
			if child.name == 'SaveMenu':
				delete = true
		return
	
	# Components Inspector
	scene.get_node('%MainColliderCheckBox').button_pressed = 'main_collider' in human.human_config.components
	scene.get_node('%RagdollCheckBox').button_pressed = 'ragdoll' in human.human_config.components
	scene.get_node('%MainColliderCheckBox').toggled.connect(human.set_component_state.bind('main_collider'))
	scene.get_node('%RagdollCheckBox').toggled.connect(human.set_component_state.bind('ragdoll'))

	# BodyParts inspector
	var bp_container = scene.get_node('%BodyPartsContainer') as BodyPartsInspector
	scene.get_node('%BodyPartsButton').pressed.connect(func(): bp_container.visible = not bp_container.visible)
	bp_container.body_part_changed.connect(func(bp): human.set_body_part(bp))
	bp_container.body_slot_cleared.connect(func(slot): human.clear_body_part(slot))
	bp_container.material_set.connect(func(slot, idx): human.set_body_part_material(slot, idx))
	bp_container.config = human.human_config
	human.on_human_reset.connect(bp_container.reset)

	# Clothes inspector
	var cl_container = scene.get_node('%ClothesContainer') as ClothesInspector
	scene.get_node('%ClothesButton').pressed.connect(func(): cl_container.visible = not cl_container.visible)
	cl_container.clothes_changed.connect(func(cl): human.apply_clothes(cl))
	cl_container.clothes_cleared.connect(func(sl): human.clear_clothes_in_slot(sl))
	cl_container.material_set.connect(func(cl, idx): human.set_clothes_material(cl, idx))
	cl_container.config = human.human_config
	human.on_human_reset.connect(cl_container.reset)
	human.on_clothes_removed.connect(cl_container.clear_clothes)

	# Skin controls
	var skin_options = scene.get_node('%SkinOptionsButton')
	skin_options.skin_selected.connect(human.set_skin_texture)
	skin_options.config = human.human_config
	human.on_human_reset.connect(skin_options.reset)
	
	# Add shapekey categories and sliders
	var sliders = {
		'RaceAge': [],
		'MuscleWeight': [],
		'Head': [],
		'Eyes': [],
		'Mouth': [],
		'Nose': [],
		'Ears': [],
		'Face': [],
		'Neck': [],
		'Chest': [],
		'Breasts': [],
		'Hips': [],
		'Arms': [],
		'Legs': [],
		'Misc': [],
	}
	var shapekeys = HumanizerUtils.get_shapekey_data()
	for name in shapekeys.shapekeys:
		if 'penis' in name.to_lower():
			continue
		if 'caucasian' in name.to_lower() or 'african' in name.to_lower() or 'asian' in name.to_lower():
			sliders['RaceAge'].append(name)
		elif 'cup' in name.to_lower() or 'bust' in name.to_lower() or 'breast' in name.to_lower() or 'nipple' in name.to_lower():
			sliders['Breasts'].append(name)
		elif 'averagemuscle' in name.to_lower() or 'minmuscle' in name.to_lower() or 'maxmuscle' in name.to_lower():
			sliders['MuscleWeight'].append(name)
		elif 'head' in name.to_lower() or 'brown' in name.to_lower() or 'top' in name.to_lower():
			sliders['Head'].append(name)
		elif 'eye' in name.to_lower():
			sliders['Eyes'].append(name)
		elif 'mouth' in name.to_lower():
			sliders['Mouth'].append(name)
		elif 'nose' in name.to_lower():
			sliders['Nose'].append(name)
		elif 'ear' in name.to_lower():
			sliders['Ears'].append(name)
		elif 'jaw' in name.to_lower() or 'cheek' in name.to_lower() or 'temple' in name.to_lower() or 'chin' in name.to_lower():
			sliders['Face'].append(name)
		elif 'arm' in name.to_lower() or 'hand' in name.to_lower() or 'finger' in name.to_lower() or 'wrist' in name.to_lower():
			sliders['Arms'].append(name)
		elif 'leg' in name.to_lower() or 'calf' in name.to_lower() or 'foot' in name.to_lower() or 'butt' in name.to_lower() or 'ankle' in name.to_lower() or 'thigh' in name.to_lower() or 'knee' in name.to_lower():
			sliders['Legs'].append(name)
		elif 'torso' in name.to_lower() or 'chest' in name.to_lower() or 'shoulder' in name.to_lower():
			sliders['Chest'].append(name)
		elif 'hip' in name.to_lower() or 'trunk' in name.to_lower() or 'pelvis' in name.to_lower() or 'waist' in name.to_lower() or 'pelvis' in name.to_lower() or 'stomach' in name.to_lower() or 'bulge' in name.to_lower():
			sliders['Hips'].append(name)
		elif 'hand' in name.to_lower() or 'finger' in name.to_lower():
			sliders['Hands'].append(name)
		elif 'neck' in name.to_lower():
			sliders['Neck'].append(name)
		else:
			sliders['Misc'].append(name)

	var cat_scene = load("res://addons/humanizer/scenes/inspector/slider_category_inspector.tscn")
	for cat in sliders:
		if sliders[cat].size() == 0:
			continue
		sliders[cat].sort()
		var button = Button.new()
		button.text = cat.replace('RaceAge', 'Race & Age').replace('MuscleWeight', 'Muscle & Weight')
		button.name = cat + 'Button'
		var cat_container = cat_scene.instantiate()
		cat_container.name = cat + 'Container'
		cat_container.visible = false
		cat_container.shapekeys = sliders[cat]
		cat_container.human = human
		scene.get_node('%VBoxContainer').add_child(button)
		scene.get_node('%VBoxContainer').add_child(cat_container)
		button.pressed.connect(func(): cat_container.visible = not cat_container.visible)
		cat_container.shapekey_value_changed.connect(human.set_shapekeys)
		cat_container.config = human.human_config
		human.on_human_reset.connect(cat_container.reset_sliders)

	# One final separator at the bottom
	scene.get_node('%VBoxContainer').add_child(HSeparator.new())
	
func _save_human(human: Humanizer, name: LineEdit) -> void:
	var save_name: String
	if name.text == null or name.text == '':
		save_name = 'MyHuman'
	else: 
		save_name = name.text
	human.serialize(save_name)
