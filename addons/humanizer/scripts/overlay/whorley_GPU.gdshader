shader_type canvas_item;
render_mode unshaded;
uniform int seed = 1;
uniform float grid_size = .1;
varying vec3 position_3D;

void vertex() {
	// Called for every vertex the material is visible on.
	position_3D.rgb = CUSTOM0.rgb;
	//COLOR.rgb = position_3D;
}


// Function to generate a pseudo-random float from a float seed
float rand_float() {
    return fract(sin(float(seed) * 12.9898 + 78.233) * 43758.5453);
}
float rand_from_vec2(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Function to generate a pseudo-random Vector3 from an integer seed
vec3 rand_vec3_from_vec3(vec3 influencing_vector) {
    float seed_float = float(seed);

    // Use a proper noise function for better results
    float random_x = rand_from_vec2(influencing_vector.xy + vec2(seed_float, 0.0));
    float random_y = rand_from_vec2(influencing_vector.yz + vec2(seed_float, 0.0));
    float random_z = rand_from_vec2(influencing_vector.zx + vec2(seed_float, 0.0));

    vec3 random_vector = vec3(random_x, random_y, random_z);
	return random_vector;
    // Further modifications (e.g., scaling, normalization) if needed
    // random_vector = normalize(random_vector) * some_radius;

    // ... (use the random_vector for shading)
}

vec3 get_cell_id(vec3 position) {
	vec3 cell_id = vec3(floor(position.x / grid_size),floor(position.y / grid_size),floor(position.z / grid_size));
	return cell_id;
	}

vec3 get_cell_center(vec3 cell_id) {
	vec3 cell_pos = cell_id * grid_size;
	vec3 center_pos = rand_vec3_from_vec3(cell_id)*grid_size;
	center_pos += cell_pos;
	return center_pos;
}

float get_color_at(vec3 position){
	float nearest = 1.0;
	vec3 cell_id = get_cell_id(position);
	for (int chunk_x=-1;chunk_x<2;chunk_x++){
		for (int chunk_y=-1;chunk_y<2;chunk_y++){
			for (int chunk_z=-1;chunk_z<2;chunk_z++){
				vec3 center_pos = get_cell_center(cell_id + vec3(float(chunk_x),float(chunk_y),float(chunk_z)));
				if (distance(position,center_pos) < nearest) {
					nearest = distance(position,center_pos);
				}
			}
		}
	}
	return nearest/grid_size;
}


void fragment() {
	//vec3 pos = vec3(VERTEX.x,VERTEX.y,0.0);
	//pos/= 2048.0;

	COLOR.r = get_color_at(position_3D);
	COLOR.g = COLOR.r;
	COLOR.b = COLOR.r;

	//COLOR.rgb = position_3D;

	//COLOR.rg = UV;
	//COLOR.rgb = center_pos;
}