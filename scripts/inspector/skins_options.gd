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
		var mat_config = config.material_configs.get(&'Body')
		if mat_config and mat_config.overlays.size() > 0:
			var texture = mat_config.overlays[0].albedo_texture_path.get_file().get_basename()
			texture = texture.replace('_diffuse', '').replace('_albedo', '')
			for item in item_count:
				if get_item_text(item) == texture:
					selected = item
		else:
			selected = 0
	
func reset() -> void:
	selected = 0

func _skin_selected(idx: int) -> void:
	if idx == 0:
		skin_selected.emit("None")
	else:
		var name = get_item_text(idx)
		skin_selected.emit(name)
