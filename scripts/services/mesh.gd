extends Resource
class_name HumanizerMeshService

static func generate_normals_and_tangents(import_mesh:ArrayMesh):
	var ST = SurfaceTool.new()
	ST.clear()
	ST.create_from(import_mesh,0)
	ST.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	ST.generate_normals()
	ST.generate_tangents()
	#ST.optimize_indices_for_cache()
	var flags = import_mesh.surface_get_format(0)
	var new_mesh = ST.commit(null,flags)
	return new_mesh
