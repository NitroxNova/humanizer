@tool
extends Resource
class_name Humanizer

var human_config:HumanConfig
var helper_vertex:PackedVector3Array = []
var mesh_arrays : Dictionary = {}
var rig: HumanizerRig 

func _init(_human_config = null):
	if _human_config == null:
		human_config = HumanConfig.new()
		human_config.targets.init_macros()
		human_config.rig = HumanizerGlobalConfig.config.default_skeleton
	else:	
		human_config = _human_config
	helper_vertex = HumanizerTargetService.init_helper_vertex(human_config.targets)
	mesh_arrays.body = HumanizerBodyService.load_basis_arrays()
	hide_body_vertices()
	rig = HumanizerRigService.get_rig(human_config.rig)
	HumanizerRigService.set_body_weights_array(rig,mesh_arrays.body)
	fit_meshes()
	
func get_mesh(mesh_name:String):
	var new_arrays = mesh_arrays[mesh_name].duplicate()
	new_arrays[Mesh.ARRAY_CUSTOM0] = null
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_arrays)
	return HumanizerMeshService.generate_normals_and_tangents(mesh)

func get_body_mesh():
	return get_mesh("body")

func hide_body_vertices():
	HumanizerBodyService.hide_vertices(mesh_arrays.body,human_config.equipment)
			
func set_targets(target_data:Dictionary):
	HumanizerTargetService.set_targets(target_data,human_config.targets,helper_vertex)
	fit_meshes()
	
func fit_meshes():
	mesh_arrays.body = HumanizerBodyService.fit_mesh_arrays(mesh_arrays.body,helper_vertex)

func get_foot_offset()->float:
	return HumanizerBodyService.get_foot_offset(helper_vertex)
	
func get_hips_height()->float:
	return HumanizerBodyService.get_hips_height(helper_vertex)

func get_head_height()->float:
	return HumanizerBodyService.get_head_height(helper_vertex)
	
func get_max_width()->float:
	return HumanizerBodyService.get_max_width(helper_vertex)
