shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, depth_prepass_alpha;

#include "WaterShaderLib.gdshaderinc"

uniform sampler2D TopColorRange : source_color;
uniform float FresnelPower = 1.0;
uniform float proximity_fade_distance;

varying vec3 Normals;

varying vec2 vertexPosA;
varying vec2 vertexPosB;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

void vertex() {
	float currentYPos = worldHeight - NODE_POSITION_WORLD.y;
	
	//vec2 model_position_frac = fract(model_position * subdiv_factor) * subdiv_size;
	vec2 model_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vertexPosA = model_vertex + (vec2(0.5, 1.0) * TIME * waveTime);
	vertexPosB = model_vertex + (vec2(-0.2, 0.5) * TIME * waveTime);
	//float currentNoise = texture(waveNoise, model_vertex / UVScale).r * waveHeight;
	vec4 generatedNormals = GenerateNormal(vertexPosA, vertexPosB);
	
	VERTEX.y = currentYPos + generatedNormals.a;
	Normals = generatedNormals.rgb;
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec3 normalMapA = texture(waveNoiseNormalMap, vertexPosA / UVScale).rgb;
	float heightMapA = texture(waveNoise, vertexPosA / UVScale).r;
	vec3 normalMapB = texture(waveNoiseNormalMap, vertexPosA / UVScale).rgb;
	float heightMapB = texture(waveNoise, vertexPosA / UVScale).r;
	
	NORMAL_MAP = HeightBasedVec3Mix(normalMapA, normalMapB, heightMapA, heightMapB, waveBlendPower, waveBlendSoftness);
	float depth_tex = textureLod(depth_texture,SCREEN_UV,0.0).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,depth_tex,1.0);
	world_pos.xyz/=world_pos.w;
	
	if (FRONT_FACING){
		ROUGHNESS = roughness;
		ALPHA =clamp(texture(TopColorRange, vec2(0.0, 0.5)).a,0.0, 1.0);
		ALPHA*=clamp(1.0-smoothstep(world_pos.z+proximity_fade_distance,world_pos.z,VERTEX.z),0.0,1.0);
		//ALPHA = clamp(ALPHA + heightMapA * 0.5, 0.0, 1.0);
	}
	else{
		ROUGHNESS = 1.0;
		//BACKLIGHT = vec3(0.1);
		ALPHA = clamp(0.5 + smoothstep(0.0, 50.0, length(VERTEX)), 0.0, 1.0 );
	}
	NORMAL = (VIEW_MATRIX * vec4(UnpackNormalMap(Normals), 0.0)).xyz;
	SPECULAR = specular;
	float basic_fresnel = clamp((fresnel(FresnelPower, NORMAL, VIEW) + 0.05), 0.0, 1.0 );
	vec3 surfaceColor = texture(TopColorRange, vec2(basic_fresnel, 0.5)).rgb;
	ALBEDO = surfaceColor;
	
	
	// Called for every pixel the material is visible on.
}

