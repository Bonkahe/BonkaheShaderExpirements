uniform float worldHeight = 0;
uniform sampler2D waveNoise;
uniform sampler2D waveNoiseNormalMap : hint_normal;

uniform float waveBlendSoftness = 0.1;
uniform float waveBlendPower :hint_range(0.0, 1.0) = 0.5;
uniform float waveHeight = 200;
uniform float waveTime = 100;
uniform float specular = 0.5;
uniform float roughness = 0.0;

uniform float UVScale = 10000.0;
uniform float subdiv_res = 1024;
uniform float NormalMapSampleRange = 10.0;

float GetHeight(vec2 positionA, vec2 positionB){
	return max(texture(waveNoise, positionA / UVScale).r * waveHeight * (1.0 - waveBlendPower), texture(waveNoise, positionB / UVScale).r * waveHeight * waveBlendPower);
}

vec4 GenerateNormal(vec2 positionA, vec2 positionB){
	
	vec3 center = vec3(positionA.x, 
		GetHeight(positionA, positionB), 
		positionA.y);
	
	vec3 left = vec3((positionA.x - NormalMapSampleRange), 
		GetHeight(vec2(positionA.x - NormalMapSampleRange, positionA.y), vec2(positionB.x - NormalMapSampleRange, positionB.y)),
		positionA.y);
	
	vec3 right = vec3((positionA.x + NormalMapSampleRange), 
		GetHeight(vec2(positionA.x + NormalMapSampleRange, positionA.y), vec2(positionB.x + NormalMapSampleRange, positionB.y)),
		positionA.y);
	
	vec3 up = vec3(positionA.x, 
		GetHeight(vec2(positionA.x, positionA.y - NormalMapSampleRange), vec2(positionB.x, positionB.y - NormalMapSampleRange)),
		(positionA.y - NormalMapSampleRange));
	
	vec3 down = vec3(positionA.x, 
		GetHeight(vec2(positionA.x, positionA.y + NormalMapSampleRange), vec2(positionB.x, positionB.y + NormalMapSampleRange)),
		(positionA.y + NormalMapSampleRange));
	//return normalize(vec3(2.0*(right.y-left.y), 2.0*(down.y-up.y), -4.0));
	vec3 upleft = vec3((positionA.x - NormalMapSampleRange), 
		GetHeight(vec2(positionA.x - NormalMapSampleRange, positionA.y - NormalMapSampleRange), vec2(positionB.x - NormalMapSampleRange, positionB.y - NormalMapSampleRange)),
		(positionA.y - NormalMapSampleRange));
	
	vec3 upright = vec3((positionA.x + NormalMapSampleRange), 
		GetHeight(vec2(positionA.x + NormalMapSampleRange, positionA.y - NormalMapSampleRange), vec2(positionB.x + NormalMapSampleRange, positionB.y - NormalMapSampleRange)),
		(positionA.y - NormalMapSampleRange));
	
	vec3 downleft = vec3((positionA.x - NormalMapSampleRange), 
		GetHeight(vec2(positionA.x - NormalMapSampleRange, positionA.y + NormalMapSampleRange), vec2(positionB.x - NormalMapSampleRange, positionB.y + NormalMapSampleRange)),
		(positionA.y + NormalMapSampleRange));
	
	vec3 downright = vec3((positionA.x + NormalMapSampleRange), 
		GetHeight(vec2(positionA.x + NormalMapSampleRange, positionA.y + NormalMapSampleRange), vec2(positionB.x + NormalMapSampleRange, positionB.y + NormalMapSampleRange)),
		(positionA.y + NormalMapSampleRange));
	
	
	vec3 leftVec = normalize(left - center);
	vec3 rightVec = normalize(right - center);
	vec3 upVec = normalize(up - center);
	vec3 downVec = normalize(down - center);
	vec3 upleftVec = normalize(upleft - center);
	vec3 uprightVec = normalize(upright - center);
	vec3 downleftVec = normalize(downleft - center);
	vec3 downrightVec = normalize(downright - center);
	
	
	vec3 finalVector = cross(rightVec,upVec);
	finalVector += cross(upVec, leftVec);
	finalVector += cross(leftVec, downVec);
	finalVector += cross(downVec, rightVec);
	
	finalVector += cross(uprightVec, upleftVec);
	finalVector += cross(upleftVec, downleftVec);
	finalVector += cross(downleftVec, downrightVec);
	finalVector += cross(downrightVec, uprightVec);
	
	finalVector = normalize(finalVector);
	finalVector = vec3((finalVector.x + 1.0) * 0.5, (finalVector.y + 1.0) * 0.5, (finalVector.z + 1.0) * 0.5);
	return vec4(finalVector, center.y);
}

vec3 UnpackNormalMap(vec3 rgb)
{
	vec3 n = rgb * 2.0 - 1.0;
	return n;
}

vec3 HeightBasedVec3Mix(vec3 colorA, vec3 colorB, float heightA, float heightB, float lerpvalue, float blendSoftness){
	
	heightA += 1.0 - lerpvalue;
	heightB += lerpvalue;
	
	float blendValue = max(heightA, heightB) - blendSoftness;
	
	heightA -= blendValue;
	heightB -= blendValue;
	
	heightA = max(heightA, 0.0);
	heightB = max(heightB, 0.0);
	
	colorA *= heightA;
	colorB *= heightB;
	
	return (colorA + colorB) / (heightA + heightB);
}

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}