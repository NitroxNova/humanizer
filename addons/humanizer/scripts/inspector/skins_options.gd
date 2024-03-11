@tool
class_name HumanizerSkinsOptions
extends OptionButton

var config: HumanConfig

signal skin_selected(name:String, data: Dictionary)


func _ready() -> void:
	var textures = HumanizerRegistry.skin_textures
	clear()
	item_selected.connect(_skin_selected)
	add_item("None")
	for skin in textures:
		add_item(skin)
	
	if config != null:
		if not config.body_part_materials.has(&'skin'):
			selected = 0
			return
		for item in item_count:
			if get_item_text(item) == config.body_part_materials[&'skin']:
				selected = item
				
func reset() -> void:
	selected = 0

func _skin_selected(idx: int) -> void:
	if idx == 0:
		skin_selected.emit("None")
	else:
		var name = get_item_text(idx)
		skin_selected.emit(name)
