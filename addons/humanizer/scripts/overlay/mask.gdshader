shader_type canvas_item;
render_mode unshaded;

//uniform sampler2D gradient: hint_default_black;
uniform float mix_amount = 1.0;
uniform sampler2D mask_image;
uniform sampler2D base_image;
//uniform sampler2D SCREEN_TEXTURE: hint_screen_texture,filter_linear_mipmap;

void fragment(){
	//vec4 input_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec4 base_color = texture(base_image, UV);
	vec4 mask_color = texture(mask_image,UV); //should be greyscale, alpha = 1
	//vec4 overlay_color = texture(overlay_image,UV); //should be greyscale, alpha = 1

	float greyscale_value = (mask_color.r + mask_color.g + mask_color.b) / 3.0;
	//vec4 sampled_color = mix(base_color,overlay_color,greyscale_value);
	//sampled_color = (sampled_color * overlay_color.a) +  (base_color * (1.0-overlay_color.a));
	vec4 sampled_color = base_color;
	sampled_color.a = base_color.a * greyscale_value;
	COLOR = sampled_color;
	//COLOR = vec4(base_color.a,base_color.a,base_color.a,1.0);
	//COLOR = base_color;
	//vec4 sampled_color = input_color * mask_color;
	//float greyscale_value = (input_color.r + input_color.g + input_color.b) / 3.0;
	//vec3 sampled_color = texture(gradient, vec2(greyscale_value, 0.0)).rgb;
	//COLOR = mix(input_color, sampled_color, mix_amount);

	//COLOR.rgb = mix(input_color.rgb, sampled_color, mix_amount);
	//COLOR.a = input_color.a;
}