class_name HumanizerEditorInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(human):
	return human is Humanizer
	
func _parse_category(human, category):
	if not Engine.is_editor_hint():
		return
	if category != 'humanizer.gd':
		return
	var scene = load("res://addons/humanizer/scenes/inspector/humanizer_inspector.tscn").instantiate()
	add_custom_control(scene)
	
	# Header Section
	scene.get_node('%ResetButton').pressed.connect(func(): human.human_config = HumanConfig.new())
	scene.get_node('%AdjustSkeletonButton').pressed.connect(human.adjust_skeleton)
	scene.get_node('%RigOptionButton').human = human

	## Color pickers
	scene.get_node('%SkinColorPicker').color = human.skin_color
	scene.get_node('%HairColorPicker').color = human.hair_color
	scene.get_node('%EyeColorPicker').color = human.eye_color
	scene.get_node('%SkinColorPicker').color_changed.connect(func(color): human.skin_color = color)
	scene.get_node('%HairColorPicker').color_changed.connect(func(color): human.hair_color = color)
	scene.get_node('%EyeColorPicker').color_changed.connect(func(color): human.eye_color = color)
	
	# Components Inspector
	scene.get_node('%MainColliderCheckBox').button_pressed = 'main_collider' in human.human_config.components
	scene.get_node('%RagdollCheckBox').button_pressed = 'ragdoll' in human.human_config.components
	scene.get_node('%MainColliderCheckBox').toggled.connect(human.set_component_state.bind(&'main_collider'))
	scene.get_node('%RagdollCheckBox').toggled.connect(human.set_component_state.bind(&'ragdoll'))
	
	## Baking section
	scene.get_node('%SelectAllButton').pressed.connect(human.set_bake_meshes.bind(&'All'))
	scene.get_node('%SelectOpaqueButton').pressed.connect(human.set_bake_meshes.bind(&'Opaque'))
	scene.get_node('%SelectTransparentButton').pressed.connect(human.set_bake_meshes.bind(&'Transparent'))
	scene.get_node('%StandardBakeButton').pressed.connect(human.standard_bake)
	scene.get_node('%SurfaceName').text = human.bake_surface_name
	scene.get_node('%SurfaceName').text_changed.connect(func(value: String): human.bake_surface_name = value)
	scene.get_node('%BakeSurfaceButton').pressed.connect(human.bake_surface)
	scene.get_node('%HumanName').text_changed.connect(func(value: String): human.human_name = value)
	scene.get_node('%SaveButton').pressed.connect(human.save_human_scene)

	## Assets
	scene.get_node('%HideVerticesButton').pressed.connect(human.update_hide_vertices)
	scene.get_node('%UnHideVerticesButton').pressed.connect(human.restore_hidden_vertices)
	
	# BodyParts inspector
	var bp_container = scene.get_node('%BodyPartsContainer') as BodyPartsInspector
	scene.get_node('%BodyPartsButton').pressed.connect(func(): bp_container.visible = not bp_container.visible)
	bp_container.body_part_changed.connect(func(bp): human.set_body_part(bp))
	bp_container.body_slot_cleared.connect(func(slot): human.clear_body_part(slot))
	bp_container.material_set.connect(func(slot, idx): human.set_body_part_material(slot, idx))
	bp_container.config = human.human_config

	# Clothes inspector
	var cl_container = scene.get_node('%ClothesContainer') as ClothesInspector
	scene.get_node('%ClothesButton').pressed.connect(func(): cl_container.visible = not cl_container.visible)
	cl_container.clothes_changed.connect(func(cl): human.apply_clothes(cl))
	cl_container.clothes_cleared.connect(func(sl): human.clear_clothes_in_slot(sl))
	cl_container.material_set.connect(func(cl, idx): human.set_clothes_material(cl, idx))
	cl_container.config = human.human_config

	# Skin controls
	var skin_options = scene.get_node('%SkinOptionsButton')
	skin_options.skin_selected.connect(human.set_skin_texture)
	skin_options.config = human.human_config
	
	# Add shapekey categories and sliders
	var sliders = HumanizerUtils.get_shapekey_categories(human.shapekey_data)
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
		scene.get_node('%ShapekeysVBoxContainer').add_child(button)
		scene.get_node('%ShapekeysVBoxContainer').add_child(cat_container)
		button.pressed.connect(func(): cat_container.visible = not cat_container.visible)

