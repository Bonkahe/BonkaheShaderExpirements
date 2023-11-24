shader_type spatial;
//render_mode cull_disabled;

uniform float TimeMult = 1.0;

uniform float proximity_fade_distance;
uniform float proximity_color_fade_distance;
uniform float FresnelFadePower;
uniform float FresnelFadeMult;

uniform float FlameLengthBasedScale = 10.0;
uniform float FlamePatternScale = 10.0;
uniform float FlameDirectionBias;
uniform float maxColorDistance;
uniform float EmissionPower;
uniform sampler2D ColorGradient;

uniform sampler3D NoisePattern;
uniform float NoisePower;
instance uniform vec3 OffsetDirection;
uniform float PointSharpness;
uniform float OffsetPower;
uniform float NormalPower;
uniform float InnerRadius;

uniform sampler2D depth_texture : source_color, hint_depth_texture;

varying float VertexDistance;

vec3 GetNoise(vec3 vertexPos, float time){
	float x = texture(NoisePattern, vertexPos.xyz - vec3(0.0, 1.0, 0.0) * time).r - FlameDirectionBias;
	float y = texture(NoisePattern, vertexPos.yxz - vec3(0.0, 1.0, 0.0) * time).r - FlameDirectionBias;
	float z = texture(NoisePattern, vertexPos.zyx - vec3(0.0, 1.0, 0.0) * time).r - FlameDirectionBias;
	
	return vec3(x,y,z);
}

void vertex() {
	vec3 worldPosition = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 localOffsetDirection = (inverse(MODEL_MATRIX) * vec4(OffsetDirection, 1.0)).xyz;
	vec3 noiseresult = GetNoise(worldPosition / FlamePatternScale, TIME * TimeMult) * NoisePower * (length(localOffsetDirection) * FlameLengthBasedScale);
	
	//vec3 localOffsetDirection = (MODELVIEW_MATRIX * vec4(OffsetDirection, 1.0)).xyz;
	
	
	
	
	vec3 velocity = localOffsetDirection * OffsetPower + noiseresult;
	
	float resultingDot = clamp(dot(VERTEX,localOffsetDirection), 0.0, 1.0) / PointSharpness;
	velocity *= resultingDot;
	vec3 targetposition = VERTEX + (NORMAL * NormalPower) + velocity;
	
	
	if (length(targetposition) < InnerRadius){
		VERTEX = normalize(VERTEX + (NORMAL * NormalPower) + velocity) * InnerRadius;
		VERTEX += noiseresult * (1.0 - resultingDot) * 0.01;
	}
	else{
		VERTEX = VERTEX + (NORMAL * NormalPower) + velocity;
	}
	VertexDistance = length(VERTEX);
}

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;	
	float proxcolorfade = clamp(smoothstep(0.0, proximity_color_fade_distance,linear_depth - distance(world, camera)),0.0,0.2);
	float verticalGradient = clamp((VertexDistance / maxColorDistance) + proxcolorfade, 0.0, 1.0);
	
	
	float basic_fresnel = fresnel(FresnelFadePower, NORMAL, VIEW) * FresnelFadeMult * ((VertexDistance / 1.0) + proxcolorfade);
	vec3 up_vector_viewspace = (INV_VIEW_MATRIX * vec4(0.0, -1.0, 0.0, 0.0)).xyz;
	float dot_product = dot(vec3(0.0, -1.0, 0.0), NORMAL);
	float bottomhighlight = smoothstep(0.0, 1.0, dot_product);
	bottomhighlight = clamp(min(bottomhighlight, pow(basic_fresnel, 1.0)), 0.0, verticalGradient);
	verticalGradient = verticalGradient - bottomhighlight;
	vec4 color = texture(ColorGradient, vec2(clamp(verticalGradient, 0.01, 0.99), 0.5));
	
	//ALBEDO = vec3(bottomhighlight);
	ALBEDO = color.xyz;
	EMISSION = color.xyz * EmissionPower;
	
	float depth_tex = textureLod(depth_texture,SCREEN_UV,0.0).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,depth_tex,1.0);
	world_pos.xyz/=world_pos.w;
	ALPHA*=clamp(1.0-smoothstep(world_pos.z+proximity_fade_distance,world_pos.z,VERTEX.z)  - basic_fresnel,0.0,1.0);
	
	//ALPHA = clamp(smoothstep(0.0, proximity_fade_distance,linear_depth - distance(world, camera)) - basic_fresnel,0.0,1.0);
	// Called for every pixel the material is visible on.
}

