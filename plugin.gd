@tool
extends EditorPlugin


# For mapping tool menu signals
const menu_ids := {
	
	'read_shapekeys': 2,
	'rig_config': 4,
	'process_raw_data': 10,
	'reload_registry': 20,
	'test': 999,
}

# Thread for background tasks
var thread := Thread.new()


func _enter_tree():
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
	var preprocessing_popup = PopupMenu.new()
	var import_assets_popup = PopupMenu.new()
	
	preprocessing_popup.name = 'preprocessing_popup'
	
	preprocessing_popup.add_item('Read ShapeKey files', menu_ids.read_shapekeys)
	preprocessing_popup.add_item('Set Up Skeleton Configs', menu_ids.rig_config)
	
	popup_menu.add_child(preprocessing_popup)
	popup_menu.add_submenu_item('Preprocessing Tasks', 'preprocessing_popup')
	popup_menu.add_item('Run All Preprocessing', menu_ids.process_raw_data)
	popup_menu.add_item('Reload Registry', menu_ids.reload_registry)
	
	add_tool_submenu_item('Humanizer', popup_menu)
	popup_menu.id_pressed.connect(_handle_menu_event)
	preprocessing_popup.id_pressed.connect(_handle_menu_event)

func _handle_menu_event(id) -> void:
	if thread.is_alive():
		printerr('Thread busy...  Try again after current task completes')
		return
	if thread.is_started():
		thread.wait_to_finish()
	elif id == menu_ids.read_shapekeys:
		thread.start(_read_shapekeys)
	elif id == menu_ids.rig_config:
		thread.start(_rig_config)
	elif id == menu_ids.process_raw_data:
		_process_raw_data()
	elif id == menu_ids.reload_registry:
		HumanizerRegistry.load_all()
	elif id == menu_ids.test:
		thread.start(_test)

#region Thread Tasks
func _process_raw_data() -> void:
	print_debug('Running all preprocessing')
	for task in [
		
		_read_shapekeys,
		_rig_config
	]:
		thread.start(task)
		while thread.is_alive():
			await get_tree().create_timer(1).timeout
		thread.wait_to_finish()
	
func _read_shapekeys() -> void:
	ShapeKeyReader.new().run()
	
func _rig_config() -> void:
	HumanizerSkeletonConfig.new().run()

		
func _test() -> void:
	print(typeof('test'))
#endregion
