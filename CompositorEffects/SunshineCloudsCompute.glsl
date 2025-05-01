#[compute]
#version 450
#define PI 3.141592

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, binding = 0) uniform image2D color_image;

layout(binding = 1) uniform sampler2D depth_image;

layout(binding = 2) uniform sampler3D large_noise;
layout(binding = 3) uniform sampler3D noise_medium;
layout(binding = 4) uniform sampler3D noise_small;
layout(binding = 5) uniform sampler2D heightmask;

layout(binding = 6) uniform uniformBuffer {
	mat4 view;
	mat4 proj;

	vec3 directionalLightDir;
	float cloud_sharpness;

	vec4 directionalLightColor;

	vec4 ambientLightColor;
	vec4 ambientGroundLightColor;
	vec4 distanceFogColor;
	
	float small_noise_scale;
	float min_step_distance;
	float max_step_distance;
	float step_density_bias;

	float cloud_floor;
	float cloud_ceiling;
	float max_step_count;
	float max_lighting_step_count;

	vec3 largenoiseposition;
	float cloud_lighting_sharpness;

	vec3 mediumnoiseposition;
	float lighting_step_distance;

	vec3 smallnoiseposition;
	float atmospheric_density;
} genericData;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float large_noise_scale;
	float medium_noise_scale;

	float time;
	float cloud_coverage;
	float cloud_density;
	float small_noise_strength;

	float cloud_lighting_power;
} params;



const mat4 bayer_matrix = mat4(
    vec4(00.0 / 16.0, 12.0 / 16.0, 03.0 / 16.0, 15.0 / 16.0),
    vec4(08.0 / 16.0, 04.0 / 16.0, 11.0 / 16.0, 07.0 / 16.0),
    vec4(02.0 / 16.0, 14.0 / 16.0, 01.0 / 16.0, 13.0 / 16.0),
    vec4(10.0 / 16.0, 06.0 / 16.0, 09.0 / 16.0, 05.0 / 16.0));

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float get_dither_value(vec2 pixel) {
    int x = int(pixel.x - 4.0 * floor(pixel.x / 4.0));
    int y = int(pixel.y - 4.0 * floor(pixel.y / 4.0));
    return bayer_matrix[x][y];
}

float remap(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

float sampleScene(vec3 largeNoisePos, vec3 mediumNoisePos, vec3 smallNoisePos, vec3 worldPosition, float cloudceiling, float cloudfloor, float largenoisescale, float mediumnoisescale, float smallnoisescale, float coverage, float smallscalePower){
	float clampedWorldHeight = remap(worldPosition.y, cloudfloor, cloudceiling, 0.0, 1.0);
	vec2 gradientSample = texture(heightmask, vec2(clampedWorldHeight, 0.5)).rg;
	float gradientResult = gradientSample.r;

	//float baseShapes = texture(noise_medium, worldPosition / mediumnoisescale).r;
	float coverageInverted = coverage;
	float shape = texture(noise_medium, (worldPosition - mediumNoisePos) / mediumnoisescale).r * gradientResult;
	float largeShape = smoothstep(coverageInverted - 0.1, coverageInverted, texture(large_noise, (worldPosition - largeNoisePos) / largenoisescale).r);
	//float shape = smoothstep(coverageInverted - 0.1, coverageInverted, texture(large_noise, worldPosition / largenoisescale).r) * gradientResult;

	shape = clamp(remap(shape, largeShape, 1.0, 0.0, 1.0), 0.0, 1.0);
	shape = clamp(remap(shape, mix(0.0, texture(noise_small, (worldPosition - smallNoisePos) / smallnoisescale).r * gradientSample.g, smallscalePower), 1.0, 0.0, 1.0), 0.0, 1.0);

	return shape * gradientResult; //* mix(1.0, texture(noise_small, worldPosition / smallnoisescale).r, smallscalePower) * gradientResult;
}

float sampleLighting(int stepCount, vec3 worldPosition, vec3 largeNoisePos, vec3 mediumNoisePos, vec3 smallNoisePos, vec3 sunDirection, float stepDistance,  float cloudceiling, float cloudfloor, float largenoisescale, float mediumnoisescale, float smallnoisescale, float coverage, float smallscalePower){
	
	
	float density = 0.0;
	float stepCountFloat = float(stepCount);
	float eachShortStep = stepDistance / stepCountFloat;
	float eachLongStep = eachShortStep * 4.0;
	float traveledDistance = eachShortStep;

	float thisDensity = 0.0;
	vec3 curPos = worldPosition;
	for (int i = 0; i < stepCount; i++) {
		
		curPos = worldPosition + sunDirection * traveledDistance;

		if (clamp(curPos.y, cloudfloor, cloudceiling) == curPos.y){
			thisDensity = sampleScene(largeNoisePos, mediumNoisePos, smallNoisePos,curPos, cloudceiling, cloudfloor, largenoisescale, mediumnoisescale, smallnoisescale, coverage, smallscalePower) / stepCountFloat;
			
			traveledDistance += mix(eachShortStep, eachLongStep, clamp(thisDensity / 0.1, 0.0, 1.0));

			density += thisDensity;
		}
		else{
			break;
		}
	}
	return density;
}

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
	vec4 view = inverse(genericData.proj) * vec4(depthUV*2.0-1.0,depth,1.0);
	view.xyz /= view.w;
	float linear_depth = length(view); //used to calculate depth based on the view angle, idk just works.

	
	// Convert screen coordinates to normalized device coordinates
	vec2 clipUV = vec2(depthUV.x, depthUV.y);
	vec2 ndc = clipUV * 2.0 - 1.0;	
	// Convert NDC to view space coordinates
	vec4 clipPos = vec4(ndc, 0.0, 1.0);
	vec4 viewPos = inverse(genericData.proj) * clipPos;
	viewPos.xyz /= viewPos.w;
	
	vec3 rd_world = normalize(viewPos.xyz);
	rd_world = mat3(genericData.view) * rd_world;
	// Define the ray properties
	
	vec3 raydirection = normalize(rd_world);
	vec3 rayOrigin = genericData.view[3].xyz; //center of camera for the ray origin, not worried about the screen width playing in, as it's for clouds.

	// Read from our color buffer.
	vec4 color = imageLoad(color_image, uv);

	float traveledDistance = 0.0;
	float density = 0.0;
	float thisStepLightingWeight = 0.0;
	float lightingWeight = 0.0;
	int lightingSamples = 0;
	float newdensity = 0.0;
	vec3 curPos = vec3(0.0);
	vec3 curLargeNoiseUV = vec3(0.0);

	vec3 largeNoisePos = genericData.largenoiseposition;
	vec3 mediumNoisePos = genericData.mediumnoiseposition;
	vec3 smallNoisePos = genericData.smallnoiseposition;

	float largenoiseScale = params.large_noise_scale;
	float mediumnoiseScale = params.medium_noise_scale;
	float smallnoiseScale = genericData.small_noise_scale;

	float minstep = genericData.min_step_distance;
	float maxstep = genericData.max_step_distance;
	float stepbias = genericData.step_density_bias;
	float densityMultiplier = params.cloud_density;
	float sharpness = genericData.cloud_sharpness;
	float lightingSharpness = genericData.cloud_lighting_sharpness;
	float lightingdensityMultiplier = params.cloud_lighting_power;
	float smallNoiseMultiplier = params.small_noise_strength;
	float coverage = params.cloud_coverage;

	float cloudfloor = genericData.cloud_floor;
	float cloudceiling = genericData.cloud_ceiling;

	vec3 sundir = normalize(genericData.directionalLightDir);
	vec2 ditherUV = uv.xy;
	ditherUV.x += params.time * 8.23124;
	ditherUV.y += params.time * 4.31589;

	traveledDistance = get_dither_value(ditherUV) * maxstep;


	int stepCount = int(genericData.max_step_count);
	int lightingStepCount = int(genericData.max_lighting_step_count);
	//float lightingStepDistance = (cloudceiling - cloudfloor) / genericData.max_lighting_step_count;
	//bool depthbreak = false;
	float ambient = 0.0;
	float maxTheoreticalStep = float(stepCount) * maxstep;
	float ceilingSample = 0.0;
	float halfcloudThickness = (cloudceiling - cloudfloor) * 0.5;
	float halfCeiling = cloudceiling - halfcloudThickness;

	float lightingStepDistance = genericData.lighting_step_distance;
	float newStep = 0.0;
	//atmospherics
	vec3 lasttotalRlh = vec3(0,0,0);
    vec3 lasttotalMie = vec3(0,0,0);
	vec3 totalRlh = vec3(0,0,0);
    vec3 totalMie = vec3(0,0,0);
	float iOdRlh = 0.0;
    float iOdMie = 0.0;

	float atmosphericDensity = genericData.atmospheric_density;
	const float atmosphericHeight = 40000.0;
	const vec3 RayleighScatteringCoef = vec3(5.5e-6, 13.0e-6, 22.4e-6);
	const float Rayleighscaleheight = 8e3;
	const float MieScatteringCoef = 21e-6;
	const float Miescaleheight = 1.2e3;
	const float MieprefferedDirection = 0.758;

	// Calculate the Rayleigh and Mie phases.
    float mu = dot(raydirection, sundir);
    float mumu = mu * mu;
    float gg = MieprefferedDirection * MieprefferedDirection;
    float pRlh = 3.0 / (16.0 * PI) * (1.0 + mumu);
    float pMie = 3.0 / (8.0 * PI) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * MieprefferedDirection, 1.5) * (2.0 + gg));

	
	for (int i = 0; i < stepCount; i++) {
		
		if (traveledDistance > linear_depth){
			
			float distanceTraveledLastStep = mix(minstep, maxstep, clamp(newdensity / stepbias, 0.0, 1.0));
			float lastStepDistance = traveledDistance - distanceTraveledLastStep;
			float lerp = clamp((linear_depth - lastStepDistance) / distanceTraveledLastStep, 0.0, 1.0);
			density = mix(density - newdensity, density, lerp); //Lerps between the max density, and the minimum density, based on the amount of remaining distance. 
			
			//totalRlh = mix(lasttotalRlh, totalRlh, lerp);
			//totalMie = mix(lasttotalMie, totalMie, lerp);
			traveledDistance = linear_depth;
			break;
		}

		curPos = rayOrigin + raydirection * traveledDistance;

		ceilingSample = halfCeiling + (1.0 - texture(large_noise, (curPos - largeNoisePos) / largenoiseScale).r) * halfcloudThickness;
		if (clamp(curPos.y, cloudfloor, ceilingSample) == curPos.y){
			

			newdensity = pow(sampleScene(largeNoisePos, mediumNoisePos, smallNoisePos, curPos, ceilingSample, cloudfloor, largenoiseScale, mediumnoiseScale, smallnoiseScale, coverage, smallNoiseMultiplier) * densityMultiplier, sharpness);
			if (newdensity > 0.0){
				lightingSamples += 1;
				thisStepLightingWeight = pow(sampleLighting(lightingStepCount,curPos, largeNoisePos, mediumNoisePos, smallNoisePos, sundir, lightingStepDistance, ceilingSample, cloudfloor, largenoiseScale, mediumnoiseScale, smallnoiseScale, coverage, smallNoiseMultiplier) * densityMultiplier * lightingdensityMultiplier, lightingSharpness);
				lightingWeight += thisStepLightingWeight;
				ambient += sampleScene(largeNoisePos, mediumNoisePos, smallNoisePos, curPos + vec3(0.0, 1.0, 0.0) * minstep, ceilingSample, cloudfloor, largenoiseScale, mediumnoiseScale, smallnoiseScale, coverage, smallNoiseMultiplier) * densityMultiplier * lightingdensityMultiplier;
			}
			else{
				thisStepLightingWeight = 0.0;
			}
			
			newStep = mix(mix(maxstep, minstep, clamp(newdensity / stepbias, 0.0, 1.0)), maxstep,  traveledDistance / maxTheoreticalStep);

			density += newdensity;
			if (density >= 1.0){
				i = stepCount;
			}
		}
		else{
			// if (curPos.y > cloudceiling && raydirection.y > 0.0){
			// 	traveledDistance = maxTheoreticalStep;
			// 	break;
			// }
			newStep = maxstep;
		}

		traveledDistance += newStep;
		
		float iHeight = curPos.y / atmosphericHeight;
		float odStepRlh = exp(-iHeight / Rayleighscaleheight) * newStep;
		float odStepMie = exp(-iHeight / Miescaleheight) * newStep;
		iOdRlh += odStepRlh;
		iOdMie += odStepMie;
		
		vec3 attn = exp(-(MieScatteringCoef * (iOdMie + Miescaleheight) + RayleighScatteringCoef * (iOdRlh + Rayleighscaleheight))) * (1.0 - thisStepLightingWeight) * atmosphericDensity * (1.0 - clamp(iHeight, 0.0, 1.0));
		
		lasttotalRlh = totalRlh;
		lasttotalMie = totalMie;
		totalRlh += odStepRlh * attn;
		totalMie += odStepMie * attn;
	}
	//22.0 = sun intensity
	

	ambient = clamp(ambient / float(lightingSamples), 0.0, 1.0);
	lightingWeight = clamp(lightingWeight / float(lightingSamples), 0.0, 1.0);
	vec4 sunlightColor = genericData.directionalLightColor;
	vec3 resultingCloudColor = sunlightColor.rgb * sunlightColor.a;
	vec3 ambientLight = genericData.ambientLightColor.rgb;
	vec3 ambientColor = mix(ambientLight, genericData.ambientGroundLightColor.rgb, ambient);
	resultingCloudColor = mix(resultingCloudColor, ambientColor, lightingWeight);
	
	pRlh *= (1.0 - lightingWeight);
	pMie *= (1.0 - lightingWeight);

	float AtmosphericsDistancePower = length(vec3(RayleighScatteringCoef * totalRlh + MieScatteringCoef * totalMie));
	//vec3 atmospherecolor = genericData.distanceFogColor.rgb;
	vec3 atmospherics = 22.0 * (ambientLight * RayleighScatteringCoef * totalRlh + pMie * MieScatteringCoef * sunlightColor.rgb * sunlightColor.a * totalMie);
	
	
	// atmospherics = mix(distanceColor, atmospherics, clamp(length(atmospherics), 0.0, 1.0));

	density = clamp(density, 0.0, 1.0);
	color.rgb = mix(color.rgb, resultingCloudColor, density);
	color.rgb = mix(color.rgb, atmospherics, clamp(AtmosphericsDistancePower, 0.0, 1.0));

	//color.rgb = mix(color.rgb, atmospherics.rgb, clamp(atmospherics.a, 0.0, 1.0));
	//color.rgb = vec3((linear_depth / 4000.0));
	//color.rgb = vec3(dot(raydirection, normalize(vec3(0.0) - rayOrigin)));
	//color.rgb = vec3(clipPos.x, clipPos.y, 0.0);
	//color.rgb = vec3(depth.r);
	// Write back to our color buffer.
	imageStore(color_image, uv, color);
}
