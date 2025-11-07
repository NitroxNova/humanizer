extends Resource
class_name WrapMeshData

#mesh data tool does not get connected faces/edges along seams, had to make my own
var vertices = {}
var faces = []
var edges = []

func _init(sf_arrays:Array):
	#print(sf_arrays[Mesh.ARRAY_VERTEX].size())
	#var sf_arrays = mesh.surface_get_arrays(0)
	#for i in sf_arrays[Mesh.ARRAY_INDEX].size()/3:
		
	for v_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var v_pos = sf_arrays[Mesh.ARRAY_VERTEX][v_id]
		var new_v_id = find_vertex(v_pos)		
		if new_v_id == null:
			new_v_id = v_pos
			var vtx = Vertex.new()
			vtx.position = v_pos
			vertices[v_pos] = vtx
	
	if sf_arrays[Mesh.ARRAY_INDEX] == null:
		for i in sf_arrays[Mesh.ARRAY_VERTEX].size()/3:
			var face = Face.new()
			for j in 3:
				var old_v_id = i*3+j
				var new_v_id =  sf_arrays[Mesh.ARRAY_VERTEX][old_v_id] 
				var uv = Vector2.ZERO
				if not sf_arrays[Mesh.ARRAY_TEX_UV] == null:
					uv = 	sf_arrays[Mesh.ARRAY_TEX_UV][old_v_id]
				face.add_uv_vertex_pair(uv,new_v_id)
			add_face(face)
			
	else:
		for i in sf_arrays[Mesh.ARRAY_INDEX].size()/3:
			var face = Face.new()
			for j in 3:
				var old_v_id = sf_arrays[Mesh.ARRAY_INDEX][i*3+j]
				var new_v_id =  sf_arrays[Mesh.ARRAY_VERTEX][old_v_id] 
				face.add_uv_vertex_pair(sf_arrays[Mesh.ARRAY_TEX_UV][old_v_id],new_v_id)
			add_face(face)

func add_face(face:Face):
	var face_id = find_face_id(face.vertices)
	if face_id == -1:	
		face_id = faces.size()	
		faces.append(face)
	else:
		#face is already added
		return
	
	for j in 3:
		var vtx_id = face.vertices[j]
		var vertex = vertices[vtx_id]
		vertex.faces.append(face_id)
	
	for j in 3:
		var k = (j + 1) % 3
		var edge_verts = [face.vertices[j],face.vertices[k]]
		edge_verts.sort_custom(sort_edge)
		var edge_id = find_edge_id(edge_verts)
		#print(edge_id, " ", edge_verts)
		if edge_id == -1:
			var edge = Edge.new()
			edge.vertices = edge_verts
			edge_id = edges.size()
			edges.append(edge)
		var edge = edges[edge_id]
		edge.faces.append(face_id)
		face.edges.append(edge_id)
		for l in 2:
			var l_vertex = vertices[ edge_verts[l]]
			if edge_id not in l_vertex.edges:
				l_vertex.edges.append(edge_id)

static func sort_edge(a:Vector3,b:Vector3):
	if a.x < b.x:
		return true
	if a.x == b.x:
		if a.y < b.y:
			return true
		if a.y == b.y:
			if a.z < b.z:
				return true
				#else they are the same which shouldnt happen
				
func find_vertex(pos:Vector3):
	if pos in vertices:
		return vertices[pos]
	#for v_id in vertices.size():
		#var vtx : Vertex = vertices[v_id]
		#if vtx.position == pos:
			#return v_id
	return null

func find_edge_id(v_index:Array):
	var dupe_index = v_index.duplicate()
	dupe_index.sort_custom(sort_edge)
	for e_id in edges.size():
		var edge : Edge = edges[e_id]
		if edge.vertices == dupe_index:
			return e_id
	return -1

func find_face_id(v_index:Array):
	for f_id in faces.size():
		var face : Face = faces[f_id]
		if face.vertices == v_index:
			return f_id
	return -1

func get_face_vertex(face_id,v_idx):
	return faces[face_id].vertices[v_idx]

func get_face_vertex_positions(face_id):
	var face = faces[face_id]
	var verts = []
	for v_id in face.vertices:
		verts.append(get_vertex_position(v_id))
	return verts

func get_face_center_point(face_id):
	var verts = get_face_vertex_positions(face_id)
	var center = (verts[0] + verts[1] + verts[2]) / 3.0
	return center
	
func get_edge_vertex_positions(edge_id):
	var edge = edges[edge_id]
	var verts = []
	for v_id in edge.vertices:
		verts.append(get_vertex_position(v_id))
	return verts

func get_vertex_position(v_id):
	return vertices[v_id].position 

func get_face_edge(face_id,edge_idx):
	return faces[face_id].edges[edge_idx]

func get_edge_vertex(edge_id,v_idx):
	return edges[edge_id].vertices[v_idx]

func get_edge_faces(edge_id):
	return edges[edge_id].faces

func get_face_normal(face_id):
	var verts = get_face_vertex_positions(face_id)
	#var normal = (verts[1] - verts[0]).cross(verts[2]-verts[0])
	var normal = (verts[2] - verts[0]).cross(verts[1]-verts[0])
	normal = normal.normalized()
	#print(verts)
	#print(normal)
	return normal

func get_edges_between_corners(vtx_pos_1:Vector3,vtx_pos_2:Vector3,other_corners:Array):
	var vtx_1 = vertices[vtx_pos_1]
	var vtx_2 = vertices[vtx_pos_2]
	var path = []
	for edge_id in vtx_1.edges:
		#print(edge_id)
		var edge = edges[edge_id]
		if edge.faces.size() == 1:
			path = [edge]
			var next_vert_pos = edge.get_opposite_vertex(vtx_pos_1)
			var next_vert = vertices[next_vert_pos]
			if next_vert_pos == vtx_pos_2:
				return path
			var tries = 1000
			while other_corners[0].position not in path[-1].vertices and other_corners[1].position not in path[-1].vertices and tries > 0: 
				for next_edge_id in next_vert.edges:
					var next_edge = edges[next_edge_id]
					if next_edge.faces.size() == 1 and next_edge not in path:
						path.append(next_edge)
						next_vert_pos = next_edge.get_opposite_vertex(next_vert_pos)
						next_vert = vertices[next_vert_pos]
						if next_vert_pos == vtx_pos_2:
							return path
						#break #shouldnt need the break, should be one and only one
				tries -= 1
	#return path

		
class Edge:
	var faces = []
	var vertices = []
	var astar_ids = []
	
	func get_opposite_vertex(vtx_id):
		if vtx_id not in vertices:
			printerr(vtx_id," not in edge ", vertices)
			return
		for v in vertices:
			if v != vtx_id:
				return v

class Face:
	var edges = []
	var vertices :Array[Vector3] = []
	var uvs = []
	#var normal 
	
	func add_uv_vertex_pair(uv:Vector2,vertex:Vector3):
		#var insert_id = 0
		#for v_id in vertices:
			#if vertex < v_id:
				#break
			#insert_id += 1
		#vertices.insert(insert_id,vertex)
		#uvs.insert(insert_id,uv)
		#order matters
		vertices.append(vertex)
		uvs.append(uv)
	
	func _to_string() -> String:
		return "vertices: " + str(vertices) + ", edges: " + str(edges)

class Vertex:
	var edges = []
	var faces = []
	var position : Vector3
	var astar_id : int = -1
	#var normal : Vector3
	var new_uv #dont declare so can check if null
	
	func distance_to(vertex):
		return position.distance_to(vertex.position)
