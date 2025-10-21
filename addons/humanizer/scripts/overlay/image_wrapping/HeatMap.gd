@tool
extends Resource
class_name HeatMap

var vertices = {}
enum {UP, RIGHT, DOWN, LEFT, }

func _init(mesh:ArrayMesh,borders:Array):
	make_from_mesh(mesh)
	#print(vertices.size())
	set_borders(borders)
	build_map()

func build_map():
	for vtx in vertices:
		for i in 4:
			if vertices[vtx].distance[i] == 0:
				update_neighbors(vtx,i)

func update_neighbors(vtx,side:int):
	for nb in vertices[vtx].connections:
		var distance = calculate_heat(nb,side,vtx)
		if distance != null:
			vertices[nb].distance[side] = distance
			update_neighbors(nb,side)

func calculate_heat(vtx_id,side:int,from_id):
	var vertex = vertices[vtx_id]
	
	if vertex.distance[side] == 0:
		return
	if vertex.distance[side] == null:
		var closest_neighbor = null
		var distance = null
		for nb in vertex.connections:
			if vertices[nb].distance[side] != null:
				var cur_distance = vertices[nb].distance[side]
				cur_distance += vtx_id.distance_to(nb)
				if closest_neighbor == null or distance > cur_distance:
					closest_neighbor = nb
					distance = cur_distance
		if closest_neighbor == null:
			return
		return distance
	
	var cur_distance = from_id.distance_to(vtx_id) + vertices[from_id].distance[side]
	if vertex.distance[side] > cur_distance:
		return cur_distance
	
func set_borders(borders:Array):
	#print(borders.size())
	for i in 4:
		for vtx in borders[i]:
			if vtx in vertices:
				vertices[vtx].distance[i] = 0
				#print("true")
			#else:
				#printerr(vtx," not in vertices")
	#print(vertices.keys())

func make_from_mesh(mesh:ArrayMesh):
	vertices = {}
	var sf_arrays = mesh.surface_get_arrays(0)
	#print(sf_arrays[Mesh.ARRAY_VERTEX].size())
	for idx in sf_arrays[Mesh.ARRAY_VERTEX].size()/3:
		for i in 3:
			var vtx1 = sf_arrays[Mesh.ARRAY_VERTEX][(idx*3)+i]
			var vtx2 = sf_arrays[Mesh.ARRAY_VERTEX][(idx*3)+ ((i+1) % 3)]
			if vtx1 not in vertices:
				vertices[vtx1] = Vertex.new()
			if vtx2 not in vertices:
				vertices[vtx2] = Vertex.new()
			if vtx1 not in vertices[vtx2].connections:
				vertices[vtx2].connections.append(vtx1)
			if vtx2 not in vertices[vtx1].connections:
				vertices[vtx1].connections.append(vtx2)


func rebuild_mesh_uvs(mesh_instance):	
	#rebuild mesh with new uvs
	var sf_arrays = mesh_instance.mesh.surface_get_arrays(0)
	sf_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	for vtx_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var vtx_pos = sf_arrays[Mesh.ARRAY_VERTEX][vtx_id]
		#var new_uv = wmd.vertices[vtx_pos].new_uv
		var new_uv = Vector2.ZERO
		var vertex = vertices[vtx_pos]
		new_uv.y = vertex.distance[0] / (vertex.distance[0] + vertex.distance[2])
		new_uv.x = vertex.distance[3] / (vertex.distance[1] + vertex.distance[3])
		sf_arrays[Mesh.ARRAY_TEX_UV].append(new_uv)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays)
	mesh_instance.mesh = mesh				

class Vertex:
	var position : Vector3
	var connections : Array = []
	var distance : Array = [null,null,null,null]
