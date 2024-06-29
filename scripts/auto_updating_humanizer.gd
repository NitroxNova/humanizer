@tool
class_name AutoUpdatingHumanizer
extends Humanizer

## For use in character editor scenes where the character should be 
## continuously updated with every change

func set_human_config(config: HumanConfig) -> void:
	human_config = config
	
func set_hair_color(color: Color) -> void:
	hair_color = color

func set_eyebrow_color(color: Color) -> void:
	eyebrow_color = color

func set_skin_color(color: Color) -> void:
	skin_color = color
	if body_mesh != null and body_mesh is HumanizerMeshInstance:
		body_mesh.material_config.update_material()
	
func set_eye_color(color: Color) -> void:
	eye_color = color
	var slots = ["LeftEye","RightEye","Eyes"]
	for equip in human_config.get_equipment_in_slots(slots):
		equip.node.material_config.update_material()
	
func add_equipment(equip: HumanAsset) -> void:
	super(equip)
	_fit_equipment_mesh(equip)
	if equip.node is HumanizerMeshInstance:
		equip.node.material_config.update_material()

func hide_body_vertices() -> void:
	super()
	_recalculate_normals()

func set_skin_texture(name: String) -> void:
	super(name)
	if body_mesh != null and body_mesh is HumanizerMeshInstance:
		body_mesh.material_config.update_material()

func set_skin_normal_texture(name: String) -> void:
	super(name)
	if body_mesh != null and body_mesh is HumanizerMeshInstance:
		body_mesh.material_config.update_material()

func set_rig(rig_name: String) -> void:
	super(rig_name)
	set_shapekeys(human_config.shapekeys)
	for equip in human_config.equipment.values():
		_add_bone_weights(equip)
	_adjust_skeleton()

func set_shapekeys(shapekeys: Dictionary) -> void:
	_set_shapekey_data(shapekeys)
	_fit_all_meshes()
	_adjust_skeleton()
	_recalculate_normals()

	if main_collider != null:
		_adjust_main_collider()
	
	## HACK shapekeys mess up mesh
	## Face bones mess up the mesh when shapekeys applied.  This fixes it
	if animator != null:
		animator.active = not animator.active
		animator.active = not animator.active
