extends Resource
class_name ShortestPath

var astar_resolution = .1
var wmd : WrapMeshData
var astar : AStar3D
var astar_meta = []

func _init(_astar_res, _wmd) -> void:
	astar_resolution = _astar_res
	wmd = _wmd
	build_astar()

func get_shortest_path(face_1,position_1,face_2,position_2):
	#print(astar.get_point_count())
	#add points to astar to stay on face
	
	var point1_astar = link_astar_point_to_face(position_1,face_1)	
	var point2_astar = link_astar_point_to_face(position_2,face_2)	
	
	var path = astar.get_id_path(point1_astar,point2_astar)
	#print(path)
	
	var line = []
	#print("~~~~~~~~")
	for p_id in path.size()-1:
		var astar_1_id = path[p_id]
		var astar_2_id = path[p_id+1]
		var face_id = -1
		var edge_id = -1
		var point_1_meta = astar_meta[astar_1_id]
		var point_2_meta = astar_meta[astar_2_id]
		if point_1_meta.type == "face":
			face_id = point_1_meta.id
			edge_id = -1
		elif point_2_meta.type == "face":
			face_id = point_2_meta.id
			if point_1_meta.type == "edge":
				edge_id = point_1_meta.id
		elif point_1_meta.type == "edge" or point_2_meta.type == "edge":
			var faces1 = []
			var faces2 = []
			if point_1_meta.type == "edge":
				faces1 = wmd.edges[point_1_meta.id].faces
				edge_id = point_1_meta.id
			else: #vertex
				faces1 = wmd.vertices[point_1_meta.id].faces
			if point_2_meta.type == "edge":
				faces2 = wmd.edges[point_2_meta.id].faces
			else: #vertex
				faces2 = wmd.vertices[point_2_meta.id].faces
			for f_id in faces1:
				if f_id in faces2:
					face_id = f_id
					
		#print(face_id)
		#print(wmd.faces[face_id].edges)
		#print("edge_1 ",point_1_meta.id)
		#print("edge_2 ",point_2_meta.id)
		#print(face_id)
			
		#print(face_id," ",point_1_meta," ",point_2_meta)		
		# else both are vertex, could be either face
		var wrap_segment = LineWrapper.Wrap_Line_Segment.new(face_id,edge_id,astar.get_point_position(astar_1_id))
		#print(wrap_segment)
		#print("~~~")
		#line.append(astar.get_point_position(p_id))
		line.append(wrap_segment)
	var last_face = -1
	var last_edge = -1
	var last_meta = astar_meta[path[-1]]
	if last_meta.type == "face":
		last_face = last_meta.id
	var wrap_segment = LineWrapper.Wrap_Line_Segment.new(last_face,last_edge,astar.get_point_position(path[-1]))
	#line.append(astar.get_point_position(p_id))
	line.append(wrap_segment)	
	astar.remove_point(astar.get_point_count()-1)
	astar.remove_point(astar.get_point_count()-1)
	astar_meta.remove_at(astar_meta.size()-1)
	astar_meta.remove_at(astar_meta.size()-1)
	return line
	

func link_astar_point_to_face(point_position,face_id):
	var face = wmd.faces[face_id]
	var new_id = astar.get_point_count()
	astar.add_point(new_id,point_position)
	astar_meta.append({type="face",id=face_id})
	for a_id in get_face_astar_ids(face_id):
		astar.connect_points(new_id,a_id)
	return new_id	
	
func build_astar():
	astar = AStar3D.new()
	var astar_id = 0
	#dont do vertices because it will require more checks, with small enough resolution it "shouldnt" be noticable
	#for v_id in wmd.vertices:
		#var vertex:WrapMeshData.Vertex = wmd.vertices[v_id]
		#astar.add_point(astar_id,vertex.position)
		#astar_meta.append({type="vertex",id=v_id})
		#vertex.astar_id = astar_id
		#astar_id+=1
	for e_id in wmd.edges.size():
		var edge:WrapMeshData.Edge = wmd.edges[e_id]
		edge.astar_ids = []
		var edge_distance = edge.vertices[0].distance_to(edge.vertices[1])
		var count:int = edge_distance/astar_resolution
		count+= 1 #want at least one per edge
		#print(count)
		#print(edge_distance)
		for i in count:
			var percent = (i + 1)/ float(count + 1)
			var point_pos = edge.vertices[0].lerp(edge.vertices[1],percent)
			astar.add_point(astar_id,point_pos)
			edge.astar_ids.append(astar_id)
			astar_meta.append({type="edge",id=e_id})
			astar_id+=1
		
			
	for face_id in wmd.faces.size():
		var face_astar_ids = get_face_astar_ids(face_id)
		for astar_id_1 in face_astar_ids:
			for astar_id_2 in face_astar_ids:
				if astar_id_1 == astar_id_2:
					continue
				astar.connect_points(astar_id_1,astar_id_2)
				

func get_face_astar_ids(face_id):
	var face:WrapMeshData.Face = wmd.faces[face_id]	
	var astar_ids = []
	#for v_id in face.vertices:
		#var vertex = wmd.vertices[v_id]
		#astar_ids.append(vertex.astar_id)
	for e_id in face.edges:
		var edge = wmd.edges[e_id]
		for a_id in edge.astar_ids:
			astar_ids.append(a_id)
	return astar_ids
