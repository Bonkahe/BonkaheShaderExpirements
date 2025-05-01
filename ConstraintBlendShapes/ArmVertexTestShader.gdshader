shader_type spatial;

const vec3 vectors[3] = {
	vec3(1.0, 0.0 ,0.0),
	vec3(0.0, 1.0 ,0.0),
	vec3(0.0, 0.0 ,1.0)
};

varying vec4 barycentrics;
varying flat uvec4 indices;

void vertex()
{
	indices = BONE_INDICES;
	barycentrics = BONE_WEIGHTS;
}

void fragment() {
	if (int(indices.x) > 2){
		ALBEDO = vec3(barycentrics.rgb);
	}
	else{
		ALBEDO = vec3(0.0);
	}
}