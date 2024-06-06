#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) restrict readonly uniform image2D uv_map;

layout(set = 0, binding = 1, rgba32f) restrict writeonly uniform image2D albedo;

layout(set = 0, binding = 2, rgba32f) restrict writeonly uniform image2D normal;

layout(set = 0, binding = 3, std140) restrict readonly uniform shader_paramters_buffer
{
	vec4 spot_color;
	float spot_amount;
	float spot_size;
};

// Function to generate a random 3D vector based on a 3D integer grid position
vec3 random3(vec3 p) {
    vec3 randomVec = fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * vec3(43758.5453, 23123.123, 12345.6789));
    return randomVec;
}

// Function to generate Voronoi noise value at a given 3D position
float voronoi3D(vec3 pos) {
    vec3 p = floor(pos);
    vec3 f = fract(pos);

    float minDist = 1.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 point = random3(p + neighbor);
                vec3 diff = neighbor + point - f;
                float dist = length(diff);
                minDist = min(minDist, dist);
            }
        }
    }
    return minDist;
}

void set_albedo(vec3 pos)
{
    vec4 color = vec4(1.);
    color.rgb = vec3(voronoi3D(pos * 100.));
    imageStore(albedo, ivec2(gl_GlobalInvocationID.xy), color);
}

void main()
{
    vec3 position = vec3(imageLoad(uv_map, ivec2(gl_GlobalInvocationID.xy)).rgb);
    set_albedo(position);
}

