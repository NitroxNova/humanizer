@tool
extends Node3D

@export var update = false:
	set(value):
		run_update()

@export var start_face_id = 0
@export var image_rotation = 0.0:
	set(value):
		image_rotation = value
		run_update()

@export var image_scale : float = 1
@export var image : Texture2D

@onready var wmd = WrapMeshData.new($BaseMesh.mesh )
@onready var short_path_builder = ShortestPath.new(.01,wmd)


func run_update():
	var borders = make_borders()
	var borders2 = cut_mesh(borders)
	#print(internal_vertices)
	#var cut_wmd = WrapMeshData.new($CutMesh.mesh)
	#for face in cut_wmd.faces:
		#for vtx_idx in face.vertices.size():
			#cut_wmd.vertices[face.vertices[vtx_idx]].new_uv = face.uvs[vtx_idx]
		
	var heatmap = HeatMap.new($CutMesh.mesh,borders2)
	heatmap.rebuild_mesh_uvs($CutMesh)

func cut_mesh(borders):
	var horizontal_lines = borders[0]
	var vertical_lines = borders[1]
	#start at face_id
	var external_faces = []
	#print("~~~~~~")
	#for segment in horizontal_lines[0]:
		#print(segment.face_id)
	#print("~~~~~~")
	for i in horizontal_lines.size():
		for segment in horizontal_lines[i]:
			if segment.face_id not in external_faces:
				external_faces.append(segment.face_id)
	for i in vertical_lines.size():
		for segment in vertical_lines[i]:
			if segment.face_id not in external_faces:
				external_faces.append(segment.face_id)
				
	var internal_faces = get_connected_internal_faces(start_face_id,external_faces)
	var internal_vertices = get_connected_internal_vertices(internal_faces)
	#print(internal_faces)
	
	var internal_uvs = []
	var sf_arrays = []
	sf_arrays.resize(Mesh.ARRAY_MAX)
	sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	sf_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	
	
	var borders2 = [borders[0][0]]
	borders2.append(borders[1][0])
	borders2.append(borders[0][1])
	borders2.append(borders[1][1])
	
	
	var cut_edge_faces = cut_edge_faces(borders2)	
	var edge_faces = cut_edge_faces[0]
	var new_borders = cut_edge_faces[1]
	var external_uvs = get_external_uvs(borders2)
	#print(edge_faces)	
	var new_edge_faces = []
	for edge_face in edge_faces:
		new_edge_faces.append(edge_face)
		#TODO
			
				
	for nf in new_edge_faces:
		for vtx_pos in nf:
			sf_arrays[Mesh.ARRAY_VERTEX].append(vtx_pos)
			#print(vtx_pos ==sf_arrays[Mesh.ARRAY_VERTEX][-1] )
			if vtx_pos in external_uvs:
				sf_arrays[Mesh.ARRAY_TEX_UV].append(external_uvs[vtx_pos])
			else:
				if vtx_pos not in internal_uvs:
					internal_uvs.append(vtx_pos)
				sf_arrays[Mesh.ARRAY_TEX_UV].append(Vector2(.5,.5))
	
	#print(new_edge_faces[-1][-1])
	#print(sf_arrays[Mesh.ARRAY_VERTEX].size())
	
	var cut_mesh = ArrayMesh.new()
	cut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays)
	$CutMesh.mesh = cut_mesh
	
	var external_wmd = WrapMeshData.new(cut_mesh)
	
	var internal_face_verts = []
	for face_id in internal_faces:
		var face = wmd.faces[face_id]
		for vtx_id in face.vertices:
			internal_face_verts.append([face.vertices[0],face.vertices[1],face.vertices[2]])
	
	get_connected_edge_faces(external_wmd,internal_face_verts,new_borders)
	#get original face
	#print(wmd.faces[start_face_id].vertices)
	
	sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	sf_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	
	for face_verts in internal_face_verts:
		#var face = wmd.faces[face_id]
		for vtx_id in face_verts:
			sf_arrays[Mesh.ARRAY_VERTEX].append(vtx_id)
			if vtx_id not in internal_uvs:
				internal_uvs.append(vtx_id)
			sf_arrays[Mesh.ARRAY_TEX_UV].append(Vector2(.5,.5))
	cut_mesh = ArrayMesh.new()
	cut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays)
	$CutMesh.mesh = cut_mesh	
	
	#print(new_edge_faces[-1][-1] == cut_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][-1])
	return new_borders

func get_connected_edge_faces(external_wmd:WrapMeshData,internal_faces,borders):
	
	for face_verts_id in internal_faces.size():
		var face_verts = internal_faces[face_verts_id]
		for i in 3:
			var vtx1 = face_verts[i]
			var vtx2 = face_verts[(i+1) %3]
			var external_edge_id = external_wmd.find_edge_id([vtx1,vtx2])
			if external_edge_id != -1 and external_edge_id != null:
				get_connected_edge_faces_recur(external_edge_id,external_wmd,internal_faces,borders)

func get_connected_edge_faces_recur(edge_id,external_wmd:WrapMeshData,internal_faces,borders):
	#print(edge_id)
	var external_edge = external_wmd.edges[edge_id]
	for i in borders.size():
		if external_edge.vertices[0] in borders[i] and external_edge.vertices[1] in borders[i]:
			#print("found external edge")
			return
	for external_face_id in external_edge.faces:
		var edge_face = external_wmd.faces[external_face_id]
		if edge_face.vertices not in internal_faces:
			#print(external_face.vertices)
			internal_faces.append(edge_face.vertices)
			for next_edge_id in edge_face.edges:
				get_connected_edge_faces_recur(next_edge_id,external_wmd,internal_faces,borders)
			
	
func get_connected_internal_faces(face_id,border_faces,internal_faces=[]):
	internal_faces.append(face_id)
	var face = wmd.faces[face_id]
	for e_id in face.edges:
		var edge = wmd.edges[e_id]
		for ef_id in edge.faces:
			if ef_id not in internal_faces and ef_id not in border_faces:
				get_connected_internal_faces(ef_id,border_faces,internal_faces)
	return internal_faces

func get_connected_internal_vertices(internal_faces):
	var internal_verts = []
	for face_id in internal_faces:
		var face = wmd.faces[face_id]
		for v_id in face.vertices:
			if v_id not in internal_verts:
				internal_verts.append(v_id)
		
	return internal_verts

func get_external_uvs(borders:Array):
	var uvs = {}
	#var uvs = [Vector2.ZERO,Vector2(1,0),Vector2(1,.5),Vector2(1,1),Vector2(0,1),Vector2(0,.5)]
	for line_id in borders.size():
		var line = borders[line_id]
		var start_uv = Vector2.ZERO
		var end_uv = Vector2.ZERO
		if line_id == 0:
			start_uv = Vector2(1,0)
			end_uv = Vector2(0,0)
		elif line_id == 1:
			start_uv = Vector2(1,0)
			end_uv = Vector2(1,1)
		elif line_id == 2:
			start_uv = Vector2(1,1)
			end_uv = Vector2(0,1)
		elif line_id == 3:
			start_uv = Vector2(0,1)
			end_uv = Vector2(0,0)
		var total_distance = 0
		for segment_id in line.size()-1:
			var segment1 = line[segment_id]
			var segment2 = line[segment_id+1]
			total_distance += segment1.position.distance_to(segment2.position)
		var cur_distance:float = 0
		for segment_id in line.size()-1:
			var segment1 = line[segment_id]
			var segment2 = line[segment_id+1]
			var ratio = cur_distance/total_distance
			var new_uv = start_uv.lerp(end_uv,ratio)
			uvs[segment1.position] = new_uv
			cur_distance += segment1.position.distance_to(segment2.position)
		uvs[line[-1].position] = end_uv
	return uvs

func cut_edge_faces(borders:Array): 
	#print(borders)
	#var horizontal_lines = borders[0]
	#var vertical_lines = borders[1]
	var border_shapes = {}
	var new_borders = []
	var line_intercepts = [{},{},{},{}]
	for line_id in borders.size():
		var line = borders[line_id]
		for segment_id in line.size():
			var segment = line[segment_id]
			if segment.edge_id != -1 and segment.edge_id != null:
				var edge = wmd.edges[segment.edge_id]
				var edge_verts = edge.vertices.duplicate()
				edge_verts.sort_custom(WrapMeshData.sort_edge)
				line_intercepts[line_id][edge_verts] = segment.position

						

	for line_id in borders.size():
		new_borders.append([])
		var line = borders[line_id]
		for segment in line:
			var face_id = segment.face_id
			if face_id not in border_shapes:
				#print(wmd.faces[face_id].vertices)
				border_shapes[face_id] = [TriangleProjection.new(wmd.faces[face_id].vertices)]
			if segment.position not in new_borders[line_id]:
				new_borders[line_id].append(segment.position)
	for line_id in borders.size():
		var line = borders[line_id]
		for segment_id in line.size()-1:
			var segment1 = line[segment_id]
			var segment2 = line[segment_id+1]
			var face_id = segment1.face_id
			var line_verts = [segment1.position,segment2.position]
			var add_tris = []
			var remove_tris = []
			for tri_proj:TriangleProjection in border_shapes[face_id]:
				var intercepts_3d = []
				for i in 3:
					var edge_intercept = null
					var edge_verts_3d = []
					edge_verts_3d.append(tri_proj.verts_3d[i])
					edge_verts_3d.append(tri_proj.verts_3d[(i+1)%3])
					edge_verts_3d.sort_custom(WrapMeshData.sort_edge)
					if edge_verts_3d in line_intercepts[line_id]:
						edge_intercept = line_intercepts[line_id][edge_verts_3d]
					else:
						#if segment1.edge_id == -1 or segment2.edge_id == -1:
							#print("here")
						edge_intercept = tri_proj.get_edge_line_intersect(i,line_verts)
						#TODO filter for null somewhere else
						line_intercepts[line_id][edge_verts_3d] = edge_intercept
						
						
						
					if edge_intercept != null:
						intercepts_3d.append({position=edge_intercept,edge_id=i})
						if edge_intercept not in new_borders[line_id]:
							new_borders[line_id].append(edge_intercept)
						
						#to fill in the corner edge
						for corner_line_id in line_intercepts.size():
							if corner_line_id == line_id:
								continue
							if edge_verts_3d[0] in new_borders[corner_line_id] and edge_verts_3d[1] in new_borders[corner_line_id]:
								#print(corner_line_id)
								new_borders[corner_line_id].append(edge_intercept)
							if edge_verts_3d in line_intercepts[corner_line_id]:
								
								var old_intercept = line_intercepts[corner_line_id][edge_verts_3d]
								if old_intercept != null:
									#line_intercepts[corner_line_id].erase(edge_verts_3d)
									var new_edge1 = [edge_verts_3d[0],edge_intercept]
									new_edge1.sort_custom(WrapMeshData.sort_edge)
									var new_edge2 = [edge_verts_3d[1],edge_intercept]
									new_edge2.sort_custom(WrapMeshData.sort_edge)

									if LineWrapper.point_within_3d_line_segment(new_edge1,old_intercept):
										line_intercepts[corner_line_id][new_edge1] = old_intercept
										line_intercepts[corner_line_id][new_edge2] = null
									else:
										line_intercepts[corner_line_id][new_edge1] = null
										line_intercepts[corner_line_id][new_edge2] = old_intercept
									
									
								
						
				if not intercepts_3d.is_empty():
					
					if segment1.edge_id == -1 or segment2.edge_id == -1:
						var temp_corner_edge = [intercepts_3d[0].position,intercepts_3d[1].position]
						temp_corner_edge.sort_custom(WrapMeshData.sort_edge)
						#print(segment1, " ", segment2)
						for corner_line_id in 4:
							if corner_line_id == line_id:
								continue
							for corner_segment in borders[corner_line_id]:
								if corner_segment.position ==  segment1.position and segment1.edge_id == -1 and corner_segment.edge_id == -1:
									line_intercepts[corner_line_id][temp_corner_edge] = corner_segment.position
								if corner_segment.position ==  segment2.position and segment2.edge_id == -1 and corner_segment.edge_id == -1:
									line_intercepts[corner_line_id][temp_corner_edge] = corner_segment.position
													
					
					remove_tris.append(tri_proj)
					var output_polygons = [ [],[] ]
					var cur_poly_id = 0
					
					for edge_id in tri_proj.verts_3d.size():
						var vtx1_id = tri_proj.verts_3d[edge_id]
						output_polygons[cur_poly_id].append(vtx1_id)
						var vtx2_id = tri_proj.verts_3d[(edge_id+1) % tri_proj.verts_3d.size()]
						
						if edge_id == intercepts_3d[0].edge_id:
							output_polygons[cur_poly_id].append(intercepts_3d[0].position)
							cur_poly_id = (cur_poly_id + 1) % 2
							output_polygons[cur_poly_id].append(intercepts_3d[0].position)
							##print(segment1.position)
						elif edge_id == intercepts_3d[1].edge_id:
							output_polygons[cur_poly_id].append(intercepts_3d[1].position)
							cur_poly_id = (cur_poly_id + 1) % 2
							output_polygons[cur_poly_id].append(intercepts_3d[1].position)
					var output_tris = []
					for temp_poly in output_polygons:
						if temp_poly.size() == 3:
							output_tris.append(TriangleProjection.new([temp_poly[0],temp_poly[1],temp_poly[2]]))
							continue
						elif temp_poly.size() == 4:
							output_tris.append(TriangleProjection.new([temp_poly[0],temp_poly[1],temp_poly[2]]))
							output_tris.append(TriangleProjection.new([temp_poly[2],temp_poly[3],temp_poly[0]]))
							continue
						else:
							printerr("more than 4 edges")
					add_tris.append_array(output_tris)
			for r in remove_tris:
				border_shapes[face_id].erase(r)
			border_shapes[face_id].append_array(add_tris)
	var shapes = []
	for face_id in border_shapes:
		for temp_tri in border_shapes[face_id]:
			shapes.append([temp_tri.verts_3d[0],temp_tri.verts_3d[1],temp_tri.verts_3d[2]])		
	return [shapes,new_borders]
			
func make_borders():
	#draw center line, going left and going right
	var start_position = wmd.get_face_center_point(start_face_id)
	var line_wrapper = LineWrapper.new(wmd)
	var horizontal_distance = image.get_width() / 100 * image_scale
	var horizontal_line = line_wrapper.make_wrapping_line(start_face_id,start_position,image_rotation,horizontal_distance)
	var vertical_distance = image.get_height() / 100 *image_scale
	var vertical_line = line_wrapper.make_wrapping_line(start_face_id,start_position,image_rotation+ PI/2,vertical_distance)
	var temp_vert_line = line_wrapper.make_vertical_wrapping_line(1,horizontal_line[0],vertical_distance)
	#vertical_line.append_array(line_wrapper.make_vertical_wrapping_line(1,horizontal_line[0],vertical_distance))
	temp_vert_line = combine_line_segments(temp_vert_line[0],temp_vert_line[1])
	vertical_line.append(temp_vert_line)
	
	temp_vert_line = line_wrapper.make_vertical_wrapping_line(1,horizontal_line[1],vertical_distance)
	temp_vert_line = combine_line_segments(temp_vert_line[0],temp_vert_line[1])
	vertical_line.append(temp_vert_line)
	##
	horizontal_line.pop_front()
	horizontal_line.pop_front()
	#
	var start_segment = vertical_line[2][0]
	var end_segment = vertical_line[0][-1]
	var path = short_path_builder.get_shortest_path(start_segment.face_id,start_segment.position,end_segment.face_id,end_segment.position)
	#horizontal_line.append(path)
	path.pop_back()
	var horiz_line1 = path
	start_segment = vertical_line[0][-1]
	end_segment = vertical_line[3][-1]
	path = short_path_builder.get_shortest_path(start_segment.face_id,start_segment.position,end_segment.face_id,end_segment.position)
	#horizontal_line.append(path)
	path.pop_front()
	horiz_line1.append_array(path)
	horizontal_line.append(horiz_line1)
	
	start_segment = vertical_line[2][-1]
	end_segment = vertical_line[1][-1]
	path = short_path_builder.get_shortest_path(start_segment.face_id,start_segment.position,end_segment.face_id,end_segment.position)
	path.pop_back()
	var horiz_line2 = path
	start_segment = vertical_line[1][-1]
	end_segment = vertical_line[3][0]
	path = short_path_builder.get_shortest_path(start_segment.face_id,start_segment.position,end_segment.face_id,end_segment.position)
	path.pop_front()
	horiz_line2.append_array(path)
	horizontal_line.append(horiz_line2)
	#
	vertical_line.pop_front()
	vertical_line.pop_front()
	
	
	
	Draw_Helper.draw_line(horizontal_line,Color.RED,$lines/center_horizontal)
	Draw_Helper.draw_line(vertical_line,Color.BLUE,$lines/center_vertical)
	$points/p1.position = start_position
	
	return [horizontal_line,vertical_line]
	
	print("update")
	
func combine_line_segments(first_line,second_line):
	var line = []
	line.append(first_line[-1])
	for i in range(first_line.size()-2,0,-1):
		var face_id = first_line[i-1].face_id
		var edge_id = first_line[i].edge_id
		var pos = first_line[i].position
		var new_segment = LineWrapper.Wrap_Line_Segment.new(face_id,edge_id,pos)
		line.append(new_segment)
	for i in range(1,second_line.size()):
		line.append(second_line[i])
	return line
