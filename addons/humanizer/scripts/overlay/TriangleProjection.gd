extends Resource
class_name TriangleProjection

var verts_3d
var verts_2d = []
var data

func _init(_verts_3d):
	verts_3d = _verts_3d
	get_3D_to_2D_projection_data()
	for i in verts_3d.size():
		verts_2d.append(project_3d_to_2d_point(verts_3d[i]))
	
func find_edge_id(vert1,vert2):
	var vert_pos1 = verts_3d.find(vert1)
	var vert_pos2 = verts_3d.find(vert2)
	return vert_pos1

func get_edge_line_intersect(edge_id:int,line_verts_2d:Array):
	#convert to 2d and back to 3d, was having issues with nearly parallel lines (due to rounding) when doing it with pure 3d intersects
	var intercept_points_2d = []
	intercept_points_2d.append(project_3d_to_2d_point(line_verts_2d[0]))
	intercept_points_2d.append(project_3d_to_2d_point(line_verts_2d[1]))
	var edge_verts_3d = []
	edge_verts_3d.append(verts_3d[edge_id])
	edge_verts_3d.append(verts_3d[(edge_id+1)%3])
	#print(edge_verts_3d)
	var edge_verts_2d = []
	edge_verts_2d.append(project_3d_to_2d_point(edge_verts_3d[0]))
	edge_verts_2d.append(project_3d_to_2d_point(edge_verts_3d[1]))
	#print(edge_verts_2d)
	var intercept_2d = LineWrapper.get_2d_line_intercept(edge_verts_2d,intercept_points_2d,true)
	if intercept_2d == null:
		return null
	var intercept_3d = project_2d_to_3d_point(intercept_2d)
	return intercept_3d

	

static func get_face_normal(verts:Array):
	var normal = (verts[2] - verts[0]).cross(verts[1]-verts[0])
	normal = normal.normalized()
	#print(verts)
	#print(normal)
	return normal

func get_3D_to_2D_projection_data():
	#p0 is a point on the base plane, p1 is the point we are projecting onto it
	#https://www.baeldung.com/cs/3d-point-2d-plane
	#3.2. An Alternative Parameterization of the Plane
	#d=ap +bq +cr
	data = {}
	var normal = get_face_normal(verts_3d)
	data.normal = normal
	var d = normal.x * verts_3d[0].x + normal.y * verts_3d[0].y + normal.z * verts_3d[0].z
	data.d = d
	var e1 = verts_3d[1] - verts_3d[0]
	e1 = e1.normalized()
	var e2 = e1.cross(normal)
	e2 = e2.normalized()
	data.e1 = e1
	data.e2 = e2
	data.origin = Vector3.ZERO
	
	#should be very close, get average just to be sure
	var offset = Vector3.ZERO
	for v in verts_3d:
		var point_2d = project_3d_to_2d_point(v)
		var point_3d = project_2d_to_3d_point(point_2d)
		offset += v-point_3d
	offset /= verts_3d.size()
	data.origin = offset
		


func project_3d_to_2d_point(p1:Vector3):
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

func project_2d_to_3d_point(p1):
	var p4 = Vector3.ZERO
	p4 = p1.x * data.e1 + p1.y * data.e2 + data.origin # + tri_verts_3d[1]
	return p4

func PointInTriangle( p_3d:Vector3):
	var p :Vector2 = project_3d_to_2d_point(p_3d)
	var p0 = verts_2d[0]
	var p1 = verts_2d[1]
	var p2 = verts_2d[2]
	var s = (p0.x - p2.x) * (p.y - p2.y) - (p0.y - p2.y) * (p.x - p2.x);
	var t = (p1.x - p0.x) * (p.y - p0.y) - (p1.y - p0.y) * (p.x - p0.x);

	if ((s < 0) != (t < 0) && s != 0 && t != 0):
		return false;

	var d = (p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x);
	return d == 0 || (d < 0) == (s + t <= 0);
