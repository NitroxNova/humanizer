@tool
extends HumanizerOverlay
class_name HumanizerOverlay3DNoiseCPU

@export var seed:int = 0
@export_enum("Cellular","Perlin","Simplex", "Simple_Smooth","Voronoi") var noise_type :String 
@export var frequency : float = .01
var noise : FastNoiseLite

func get_texture_node(target_size:Vector2,mesh_arrays:Array): 
	#print("generate 3d noise uv texture")
	var n_image = render_3d_noise(target_size,mesh_arrays)
			
	var node = TextureRect.new()
	node.size = target_size
	node.texture = ImageTexture.create_from_image(n_image)
	return node
	
func render_3d_noise(target_size:Vector2,mesh_arrays:Array):
	#https://www.sunshine2k.de/coding/java/TriangleRasterization/TriangleRasterization.html#sunbresenhamarticle
	var n_image = Image.create_empty(target_size.x,target_size.y,false,Image.FORMAT_RGBA8)
	noise = FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	if noise_type == "Cellular":
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	elif noise_type == "Perlin":
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
	elif noise_type == "Simplex":
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	elif noise_type == "Simplex_Smooth":
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elif noise_type == "Voronoi":
		#https://www.reddit.com/r/godot/comments/1cumyn4/voranoi_texture_in_godot/
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		
	#noise.frequency 
	#drawTriangle(Vector2(100,100),Vector2(900,250),Vector2(200,800),n_image)
	for tri_idx in mesh_arrays[Mesh.ARRAY_INDEX].size()/3:
	#for tri_idx in 100:
		var v1_id = mesh_arrays[Mesh.ARRAY_INDEX][tri_idx*3]
		var v2_id = mesh_arrays[Mesh.ARRAY_INDEX][tri_idx*3 +1]
		var v3_id = mesh_arrays[Mesh.ARRAY_INDEX][tri_idx*3 +2]
		var v1_uv = mesh_arrays[Mesh.ARRAY_TEX_UV][v1_id] * target_size
		var v2_uv = mesh_arrays[Mesh.ARRAY_TEX_UV][v2_id] * target_size
		var v3_uv = mesh_arrays[Mesh.ARRAY_TEX_UV][v3_id] * target_size
		var v1_vtx = mesh_arrays[Mesh.ARRAY_VERTEX][v1_id] 
		var v2_vtx = mesh_arrays[Mesh.ARRAY_VERTEX][v2_id] 
		var v3_vtx = mesh_arrays[Mesh.ARRAY_VERTEX][v3_id] 
		var triangle = BarycentricTriangle.new(PackedVector2Array([v1_uv,v2_uv,v3_uv]),PackedVector3Array([v1_vtx,v2_vtx,v3_vtx]))
		#print(triangle.uv)
		drawTriangle(n_image,triangle)
	return n_image
	
func fillBottomFlatTriangle(image:Image,triangle:BarycentricTriangle,uv1,uv2,uv3):
	var invslope1:float = (uv2.x - uv1.x) / (uv2.y - uv1.y)
	var invslope2:float = (uv3.x - uv1.x) / (uv3.y - uv1.y)

	var curx1:float = uv1.x
	var curx2:float = uv1.x
	
	for scanlineY in range(uv1.y,uv2.y+1):
		drawLine(image,int(curx1), int(curx2), scanlineY,triangle);
		curx1 += invslope1;
		curx2 += invslope2;
  
func drawLine(image,x1:int,x2:int,y,triangle:BarycentricTriangle):
	#print("draw line",x1,x2)
	if x2 < x1:
		var temp = x1
		x1 = x2
		x2 = temp
		
	for x in range(x1,x2+1):
		#print("set pixel ",x,y)
		#var noise_coords = get_barycentric_coords(Vector2(x,y))
		var noise_pos = triangle.get_barycentric_coords_3d(Vector2(x,y))
		var noise_value = noise.get_noise_3dv(noise_pos)
		noise_value = (noise_value + 1) /2
		var color = Color(noise_value,noise_value,noise_value)
		#print(noise_value)
		image.set_pixel(x,y,color)
		
func fillTopFlatTriangle(image:Image,triangle:BarycentricTriangle,uv1,uv2,uv3):
	var invslope1:float = (uv3.x - uv1.x) / (uv3.y - uv1.y)
	var invslope2:float = (uv3.x - uv2.x) / (uv3.y - uv2.y)

	var curx1:float = uv3.x;
	var curx2:float = uv3.x;

	#for (int scanlineY = v3.y; scanlineY > v1.y; scanlineY--)
	for scanlineY in range(uv3.y,uv1.y,-1):
		drawLine(image,int(curx1), int(curx2), scanlineY,triangle);
		curx1 -= invslope1;
		curx2 -= invslope2;
  

func drawTriangle(image:Image,triangle:BarycentricTriangle):
  #/* here we know that v1.y <= v2.y <= v3.y */
  #/* check for trivial case of bottom-flat triangle */
	var uv1 = triangle.uv[0]
	var uv2 = triangle.uv[1]
	var uv3 = triangle.uv[2]
	if (uv2.y == uv3.y):
		fillBottomFlatTriangle(image,triangle,uv1,uv2,uv3);
  #/* check for trivial case of top-flat triangle */
	elif (uv1.y == uv2.y):
		fillTopFlatTriangle(image,triangle,uv1,uv2,uv3);
	else:
	#/* general case - split the triangle in a topflat and bottom-flat one */
		var uv4 = Vector2(
		(int)(uv1.x + ((float)(uv2.y - uv1.y) / (float)(uv3.y - uv1.y)) * (uv3.x - uv1.x)), uv2.y);
		fillBottomFlatTriangle(image,triangle,uv1,uv2,uv4);
		fillTopFlatTriangle(image,triangle,uv2,uv4,uv3);
  


func render_2d_noise(target_size:Vector2):
	var n_image = Image.create_empty(target_size.x,target_size.y,false,Image.FORMAT_RGBA8)
	var noise = FastNoiseLite.new()
	noise.seed = seed
	for x in n_image.get_width():
		for y in n_image.get_height():
			var n_val = noise.get_noise_2d(x,y )
			n_val = (n_val + 1) /2
			var color = Color(n_val,n_val,n_val)
			n_image.set_pixel( x,y, color)
	return n_image
	

class BarycentricTriangle:
	#https://math.stackexchange.com/questions/5052177/how-to-map-2d-to-3d-triangle-knowing-the-vertices-in-both-coordinate-systems
	var uv : PackedVector2Array
	var vtx : PackedVector3Array
	#var matrix : Basis
	
	func _init(_uv,_vertex):
		var sort_verts = []
		for i in 3:
			sort_verts.append([_uv[i],_vertex[i]])
		sort_verts.sort_custom(sort_uv_ascending)
		for i in 3:
			uv.append(sort_verts[i][0])
			vtx.append(sort_verts[i][1])
		
		#var mx1 :Basis = Basis(Vector3(vtx[0].x,vtx[1].x,vtx[2].x),Vector3(vtx[0].y,vtx[1].y,vtx[2].y),Vector3(vtx[0].z,vtx[1].z,vtx[2].z))
		#var mx2 :Basis = Basis(Vector3(uv[0].x,uv[1].x,uv[2].x),Vector3(uv[0].y,uv[1].y,uv[2].y),Vector3(1.0,1.0,1.0)).inverse()
		#matrix = mx1*mx2
		#print(matrix)
		
	func sort_uv_ascending(a,b):
		if a[0].y < b[0].y:
			return true
		return false		
	
	#func get_3d_coords(input_uv:Vector2):
		##var vec3 = Vector3(input_uv.x,input_uv.y,1.0)
		##var out_vertex : Vector3 = matrix * vec3
		##print(out_vertex)
		#var bary_coords2d = get_barycentric_coords_2d(input_uv)
		#var bary_coords3d = get_barycentric_coords_3d(bary_coords2d)
		##print(bary_coords)
		#return bary_coords3d
		##return out_vertex
		##print("test")
		
		#https://stackoverflow.com/questions/65066769/project-point-on-2d-triangle-back-into-3d
		#// tri is a 3D triangle with points p0, p1 and p2
	#// point is a 2D point within that triangle, assuming the Z axis is discarded
	func get_barycentric_coords_3d(point:Vector2):
	#// Find the barycentric coords for the chosen 2D point...
		
		var bary2d:Vector3 = get_barycentric_coords_2d(point);
		#// ...and then find what the Z value would be for those barycentric coords in 3D
		var point2 = Vector3.ZERO
		#point2.x = vtx[0].x + (vtx[1].x - vtx[0].x) * bary2d.x + (vtx[2].x - vtx[0].x) * bary2d.y
		#point2.y = vtx[0].y + (vtx[1].y - vtx[0].y) * bary2d.x + (vtx[2].y - vtx[0].y) * bary2d.y
		#point2.z = vtx[0].z + (vtx[1].z - vtx[0].z) * bary2d.x + (vtx[2].z - vtx[0].z) * bary2d.y
		point2 = (bary2d.x * vtx[0] + bary2d.y * vtx[1] + bary2d.z * vtx[2]) 
		return point2

	#// https://gamedev.stackexchange.com/a/63203/48697
	#func get_barycentric2D( p:Vector2):
	#
		#var v0:Vector2 = uv[1] - uv[0];
		#var v1:Vector2 = uv[2] - uv[0];
		#var v2:Vector2 = p - uv[0];
		#var den:float = v0.x * v1.y - v1.x * v0.y;
		#var v = (v2.x * v1.y - v1.x * v2.y) / den;
		#var w = (v0.x * v2.y - v2.x * v0.y) / den;
		#var u = 1.0 - v - w;
		#return Vector3(u,v,w)
	
	
	##https://stackoverflow.com/questions/65066769/project-point-on-2d-triangle-back-into-3d
	#func get_barycentric_coords_3d(bary2d:Vector3):
		#var point = Vector3.ZERO
		#point.x = vtx[0].x + (vtx[1].x - vtx[0].x) * bary2d.x + (vtx[2].x - vtx[0].x) * bary2d.y
		#point.y = vtx[0].y + (vtx[1].y - vtx[0].y) * bary2d.x + (vtx[2].y - vtx[0].y) * bary2d.y
		#point.z = vtx[0].z + (vtx[1].z - vtx[0].z) * bary2d.x + (vtx[2].z - vtx[0].z) * bary2d.y
		#return point
			#
	## https://gamedev.stackexchange.com/questions/23743/whats-the-most-efficient-way-to-find-barycentric-coordinates		
	##// Compute barycentric coordinates (u, v, w) for
	##// point p with respect to triangle (a, b, c)
	func get_barycentric_coords_2d( point:Vector2):
		
		var v0:Vector2 = uv[1] - uv[0]
		var v1:Vector2 = uv[2] - uv[0]
		var v2:Vector2 = point - uv[0];
		var d00:float = v0.dot(v0)
		var d01:float = v0.dot(v1);
		var d11:float = v1.dot(v1);
		var d20:float = v2.dot(v0);
		var d21:float = v2.dot(v1);
		var denom:float = d00 * d11 - d01 * d01;
		var v = (d11 * d20 - d01 * d21) / denom;
		var w = (d00 * d21 - d01 * d20) / denom;
		var u = 1.0 - v - w;
		return Vector3(u,v,w)
