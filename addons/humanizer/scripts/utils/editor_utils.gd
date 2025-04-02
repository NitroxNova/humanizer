class_name HumanizerEditorUtils

static func replace_node(old_node:Node,new_node:Node):
	old_node.replace_by(new_node)
	old_node.queue_free()

static func show_window(interior, closeable: bool = true, size=Vector2i(500, 500)) -> void:
	if not Engine.is_editor_hint():
		return
	var window = Window.new()
	if interior is PackedScene:
		interior = interior.instantiate()
	window.add_child(interior)	
	if closeable:
		window.close_requested.connect(func(): window.queue_free())
	window.size = size
	EditorInterface.popup_dialog_centered(window)

static func set_owner_for_children(node:Node):
	for child in node.get_children():
		set_node_owner(child,node)
	
static func set_node_owner(node:Node,owner:Node):
	for child in node.get_children():
		set_node_owner(child,owner)
	node.owner=owner
	
	
