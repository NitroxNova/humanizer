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
	for slot in [&'RightEye', &'LeftEye', &'Eyes']:
		if not human_config.body_parts.has(slot):
			continue
		var bp: HumanBodyPart = human_config.body_parts[slot]
		if bp.node is HumanizerMeshInstance:
			bp.node.material_config.update_material()

func set_body_part(bp: HumanBodyPart) -> void:
	super(bp)
	_fit_body_part_mesh(bp)
	if bp.node is HumanizerMeshInstance:
		bp.node.material_config.update_material()

func _add_clothes_mesh(cl: HumanClothes) -> void:
	super(cl)
	_fit_clothes_mesh(cl)
	if cl.node is HumanizerMeshInstance:
		cl.node.material_config.update_material()

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
	_adjust_skeleton()
	set_shapekeys(human_config.shapekeys)
	for cl in human_config.clothes:
		_add_bone_weights(cl)
	for bp in human_config.body_parts.values():
		_add_bone_weights(bp)

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
