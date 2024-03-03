@tool
extends EditorPlugin

# The new node type to be added
const humanizer_node = preload('res://addons/humanizer/scripts/humanizer.gd')
# Its icon in the scene tree
const node_icon = preload('res://addons/humanizer/icon.png')
# Editor inspectors 
var humanizer_inspector = HumanizerEditorInspectorPlugin.new()
var asset_import_inspector = AssetImporterInspectorPlugin.new()

# For mapping tool menu signals
const menu_ids := {
	'generate_base_mesh': 1,
	'read_shapekeys': 2,
	'rig_config': 4,
	'process_raw_data': 10,
	'import_eyes': 11,
	'import_eyebrows': 12,
	'import_eyelashes': 13,
	'import_teeth': 14,
	'import_tongue': 15,
	'import_hair': 16,
	'import_clothes': 21,
	'asset_importer': 30,
	'test': 999,
}

# Thread for background tasks
var thread := Thread.new()


func _enter_tree():
	# Load global config singleton
	add_autoload_singleton('HumanizerConfig', "res://addons/humanizer/scenes/humanizer_config.tscn")
	# Add editor inspector plugins
	add_inspector_plugin(humanizer_inspector)
	add_inspector_plugin(asset_import_inspector)
	# Add custom humanizer node
	add_custom_type('Humanizer', 'Node3D', humanizer_node, node_icon)
	# Add a submenu to the Project/Tools menu
	_add_tool_submenu()

func _exit_tree():
	remove_custom_type('Humanizer')
	remove_tool_menu_item('Humanizer')
	remove_inspector_plugin(humanizer_inspector)
	remove_inspector_plugin(asset_import_inspector)
	remove_autoload_singleton('HumanizerConfig')
	if thread.is_started():
		thread.wait_to_finish()
		
func _add_tool_submenu() -> void:
	# Should we cache this to clean up signals in _exit_tree?
	var popup_menu = PopupMenu.new()
	var preprocessing_popup = PopupMenu.new()
	var import_assets_popup = PopupMenu.new()
	
	preprocessing_popup.name = 'preprocessing_popup'
	preprocessing_popup.add_item('Generate Base Meshes', menu_ids.generate_base_mesh)
	preprocessing_popup.add_item('Read ShapeKey files', menu_ids.read_shapekeys)
	preprocessing_popup.add_item('Set Up Skeleton Configs', menu_ids.rig_config)
	
	import_assets_popup.name = 'import_assets_popup'
	import_assets_popup.add_item('Import Eyes Assets', menu_ids.import_eyes)
	import_assets_popup.add_item('Import Eyebrows Assets', menu_ids.import_eyebrows)
	import_assets_popup.add_item('Import Eyelashes Assets', menu_ids.import_eyelashes)
	import_assets_popup.add_item('Import Teeth Assets', menu_ids.import_teeth)
	import_assets_popup.add_item('Import Tongue Assets', menu_ids.import_tongue)
	import_assets_popup.add_item('Import Hair Assets', menu_ids.import_hair)
		
	popup_menu.add_child(preprocessing_popup)
	popup_menu.add_submenu_item('Preprocessing Tasks', 'preprocessing_popup')
	popup_menu.add_item('Run All Preprocessing', menu_ids.process_raw_data)
	popup_menu.add_item('Import All Assets', menu_ids.asset_importer)
	popup_menu.add_item('Run Test Function', menu_ids.test)
	
	add_tool_submenu_item('Humanizer', popup_menu)
	popup_menu.id_pressed.connect(_handle_menu_event)
	preprocessing_popup.id_pressed.connect(_handle_menu_event)
	#import_assets_popup.id_pressed.connect(_handle_menu_event)

func _handle_menu_event(id) -> void:
	if thread.is_alive():
		printerr('Thread busy...  Try again after current task completes')
		return
	if thread.is_started():
		thread.wait_to_finish()
	if id == menu_ids.generate_base_mesh:
		thread.start(_generate_base_meshes)
	elif id == menu_ids.read_shapekeys:
		thread.start(_read_shapekeys)
	elif id == menu_ids.rig_config:
		thread.start(_rig_config)
	elif id == menu_ids.process_raw_data:
		_process_raw_data()
	elif id == menu_ids.asset_importer:
		thread.start(_import_assets)
	elif id == menu_ids.test:
		thread.start(_test)


## Testing asset importer in its own window
func _open_asset_importer() -> void:
	var scene = load("res://addons/humanizer/scenes/inspector/asset_importer_inspector.tscn")
	var script = load("res://addons/humanizer/scripts/assets/asset_importer.gd")
	scene.set_script(script)
	HumanizerUtils.show_window(scene.instantiate())

#region Thread Tasks
func _process_raw_data() -> void:
	print_debug('Running all preprocessing')
	for task in [
		_generate_base_meshes,
		_read_shapekeys,
		_rig_config
	]:
		thread.start(task)
		while thread.is_alive():
			await get_tree().create_timer(1).timeout
		thread.wait_to_finish()
	
func _generate_base_meshes() -> void:
	ReadBaseMesh.new().run()
	
func _read_shapekeys() -> void:
	ShapeKeyReader.new().run()
	
func _rig_config() -> void:
	HumanizerSkeletonConfig.new().run()

func _import_assets() -> void:
	HumanizerAssetImporter.new().run()
	
func _test() -> void:
	var scene = load("res://addons/humanizer/data/assets/clothes/outfits/female_casualsuit01/female_casualsuit01_scene.tscn").instantiate()
	printerr((scene as MeshInstance3D).get_surface_override_material(0).resource_path)
#endregion
