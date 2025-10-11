extends Resource
class_name LineWrapper

var wmd : WrapMeshData

func _init(_wmd):
	wmd = _wmd
	
func make_wrapping_line(start_face_id:int, start_position:Vector3, line_rotation:float,total_distance:float):
	var left_line = []
	var right_line = []
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
	remaining_distance -= (p1.distance_to(intercept))
	right_line.append_array(make_wrapping_line_one_way(remaining_distance,intersection,start_face_id,start_position))
	perp_vector = perp_vector.rotated(face_normal,PI)
	
	p2 = perp_vector + start_position
	intersection = get_face_intercepts(start_face_id,p1,p2,-1)
	intercept = intersection[0]
	left_line.append(LineWrapper.Wrap_Line_Segment.new(start_face_id,-1,start_position))
	remaining_distance = total_distance
	remaining_distance -= (p1.distance_to(intercept))
	left_line.append_array(make_wrapping_line_one_way(remaining_distance,intersection,start_face_id,start_position))
	return [left_line,right_line]

func make_wrapping_line_one_way(remaining_distance:float,intersection:Array,curr_face_id:int,prev_intercept:Vector3):
	var line : Array[LineWrapper.Wrap_Line_Segment] = []
	var tries = 10000
	while remaining_distance > 0 and tries > 0:
		#
		var edge_id = intersection[1]
		var next_faces:Array = wmd.get_edge_faces(edge_id).duplicate()
		#print(next_faces)
		next_faces.erase(curr_face_id)
		if next_faces.size() > 1:
			printerr("too many connected faces")
		elif next_faces.size() < 1:
			printerr("not enough connected faces")
		var next_face_id = next_faces[0]
		var next_face = wmd.faces[next_face_id]
		var intercept = intersection[0]
		var line_vector : Vector3 = intercept - prev_intercept
		prev_intercept = intercept
		
		var wrap_line = LineWrapper.Wrap_Line_Segment.new(next_face_id,intersection[1],intercept)
		line.append(wrap_line)
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
		if p1.distance_to(intercept) >= remaining_distance:
			var percent = remaining_distance / p1.distance_to(intercept)
			intercept = p1.lerp(intercept,percent)
			remaining_distance = 0			
			wrap_line = LineWrapper.Wrap_Line_Segment.new(next_face_id,-1,intercept)
			line.append(wrap_line)


		remaining_distance -= p1.distance_to(intercept)
		curr_face_id = next_face_id
		tries -= 1
		##print(remaining_distance)

	return line
	
func get_face_intercepts(face_id:int,p1:Vector3,p2:Vector3,crossed_edge_id:int):
	#if p1 == p2:
		#printerr("get face intercepts - p1 equals p2")
	#print("get face intercepts")
	var projection_data = get_3D_to_2D_projection_data(face_id)
	var intercept_points_2d = []
	intercept_points_2d.append(project_3d_to_2d_point(projection_data,p1))
	intercept_points_2d.append(project_3d_to_2d_point(projection_data,p2))
	#var p1_projected = get_edge_line_intersect(projection_data,crossed_edge_id,intercept_points_2d)
	var p1_projected = project_2d_to_3d_point(projection_data, project_3d_to_2d_point(projection_data,p1))
	var intercepts = []
	for idx in 3:
		var edge_id = wmd.faces[face_id].edges[idx]
		if edge_id == crossed_edge_id:
			#printerr("crossed edge")
			continue
		
		var intercept_3d = get_edge_line_intersect(projection_data,edge_id,intercept_points_2d)
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
	
	var intercept = intercepts[0]
	return intercept

func get_3D_to_2D_projection_data(curr_face_id:int):
	#p0 is a point on the base plane, p1 is the point we are projecting onto it
	#https://www.baeldung.com/cs/3d-point-2d-plane
	#3.2. An Alternative Parameterization of the Plane
	#d=ap +bq +cr
	var data = {}
	var normal = wmd.get_face_normal(curr_face_id)
	data.normal = normal
	var tri_verts_3d = wmd.get_face_vertex_positions(curr_face_id)
	var d = normal.x * tri_verts_3d[0].x + normal.y * tri_verts_3d[0].y + normal.z * tri_verts_3d[0].z
	data.d = d
	var e1 = tri_verts_3d[1] - tri_verts_3d[0]
	e1 = e1.normalized()
	var e2 = e1.cross(normal)
	e2 = e2.normalized()
	data.e1 = e1
	data.e2 = e2
	data.origin = Vector3.ZERO
	
	#should be very close, get average just to be sure
	var offset = Vector3.ZERO
	for v in tri_verts_3d:
		var point_2d = project_3d_to_2d_point(data,v)
		var point_3d = project_2d_to_3d_point(data,point_2d)
		offset += v-point_3d
	offset /= tri_verts_3d.size()
	data.origin = offset
		
	#print(p4)
	#print(p2-p4)
	
	return data



func project_3d_to_2d_point(data:Dictionary,p1:Vector3):
	#If the normal vector is also a unit vector (i.e., its length is 1), the denominator is also one since it denotes the vector’s squared length.
	#if pow(normal.x,2) + pow(normal.y,2) + pow(normal.z,2) != 1.0:
		#printerr("normal not normalized")
	var k = data.d - data.normal.x * p1.x - data.normal.y * p1.y - data.normal.z * p1.z
	k = k / (pow(data.normal.x,2) + pow(data.normal.y,2) + pow(data.normal.z,2))
	#print(k)
	var p2 = Vector3.ZERO #the 3d point projected onto the plane (in 3d)
	p2.x = p1.x + k * data.normal.x
	p2.y = p1.y + k * data.normal.y
	p2.z = p1.z + k * data.normal.z
	var p3 = Vector2.ZERO
	p3.x = data.e1.x*p2.x + data.e1.y*p2.y + data.e1.z*p2.z
	p3.y = data.e2.x*p2.x + data.e2.y*p2.y + data.e2.z*p2.z
	return p3

func project_2d_to_3d_point(data:Dictionary,p1):
	var p4 = Vector3.ZERO
	p4 = p1.x * data.e1 + p1.y * data.e2 + data.origin # + tri_verts_3d[1]
	return p4


func get_edge_line_intersect(projection_data,edge_id,line:Array):
	#convert to 2d and back to 3d, was having issues with nearly parallel lines (due to rounding) when doing it with pure 3d intersects
	var edge_verts_3d = []
	edge_verts_3d.append(wmd.get_vertex_position(wmd.get_edge_vertex(edge_id,0)))
	edge_verts_3d.append(wmd.get_vertex_position(wmd.get_edge_vertex(edge_id,1)))
	var edge_verts_2d = []
	edge_verts_2d.append(project_3d_to_2d_point(projection_data,edge_verts_3d[0]))
	edge_verts_2d.append(project_3d_to_2d_point(projection_data,edge_verts_3d[1]))
	#print(edge_verts_2d)
	var intercept_2d = get_2d_line_intercept(line,edge_verts_2d)
	if intercept_2d == null:
		return null
	var intercept_3d = project_2d_to_3d_point(projection_data,intercept_2d)
	return intercept_3d

	
func get_2d_line_intercept(line1,line2):
	var l1_eq = get_2d_line_equation(line1[0],line1[1])
	var l2_eq = get_2d_line_equation(line2[0],line2[1])
	var point_2d = Vector2.ZERO
	if l1_eq.a*l2_eq.b - l1_eq.b * l2_eq.a == 0:
		return null
	point_2d.x = (l1_eq.c * l2_eq.b - l1_eq.b*l2_eq.c) / (l1_eq.a*l2_eq.b - l1_eq.b * l2_eq.a)
	point_2d.y = (l1_eq.a * l2_eq.c - l1_eq.c*l2_eq.a) / (l1_eq.a*l2_eq.b - l1_eq.b * l2_eq.a)
	#print(point_2d)
	return point_2d
		
func get_2d_line_equation(p1,p2):
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
	
	#TODO this might be wrong
	var intercept_vector = horizontal_line[segment_id].position-horizontal_line[segment_id-1].position
	#var intercept_vector = 
	intercept_vector = intercept_vector.rotated(wmd.get_face_normal(curr_face_id),-PI/2)
	intercept_vector = intercept_vector.normalized()
	
	
	var face_normal = wmd.get_face_normal(curr_face_id)
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
	var face_id:int # face the next part goes through, -1 at the end
	var edge_id:int #intersection, -1 if on face
	var position :Vector3
	
	func _init(_face_id:int, _edge_id : int,_position:Vector3) -> void:
		face_id = _face_id
		position = _position
		edge_id = _edge_id
	
	func _to_string() -> String:
		return "face_id=" + str(face_id) + " edge_id=" + str(edge_id) + " position=" + str(position)
