@tool
extends MeshInstance3D
class_name HumanizerMeshInstance

signal trigger_material_update(equip_type:String)

@export var material_config: HumanizerMaterial:
	set(value):
		if material_config != value:
			material_config = value
			initialize()

func initialize() -> void:
	# Make everything local
	if get_surface_override_material(0) != null:
		get_surface_override_material(0).resource_local_to_scene = true
	material_config.resource_local_to_scene = true
	material_config.material_updated.connect(update_material)

func update_material() -> void:
	trigger_material_update.emit(name)
