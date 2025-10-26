@tool
extends Node3D

@export var update = false:
	set(value):
		run_update()

@export var img_texture : Texture2D:
	set(value):
		img_texture = value
		run_update()

@export var face_id = 0:
	set(value):
		face_id = value
		run_update()
		
@export var img_distance = 1.0 :
	set(value):
		img_distance = value
		run_update()
		
@export var img_rotate = 0.0:
	set(value):
		img_rotate = value
		run_update()

@export var img_scale = 1.0:
	set(value):
		img_scale = value
		run_update()
		
		
@export var hide_back_faces = false:
	set(value):
		hide_back_faces = value
		run_update()

@export var block_faces = false:
	set(value):
		block_faces = value
		run_update()
	

func run_update():
	#print("update")
	$SubViewport2/image.texture = img_texture
	$SubViewport2/image.centered = false
	$SubViewport2/image.offset = Vector2.ONE
	
	$SubViewport2.size = img_texture.get_size() + Vector2(2,2)
	$plane.get_surface_override_material(0).albedo_texture = img_texture
	
	
	var sf_arrays = $FedoraCocked.mesh.surface_get_arrays(0)
	var face_verts = []
	for i in 3:
		var idx = face_id * 3 + i
		var vtx_id = sf_arrays[Mesh.ARRAY_INDEX][idx]
		var vtx_pos = sf_arrays[Mesh.ARRAY_VERTEX][vtx_id]
		face_verts.append(vtx_pos)
	var axis_max:float =  max(img_texture.get_width(),img_texture.get_height()) 
	var axis_scale = Vector2(img_texture.get_width()/axis_max,img_texture.get_height()/axis_max)
	axis_scale *= img_scale
	var plane = Plane_Projection.new(face_verts,img_rotate,axis_scale)
	draw_plane(plane,axis_scale)
	
	var uv_arrays = []
	uv_arrays.resize(Mesh.ARRAY_MAX)
	uv_arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array()
	uv_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	
	var valid_verts = []
	
	for face_id in sf_arrays[Mesh.ARRAY_INDEX].size()/3:
		var cur_verts = []
		for i in 3:
			var idx = face_id * 3 + i
			var vtx_id = sf_arrays[Mesh.ARRAY_INDEX][idx]
			var vtx_pos = sf_arrays[Mesh.ARRAY_VERTEX][vtx_id]
			var p1 = vtx_pos + plane.normal_3d
			var intersect_3d = plane.intersect_line_plane_v3(vtx_pos,p1)
			var intersect_2d = plane.project_3d_to_2d(intersect_3d)
			#print(intersect_2d)
			#var uv_1 = sf_arrays[Mesh.ARRAY_TEX_UV][vtx_id] * 512
			if vtx_pos.distance_to(intersect_3d) < img_distance:
				cur_verts.append([vtx_id,intersect_2d,vtx_pos,intersect_3d])
		if cur_verts.size()	== 3:
			var minx = min(cur_verts[0][1].x,cur_verts[1][1].x,cur_verts[2][1].x) 
			var miny = min(cur_verts[0][1].y,cur_verts[1][1].y,cur_verts[2][1].y)
			var maxx = max(cur_verts[0][1].x,cur_verts[1][1].x,cur_verts[2][1].x)
			var maxy = max(cur_verts[0][1].y,cur_verts[1][1].y,cur_verts[2][1].y)
			if minx > 1 or miny > 1 or maxx < 0 or maxy < 0:
				continue
			if hide_back_faces:
				var vtx1 = sf_arrays[Mesh.ARRAY_VERTEX][cur_verts[0][0]]
				var vtx2 = sf_arrays[Mesh.ARRAY_VERTEX][cur_verts[1][0]]
				var vtx3 = sf_arrays[Mesh.ARRAY_VERTEX][cur_verts[2][0]]
				var normal = TriangleProjection.get_face_normal([vtx1,vtx2,vtx3])
				if normal.angle_to(plane.normal_3d) > PI * .5:
					continue
			valid_verts.append(cur_verts)
	
	#print(valid_verts.size())
	
	if block_faces:
		for tri_id in range(valid_verts.size()-1,-1,-1):
			if is_blocked_face(tri_id,valid_verts,plane.normal_3d):
				valid_verts.remove_at(tri_id)		
	
	#print(valid_verts.size())				
			
	for cur_verts in valid_verts:		
		for i in 3:
			var vtx_id = cur_verts[i][0]
			var vtx_pos =  sf_arrays[Mesh.ARRAY_TEX_UV][vtx_id] * 512 
			uv_arrays[Mesh.ARRAY_VERTEX].append(vtx_pos)
			uv_arrays[Mesh.ARRAY_TEX_UV].append(cur_verts[i][1])	
			
	var uv_mesh = ArrayMesh.new()
	if valid_verts.size() > 0:
		uv_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,uv_arrays)
	$SubViewport/projection.mesh = uv_mesh		

func is_blocked_face(tri_id,valid_verts,plane_normal):
	var tri_verts = valid_verts[tri_id]
	for check_tri in valid_verts:
		if check_tri == tri_verts:
			continue
		#check each vertex against each valid triangle
		var check_tri_verts = [check_tri[0][2],check_tri[1][2],check_tri[2][2]]
		for vertex in tri_verts:
			var intersect = intersect_triangle(vertex[2],plane_normal,check_tri_verts)
			if intersect != null:
				if vertex[3].distance_to(vertex[2]) > vertex[3].distance_to(intersect):
				##else opposite side of face, ignore
					return true
	return false
	
#https://stackoverflow.com/questions/42740765/intersection-between-line-and-triangle-in-3d
func intersect_triangle(line_origin:Vector3, line_direction:Vector3, tri_verts:Array):
	#in Ray R, in vec3 A, in vec3 B, in vec3 C, out float t, 
	#out float u, out float v, out vec3 N
#) { 
	var E1 : Vector3 = tri_verts[1]-tri_verts[0];
	var E2 : Vector3 = tri_verts[2]-tri_verts[0];
	var N = E1.cross(E2)
	var det:float = - line_direction.dot(N) ;
	var invdet:float = 1.0/det;
	var AO : Vector3  = line_origin - tri_verts[0];
	var DAO : Vector3 = AO.cross(line_direction)
	var u =  E2.dot(DAO) * invdet;
	var v = - E1.dot(DAO) * invdet;
	var t =  AO.dot(N)  * invdet; 
	if (det >= 1e-6 && t >= 0.0 && u >= 0.0 && v >= 0.0 && (u+v) <= 1.0):
		return line_origin + t * line_direction
	return null

#}

func draw_plane(plane,axis_scale):
	var rect_uvs = [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	var rect_corners = []
	rect_corners.append(plane.project_2d_to_3d(rect_uvs[0]))
	rect_corners.append(plane.project_2d_to_3d(rect_uvs[1]))
	rect_corners.append(plane.project_2d_to_3d(rect_uvs[2]))
	rect_corners.append(plane.project_2d_to_3d(rect_uvs[3]))
	var plane_sf = []
	plane_sf.resize(Mesh.ARRAY_MAX)
	plane_sf[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	plane_sf[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	for i in [0,1,2,2,3,0]:
		plane_sf[Mesh.ARRAY_VERTEX].append(rect_corners[i])
		plane_sf[Mesh.ARRAY_TEX_UV].append(rect_uvs[i])
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,plane_sf)
	$plane.mesh = array_mesh
	#print(plane.origin_3d)	
	
	
class Plane_Projection:
	
	var origin_3d : Vector3
	var normal_3d : Vector3
	var unit_1 :Vector3
	var unit_2 :Vector3
	var axis_scale : Vector2
	
	func _init(face_verts,rotate,_axis_scale):
		origin_3d = (face_verts[0] + face_verts[1] + face_verts[2]) / 3
		normal_3d = TriangleProjection.get_face_normal(face_verts)
		unit_1 = (face_verts[0] - face_verts[1])
		unit_1 = unit_1.rotated(normal_3d,rotate)
		unit_1 = unit_1.normalized()
		unit_2 = unit_1.cross(normal_3d)
		unit_2 = unit_2.normalized()
		axis_scale = _axis_scale
		#unit_1 *= axis_scale.x
		#unit_2 *= axis_scale.y
	
	func project_2d_to_3d(point_2d:Vector2):
		point_2d = point_2d*axis_scale-(axis_scale/2)
		var point_3d = origin_3d + (point_2d.x * unit_1) + (point_2d.y * unit_2)
		
		return point_3d
	
	func project_3d_to_2d(point_3d:Vector3):
		var v = point_3d - origin_3d
		var point_2d :Vector2
		point_2d.x = v.dot(unit_1)
		point_2d.y = v.dot(unit_2)
		point_2d /= axis_scale
		point_2d += Vector2(.5,.5)
		return point_2d
		
#https://stackoverflow.com/questions/5666222/3d-line-plane-intersection
	func intersect_line_plane_v3(p0, p1, epsilon=1e-6):
		#"""
		#p0, p1: Define the line.
		#p_co, p_no: define the plane:
			#p_co Is a point on the plane (plane coordinate).
			#p_no Is a normal vector defining the plane direction;
				 #(does not need to be normalized).
	#
		#Return a Vector or None (when the intersection can't be found).
		#"""

		var u = sub_v3v3(p1, p0)
		var dot = dot_v3v3(normal_3d, u)

		if abs(dot) > epsilon:
			# The factor of the point between p0 -> p1 (0 - 1)
			# if 'fac' is between (0 - 1) the point intersects with the segment.
			# Otherwise:
			#  < 0.0: behind p0.
			#  > 1.0: infront of p1.
			var w = sub_v3v3(p0, origin_3d)
			var fac = -dot_v3v3(normal_3d, w) / dot
			u = mul_v3_fl(u, fac)
			return add_v3v3(p0, u)

		# The segment is parallel to plane.
		return null

# ----------------------
# generic math functions

	func add_v3v3(v0, v1):
		return Vector3(
			v0[0] + v1[0],
			v0[1] + v1[1],
			v0[2] + v1[2],
		)


	func sub_v3v3(v0, v1):
		return [
			v0[0] - v1[0],
			v0[1] - v1[1],
			v0[2] - v1[2],
		]


	func dot_v3v3(v0, v1):
		return (
			(v0[0] * v1[0]) +
			(v0[1] * v1[1]) +
			(v0[2] * v1[2])
		)


	func len_squared_v3(v0):
		return dot_v3v3(v0, v0)


	func mul_v3_fl(v0, f):
		return [
			v0[0] * f,
			v0[1] * f,
			v0[2] * f,
		]
