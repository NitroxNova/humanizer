shader_type canvas_item;
render_mode unshaded;

uniform sampler2D gradient: hint_default_black;
uniform float mix_amount = 1.0;
//uniform sampler2D SCREEN_TEXTURE: hint_screen_texture,filter_linear_mipmap;

void fragment(){
	//vec4 input_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec4 input_color = texture(TEXTURE, UV);
	float greyscale_value = (input_color.r + input_color.g + input_color.b) / 3.0;
	vec4 sampled_color = texture(gradient, vec2(greyscale_value, 0.0));

	COLOR.rgb = mix(input_color, sampled_color, mix_amount).rgb;
	COLOR.a = input_color.a * sampled_color.a;
}