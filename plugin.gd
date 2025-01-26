@tool
extends EditorPlugin

# Thread for background tasks
var thread := Thread.new()

func _enter_tree():
	init_config()
	# Load global config singleton
	add_autoload_singleton('HumanizerGlobal', "res://addons/humanizer/scenes/humanizer_global.tscn")
	# Add a submenu to the Project/Tools menu
	_add_tool_submenu()
	
func _exit_tree():
	remove_custom_type('Humanizer')
	remove_tool_menu_item('Humanizer')
	remove_autoload_singleton('HumanizerGlobal')
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
	if not ProjectSettings.has_setting("addons/humanizer/slots"):
		var slots = {"Body Parts"={"body"="Body","righteye"="Right Eye","lefteye"="Left Eye","righteybrow"="Right Eyebrow","lefteyebrow"="Left Eyebrow","righteyelash"="Right Eyelash","lefteyelash"="Left Eyelash","hair"="Hair","teeth"="Teeth","tongue"="Tongue",},
		"Clothing"={"headclothes"="Head","eyesclothes"="Eyes","mouthclothes"="Mouth","handsclothes"="Hands","armsclothes"="Arms","torsoclothes"="Torso","legsclothes"="Legs","feetclothes"="Feet"}}
		ProjectSettings.set_setting("addons/humanizer/slots", slots)
		#ProjectSettings.save_custom("override.cfg") works but why does it still save to project.godot as well? 
