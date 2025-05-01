shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;
render_mode unshaded;

uniform float cutoffDistance = 100.0;

uniform float StepCount = 5.0;
uniform float EdgeSize = 0.5;
uniform float EdgeSensitivity = 4.0;
uniform float EdgeNormalSensitivity = 0.7;
uniform float EdgeSwapBias : hint_range(0.0, 1.0) = 0.02;
uniform float EdgeBrightnessCutoffBias : hint_range(0.0, 1.0) = 0.1;

uniform float LightSidePower;
uniform vec3 DarkTint : source_color = vec3(0.664,0.716,0.716);
//166,179,179

uniform sampler2D depth_texture : source_color, hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest_mipmap;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

//
//uniform float min_step : hint_range(0.0, 1.0, 0.01) = 0.4; // min step for the smoothstep() function
//uniform float max_step : hint_range(0.0, 1.0, 0.01) = 0.6; // max step for the smoothstep() function
//
//// x direction kernel
//const mat3 kx = mat3(
	//vec3(-1, 0, 1),
	//vec3(-2, 0, 2),
	//vec3(-1, 0, 1)
//);
//// y direction kernel
//const mat3 ky = mat3(
	//vec3(-1, -2, -1),
	//vec3(0, 0, 0),
	//vec3(1, 2, 1)
//);
varying mat4 CAMERA;

void vertex() {
	VERTEX = (PROJECTION_MATRIX * vec4(VERTEX , 1.0)).xyz;
	CAMERA = INV_VIEW_MATRIX;
}

float GetDepth(vec2 pos, mat4 projectionMatrix){
	float depth = textureLod(depth_texture, pos, 0.0).r;
	vec3 ndc = vec3(pos * 2.0 - 1.0, depth);
	vec4 view = projectionMatrix * vec4(pos*2.0-1.0,depth,1.0);
	view.xyz /= view.w;
	return length(view);
	//return depth;
}

float GetBrightness(vec3 color){
	return (color.r + color.g + color.b) / 3.0;
}

void fragment() {
	vec2 ViewportSize = VIEWPORT_SIZE;
	float centerDepth = GetDepth(SCREEN_UV, INV_PROJECTION_MATRIX);
	//float leftDepth = GetDepth(SCREEN_UV + vec2(1.0 / VIEWPORT_SIZE.x,0.0) * EdgeSize, INV_PROJECTION_MATRIX);
	//if (leftDepth < centerDepth){
		//ALBEDO = vec3(1.0);
	//}
	//else{
		//ALBEDO = vec3(0.0);
	//}
	vec2 tempUV = SCREEN_UV;
	float maxvalue = centerDepth;

	vec3 centercolor = texture(screen_texture, SCREEN_UV).rgb;
	vec3 centernormal = texture(normal_roughness_texture, SCREEN_UV).rgb * 2.0 - 1.0;

	vec3 currentColor = centercolor;
	vec3 brightestColor = centercolor;
	vec3 brightestNormal = centernormal;
	vec3 currentNormal = centernormal;
	float hardestNormal = 1.0;

	vec3 darkestColor = centercolor;
	float brightestValue = GetBrightness(centercolor);
	float darkestValue = brightestValue;
	float currentValue = brightestValue;

	vec3 mincolor = centercolor;
	float minvalue = centerDepth;

	float helfCount = floor(StepCount / 2.0);

	float tempDepth = 0.0;
	for (float x = 0.0; x < StepCount; x++){
		for (float y = 0.0; y < StepCount; y++){
			if (x == helfCount && y == helfCount){
				continue;
			}
			tempUV = SCREEN_UV + ((vec2(x - helfCount ,y - helfCount) / ViewportSize) * EdgeSize);
			tempDepth = GetDepth(tempUV, INV_PROJECTION_MATRIX);
			currentColor = texture(screen_texture, tempUV).rgb;
			currentValue = GetBrightness(currentColor);
			if (tempDepth > maxvalue){
				maxvalue = tempDepth;
			}

			if (tempDepth < minvalue){
				minvalue = tempDepth;
				mincolor = currentColor;
			}

			currentNormal = texture(normal_roughness_texture, tempUV).rgb * 2.0 - 1.0;
			hardestNormal = min(hardestNormal, dot(brightestNormal, currentNormal));

			if (currentValue > brightestValue){
				brightestValue = currentValue;
				brightestColor = currentColor;
				brightestNormal = currentNormal;
			}

			if (currentValue < darkestValue){
				darkestValue = currentValue;
				darkestColor = currentColor;
			}
		}
	}

	if (minvalue > cutoffDistance){
		discard;
	}

	float edgeWeight = ((distance(maxvalue, minvalue) / EdgeSensitivity) * -1.0) + 1.0;
	edgeWeight += hardestNormal;

	if (hardestNormal < EdgeNormalSensitivity || distance(maxvalue, minvalue) > EdgeSensitivity){
		if (length(darkestColor) > EdgeSwapBias){
			ALBEDO = darkestColor * LightSidePower;
		}
		else{
			ALBEDO = darkestColor * DarkTint;
		}
	}
	else{
		discard;
	}

	//
	//if (distance(maxvalue, minvalue) > EdgeSensitivity && distance(brightestValue, darkestValue) > EdgeBrightnessCutoffBias){
		//
		////vec3 world = (CAMERA * vec4(VERTEX, 1.0)).xyz;
		//////// Get the camera position
		////vec3 camera = (CAMERA * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		//////
		//////// Raymarching direction
		////vec3 dir = normalize(world - camera);
		////vec3 origin = world.xyz;
		////
		//
		//if (length(mincolor) > EdgeSwapBias){
			//ALBEDO = mincolor * LightSidePower;
		//}
		//else{
			//ALBEDO = mincolor * DarkTint;
		//}
	//}
	//else{
		//discard;
	//}

	//mat3 I = mat3(0);
	//for (int i = 0; i < 3; i++ ) {
		//for (int j = 0; j < 3; j++) {
			//tempUV = SCREEN_UV + (vec2(float(i-1),float(j-1)) * EdgeSize);
			//vec3 sample_around_pixel = texture(screen_texture, vec2(SCREEN_UV) + vec2(float(i-1),float(j-1))).rgb;
			//vec3 sample_grey = vec3(sample_around_pixel.r * 0.3, sample_around_pixel.g * 0.59, sample_around_pixel.b * 0.11);
			//I[i][j] = GetDepth(tempUV, INV_PROJECTION_MATRIX);
			//
		//}
	//}
	//
	//float gx = dot(kx[0], I[0]) + dot(kx[1], I[1]) + dot(kx[2], I[2]); // convolution of the image's and intensity's 'x' values
	//float gy = dot(ky[0], I[0]) + dot(ky[1], I[1]) + dot(ky[2], I[2]); // convolution of the image's and intensity's 'y' values
	//float g = sqrt(pow(gx, 2.0) + pow(gy, 2.0)); // combine x and y of the sobel and get rid of negative values
	//
	//g = smoothstep(min_step, max_step, g); // smoothstep() smooths out a value over a curve if it is within min and max steps. Otherwise, it returns 0 (if smaller than min_step) and 1 (if bigger than max_step)
	//
	//ALBEDO = vec3(g);
	////if (g < EdgeSensitivity){
		////ALBEDO = vec3(0.0);
	////}
	////else{
		////ALBEDO = vec3(1.0);
	////}
}
