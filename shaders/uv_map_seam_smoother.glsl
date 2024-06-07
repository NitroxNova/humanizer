#[compute]
#version 450

// Smooth the seams of the uv to object space map image

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) restrict readonly uniform image2D input_texture;

layout(set = 0, binding = 1, rgba32f) restrict writeonly uniform image2D output_texture;

bool isBlack(vec4 color)
{
    return length(color.rgb) < 0.0001;
}

void main()
{
    vec4 color = imageLoad(input_texture, ivec2(gl_GlobalInvocationID.xy));
    // Texels outside the mesh bounds are black
    if (isBlack(color))
    {
        float norm = 0.;
        vec4 new_color = vec4(0.);
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                vec4 texel = imageLoad(input_texture, ivec2(gl_GlobalInvocationID.xy) + ivec2(i, j));
                if (! isBlack(texel)) {
                    norm += 1.;
                    new_color += texel;
                }
            }
        }
        if (norm >= 0.999) {
            new_color /= norm;
            imageStore(output_texture, ivec2(gl_GlobalInvocationID.xy), new_color);
        }
    }
}

