extends Resource
class_name HarmonicMap

var internal_vertices : Array
var wmd : WrapMeshData

func _init(_wmd,_iv):
	wmd = _wmd
	internal_vertices = _iv

func propagate_uvs():
	for vtx_id in internal_vertices:
		var vertex = wmd.vertices[vtx_id]
		var average_uv = Vector2.ZERO
		var average_count = 0
		#average all the ratios per edge
		for i in vertex.edges.size():
			for j in vertex.edges.size():
				if i >= j:
					continue
				var edge1 = wmd.edges[vertex.edges[i]]
				var edge2 = wmd.edges[vertex.edges[j]]
				var vtx1 = wmd.vertices[ edge1.get_opposite_vertex(vtx_id)]
				var vtx2 = wmd.vertices[ edge2.get_opposite_vertex(vtx_id)]
				var distance1 = vertex.distance_to(vtx1)
				var distance2 = vertex.distance_to(vtx2)
				var cur_ratio = distance1 / (distance1 + distance2)
				average_uv += vtx1.new_uv.lerp(vtx2.new_uv,cur_ratio)
				average_count += 1
		average_uv = average_uv/average_count
		vertex.new_uv = average_uv	

func rebuild_mesh_uvs(mesh_instance):	
	#rebuild mesh with new uvs
	var sf_arrays = mesh_instance.mesh.surface_get_arrays(0)
	#sf_arrays.resize(Mesh.ARRAY_MAX)
	#sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	sf_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	for vtx_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var vtx_pos = sf_arrays[Mesh.ARRAY_VERTEX][vtx_id]
		var new_uv = wmd.vertices[vtx_pos].new_uv
		sf_arrays[Mesh.ARRAY_TEX_UV].append(new_uv)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays)
	mesh_instance.mesh = mesh
