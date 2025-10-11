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
	var internal_vertices = cut_mesh(borders)
	print(internal_vertices)
	var cut_wmd = WrapMeshData.new($CutMesh.mesh)
	for face in cut_wmd.faces:
		for vtx_idx in face.vertices.size():
			cut_wmd.vertices[face.vertices[vtx_idx]].new_uv = face.uvs[vtx_idx]
	var harmap = HarmonicMap.new(cut_wmd,internal_vertices)
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.propagate_uvs()
	harmap.rebuild_mesh_uvs($CutMesh)

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
	for face_id in internal_faces:
		var face = wmd.faces[face_id]
		for vtx_id in face.vertices:
			sf_arrays[Mesh.ARRAY_VERTEX].append(vtx_id)
			if vtx_id not in internal_uvs:
				internal_uvs.append(vtx_id)
			sf_arrays[Mesh.ARRAY_TEX_UV].append(Vector2(.5,.5))
	
	var borders2 = [borders[0][0]]
	borders2.append(borders[1][0])
	borders2.append(borders[1][1])
	borders2.append(borders[0][1])
	borders2.append(borders[1][2])
	borders2.append(borders[1][3])
	
	var external_uvs = get_external_uvs(borders2)
	#print(external_uvs)
	
	var edge_faces = cut_edge_faces(borders2)		
	var new_edge_faces = []
	for edge_face in edge_faces:
		#print(ef_id)
		for vtx_pos in edge_face:
			if vtx_pos in internal_vertices:
				if edge_face.size() == 3:
					new_edge_faces.append(edge_face)
					break
				elif edge_face.size() == 4:
					new_edge_faces.append([edge_face[0],edge_face[1],edge_face[2]])
					new_edge_faces.append([edge_face[2],edge_face[3],edge_face[0]])
					break
				else:
					printerr("more than 4 edges")
				
	for nf in new_edge_faces:
		for vtx_pos in nf:
			sf_arrays[Mesh.ARRAY_VERTEX].append(vtx_pos)
			if vtx_pos in external_uvs:
				sf_arrays[Mesh.ARRAY_TEX_UV].append(external_uvs[vtx_pos])
			else:
				if vtx_pos not in internal_uvs:
					internal_uvs.append(vtx_pos)
				sf_arrays[Mesh.ARRAY_TEX_UV].append(Vector2(.5,.5))
			
	var cut_mesh = ArrayMesh.new()
	cut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays)
	$CutMesh.mesh = cut_mesh
	return internal_uvs
	
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
			end_uv = Vector2(1,.5)
		elif line_id == 2:
			start_uv = Vector2(1,.5)
			end_uv = Vector2(1,1)
		elif line_id == 3:
			start_uv = Vector2(1,1)
			end_uv = Vector2(0,1)
		elif line_id == 4:
			start_uv = Vector2(0,1)
			end_uv = Vector2(0,.5)
		elif line_id == 5:
			start_uv = Vector2(0,.5)
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
	var shapes = []
	#print(borders[1])
	for line_id in borders.size():
		var line = borders[line_id]
		
		for segment_id in line.size()-1:
			var segment1 = line[segment_id]
			var segment2 = line[segment_id+1]
			if segment1.edge_id == -1 or segment2.edge_id == -1: #conrner
				continue
			#print(segment1.edge_id)
			var face = wmd.faces[segment1.face_id]
			#print(segment1)
			#print(segment2)
			if segment1.edge_id not in face.edges:
				printerr("segment 1 edge ",segment1.edge_id ," not in face ",segment1.face_id)
			if segment2.edge_id not in face.edges:
				printerr("segment 2 edge ",segment2.edge_id ," not in face ",segment1.face_id)
			var face_verts = face.vertices.duplicate()
			var output_polygons = [ [],[] ]
			var cur_poly_id = 0
			for i in face_verts.size():
				var vtx1_id = face_verts[i]
				output_polygons[cur_poly_id].append(vtx1_id)
				var vtx2_id = face_verts[(i+1) % face_verts.size()]
				var edge_id = wmd.find_edge_id([vtx1_id,vtx2_id])
				if edge_id == segment1.edge_id:
					output_polygons[cur_poly_id].append(segment1.position)
					cur_poly_id = (cur_poly_id + 1) % 2
					output_polygons[cur_poly_id].append(segment1.position)
				elif edge_id == segment2.edge_id:
					output_polygons[cur_poly_id].append(segment2.position)
					cur_poly_id = (cur_poly_id + 1) % 2
					output_polygons[cur_poly_id].append(segment2.position)
			shapes.append_array(output_polygons)
			#print(output_polygons)		
			#shapes.append(first_shape)
	#print(shapes)
	return shapes

	
			
func make_borders():
	#draw center line, going left and going right
	var start_position = wmd.get_face_center_point(start_face_id)
	var line_wrapper = LineWrapper.new(wmd)
	var horizontal_distance = image.get_width() / 100 * image_scale
	var horizontal_line = line_wrapper.make_wrapping_line(start_face_id,start_position,image_rotation,horizontal_distance)
	var vertical_distance = image.get_height() / 100 *image_scale
	var vertical_line = line_wrapper.make_wrapping_line(start_face_id,start_position,image_rotation+ PI/2,vertical_distance)
	vertical_line.append_array(line_wrapper.make_vertical_wrapping_line(1,horizontal_line[0],vertical_distance))
	vertical_line.append_array(line_wrapper.make_vertical_wrapping_line(1,horizontal_line[1],vertical_distance))
	##
	horizontal_line.pop_front()
	horizontal_line.pop_front()
	#
	var start_segment = vertical_line[2][-1]
	var end_segment = vertical_line[0][-1]
	var path = short_path_builder.get_shortest_path(start_segment.face_id,start_segment.position,end_segment.face_id,end_segment.position)
	#horizontal_line.append(path)
	path.pop_back()
	var horiz_line1 = path
	start_segment = vertical_line[0][-1]
	end_segment = vertical_line[5][-1]
	path = short_path_builder.get_shortest_path(start_segment.face_id,start_segment.position,end_segment.face_id,end_segment.position)
	#horizontal_line.append(path)
	path.pop_front()
	horiz_line1.append_array(path)
	horizontal_line.append(horiz_line1)
	
	start_segment = vertical_line[3][-1]
	end_segment = vertical_line[1][-1]
	path = short_path_builder.get_shortest_path(start_segment.face_id,start_segment.position,end_segment.face_id,end_segment.position)
	path.pop_back()
	var horiz_line2 = path
	start_segment = vertical_line[1][-1]
	end_segment = vertical_line[4][-1]
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
