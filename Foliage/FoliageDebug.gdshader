shader_type spatial;

uniform int DebugMode : hint_range(0, 5, 1) = 0;

void fragment() {
	if (DebugMode == 0){
		ALBEDO = COLOR.rgb;
	}
	else if (DebugMode == 1){
		ALBEDO = vec3(COLOR.r);
	}
	else if (DebugMode == 2){
		ALBEDO = vec3(COLOR.g);
	}
	else if (DebugMode == 3){
		ALBEDO = vec3(COLOR.b);
	}
	else if (DebugMode == 4){
		ALBEDO = vec3(COLOR.a);
	}
	else if (DebugMode == 5){
		ALBEDO = normalize(NORMAL);
	}
}
