shader_type spatial;

uniform sampler2D colorGradient : source_color, repeat_disable;
uniform sampler2D noiseTexture : hint_roughness_r;
uniform float depthOffsetMax : hint_range(0.0, 0.5) = 0.1;
uniform float noiseScale : hint_range(0.0, 100.0) = 1.0;
uniform float noiseSpeed : hint_range(0.0, 5.0) = 0.1;
uniform float noiseEffectPower : hint_range(0.0, 1.0) = 1.0;
uniform float noiseEffectDistanceFade : hint_range(0.0, 1000.0) = 100.0;
uniform float depthDiscardBlendRange : hint_range(0.0, 10.0) = 1.0;
//uniform float depthDiscardOverDrawPower : hint_range(0.0, 5.0) = 1.0;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;

void vertex() {
	// Called for every vertex the material is visible on.
}

float GetDepth(vec2 pos, mat4 projectionMatrix){
	float depth = textureLod(depth_texture, pos, 0.0).r;
	vec4 view = projectionMatrix * vec4(pos*2.0-1.0,depth,1.0);
	view.xyz /= view.w;
	return length(view);
	//return depth;
}

void fragment() {
	vec3 fragWorldPos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float fragDistance = length(fragWorldPos - camera);
	float finalnoiseEffectPower= mix(noiseEffectPower, 0.0, smoothstep(1.0, noiseEffectDistanceFade, fragDistance));
	float noisePower = (texture(noiseTexture, fragWorldPos.xz * noiseScale + vec2(0.0, TIME * noiseSpeed)).r * finalnoiseEffectPower) - (finalnoiseEffectPower / 2.0);
	//vec2 screenUV = SCREEN_UV + vec2(noisePower, 0.0);
//
	//float depth = textureLod(depthTexture,screenUV + vec2(noisePower, 0.0) * depthDiscardOverDrawPower,0.0).r;
	//vec4 world_pos = INV_PROJECTION_MATRIX * vec4(screenUV * 2.0 - 1.0, depth, 1.0);
	//world_pos.xyz /= world_pos.w;
	float depth = GetDepth(SCREEN_UV, INV_PROJECTION_MATRIX);
	
	float depthMask = smoothstep(0.0, depthDiscardBlendRange, depth - fragDistance);
	vec2 newUV = SCREEN_UV + vec2(0.0, depthOffsetMax * depthMask) + vec2(noisePower, 0.0);;
	depth = GetDepth(newUV, INV_PROJECTION_MATRIX);
	depthMask = smoothstep(0.0, depthDiscardBlendRange, depth - fragDistance);
	newUV = mix(SCREEN_UV + vec2(0.0, depthOffsetMax * depthMask), newUV, 0.5);
	
	depth = GetDepth(newUV, INV_PROJECTION_MATRIX);
	
	
	
	//ALBEDO = vec3(smoothstep(0.0, depthDiscardBlendRange, depth - fragDistance));
	float baseMask = smoothstep(0.0, depthDiscardBlendRange, depth - fragDistance);
	float invMask = 1.0 - baseMask;
	vec4 color = texture(colorGradient, vec2(invMask, 0.5));
	vec3 screenColor = texture(screen_texture, newUV + vec2(0.0, depthOffsetMax * baseMask)).rgb;
	ALBEDO = mix(screenColor, color.rgb, color.a);
	//ALBEDO = vec3(mask);
	//ALPHA = color.a;
	
	//float mask = 1.0;
	//if (VERTEX.z - world_pos.z < 0.0){
		//mask = 0.0;
	//}

	//mask = min(mask, smoothstep(0.0, 0.01, screenUV.x));
	//mask = min(mask, smoothstep(1.0, 0.99, screenUV.x));
	//if (world_pos.z > VERTEX.z){
		//mask = 0.0;
		////screenUV = SCREEN_UV + vec2(noisePower * -1.0, 0.0);
	//}

	//ALBEDO = vec3(mask);
	//ALBEDO = texture(screenTexture, SCREEN_UV).rgb;
	//ALBEDO = texture(screenTexture, screenUV).rgb;
	//ALBEDO = texture(screenTexture, mix(SCREEN_UV, screenUV, mask)).rgb;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
