shader_type canvas_item;

uniform int margin = 1;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	if (COLOR.a == 0.0){
		vec2 closest_pixel = vec2(999,999);
		vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	    for(int y = -margin; y <= margin; y++) 
		{
		    for(int x = -margin; x <= margin; x++)
		    {
		        vec2 pixel_off = vec2(float(x), float(y));
				vec2 off_uv = UV + pixel_off * pixel_size;
		        vec4 tex = texture(TEXTURE, off_uv);
		        if (tex.a != 0.0)
				{
					if (distance(UV,off_uv) < distance(UV,closest_pixel))
					{
						closest_pixel = off_uv;
					}
				}
		    }
		}
		
		COLOR = texture(TEXTURE, closest_pixel);
		COLOR.a = 1.0;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
