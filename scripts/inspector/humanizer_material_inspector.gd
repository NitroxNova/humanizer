class_name HumanizerMeshInstanceInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(node):
	return node is HumanizerMeshInstance
	
func _parse_category(node, category):
	if category != 'humanizer_mesh_instance.gd':
		return
		
	var scene = HumanizerAPI.load_resource("res://addons/humanizer/scenes/inspector/humanizer_material_inspector.tscn").instantiate()
	scene.get_node('%UpdateButton').pressed.connect(node.update_material)
	add_custom_control(scene)
