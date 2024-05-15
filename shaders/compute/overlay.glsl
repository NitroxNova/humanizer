#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1024, local_size_z = 1) in;

//layout(set = 0, binding = 0, rgba32f) readonly restrict uniform image2DArray overlays;
layout(set = 0, binding = 1, rgba32f) writeonly restrict uniform image2D output_texture;
//layout(set = 0, binding = 2, std430) restrict buffer ArrayData {
//	vec3 color[];
//} data;
//layout(set = 0, binding = 3) restrict uniform ArraySize {
//	int size;
//} array;

void main() {
	/*
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	vec4 color = imageLoad(overlays, ivec3(id, 0));
	color.rgb *= data.color[0];
	for (int i = 1; i < array.size; i++) {
		vec4 ov_color = imageLoad(overlays, ivec3(id, i));
		ov_color.rgb *= data.color[i];
		color.rgb = (1 - ov_color.a) * color.rgb + ov_color.a * ov_color.rgb;
		imageStore(output_texture, id, vec4(0.));//color);
	}
	*/
}
