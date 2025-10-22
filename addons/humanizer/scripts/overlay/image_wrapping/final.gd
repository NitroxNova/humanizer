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
	var border_faces = []
	#print("~~~~~~")
	#for segment in horizontal_lines[0]:
		#print(segment.face_id)
	#print("~~~~~~")
	for i in horizontal_lines.size():
		for segment in horizontal_lines[i]:
			if segment.face_id not in border_faces:
				border_faces.append(segment.face_id)
	for i in vertical_lines.size():
		for segment in vertical_lines[i]:
			if segment.face_id not in border_faces:
				border_faces.append(segment.face_id)
				
	#print(internal_faces)
	
	var sf_arrays = []
	sf_arrays.resize(Mesh.ARRAY_MAX)
	sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	
	
	var borders2 = [borders[0][0]]
	borders2.append(borders[1][0])
	borders2.append(borders[0][1])
	borders2.append(borders[1][1])
	
	
	var cut_edge_faces = cut_edge_faces(borders2)	
	var edge_faces = cut_edge_faces[0]
	var new_borders = cut_edge_faces[1]
	#print(edge_faces)	
	var new_edge_faces = []
	for face_id in edge_faces:
		for temp_tri in edge_faces[face_id]:
			new_edge_faces.append([temp_tri.verts_3d[0],temp_tri.verts_3d[1],temp_tri.verts_3d[2]])
		#TODO		
	for nf in new_edge_faces:
		for vtx_pos in nf:
			sf_arrays[Mesh.ARRAY_VERTEX].append(vtx_pos)
			#print(vtx_pos ==sf_arrays[Mesh.ARRAY_VERTEX][-1] )
	
	#print(new_edge_faces[-1][-1])
	#print(sf_arrays[Mesh.ARRAY_VERTEX].size())
	
	var cut_mesh = ArrayMesh.new()
	cut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays)
	$CutMesh.mesh = cut_mesh
	
	var first_tri = []
	var edges_wmd = WrapMeshData.new(cut_mesh)
	if start_face_id in border_faces:
		var start_pos = wmd.get_face_center_point(start_face_id)
		for face in edge_faces[start_face_id]:
			if face.PointInTriangle(start_pos):
				first_tri = face.verts_3d.duplicate()
	else:
		first_tri = wmd.faces[start_face_id].vertices.duplicate()
	
	var connected_faces = []
	get_connected_internal_faces(first_tri,edges_wmd,new_borders,edge_faces,connected_faces)	
		
	sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	for nf in connected_faces:
		for vtx_pos in nf:
			sf_arrays[Mesh.ARRAY_VERTEX].append(vtx_pos)
	cut_mesh = ArrayMesh.new()
	cut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays)
	$CutMesh.mesh = cut_mesh	
	return new_borders
	
func get_connected_internal_faces(verts_3d,edges_wmd:WrapMeshData,border_edges,border_faces,connected_faces=[]):
	#print(border_edges)
	if verts_3d in connected_faces:
		return
	connected_faces.append(verts_3d) 
	for i in 3:
		var vert1 = verts_3d[i]
		var vert2 = verts_3d[(i+1) %3]
		if is_border_edge([vert1,vert2],border_edges):
			continue
		var edge_id = edges_wmd.find_edge_id([vert1,vert2])
		if edge_id != -1:
			for face_id in edges_wmd.edges[edge_id].faces:
				var face = edges_wmd.faces[face_id]
				get_connected_internal_faces(face.vertices,edges_wmd,border_edges,border_faces,connected_faces)
		edge_id = wmd.find_edge_id([vert1,vert2])
		if edge_id != -1:
			for face_id in wmd.edges[edge_id].faces:
				if face_id in border_faces:
					continue	
				var face = wmd.faces[face_id]
				get_connected_internal_faces(face.vertices,edges_wmd,border_edges,border_faces,connected_faces)				

func is_border_edge(verts:Array,border_edges):
	for line in border_edges:
		if verts[0] in line and verts[1] in line:
			return true
	return false	
			


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
	#var shapes = []
	#for face_id in border_shapes:
		#for temp_tri in border_shapes[face_id]:
			#shapes.append([temp_tri.verts_3d[0],temp_tri.verts_3d[1],temp_tri.verts_3d[2]])		
	return [border_shapes,new_borders]
			
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
