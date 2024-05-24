class_name AssetImporterInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(node):
	return node is HumanizerAssetImporter
	
func _parse_category(importer, category):
	if category != 'asset_importer.gd':
		return
	var scene = load("res://addons/humanizer/scenes/inspector/asset_importer_inspector.tscn").instantiate()
	add_custom_control(scene)
	
	scene.get_node('%ImportButton').pressed.connect(importer.run)
