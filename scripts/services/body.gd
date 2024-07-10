extends Resource
class_name HumanizerBodyService

static func load_mesh(rig, helper_vertex:PackedVector3Array)->ArrayMesh:
	var basis_mesh = load_basis_mesh()
	var basis_arrays = basis_mesh.surface_get_arrays(0)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,basis_arrays,[],{},basis_mesh.surface_get_format(0))
	return mesh
	
static func load_basis_mesh()->ArrayMesh:
	return load("res://addons/humanizer/data/resources/base_human.res")

static func fit_mesh(in_mesh:ArrayMesh,helper_vertex:PackedVector3Array)->ArrayMesh:
	var sf_arrays = _fit_mesh_arrays(in_mesh.surface_get_arrays(0),helper_vertex)
	var out_mesh = ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays,[],{},in_mesh.surface_get_format(0))
	return out_mesh

static func _fit_mesh_arrays(sf_arrays:Array,helper_vertex:PackedVector3Array)-> Array:
	for gd_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = sf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		sf_arrays[Mesh.ARRAY_VERTEX][gd_id] = helper_vertex[mh_id]
	return sf_arrays
	
