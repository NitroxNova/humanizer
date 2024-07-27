@tool
extends Resource
class_name HumanizerBodyService
#everything to do with the humanizer body mesh

## Vertex ids
const shoulder_id: int = 16951 
const waist_id: int = 17346
const hips_id: int = 18127
const feet_ids: Array[int] = [15500, 16804]
const head_top_id : int = 14570

static func load_mesh(rig, helper_vertex:PackedVector3Array)->ArrayMesh:
	var basis_mesh = load_basis_mesh()
	var basis_arrays = basis_mesh.surface_get_arrays(0)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,basis_arrays,[],{},basis_mesh.surface_get_format(0))
	return mesh

static func load_mesh_arrays(rig ,helper_vertex:PackedVector3Array)->Array:
	return fit_mesh_arrays(load_basis_arrays(),helper_vertex)

static func load_basis_arrays()->Array:
	return load_basis_mesh().surface_get_arrays(0)

static func load_basis_mesh()->ArrayMesh:
	return load("res://addons/humanizer/data/resources/base_human.res")

static func fit_mesh(in_mesh:ArrayMesh,helper_vertex:PackedVector3Array)->ArrayMesh:
	var sf_arrays = fit_mesh_arrays(in_mesh.surface_get_arrays(0),helper_vertex)
	var out_mesh = ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays,[],{},in_mesh.surface_get_format(0))
	return out_mesh

static func fit_mesh_arrays(sf_arrays:Array,helper_vertex:PackedVector3Array)-> Array:
	for gd_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = sf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		sf_arrays[Mesh.ARRAY_VERTEX][gd_id] = helper_vertex[mh_id]
	return sf_arrays
	
static func get_hips_height(helper_vertex:PackedVector3Array):
	return helper_vertex[hips_id].y

static func get_foot_offset(helper_vertex:PackedVector3Array):
	var offset = max(helper_vertex[feet_ids[0]].y, helper_vertex[feet_ids[1]].y)
	var foot_offset = Vector3.UP * offset
	return foot_offset.y

static func get_head_height(helper_vertex:PackedVector3Array):
	return helper_vertex[head_top_id].y

static func get_max_width(helper_vertex:PackedVector3Array):
	var width_ids = [shoulder_id,waist_id,hips_id]
	var max_width = 0
	for mh_id in width_ids:
		var vertex_position = helper_vertex[mh_id]
		var distance = Vector2(vertex_position.x,vertex_position.z).distance_to(Vector2.ZERO)
		if distance > max_width:
			max_width = distance
	return max_width * 1.5
