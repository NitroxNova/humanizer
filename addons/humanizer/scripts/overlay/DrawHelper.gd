extends Resource
class_name Draw_Helper


static func draw_line(line:Array, color:Color,mi:MeshInstance3D):
	
	var meshInstance = mi
	var mesh = ImmediateMesh.new();
	var material = StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	meshInstance.mesh = mesh
	
	mesh.surface_begin(Mesh.PRIMITIVE_LINES);
	mesh.surface_set_color(color);
	
	if line[0] is LineWrapper.Wrap_Line_Segment:
		draw_line_segments(line,mesh)
	elif line[0] is Vector3:
		draw_line_points(line,mesh)
	else:
		for line_array in line:
			if line_array == null:
				continue
			if line_array[0] is LineWrapper.Wrap_Line_Segment:
				draw_line_segments(line_array,mesh)
			elif line_array[0] is Vector3:
				draw_line_points(line_array,mesh)
	
	mesh.surface_end();
	mesh.surface_set_material(0,material)

static func draw_line_points(line,mesh):
	for i in line.size()-1:
		var v1 = line[i]
		var v2 = line[i+1]
		mesh.surface_add_vertex(v1);
		mesh.surface_add_vertex(v2);
		

static func draw_line_segments(line,mesh): 
	for s_id in line.size()-1:
		var segment = line[s_id]
		var segment2 = line[s_id+1]
		var v1 = segment.position
		var v2 = segment2.position
		mesh.surface_add_vertex(v1);
		mesh.surface_add_vertex(v2);

	
