shader_type spatial;
render_mode depth_draw_always;

#include "res://Water/WaterShaderLib.gdshaderinc"

//uniform sampler2D colorGradient : source_color, repeat_disable;
//uniform sampler2D noiseTexture : hint_roughness_r;
uniform vec3 ColorBase : source_color = vec3(1.0);
//uniform float noiseScale : hint_range(0.0, 100.0) = 1.0;
//uniform float noiseSpeed : hint_range(0.0, 5.0) = 0.1;
//uniform float noiseEffectPower : hint_range(0.0, 1.0) = 1.0;
//uniform float noiseEffectDistanceFade : hint_range(0.0, 1000.0) = 100.0;
//uniform float depthDiscardBlendRange : hint_range(0.0, 10.0) = 1.0;
////uniform float depthDiscardOverDrawPower : hint_range(0.0, 5.0) = 1.0;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;


uniform float ReflectionAngleBlend : hint_range(0.0, 1.0) = 0.5;
uniform float ReflectionBottomEdgeFade : hint_range(0.0, 0.5) = 0.157;
uniform float MaxDifferenceMultiplier = 2.0;

varying vec3 Normals;
varying vec2 vertexPosA;
varying vec2 vertexPosB;

void vertex() {
	vec2 model_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vertexPosA = model_vertex + (vec2(0.5, 1.0) * TIME * waveTime);
	vertexPosB = (model_vertex + (vec2(-0.2, 0.5) * TIME * waveTime)) * 1.2;

	vec4 generatedNormals = GenerateNormal(vertexPosA, vertexPosB);

	VERTEX.y += generatedNormals.a;
	Normals = generatedNormals.rgb;
	// Called for every vertex the material is visible on.
}

//float GetDepth(vec2 pos, mat4 projectionMatrix){
	//float depth = textureLod(depth_texture, pos, 0.0).r;
	//vec4 view = projectionMatrix * vec4(pos*2.0-1.0,depth,1.0);
	//view.xyz /= view.w;
	//return length(view);
//}

vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m)
{
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m)
{
	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
	vec4 view_position = inv_proj_m * position_ndc;
	return view_position.xyz /= view_position.w;
}

float boundaryBlend(vec2 position){
	float bottomBoundry = smoothstep(0.0, ReflectionBottomEdgeFade, 1.0 - clamp(position.y, 0.0, 1.0));
	return bottomBoundry;
}
//
//bool is_within_screen_boundaries(vec2 position) {
	//return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
//}

void fragment(){
	vec3 normalMapA = texture(waveNoiseNormalMap, vertexPosA / UVScale).rgb;
	float heightMapA = texture(waveNoise, vertexPosA / UVScale).r;
	vec3 normalMapB = texture(waveNoiseNormalMap, vertexPosA / UVScale).rgb;
	float heightMapB = texture(waveNoise, vertexPosA / UVScale).r;

	//NORMAL_MAP = HeightBasedVec3Mix(normalMapA, normalMapB, heightMapA, heightMapB, waveBlendPower, waveBlendSoftness);
	NORMAL = (VIEW_MATRIX * vec4(UnpackNormalMap(Normals), 0.0)).xyz;

	float screen_depth = texture(depth_texture, SCREEN_UV).x;
	float surface_depth = FRAGCOORD.z;

	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,screen_depth,1.0);
	world_pos.xyz/=world_pos.w;

	vec3 screen_view_position = get_view_position_from_uv(SCREEN_UV, screen_depth, INV_PROJECTION_MATRIX);
	vec3 surface_view_position = get_view_position_from_uv(SCREEN_UV, surface_depth, INV_PROJECTION_MATRIX);

	//float distanceBlend = clamp(length(surface_view_position) / MaxReflectionDistanceScale, 0.0, 1.0);
	vec3 current_position_view_space = surface_view_position;
	vec3 view_direction_view_space = VIEW * -1.0;

	vec3 baseDirection = view_direction_view_space.xyz;
	vec3 downDirection = (NORMAL.xyz * -1.0);
	float blend = clamp(pow(dot(baseDirection, downDirection) * 2.0, 0.8), 0.0, 1.0);
	ALBEDO = vec3(blend);

	vec3 reflect_vector_view_space = mix((NORMAL.xyz * -1.0), view_direction_view_space.xyz, blend);
	//vec3 reflect_vector_view_space = normalize(reflect(view_direction_view_space.xyz, NORMAL.xyz));

	vec2 current_screen_position = vec2(0.0);
	//vec3 resulting_color = SkyColor;
	float curBoundaryBlend = 0.0;
	float currentMaxTravel = 10.0;
	float lowest_depth_diff = currentMaxTravel;
	float finalTravel = 0.0;
	float ssrCurResolution = 0.1;

	vec4 clipPos = vec4((FRAGCOORD.xy / VIEWPORT_SIZE.xy) * 2.0 - 1.0, FRAGCOORD.z, 1.0);
	vec4 viewPos = INV_PROJECTION_MATRIX * clipPos;
	vec3 rd_world = normalize(viewPos.xyz / viewPos.w);
	rd_world = mat3(INV_VIEW_MATRIX) * rd_world;
	vec3 cameraLookDir = rd_world;

	vec3 depth_texture_probe_view_position = vec3(0.0);
	float depth_texture_probe_raw = 0.0;
	float depth_diff = 0.0;
	float roughnessControl = 0.0;

	vec3 resulting_color = ColorBase;

	for(float travel=0.0;  travel < currentMaxTravel; travel = travel + ssrCurResolution)
	{
		finalTravel = travel;
		current_position_view_space += reflect_vector_view_space * ssrCurResolution;
		current_screen_position = get_uv_from_view_position(current_position_view_space, PROJECTION_MATRIX);
		if (current_screen_position.y > smoothstep(0.0, 1.0, rd_world.y + 1.0)){
			current_screen_position.y = 0.0;
		}

		depth_texture_probe_raw = texture(depth_texture, current_screen_position).x;
		depth_texture_probe_view_position = get_view_position_from_uv(current_screen_position, depth_texture_probe_raw, INV_PROJECTION_MATRIX);

		depth_diff = depth_texture_probe_view_position.z - current_position_view_space.z;
		//resulting_color = texture(screen_texture, current_screen_position).rgb;

		curBoundaryBlend = boundaryBlend(current_screen_position);

		resulting_color = texture(screen_texture, current_screen_position).rgb;

		if ( depth_diff >= 0.0 && depth_diff < ssrCurResolution * MaxDifferenceMultiplier){
			break;
		}
		//resulting_color = (is_within_screen_boundaries(current_screen_position) && depth_diff >= 0.0 && depth_diff < ssr_max_diff) ? texture(screen_texture, current_screen_position.xy).rgb : vec3(-1.0);
	}

	float blendValue = min(curBoundaryBlend, smoothstep(0.5, 0.6, rd_world.y + 1.0));
	resulting_color = mix(ColorBase, resulting_color, blendValue);

	//vec3 ro_world = INV_VIEW_MATRIX[3].xyz;
	//vec4 clipPos = vec4((FRAGCOORD.xy / VIEWPORT_SIZE.xy) * 2.0 - 1.0, FRAGCOORD.z, 1.0);
	//vec4 viewPos = INV_PROJECTION_MATRIX * clipPos;
	//vec3 rd_world = normalize(viewPos.xyz / viewPos.w);
	//rd_world = mat3(INV_VIEW_MATRIX) * rd_world;
	//
	//vec3 view_dir = normalize(rd_world);


	//ALBEDO = vec3(boundaryBlend(current_screen_position));
	ALBEDO = resulting_color;
	//ALBEDO = texture(screen_texture, SCREEN_UV).rgb;
	ROUGHNESS = roughness;
	//vec3 fragWorldPos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	//vec3 camera = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	//float fragDistance = length(fragWorldPos - camera);
	//float finalnoiseEffectPower= mix(noiseEffectPower, 0.0, smoothstep(1.0, noiseEffectDistanceFade, fragDistance));
	//float noisePower = (texture(noiseTexture, fragWorldPos.xz * noiseScale + vec2(0.0, TIME * noiseSpeed)).r * finalnoiseEffectPower) - (finalnoiseEffectPower / 2.0);
	////vec2 screenUV = SCREEN_UV + vec2(noisePower, 0.0);
////
	////float depth = textureLod(depthTexture,screenUV + vec2(noisePower, 0.0) * depthDiscardOverDrawPower,0.0).r;
	////vec4 world_pos = INV_PROJECTION_MATRIX * vec4(screenUV * 2.0 - 1.0, depth, 1.0);
	////world_pos.xyz /= world_pos.w;
	//float depth = GetDepth(SCREEN_UV, INV_PROJECTION_MATRIX);
	//
	//float depthMask = smoothstep(0.0, depthDiscardBlendRange, depth - fragDistance);
	//vec2 newUV = SCREEN_UV + vec2(0.0, depthOffsetMax * depthMask) + vec2(noisePower, 0.0);;
	//depth = GetDepth(newUV, INV_PROJECTION_MATRIX);
	//depthMask = smoothstep(0.0, depthDiscardBlendRange, depth - fragDistance);
	//newUV = mix(SCREEN_UV + vec2(0.0, depthOffsetMax * depthMask), newUV, 0.5);
	//
	//depth = GetDepth(newUV, INV_PROJECTION_MATRIX);
	//
	//
	//
	////ALBEDO = vec3(smoothstep(0.0, depthDiscardBlendRange, depth - fragDistance));
	//float baseMask = smoothstep(0.0, depthDiscardBlendRange, depth - fragDistance);
	//float invMask = 1.0 - baseMask;
	//vec4 color = texture(colorGradient, vec2(invMask, 0.5));
	//vec3 screenColor = texture(screen_texture, newUV + vec2(0.0, depthOffsetMax * baseMask)).rgb;
	//ALBEDO = mix(screenColor, color.rgb, color.a);
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
