shader_type spatial;

#include "WaterShaderLib.gdshaderinc"

uniform sampler2D TopColorRange : source_color;
uniform vec3 AlbedoColor : source_color;
uniform vec3 DepthsColor : source_color;
uniform float LightPower;
uniform float LightStrength;
uniform float ShadowOpacity;
uniform float ShadowStrength;
uniform float fadeOffUpper = 2.0;
uniform float fadeOffBottomBeginning = 5.0;
uniform float fadeOffBottomEnd = 30.0;

//varying vec3 Normals;

//varying vec2 vertexPosA;
//varying vec2 vertexPosB;

varying vec3 fragment_worldpos;

void vertex() {
	//float currentYPos = worldHeight - NODE_POSITION_WORLD.y;
	
	//vec2 model_position_frac = fract(model_position * subdiv_factor) * subdiv_size;
	//vec2 model_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	//vertexPosA = model_vertex + (vec2(0.5, 1.0) * TIME * waveTime);
	//vertexPosB = model_vertex + (vec2(-0.2, 0.5) * TIME * waveTime);
}

void fragment() {
	// Called for every pixel the material is visible on.
	fragment_worldpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ALBEDO = AlbedoColor;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL){
		float cast_shadow = ATTENUATION;
		
		vec3 origin = fragment_worldpos;
		
		vec2 vertexPosA = origin.xz + (vec2(0.5, 1.0) * TIME * waveTime);
		vec2 vertexPosB = origin.xz + (vec2(-0.2, 0.5) * TIME * waveTime);
		
		float heightvalue = GetHeight(vertexPosA, vertexPosB) + 0.1;
		
		if (origin.y > heightvalue){
			DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * 0.5 * LIGHT_COLOR;
		}
		else{
			float angleUpward = clamp(2.0 - ((dot(LIGHT, vec3(0.0, 1.0, 0.0)) + 1.0)) * 180.0, 0.0, 180.0);
			
			//
			if (origin.y < worldHeight){
				float lengthToTravel = (worldHeight + 1.0) - origin.y / sin(90.0 - angleUpward);
				
				//origin += SunshineClouds_SunDirection * dither;
				origin += LIGHT * lengthToTravel;
			}
			else
			{
				origin += LIGHT * 1.0;
			}
			////origin.y = max(origin.y, SunshineClouds_CloudsFloor + 200.0);
			
			vertexPosA = origin.xz + (vec2(0.5, 1.0) * TIME * waveTime);
			vertexPosB = origin.xz + (vec2(-0.2, 0.5) * TIME * waveTime);
			vec4 generatedNormals = GenerateNormal(vertexPosA, vertexPosB);
			//float cloud_shadow = (1.0 - clamp(samplecloudmap(origin, TIME) * CloudDensity, 0.0, 1.0));
			float shadow = mix(ATTENUATION, smoothstep(worldHeight, worldHeight + waveHeight, generatedNormals.a), ShadowOpacity);
			//float topBlend = clamp(fragment_worldpos.y - (fragment_worldpos.y - fadeOffUpper) / heightvalue - (heightvalue - fadeOffUpper), 0.0, 1.0);
			float topBlend = smoothstep(heightvalue - fadeOffUpper, heightvalue, fragment_worldpos.y);
			float topBlendB = smoothstep(heightvalue - fadeOffUpper / 2.0, heightvalue, fragment_worldpos.y) * 0.2;
			float bottomBlend = smoothstep(heightvalue - fadeOffBottomEnd, heightvalue - fadeOffBottomBeginning, fragment_worldpos.y);
			shadow = shadow * bottomBlend;
			vec3 surfacecolor = texture(TopColorRange, vec2(0.0, 0.5)).rgb;
			vec3 shadowcolor = mix(pow(shadow, LightPower) * LightStrength * surfacecolor, mix(surfacecolor, ATTENUATION * LIGHT_COLOR, topBlendB), topBlend);
			float farBottomBlend = smoothstep(heightvalue - fadeOffBottomEnd * 2.0, heightvalue - fadeOffBottomBeginning * 2.0, fragment_worldpos.y);
			DIFFUSE_LIGHT = mix(DepthsColor, DIFFUSE_LIGHT, farBottomBlend);
			//DIFFUSE_LIGHT += dot(LIGHT, NORMAL) * LIGHT_COLOR;
			DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * shadowcolor * ATTENUATION ;
		}
	}
	else{
		DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
	}
}
