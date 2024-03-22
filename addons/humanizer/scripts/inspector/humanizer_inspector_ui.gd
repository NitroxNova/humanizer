@tool
extends Node

var human: Humanizer:
	set(value):
		human = value
		_setup_controls()

func _setup_controls():
	# Header Section
	%ResetButton.pressed.connect(func(): human.human_config = HumanConfig.new())
	%AdjustSkeletonButton.pressed.connect(human.adjust_skeleton)
	%RigOptionButton.human = human

	## Color picker s
	%SkinColorPicker.color = human.skin_color
	%HairColorPicker.color = human.hair_color
	%EyeColorPicker.color = human.eye_color
	%SkinColorPicker.color_changed.connect(func(color): human.skin_color = color)
	%HairColorPicker.color_changed.connect(func(color): human.hair_color = color)
	%EyeColorPicker.color_changed.connect(func(color): human.eye_color = color)
	
	# Components Inspector
	%MainColliderCheckBox.button_pressed = 'main_collider' in human.human_config.components
	%RagdollCheckBox.button_pressed = 'ragdoll' in human.human_config.components
	%MainColliderCheckBox.toggled.connect(human.set_component_state.bind(&'main_collider'))
	%RagdollCheckBox.toggled.connect(human.set_component_state.bind(&'ragdoll'))
	
	## Baking section
	%SelectAllButton.pressed.connect(human.set_bake_meshes.bind(&'All'))
	%SelectOpaqueButton.pressed.connect(human.set_bake_meshes.bind(&'Opaque'))
	%SelectTransparentButton.pressed.connect(human.set_bake_meshes.bind(&'Transparent'))
	%StandardBakeButton.pressed.connect(human.standard_bake)
	%SurfaceName.text = human.bake_surface_name
	%SurfaceName.text_changed.connect(func(value: String): human.bake_surface_name = value)
	%BakeSurfaceButton.pressed.connect(human.bake_surface)
	%HumanName.text_changed.connect(func(value: String): human.human_name = value)
	%SaveButton.pressed.connect(human.save_human_scene)

	## Assets
	%HideVerticesButton.pressed.connect(human.update_hide_vertices)
	%UnHideVerticesButton.pressed.connect(human.restore_hidden_vertices)
	
	# BodyParts inspector
	var bp_container = %BodyPartsContainer as BodyPartsInspector
	%BodyPartsButton.pressed.connect(func(): bp_container.visible = not bp_container.visible)
	bp_container.body_part_changed.connect(func(bp): human.set_body_part(bp))
	bp_container.body_slot_cleared.connect(func(slot): human.clear_body_part(slot))
	bp_container.material_set.connect(func(slot, idx): human.set_body_part_material(slot, idx))
	bp_container.config = human.human_config

	# Clothes inspector
	var cl_container = %ClothesContainer as ClothesInspector
	%ClothesButton.pressed.connect(func(): cl_container.visible = not cl_container.visible)
	cl_container.clothes_changed.connect(func(cl): human.apply_clothes(cl))
	cl_container.clothes_cleared.connect(func(sl): human.clear_clothes_in_slot(sl))
	cl_container.material_set.connect(func(cl, idx): human.set_clothes_material(cl, idx))
	cl_container.config = human.human_config

	# Skin controls
	var skin_options = %SkinOptionsButton
	skin_options.skin_selected.connect(human.set_skin_texture)
	skin_options.config = human.human_config
	
	# Shapekey categories and sliders
	var sliders = HumanizerUtils.get_shapekey_categories(human.shapekey_data)
	var cat_scene = load("res://addons/humanizer/scenes/inspector/slider_category_inspector.tscn")
	for cat in sliders:
		if sliders[cat].size() == 0:
			continue
		sliders[cat].sort()
		var button = Button.new()
		button.text = cat
		button.name = cat + 'Button'
		var cat_container = cat_scene.instantiate()
		cat_container.name = cat + 'Container'
		cat_container.visible = false
		cat_container.shapekeys = sliders[cat]
		cat_container.human = human
		%ShapekeysVBoxContainer.add_child(button)
		%ShapekeysVBoxContainer.add_child(cat_container)
		button.pressed.connect(func(): cat_container.visible = not cat_container.visible)
