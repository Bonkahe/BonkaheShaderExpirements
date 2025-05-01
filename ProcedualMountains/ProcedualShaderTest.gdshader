shader_type spatial;

uniform sampler2D ProcedualNoiseA;
uniform sampler2D ProcedualNoiseB;
uniform sampler2D ProcedualNoiseC;
uniform sampler2D Gradient;

uniform float NoiseOffsetPower;

uniform float AngleStepDistance : hint_range(0.01, 0.1);
uniform float SlopeEffect : hint_range(0.0, 1.0);

varying float finalHeight;
varying float finalGradient;

vec3 GetGradient(vec2 uv, sampler2D heightmap){
	float heightA = texture(heightmap, uv).r;
	float heightB = texture(heightmap, vec2(uv.x, uv.y + AngleStepDistance)).r;
	float heightC = texture(heightmap, vec2(uv.x + AngleStepDistance, uv.y)).r;

	float upDerivitive = (heightB - heightA) / AngleStepDistance;
	float rightDerivitive = (heightC - heightA) / AngleStepDistance;

	return vec3(rightDerivitive, upDerivitive, heightA);
}


void vertex(){
	vec2 newUV = UV * 0.5;
	vec3 heightA = GetGradient(newUV, ProcedualNoiseA);
	vec3 heightB = GetGradient(newUV, ProcedualNoiseB);
	vec3 heightC = GetGradient(newUV, ProcedualNoiseC);

	float currentSlope = (length(vec2(heightA.xy)));
	currentSlope = texture(Gradient, vec2(currentSlope, 0.5)).r;
	float currentHeight = mix(0.0, heightA.z, currentSlope);

	//currentSlope += ((length(vec2(heightB.xy))) * SlopeEffect);
	//currentHeight += heightB.z * currentSlope;

	//VERTEX += NORMAL * currentHeight * NoiseOffsetPower;
	finalHeight = currentHeight;
	finalGradient = currentSlope;
}

void fragment() {
	ALBEDO = vec3(finalGradient);
	//ALBEDO = texture(ProcedualNoise, UV).rgb;
}
