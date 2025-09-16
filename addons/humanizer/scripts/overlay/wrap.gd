@tool
extends Node


var mdt : WrapMeshData
var target_size = Vector2(128,128)
var image : Image = Image.create(target_size.x,target_size.y,false,Image.FORMAT_RGBA8)

@export var start_face_id :int = 0

@export var rotate_line = 0.0:
	set(value):
		rotate_line = value
		run_update()

@export var line_distance = 1.0		
	
@export var update = false:
	set(value):
		run_update()

func _ready():	
	#mdt.create_from_surface($MeshInstance3D.mesh, 0) # Use surface 0, or iterate through surfaces
	mdt = WrapMeshData.new($MeshInstance3D.mesh)

func _process(delta:float):
	#rotate_line += delta
	pass

func run_update():
	run_update2()
	#draw_normals($line_gimbal/Line_3D)

func run_update2():
	var line = []
	mdt = WrapMeshData.new($MeshInstance3D.mesh)
	#start in the center and draw line to edge
	image.fill(Color.PINK)
	var face_id = start_face_id
	var face = mdt.faces[face_id]
	var verts = mdt.get_face_vertex_positions(face_id)
	#print(verts)
		
	var uvs = mdt.faces[face_id].uvs
	var center_point :Vector3 = mdt.get_face_center_point(face_id)
	line.append(center_point)
	#draw on starting point
	var bary_triangle = Barycentric_Triangle_3D.new(verts[0],verts[1],verts[2])
	var coords_2d = bary_triangle.get_2D_coords(center_point,uvs,target_size)
	image.set_pixelv(coords_2d,Color.BLUE)
	
	var face_normal = mdt.get_face_normal(face_id)

	var perp_vector :Vector3 = face_normal.cross(Vector3.UP)
	if perp_vector == Vector3.ZERO:
		perp_vector = face_normal.cross(Vector3.FORWARD)

	perp_vector = perp_vector.rotated(face_normal,rotate_line)
	perp_vector = perp_vector.normalized()
	
	var p1 = center_point
	var p2 = perp_vector + center_point

	var intersection = get_face_intercepts(face_id,p1,p2,-1)
	#var intersection = get_face_intercepts(face,p1,p2,-1)
	var intercept = intersection[0]
	var prev_intercept = center_point
	line.append(intercept)
	var remaining_distance = line_distance
	var curr_face_id = face_id #so export var doesnt change
	remaining_distance -= (p1.distance_to(intercept))
	
	var tries = 10000
	while remaining_distance > 0 and tries > 0:
		#
		var edge_id = intersection[1]
		var next_faces:Array = mdt.get_edge_faces(edge_id).duplicate()
		next_faces.erase(curr_face_id)
		if next_faces.size() > 1:
			printerr("too many connected faces")
		elif next_faces.size() < 1:
			printerr("not enough connected faces")
		var next_face_id = next_faces[0]
		var next_face = mdt.faces[next_face_id]
		#
		var line_vector : Vector3 = intercept - prev_intercept
		prev_intercept = intercept
		
#
		var face1_normal = mdt.get_face_normal(curr_face_id)
		var face2_normal = mdt.get_face_normal(next_face_id)
		var rotation_angle = face1_normal.angle_to(face2_normal)
		var axis : Vector3 = mdt.get_vertex_position(mdt.get_edge_vertex(edge_id,1)) - mdt.get_vertex_position(mdt.get_edge_vertex(edge_id,0))
		var axis2 : Vector3 = mdt.get_vertex_position(mdt.get_edge_vertex(edge_id,0)) - mdt.get_vertex_position(mdt.get_edge_vertex(edge_id,1))
		axis = axis.normalized()
		axis2 = axis2.normalized()
		var result1 = face1_normal.rotated(axis,rotation_angle)
		var result2 = face1_normal.rotated(axis2,rotation_angle)
		if result2.distance_to(face2_normal) < result1.distance_to(face2_normal):
			axis = axis2 
		#
		line_vector = line_vector.rotated(axis,rotation_angle)
		p1 = intercept
		p2 = intercept + line_vector
		
		
		var intercept_line = []
		intercept_line.append(p1)
		intercept_line.append(p2)
		var dh = Draw_Helper.new($line_gimbal/Line_3D)
		dh.draw_line(intercept_line,Color.RED)
		
		intersection = get_face_intercepts(next_face_id,p1,p2,edge_id)

		intercept = intersection[0]
		line.append(intercept)

		remaining_distance -= p1.distance_to(intercept)
		#
		#
		curr_face_id = next_face_id
		tries -= 1
		##print(remaining_distance)
		#
	##print(tries)
	var dh = Draw_Helper.new($line_gimbal/Line_3D)
	dh.draw_line(line,Color.RED)
	
	
	
	var material = $MeshInstance3D.get_surface_override_material(0)
	material.albedo_texture = ImageTexture.create_from_image(image)

func get_face_intercepts(face_id:int,p1:Vector3,p2:Vector3,crossed_edge_id:int):
	$points/p1.hide()
	$points/p2.hide()
	$points/p3.hide()
	var projection_data = get_3D_to_2D_projection_data(face_id)
	var intercept_points_2d = []
	intercept_points_2d.append(project_3d_to_2d_point(projection_data,p1))
	intercept_points_2d.append(project_3d_to_2d_point(projection_data,p2))
	var p1_projected = get_edge_line_intersect(projection_data,crossed_edge_id,intercept_points_2d)
	var intercepts = []
	for idx in 3:
		var edge_id = mdt.faces[face_id].edges[idx]
		if edge_id == crossed_edge_id:
			continue
		
		var intercept_3d = get_edge_line_intersect(projection_data,edge_id,intercept_points_2d)
		if intercept_3d == null:
			continue
		
		if intercept_3d.distance_to(p2) > intercept_3d.distance_to(p1-(p2-p1)):
			continue
			
		#var node_name = "p" + str(idx+1)
		#var node = $points.get_node(node_name)
		#node.show()
		#node.position = intercept_3d
			
		if intercept_3d == p1_projected && crossed_edge_id != -1: #this should be the actual projected point
			#printerr("intercept on vertex")
			continue
		
		intercepts.append([intercept_3d,edge_id])
			
	while intercepts.size() > 1:
		if intercepts[0][0].distance_to(p1) < intercepts[1][0].distance_to(p1):
			intercepts.remove_at(1)
		else:
			intercepts.remove_at(0)
	
	var intercept = intercepts[0]
	return intercept

func get_edge_line_intersect(projection_data,edge_id,line:Array):
	#convert to 2d and back to 3d, was having issues with nearly parallel lines (due to rounding) when doing it with pure 3d intersects
	var edge_verts_3d = []
	edge_verts_3d.append(mdt.get_vertex_position(mdt.get_edge_vertex(edge_id,0)))
	edge_verts_3d.append(mdt.get_vertex_position(mdt.get_edge_vertex(edge_id,1)))
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
		

func draw_normals(mi):
	
	var meshInstance = mi
	var mesh = ImmediateMesh.new();
	var material = StandardMaterial3D.new()
	var color = Color.RED

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	mesh.surface_begin(Mesh.PRIMITIVE_LINES);
	mesh.surface_set_color(color);
	
	meshInstance.mesh = mesh
	for face_id in mdt.faces.size():
		var normal = mdt.get_face_normal(face_id)
		var center = mdt.get_face_center_point(face_id)
		mesh.surface_add_vertex(center);
		mesh.surface_add_vertex(center + normal);
	mesh.surface_end();
	mesh.surface_set_material(0,material)
	
func get_3D_to_2D_projection_data(curr_face_id:int):
	#p0 is a point on the base plane, p1 is the point we are projecting onto it
	#https://www.baeldung.com/cs/3d-point-2d-plane
	#3.2. An Alternative Parameterization of the Plane
	#d=ap +bq +cr
	var data = {}
	var normal = mdt.get_face_normal(curr_face_id)
	data.normal = normal
	var tri_verts_3d = mdt.get_face_vertex_positions(curr_face_id)
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
	

func get_3D_line_intersect(p1:Vector3,p2:Vector3,p3:Vector3,p4:Vector3):
	#https://paulbourke.net/geometry/pointlineplane/
	
	var d1321 = get_3D_line_intersect_dot_product(p1,p3,p2,p1)
	var d1343 = get_3D_line_intersect_dot_product(p1,p3,p4,p3)
	var d2121 = get_3D_line_intersect_dot_product(p2,p1,p2,p1)
	var d4321 = get_3D_line_intersect_dot_product(p4,p3,p2,p1)
	var d4343 = get_3D_line_intersect_dot_product(p4,p3,p4,p3)
	var mua = (d1343*d4321 - d1321*d4343)/(d2121*d4343 - d4321 * d4321)
	var mub = (d1343 + mua * d4321)/d4343
	var pa = p1 + mua * (p2 - p1)
	#print(mua)
	#print(mub)
	var pb = p3 + mub * (p4 - p3)
	#if pa != pb:
		#print(pa," --- ",pb)
		#printerr("lines are skewed")
	return [pa,pb]

func get_3D_line_intersect_dot_product(m:Vector3,n:Vector3,o:Vector3,p:Vector3):
	return ((m.x-n.x) * (o.x-p.x)) + ((m.y-n.y)*(o.y-p.y)) + ((m.z-n.z)*(o.z-p.z))

class WrapMeshData:
	#mesh data tool does not get connected faces/edges along seams, had to make my own
	var vertices = []
	var faces = []
	var edges = []
	
	func _init(mesh:ArrayMesh):
		var sf_arrays = mesh.surface_get_arrays(0)
		#for i in sf_arrays[Mesh.ARRAY_INDEX].size()/3:
			
		for v_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
			var v_pos = sf_arrays[Mesh.ARRAY_VERTEX][v_id]
			var new_v_id = find_vertex_id(v_pos)		
			if new_v_id == -1:
				var vtx = Vertex.new()
				vtx.position = v_pos
				vertices.append(vtx)
		
		for i in sf_arrays[Mesh.ARRAY_INDEX].size()/3:
			var face = Face.new()
			for j in 3:
				var old_v_id = sf_arrays[Mesh.ARRAY_INDEX][i*3+j]
				var new_v_id = find_vertex_id( sf_arrays[Mesh.ARRAY_VERTEX][old_v_id] )
				face.add_uv_vertex_pair(sf_arrays[Mesh.ARRAY_TEX_UV][old_v_id],new_v_id)
				#face.normal = sf_arrays[Mesh.ARRAY_NORMAL][old_v_id]
				#tri_data.append({v_id=new_v_id,uv=sf_arrays[Mesh.ARRAY_TEX_UV][old_v_id]})
			
			var face_id = find_face_id(face.vertices)
			if face_id == -1:	
				face_id = faces.size()	
				faces.append(face)
				
			for j in 3:
				var k = (j + 1) % 3
				var edge_verts = [face.vertices[j],face.vertices[k]]
				edge_verts.sort()
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
					
					
	func find_vertex_id(pos:Vector3):
		for v_id in vertices.size():
			var vtx : Vertex = vertices[v_id]
			if vtx.position == pos:
				return v_id
		return -1
	
	func find_edge_id(v_index:Array):
		for e_id in edges.size():
			var edge : Edge = edges[e_id]
			if edge.vertices == v_index:
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
		
	class Edge:
		var faces = []
		var vertices = []
	
	class Face:
		var edges = []
		var vertices :Array[int] = []
		var uvs = []
		#var normal 
		
		func add_uv_vertex_pair(uv:Vector2,vertex:int):
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
	
	class Vertex:
		var edges = []
		var faces = []
		var position : Vector3

	

class Barycentric_Triangle_3D:
	var a : Vector3
	var b : Vector3
	var c : Vector3
	var v0 : Vector3
	var v1 : Vector3
	var d00 : float
	var d01 : float
	var d11 : float
	var denom : float
	
	func _init(_a,_b,_c):
		a = _a
		b = _b
		c = _c
		v0 = b-a
		v1 = c-a	
		d00 = v0.dot(v0)
		d01 = v0.dot(v1)
		d11 = v1.dot(v1)
		denom = d00 * d11 - d01 * d01;
	
	func get_bary_coords(p:Vector3):
		var v2 :Vector3 = p-a
		var d20 : float = v2.dot(v0)
		var d21 : float = v2.dot(v1)
		var v = (d11 * d20 - d01 * d21) / denom;
		var w = (d00 * d21 - d01 * d20) / denom;
		var u = 1.0 - v - w;
		return Vector3(u,v,w)
	
	func get_2D_coords(p:Vector3,uvs:Array,target_size:Vector2):
		var a_2d = uvs[0] * target_size
		var b_2d = uvs[1] * target_size
		var c_2d = uvs[2] * target_size
		var bary_coords = get_bary_coords(p)
		var coords_2D = (a_2d * bary_coords.x) + (b_2d * bary_coords.y) + (c_2d * bary_coords.z)
		return coords_2D

class Draw_Helper:
	var material = StandardMaterial3D.new()
	var  mesh :ImmediateMesh
	var  meshInstance : MeshInstance3D

	func _init(mi:MeshInstance3D):
		meshInstance = mi
		mesh = ImmediateMesh.new();
		material = StandardMaterial3D.new()

		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		meshInstance.mesh = mesh
	

	func draw_line(line:Array, color:Color):
		mesh.surface_begin(Mesh.PRIMITIVE_LINES);
		mesh.surface_set_color(color);
		for v_id in line.size()-1:
			var v1 = line[v_id]
			var v2 = line[v_id+1]
			mesh.surface_add_vertex(v1);
			mesh.surface_add_vertex(v2);
		mesh.surface_end();
		mesh.surface_set_material(0,material)
	
