#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, binding = 0) uniform image2D color_image;

layout(binding = 1) uniform sampler2D depth_image;

layout(binding = 2) uniform uniformBuffer {
	mat4 view;
	mat4 proj;
} mat;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;



// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	// vec3 sphereCenter = vec3(0.0);
	// float sphereRadius = 10.0;

	

	
	vec2 depthUV = vec2(float(uv.x) / float(size.x), float(uv.y) / float(size.y));
	float depth = texture(depth_image, depthUV).r;
	vec4 view = inverse(mat.proj) * vec4(depthUV*2.0-1.0,depth,1.0);
	view.xyz /= view.w;
	float linear_depth = length(view); //used to calculate depth based on the view angle, idk just works.

	
	// Convert screen coordinates to normalized device coordinates
	vec2 clipUV = vec2(depthUV.x, depthUV.y);
	vec2 ndc = clipUV * 2.0 - 1.0;	
	// Convert NDC to view space coordinates
	vec4 clipPos = vec4(ndc, 0.0, 1.0);
	vec4 viewPos = inverse(mat.proj) * clipPos;
	viewPos.xyz /= viewPos.w;
	
	vec3 rd_world = normalize(viewPos.xyz);
	rd_world = mat3(mat.view) * rd_world;
	// Define the ray properties
	
	vec3 raydirection = normalize(rd_world);
	vec3 rayOrigin = mat.view[3].xyz; //center of camera for the ray origin, not worried about the screen width playing in, as it's for clouds.



	// Read from our color buffer.
	vec4 color = imageLoad(color_image, uv);

	float traveledDistance = 0.0;
	float density = 0.0;
	vec3 curPos = vec3(0.0);
	float posDistance = 0.0;
	
	//bool depthbreak = false;
	for (int i = 0; i < 1000; i++) {
		traveledDistance += 0.1;
		if (traveledDistance > linear_depth){
			//depthbreak = true;
			break;
		}
		curPos = rayOrigin + raydirection * traveledDistance;
		posDistance = distance(curPos, vec3(0.0));
		if (posDistance < 10.0){
			density += mix(1.0, 0.0, (posDistance / 10.0)) * 0.1;
			if (density >= 1.0){
				break;
			}
		}
	}
	density = clamp(density, 0.0, 1.0);

	// if (depthbreak){
	// 	color.rgb = vec3(1.0,0.0,0.0);
	// }
	// else{
	// 	color.rgb = vec3(linear_depth / 4000.0);
	// }
	// Apply our changes
	
	color.rgb = mix(color.rgb, vec3(1.0), density);
	//color.rgb = vec3((linear_depth / 4000.0));
	//color.rgb = vec3(dot(raydirection, normalize(vec3(0.0) - rayOrigin)));
	//color.rgb = vec3(clipPos.x, clipPos.y, 0.0);
	//color.rgb = vec3(depth.r);
	// Write back to our color buffer.
	imageStore(color_image, uv, color);
}
