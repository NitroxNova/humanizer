extends Resource
class_name LineWrapper

var wmd : WrapMeshData

func _init(_wmd):
	wmd = _wmd

func make_floating_line(face_normal:Vector3,start_position:Vector3, line_rotation:float,total_distance:float ):
	var left_line = []
	var right_line = []

	var perp_vector :Vector3 = face_normal.cross(Vector3.UP)
	if perp_vector == Vector3.ZERO:
		perp_vector = face_normal.cross(Vector3.FORWARD)
	#print(perp_vector)

	perp_vector = perp_vector.rotated(face_normal,line_rotation)
	perp_vector = perp_vector.normalized()
	#print(perp_vector)
	
	var p1 = start_position
	var p2 = perp_vector *total_distance + start_position
	
	right_line.append(LineWrapper.Wrap_Line_Segment.new(-1, -1 ,start_position))
	right_line.append(LineWrapper.Wrap_Line_Segment.new(-1, -1 ,p2))
	
	perp_vector = perp_vector.rotated(face_normal,PI)
	p2 = perp_vector *total_distance + start_position
	left_line.append(LineWrapper.Wrap_Line_Segment.new(-1,-1,start_position))
	left_line.append(LineWrapper.Wrap_Line_Segment.new(-1,-1,p2))
	#return [left_line,right_line]
	return [right_line,left_line]
	
	
func make_wrapping_line(start_face_id:int, start_position:Vector3, line_rotation:float,total_distance:float):
	var left_line = []
	var right_line = []
	if start_face_id == -1:
		printerr("start face is -1")
		return [left_line,right_line]
		
	var face_normal = wmd.get_face_normal(start_face_id)

	var perp_vector :Vector3 = face_normal.cross(Vector3.UP)
	if perp_vector == Vector3.ZERO:
		perp_vector = face_normal.cross(Vector3.FORWARD)
	#print(perp_vector)

	perp_vector = perp_vector.rotated(face_normal,line_rotation)
	perp_vector = perp_vector.normalized()
	#print(perp_vector)
	
	var p1 = start_position
	var p2 = perp_vector + start_position
	

	var intersection = get_face_intercepts(start_face_id,p1,p2,-1)
	var intercept = intersection[0]
	
	right_line.append(LineWrapper.Wrap_Line_Segment.new(start_face_id, -1 ,start_position))
	var remaining_distance = total_distance
	right_line.append_array(make_wrapping_line_one_way(remaining_distance,intersection,start_face_id,start_position))
	perp_vector = perp_vector.rotated(face_normal,PI)
	
	p2 = perp_vector + start_position
	intersection = get_face_intercepts(start_face_id,p1,p2,-1)
	intercept = intersection[0]
	left_line.append(LineWrapper.Wrap_Line_Segment.new(start_face_id,-1,start_position))
	remaining_distance = total_distance
	left_line.append_array(make_wrapping_line_one_way(remaining_distance,intersection,start_face_id,start_position))
	return [left_line,right_line]

func make_wrapping_line_one_way(remaining_distance:float,intersection:Array,curr_face_id:int,prev_intercept:Vector3):
	var line : Array[LineWrapper.Wrap_Line_Segment] = []
	var tries = 10000
	#print("starting distance = ",remaining_distance)
	#remaining_distance -= intersection[0].distance_to(prev_intercept)
	while remaining_distance > 0 and tries > 0:
		
		var intercept = intersection[0]
		var line_vector : Vector3 = intercept - prev_intercept
		line_vector = line_vector.normalized()
		var edge_id = intersection[1]
		var next_faces:Array = wmd.get_edge_faces(edge_id).duplicate()
		#print(next_faces)
		next_faces.erase(curr_face_id)
		
		if next_faces.size() > 1:
			printerr("too many connected faces")
		elif next_faces.size() < 1:
			#printerr("not enough connected faces")
			#straight line off the mesh
			var wrap_line = LineWrapper.Wrap_Line_Segment.new(-1,edge_id,intercept)
			#print(wrap_line)
			line.append(wrap_line)
			remaining_distance -= prev_intercept.distance_to(intercept)
			line_vector = prev_intercept - intercept
			line_vector = line_vector.normalized()
			intercept = line_vector * remaining_distance + intercept
			wrap_line = LineWrapper.Wrap_Line_Segment.new(-1,-1,intercept)
			line.append(wrap_line)
			return line
			
		var next_face_id = next_faces[0]
		var next_face = wmd.faces[next_face_id]
		
		if prev_intercept.distance_to(intercept) >= remaining_distance:
			var percent = remaining_distance / prev_intercept.distance_to(intercept)
			intercept = prev_intercept.lerp(intercept,percent)
			remaining_distance = 0			
			var wrap_line = LineWrapper.Wrap_Line_Segment.new(curr_face_id,-1,intercept)
			line.append(wrap_line)
		else:
			var wrap_line = LineWrapper.Wrap_Line_Segment.new(next_face_id,intersection[1],intercept)
			line.append(wrap_line)
		
		remaining_distance -= prev_intercept.distance_to(intercept)
		prev_intercept = intercept
		
		if remaining_distance > 0:
#
			var face1_normal = wmd.get_face_normal(curr_face_id)
			var face2_normal = wmd.get_face_normal(next_face_id)
			var rotation_angle = face1_normal.angle_to(face2_normal)
			var axis : Vector3 = wmd.get_vertex_position(wmd.get_edge_vertex(edge_id,1)) - wmd.get_vertex_position(wmd.get_edge_vertex(edge_id,0))
			var axis2 : Vector3 = wmd.get_vertex_position(wmd.get_edge_vertex(edge_id,0)) - wmd.get_vertex_position(wmd.get_edge_vertex(edge_id,1))
			axis = axis.normalized()
			axis2 = axis2.normalized()
			var result1 = face1_normal.rotated(axis,rotation_angle)
			var result2 = face1_normal.rotated(axis2,rotation_angle)
			if result2.distance_to(face2_normal) < result1.distance_to(face2_normal):
				axis = axis2 
			#
			line_vector = line_vector.rotated(axis,rotation_angle)
			var p1 = intercept
			var p2 = intercept + line_vector
			
			#print("make wrap line one way get face intercept")
			intersection = get_face_intercepts(next_face_id,p1,p2,edge_id)

			intercept = intersection[0]
			curr_face_id = next_face_id
			tries -= 1
	
	
	
	if tries <= 0:
		printerr("Ran out of tries")
	#print(line)
	return line
	
func get_face_intercepts(face_id:int,p1:Vector3,p2:Vector3,crossed_edge_id:int):
	#if p1 == p2:
		#printerr("get face intercepts - p1 equals p2")
	#print("get face intercepts")
	var proj_tri = TriangleProjection.new(wmd.faces[face_id].vertices)
	
	
	#var p1_projected = get_edge_line_intersect(projection_data,crossed_edge_id,intercept_points_2d)
	var p1_projected = proj_tri.project_2d_to_3d_point(proj_tri.project_3d_to_2d_point(p1))
	var intercepts = []
	for idx in 3:
		var edge_id = wmd.faces[face_id].edges[idx]
		if edge_id == crossed_edge_id:
			#printerr("crossed edge")
			continue
		var edge_verts_3d = []
		edge_verts_3d.append(wmd.get_vertex_position(wmd.get_edge_vertex(edge_id,0)))
		edge_verts_3d.append(wmd.get_vertex_position(wmd.get_edge_vertex(edge_id,1)))
		#print(edge_verts_3d)
		var intercept_3d = proj_tri.get_edge_line_intersect(idx,[p1,p2])
		if intercept_3d == null:
			#printerr("intercept is null")
			continue
		
		if intercept_3d.distance_to(p2) > intercept_3d.distance_to(p1-(p2-p1)):
			#printerr("on opposite side of line")
			continue
			
		#if intercept_3d == p1_projected && crossed_edge_id != -1: #this should be the actual projected point
		if intercept_3d == p1_projected:
			#printerr("intercept on previous intercept")
			continue
		
		intercepts.append([intercept_3d,edge_id])
			
	while intercepts.size() > 1:
		if intercepts[0][0].distance_to(p1) < intercepts[1][0].distance_to(p1):
			intercepts.remove_at(1)
		else:
			intercepts.remove_at(0)
	
	if intercepts.size() == 0:
		print(face_id)
		print(p1)
		print(p2)
		print(crossed_edge_id)
		return null
	
	var intercept = intercepts[0]
	return intercept



static func point_within_3d_line_segment(line:Array,point:Vector3):
	var minx = min(line[0].x,line[1].x)
	var miny = min(line[0].y,line[1].y)
	var minz = min(line[0].z,line[1].z)
	var maxx = max(line[0].x,line[1].x)
	var maxy = max(line[0].y,line[1].y)
	var maxz = max(line[0].z,line[1].z)
	if point.x < minx:
		return false
	if point.y < miny:
		return false
	if point.z < minz:
		return false
	if point.x > maxx:
		return false
	if point.y > maxy:
		return false
	if point.z > maxz:
		return false
	return true
	

	
static func get_2d_line_intercept(line1,line2,clamp:bool): #clamp to line1 (edge) only NOT line2
	var l1_eq = get_2d_line_equation(line1[0],line1[1])
	var l2_eq = get_2d_line_equation(line2[0],line2[1])
	var point_2d = Vector2.ZERO
	if l1_eq.a*l2_eq.b - l1_eq.b * l2_eq.a == 0:
		return null
	point_2d.x = (l1_eq.c * l2_eq.b - l1_eq.b*l2_eq.c) / (l1_eq.a*l2_eq.b - l1_eq.b * l2_eq.a)
	point_2d.y = (l1_eq.a * l2_eq.c - l1_eq.c*l2_eq.a) / (l1_eq.a*l2_eq.b - l1_eq.b * l2_eq.a)
	
	var max_x = max(line1[0].x,line1[1].x)
	var min_x = min(line1[0].x,line1[1].x)
	var max_y = max(line1[0].y,line1[1].y)
	var min_y = min(line1[0].y,line1[1].y)
	
	if clamp:
		if point_2d.x < min_x or point_2d.y < min_y or point_2d.x > max_x or point_2d.y > max_y:
			return null
	
	#print(point_2d)
	return point_2d
		
static func get_2d_line_equation(p1,p2):
	# to standard form a1x+b1y=c1
	if p1.x == p2.x:
		var a = 1
		var b = 0
		var c = p1.x
		return {a=a,b=b,c=c}
	var m = (p2.y - p1.y) / (p2.x - p1.x)
	#Use the point-slope formula: y - y₁ = m(x - x₁)
	# -y1 + mx1 = mx - y
	var mx1 = m * p1.x
	var c = -1 * p1.y + mx1
	var b = -1
	var a = m
	#print(m)
	return {a=a,b=b,c=c}

func make_vertical_wrapping_line(percent:float,horizontal_line,vertical_distance:float):
#make perpendicular lines
	
	var segment_data = get_weighted_line_segment(percent,horizontal_line)
	#print(percent)
	#print(horizontal_line.size())
	#print(percent)
	#print(segment_data)
	var segment_id = segment_data.segment_id
	var curr_face_id = horizontal_line[segment_id].face_id
	
	var face_normal = wmd.get_face_normal(curr_face_id)
	if curr_face_id == -1:
		face_normal = wmd.get_face_normal(horizontal_line[segment_id-2].face_id)
		
	#TODO this might be wrong
	var intercept_vector = horizontal_line[segment_id].position-horizontal_line[segment_id-1].position
	#var intercept_vector = 
	intercept_vector = intercept_vector.rotated(face_normal,-PI/2)
	intercept_vector = intercept_vector.normalized()
	
	
		
	var perp_vector :Vector3 = face_normal.cross(Vector3.UP)
	if perp_vector == Vector3.ZERO:
		perp_vector = face_normal.cross(Vector3.FORWARD)
	#printerr(perp_vector)
	#printerr(intercept_vector)
	var line_rotation = perp_vector.angle_to(intercept_vector)
	#printerr(perp_vector.rotated(face_normal,line_rotation).normalized())
	if perp_vector.rotated(face_normal,line_rotation).normalized().distance_to(intercept_vector) > perp_vector.rotated(face_normal,-line_rotation).normalized().distance_to(intercept_vector):
		#printerr("intercept vector doesnt match")
		#printerr(perp_vector.rotated(face_normal,-line_rotation).normalized())
		line_rotation = -line_rotation
	if curr_face_id == -1:
		return make_floating_line(face_normal,segment_data.start_point,line_rotation,vertical_distance)
		
	
	return make_wrapping_line(curr_face_id,segment_data.start_point,line_rotation,vertical_distance)
	#return [[segment_data.start_point,segment_data.start_point+intercept_vector]]

func get_weighted_line_segment(weight:float,horizontal_line:Array):
	var total_distance = 0
	for segment_id in horizontal_line.size()-1:
		var segment1 = horizontal_line[segment_id]
		var segment2 = horizontal_line[segment_id+1]
		total_distance += segment1.position.distance_to(segment2.position)
		
	var target_distance = weight * total_distance
	var output = {} 
	var cur_distance = 0
	if weight >= 1:
		output.segment_id = horizontal_line.size()-1
		output.start_point = horizontal_line[-1].position
		return output
	for segment_id in horizontal_line.size()-1:
		var segment = horizontal_line[segment_id]
		var segment2 = horizontal_line[segment_id+1]
		var next_distance = cur_distance + segment.position.distance_to(segment2.position)
		if next_distance >= target_distance or segment_id == horizontal_line.size()-1:
			output.segment_id = segment_id
			var percent = (target_distance-cur_distance)/(next_distance-cur_distance)
			output.start_point = segment.position.lerp(segment2.position,percent)
			#print(output)
			return output
		cur_distance = next_distance
		
class Wrap_Line_Segment:
	var face_id:int # face the next part goes through, -1 if it goes over the edges
	var edge_id:int #intersection, -1 if on face
	var position :Vector3
	
	func _init(_face_id:int, _edge_id : int,_position:Vector3) -> void:
		face_id = _face_id
		position = _position
		edge_id = _edge_id
	
	func _to_string() -> String:
		return "face_id=" + str(face_id) + " edge_id=" + str(edge_id) + " position=" + str(position)
