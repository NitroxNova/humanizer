@tool
class_name AutoUpdatingHumanizer
extends Humanizer

## For use in character editor scenes where the character should be 
## continuously updated with every change


func set_human_config(config: HumanConfig) -> void:
	human_config = config
	load_human()
	
func set_hair_color(color: Color) -> void:
	hair_color = color

func set_eyebrow_color(color: Color) -> void:
	eyebrow_color = color

func set_skin_color(color: Color) -> void:
	skin_color = color
	if body_mesh != null:
		body_mesh.material_config.update_material()
	
func set_eye_color(color: Color) -> void:
	eye_color = color
	for slot in [&'RightEye', &'LeftEye', &'Eyes']:
		if human_config.body_parts.has(slot):
			var mesh = human_config.body_parts[slot].node
			mesh.material_config.update_material()

func set_body_part(bp: HumanBodyPart) -> void:
	super(bp)
	if bp.node == null:
		return
	var mhclo: MHCLO = load(bp.mhclo_path)
	var new_mesh = MeshOperations.build_fitted_mesh(bp.node.mesh, _helper_vertex, mhclo)
	new_mesh = MeshOperations.generate_normals_and_tangents(new_mesh)
	bp.node.mesh = new_mesh
	
func _add_clothes_mesh(cl: HumanClothes) -> void:
	super(cl)
	if cl.node == null:  
		return
	var mhclo: MHCLO = load(cl.mhclo_path)
	var new_mesh = MeshOperations.build_fitted_mesh(cl.node.mesh, _helper_vertex, mhclo)
	new_mesh = MeshOperations.generate_normals_and_tangents(new_mesh)
	cl.node.mesh = new_mesh

func hide_body_vertices() -> void:
	super()
	_recalculate_normals()

func set_skin_texture(name: String) -> void:
	super(name)
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
	super(shapekeys)
	fit_body_mesh()
	
	# Apply to body parts and clothes
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var res: HumanAsset = _get_asset_by_name(child.name)
		if res != null:   # Body parts/clothes
			var mhclo: MHCLO = load(res.mhclo_path)
			var new_mesh = MeshOperations.build_fitted_mesh(child.mesh, _helper_vertex, mhclo)
			child.mesh = new_mesh

	_recalculate_normals()
	_adjust_skeleton()
	if main_collider != null:
		_adjust_main_collider()
			
	## Face bones mess up the mesh when shapekeys applied.  This fixes it
	if animator != null:
		animator.active = not animator.active
		animator.active = not animator.active
