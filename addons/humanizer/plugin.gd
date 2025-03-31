@tool
extends EditorPlugin

# Thread for background tasks
var thread := Thread.new()

func _enter_tree():
	init_config()
	# Load global config singleton
	add_autoload_singleton('HumanizerAPI', "res://addons/humanizer/scenes/humanizer_api.tscn")
	# Add a submenu to the Project/Tools menu
	_add_tool_submenu()
	
func _exit_tree():
	remove_custom_type('Humanizer')
	remove_tool_menu_item('Humanizer')
	remove_autoload_singleton('HumanizerAPI')
	if thread.is_started():
		thread.wait_to_finish()
		
func _add_tool_submenu() -> void:
	# Should we cache this to clean up signals in _exit_tree?
	var popup_menu = PopupMenu.new()
	popup_menu.add_item('Settings')
	popup_menu.set_item_metadata(popup_menu.item_count-1,_open_settings_popup)
	popup_menu.id_pressed.connect(_handle_menu_event.bind(popup_menu))
	add_tool_submenu_item('Humanizer', popup_menu)

func _handle_menu_event(id:int,popup_menu:PopupMenu) -> void:
	var callable : Callable = popup_menu.get_item_metadata(id)
	callable.call()

#region Thread Tasks
func _open_settings_popup():
	var popup = load("res://addons/humanizer/scenes/settings_popup.tscn").instantiate()
	get_editor_interface().popup_dialog(popup)

#endregion

func init_config():
	if not ProjectSettings.has_setting("addons/humanizer/asset_import_paths"):
		var property_info = {}
		var slots = {"Body Parts"={"body"="Body","righteye"="Right Eye","lefteye"="Left Eye","righteyebrow"="Right Eyebrow","lefteyebrow"="Left Eyebrow","righteyelash"="Right Eyelash","lefteyelash"="Left Eyelash","hair"="Hair","teeth"="Teeth","tongue"="Tongue",},
		"Clothing"={"headclothes"="Head","eyesclothes"="Eyes","mouthclothes"="Mouth","handsclothes"="Hands","armsclothes"="Arms","torsoclothes"="Torso","legsclothes"="Legs","feetclothes"="Feet"}}
		ProjectSettings.set_setting("addons/humanizer/slots", slots)
		#ProjectSettings.set_initial_value("addons/humanizer/slots",slots)
		
		ProjectSettings.clear("addons/humanizer/asset_import_paths")
		var import_paths:PackedStringArray = ["res://addons/humanizer/data/assets/","res://addons/humanizer_assets/","user://humanizer/","res://humanizer/"]
		ProjectSettings.set("addons/humanizer/asset_import_paths",import_paths)
		#var property_info = {
			#name = "addons/humanizer/asset_import_paths",
			#type = TYPE_ARRAY,
			#hint = PROPERTY_HINT_TYPE_STRING,
			#hint_string = str(TYPE_STRING) + "/" + str(PROPERTY_HINT_GLOBAL_DIR) 
		#}
		#ProjectSettings.add_property_info(property_info)
		##setting initial value makes it not work in game?
		#ProjectSettings.set_initial_value("addons/humanizer/asset_import_paths",import_paths)
		
		var human_export_path: String = 'res://data/humans/'
		ProjectSettings.set_setting("addons/humanizer/human_export_path", human_export_path)
		#ProjectSettings.set_initial_value("addons/humanizer/human_export_path", human_export_path)
		
		var character_body_script = "res://addons/humanizer/scripts/utils/human_controller.gd"
		ProjectSettings.set_setting("addons/humanizer/default_characterbody_script",character_body_script)
		#ProjectSettings.set_initial_value("addons/humanizer/default_characterbody_script",character_body_script)
		
		ProjectSettings.set_setting("addons/humanizer/default_rigidbody_script","")
		ProjectSettings.set_setting("addons/humanizer/default_staticbody_script","")
		ProjectSettings.set_setting("addons/humanizer/default_area_script","")
		
		var default_skeleton = "game_engine-RETARGETED"
		ProjectSettings.set_setting("addons/humanizer/default_skeleton",default_skeleton)
		#ProjectSettings.set_initial_value("addons/humanizer/default_skeleton",default_skeleton)
		
		var animation_tree = "res://addons/humanizer/data/animations/animation_tree.tscn"
		ProjectSettings.set_setting("addons/humanizer/default_animation_tree",animation_tree)
		#ProjectSettings.set_initial_value("addons/humanizer/default_animation_tree",animation_tree)
		
		var default_baked_root_node: String = "CharacterBody3D"
		ProjectSettings.set_setting("addons/humanizer/default_baked_root_node",default_baked_root_node)
		#ProjectSettings.set_initial_value("addons/humanizer/default_baked_root_node",default_baked_root_node)
		property_info = {
			name = "addons/humanizer/default_baked_root_node",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "CharacterBody3D,RigidBody3D,StaticBody3D,Area3D"
		}
		ProjectSettings.add_property_info(property_info)
		
		## Default character collider layer
		var default_character_physics_layers:int = 1 << 1
		ProjectSettings.set_setting("addons/humanizer/character_physics_layers",default_character_physics_layers)
		#ProjectSettings.set_initial_value("addons/humanizer/character_physics_layers",default_character_physics_layers)
		property_info = {
			name = "addons/humanizer/character_physics_layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
		}
		ProjectSettings.add_property_info(property_info)
		
		## Default character collider mask
		var default_character_physics_mask : int = 1 | 1 << 1
		ProjectSettings.set_setting("addons/humanizer/character_physics_mask",default_character_physics_mask)
		#ProjectSettings.set_initial_value("addons/humanizer/character_physics_mask",default_character_physics_mask)
		property_info = {
			name = "addons/humanizer/character_physics_mask",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
		}
		ProjectSettings.add_property_info(property_info)
		## Default static layer for StaticBody3D humans
		var default_staticbody_physics_layers : int = 1
		ProjectSettings.set_setting("addons/humanizer/staticbody_physics_layers",default_staticbody_physics_layers)
		#ProjectSettings.set_initial_value("addons/humanizer/staticbody_physics_layers",default_staticbody_physics_layers)
		property_info = {
			name = "addons/humanizer/staticbody_physics_layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
		}
		ProjectSettings.add_property_info(property_info)
		
		## Default ragdoll physics layer
		var default_physical_bone_layers : int = 1 << 2
		ProjectSettings.set_setting("addons/humanizer/physical_bone_layers",default_physical_bone_layers)
		#ProjectSettings.set_initial_value("addons/humanizer/physical_bone_layers",default_physical_bone_layers)
		property_info = {
			name = "addons/humanizer/physical_bone_layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
		}
		ProjectSettings.add_property_info(property_info)
		
		## Default ragdoll physics mask
		var default_physical_bone_mask : int = 1 | 1 << 2
		ProjectSettings.set_setting("addons/humanizer/physical_bone_mask",default_physical_bone_mask)
		#ProjectSettings.set_initial_value("addons/humanizer/physical_bone_mask",default_physical_bone_mask)
		property_info = {
			name = "addons/humanizer/physical_bone_mask",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
		}
		ProjectSettings.add_property_info(property_info)
		
		var default_character_render_layers : int = 1
		ProjectSettings.set_setting("addons/humanizer/character_render_layers",default_character_render_layers)
		#ProjectSettings.set_initial_value("addons/humanizer/character_render_layers",default_character_render_layers)
		property_info = {
			name = "addons/humanizer/character_render_layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_RENDER,
		}
		ProjectSettings.add_property_info(property_info)
		
		var atlas_resolution: int = 2048
		ProjectSettings.set_setting("addons/humanizer/atlas_resolution",atlas_resolution)
		#ProjectSettings.set_initial_value("addons/humanizer/atlas_resolution",atlas_resolution)
		property_info = {
			name = "addons/humanizer/atlas_resolution",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "1k:1024,2k:2048,4k:4096"
		}
		ProjectSettings.add_property_info(property_info)
		
		ProjectSettings.save()
		#ProjectSettings.save_custom("override.cfg") #works but why does it still save to project.godot as well? 
