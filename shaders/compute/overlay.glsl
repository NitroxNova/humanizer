#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) readonly restrict uniform image2DArray overlays;
layout(set = 0, binding = 1, rgba32f) writeonly restrict uniform image2D output_texture;
layout(set = 0, binding = 2, std430) readonly restrict buffer ArrayData { vec3 colors[]; };
layout(set = 0, binding = 3, std140) readonly restrict uniform ArraySize { int size; };

void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	vec4 color = imageLoad(overlays, ivec3(id, 0));
	color.rgb *= colors[0];
	for (int i = 1; i < size; i++) {
		vec4 ov_color = imageLoad(overlays, ivec3(id, i));
		ov_color.rgb *= colors[i];
		color.rgb = mix(color.rgb, ov_color.rgb, ov_color.a);
		imageStore(output_texture, id, color);
	}
}
