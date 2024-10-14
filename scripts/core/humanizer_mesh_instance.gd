@tool
extends MeshInstance3D
class_name HumanizerMeshInstance

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

func update_material() -> void:
	var mat: BaseMaterial3D = get_surface_override_material(0)
	if mat == null:
		mat = StandardMaterial3D.new()
		set_surface_override_material(0, mat)
	material_config.update_standard_material_3D(mat)
	
	if get_parent_node_3d():
		get_parent_node_3d().human_config.equipment[name].material_config = material_config
