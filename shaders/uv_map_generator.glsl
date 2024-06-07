#[compute]
#version 450


// Generate an image encoding a mapping from texture space to object space

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, std140) restrict readonly uniform n_faces_buffer {
	uint n_faces;
};

layout(set = 0, binding = 1, std430) restrict buffer vtx_positions_buffer {
	vec3[] vtx_positions;
};

layout(set = 0, binding = 2, std430) restrict buffer vtx_uv_buffer {
	vec2[] vtx_uv;
};

layout(set = 0, binding = 3, std430) restrict buffer faces_buffer {
	ivec3[] faces;
};

layout(set = 0, binding = 10, rgba32f) restrict writeonly uniform image2D output_texture;


vec2 get_texture_coordinates() 
{
	vec2 uv = vec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_texture);
	// Center on texel (+ 0.5)
	return (uv + 0.5) / float(size.x);
}

vec3 get_barycentric_coordinates(ivec3 face, vec2 p)
{
	vec2 a = vtx_uv[face[0]];
	vec2 b = vtx_uv[face[1]];
	vec2 c = vtx_uv[face[2]];

    // Vectors from triangle vertices to the point
    vec2 v0 = b - a;
    vec2 v1 = c - a;
    vec2 v2 = p - a;

    // Compute dot products
    float d00 = dot(v0, v0);
    float d01 = dot(v0, v1);
    float d11 = dot(v1, v1);
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);

    // Compute the denominators
    float invDenom = 1.0 / (d00 * d11 - d01 * d01);

    // Compute barycentric coordinates
    float v = (d11 * d20 - d01 * d21) * invDenom;
    float w = (d00 * d21 - d01 * d20) * invDenom;
    float u = 1.0 - v - w;

    return vec3(u, v, w);
}

bool texel_is_inside_face(vec3 barycentric_coords)
{
	// All coordinates should be in [0, 1] and they should sum to 1
	if (barycentric_coords.x < 0)
		return false;
	if (barycentric_coords.x > 1)
		return false;
	if (barycentric_coords.y < 0)
		return false;
	if (barycentric_coords.y > 1)
		return false;
	if (barycentric_coords.z < 0)
		return false;
	if (barycentric_coords.z > 1)
		return false;
	if (abs(barycentric_coords.x + barycentric_coords.y + barycentric_coords.z - 1.0) > .0001)
		return false;
	return true;
}

void main() 
{
	vec2 uv = get_texture_coordinates();
	for (int i = 0; i < n_faces; i++)
	{
		// if face isn't close don't bother doing any computation
		if (length(vtx_uv[faces[i][0]] - uv) > 0.1)
			continue;

		vec3 barycentric_coords = get_barycentric_coordinates(faces[i], uv);
		if (texel_is_inside_face(barycentric_coords))
		{
			vec3 interpolated_position = barycentric_coords.x * vtx_positions[faces[i][0]]
			   						   + barycentric_coords.y * vtx_positions[faces[i][1]]
			   						   + barycentric_coords.z * vtx_positions[faces[i][2]];
			imageStore(output_texture, ivec2(gl_GlobalInvocationID.xy), vec4(interpolated_position, 1.0));
			break;
		}
	}
}

