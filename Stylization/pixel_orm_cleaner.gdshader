shader_type spatial;
render_mode diffuse_burley, specular_toon;



#define M_PI 3.14159265359




#define cull_disabled

#define SHADOWS_DISABLED


float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

float D_GGX_anisotropic(float cos_theta_m, float alpha_x, float alpha_y, float cos_phi, float sin_phi) {
	float alpha2 = alpha_x * alpha_y;
	highp vec3 v = vec3(alpha_y * cos_phi, alpha_x * sin_phi, alpha2 * cos_theta_m);
	highp float v2 = dot(v, v);
	float w2 = alpha2 / v2;
	float D = alpha2 * w2 * w2 * (1.0 / M_PI);
	return D;
}

float V_GGX_anisotropic(float alpha_x, float alpha_y, float TdotV, float TdotL, float BdotV, float BdotL, float NdotV, float NdotL) {
	float Lambda_V = NdotL * length(vec3(alpha_x * TdotV, alpha_y * BdotV, NdotV));
	float Lambda_L = NdotV * length(vec3(alpha_x * TdotL, alpha_y * BdotL, NdotL));
	return 0.5 / (Lambda_V + Lambda_L);
}

float D_GGX(float cos_theta_m, float alpha) {
	float a = cos_theta_m * alpha;
	float k = alpha / (1.0 - cos_theta_m * cos_theta_m + a * a);
	return k * k * (1.0 / M_PI);
}

// From Earl Hammon, Jr. "PBR Diffuse Lighting for GGX+Smith Microsurfaces" https://www.gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
float V_GGX(float NdotL, float NdotV, float alpha) {
	return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
}

float SchlickFresnel(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m; // pow(m,5)
}

vec3 F0(float metallic, float specular, vec3 albedo) {
	float dielectric = 0.16 * specular * specular;
	// use albedo * metallic as colored specular reflectance at 0 angle for metallic materials;
	// see https://google.github.io/filament/Filament.md.html
	return mix(vec3(dielectric), albedo, vec3(metallic));
}

float random( vec2 p )
{
   // e^pi (Gelfond's constant)
   // 2^sqrt(2) (Gelfond–Schneider constant)
     vec2 K1 = vec2( 23.14069263277926, 2.665144142690225 );

   //return fract( cos( mod( 12345678., 256. * dot(p,K1) ) ) ); // ver1
   //return fract(cos(dot(p,K1)) * 123456.); // ver2
     return fract(cos(dot(p,K1)) * 12345.6789); // ver3
}

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float my_random( vec2 p )
{
   // e^pi (Gelfond's constant)
   // 2^sqrt(2) (Gelfond–Schneider constant)
     vec2 K1 = vec2( 23.0, 2.6 );

   //return fract( cos( mod( 12345678., 256. * dot(p,K1) ) ) ); // ver1
   //return fract(cos(dot(p,K1)) * 123456.); // ver2
     return fract(cos(dot(p,K1)) * 12345.0); // ver3
}

uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform vec3 albedo;




uniform bool on = true;
uniform float ln1 : hint_range(0.0, 1.0) = 0.0;
uniform float l0 : hint_range(0.0, 1.0) = 0.25;
uniform float l1 : hint_range(0.0, 1.0) = 0.5;
uniform float l2 : hint_range(0.0, 1.0) = 0.588;
uniform float l3 : hint_range(0.0, 1.0) = 0.675;

uniform bool iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiq = true;

uniform float r0 : hint_range(0.0, 10.0) = 0.1;
uniform float r1 : hint_range(0.0, 10.0) = 0.175;
uniform float r2 : hint_range(0.0, 10.0) = 2.174;
uniform float r3 : hint_range(0.0, 10.0) = 2.439;
uniform float r4 : hint_range(0.0, 10.0) = 10.0;

uniform bool iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiw = true;

uniform float t0 : hint_range(0.0, 2.0) = 0.1;
uniform float t1 : hint_range(0.0, 2.0) = 0.04;
uniform float t2 : hint_range(0.0, 2.0) = 1.0;
uniform float t3 : hint_range(0.0, 2.0) = 1.0;

uniform bool iiiiiiiiiiiiiiiiiiiiSPECULARiiiiiiiiiiiiiiiiiiiiiiiiig = true;

uniform float s_l0 : hint_range(0.0, 2.0) = 0.005;
uniform float s_l1 : hint_range(0.0, 2.0) = 0.098;
uniform float s_l2 : hint_range(0.0, 2.0) = 0.247;
uniform float s_l3 : hint_range(0.0, 2.0) = 0.657;

uniform bool iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiir = true;

uniform float s_r0 : hint_range(0.0, 1.0) = 0.063;
uniform float s_r1 : hint_range(0.0, 1.0) = 0.082;
uniform float s_r2 : hint_range(0.0, 1.0) = 0.312;
uniform float s_r3 : hint_range(0.0, 1.0) = 0.554;

uniform bool iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiy = true;

uniform float s_t0 : hint_range(-1.0, 1.0) = 0.0;
uniform float s_t1 : hint_range(-1.0, 1.0) = 0.0;
uniform float s_t2 : hint_range(-1.0, 1.0) = 0.0;

uniform bool iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiie = true;


uniform float mod : hint_range(0.0, 10.0) = 1.0;


uniform bool manual_occlusion = false;
uniform float occlusion_adjust : hint_range(0.0, 1.0) = 0.0;
uniform bool manual_roughness = false;
uniform float roughness_adjust : hint_range(0.0, 1.0) = 0.5;
uniform bool manual_metalness = false;
uniform float metalness_adjust : hint_range(0.0, 1.0) = 0.0;
uniform bool manual_specular = true;
uniform float specular_adjust : hint_range(0.0, 1.0) = 0.5;
uniform bool alpha_clip = false;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool manual_alpha = false;
uniform float manual_alpha_adjust : hint_range(0.0, 1.0) = 0.5;
uniform bool manual_emission = true;
uniform float emission_adjust : hint_range(0.0, 1.0) = 0.0;


uniform sampler2D albedo_map:  filter_nearest;
uniform sampler2D orm_map: filter_nearest;
uniform sampler2D normal_map : hint_normal, filter_linear;
uniform sampler2D specular_map :  filter_nearest;
uniform sampler2D emission_map:  filter_nearest;
uniform sampler2D alpha_map:  filter_nearest;
uniform sampler2D light_map_input :  filter_nearest;

uniform float max_dist = 50;
uniform float min_dist = 10;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
varying float fragmentdistance;

void fragment() {
	METALLIC = 0.0;

	vec3 orm_map_v3 = texture(orm_map, UV).rgb;

	vec3 world_camera = (INV_VIEW_MATRIX * vec4(vec3(0.0), 1.0)).xyz;
	vec4 a = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	fragmentdistance = smoothstep(min_dist, max_dist, distance(a.xyz, world_camera));

	ROUGHNESS = orm_map_v3.g;
	METALLIC = orm_map_v3.b;

	vec3 light_map = texture(light_map_input, UV*mod).rgb;

	vec3 normal_map_v3 = texture(normal_map, UV).rgb;
	normal_map_v3.xy = normal_map_v3.xy * 2.0 - 1.0;
	normal_map_v3.z = sqrt(max(0.0, 1.0 - dot(normal_map_v3.xy, normal_map_v3.xy))); //always ignore Z, as it can be RG packed, Z may be pos/neg, etc.

	NORMAL = normalize(mix(NORMAL, TANGENT * normal_map_v3.x + BINORMAL * normal_map_v3.y + NORMAL* normal_map_v3.z, NORMAL_MAP_DEPTH));

	vec3 albedo_map_v3 = texture(albedo_map, UV).rgb;
	ALBEDO = albedo_map_v3;


	vec3 emission_map_v3 = texture(emission_map, UV).rgb;

	if (manual_roughness == true) {
		ROUGHNESS = roughness_adjust * roughness_adjust;
	}

	if (manual_occlusion == true) {
		AO = occlusion_adjust;
	}

	if (manual_metalness == true) {
		METALLIC = metalness_adjust;
	}

	if (manual_specular == true) {
		SPECULAR = specular_adjust;
	}

	if (manual_emission == true) {
		// EMISSION = vec3(emission_adjust, emission_adjust, emission_adjust);
	} else {
		EMISSION = mix(emission_map_v3, albedo_map_v3, emission_map_v3.r);
	}



	if (alpha_clip == true) {
		SPECULAR = specular_adjust;
		ALPHA = texture(alpha_map, UV).a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
		if (manual_alpha == true) {
			ALPHA = manual_alpha_adjust;
		}
	}
}

void light() {
	if (on == true) {
		vec3 hsv;
		hsv = rgb2hsv(DIFFUSE_LIGHT);
		float strength = hsv.z;
		float range;
		vec2 p;
		float rnum;

		vec3 lightmap_rgb = texture(light_map_input, UV* mod * (1.0 -fragmentdistance)).rgb;

		if (strength < r0) {
			range = map(strength, r0 - t0, r0, 0.0, 1.0);
			p = vec2(lightmap_rgb.x, lightmap_rgb.y);
			rnum = random(p);
			if (rnum < range) {
				strength = l0;
			} else {
				strength = ln1;
			}
		} else if (strength < r1) {
			range = map(strength, r1 - t1, r1, 0.0, 1.0);
			p = vec2(lightmap_rgb.x, lightmap_rgb.y);
			rnum = random(p);
			if (rnum < range) {
				strength = l1;
			} else {
				strength = l0;
			}
		}  else if (strength > r1) {
			strength = l1;
		}

		DIFFUSE_LIGHT += LIGHT_COLOR * strength;

		hsv = rgb2hsv(SPECULAR_LIGHT);
		strength = hsv.z;

		if (strength > s_r0 && strength < s_r1) {
			range = map(strength, s_r0-s_t0, s_r1, 0.0, 1.0);
			p = vec2(lightmap_rgb.x, lightmap_rgb.y);
			rnum = random(p);
			if (rnum < range) {
				strength = s_l0;
			} else {
				strength = 0.0;
			}
		} else if (strength > s_r1 && strength < s_r2) {
			range = map(strength, s_r1-s_t0, s_r2, 0.0, 1.0);
			p = vec2(lightmap_rgb.x, lightmap_rgb.y);
			rnum = random(p);
			if (rnum < range) {
				strength = s_l1;
			} else {
				strength = s_l0;
			}
		} else if (strength > s_r2){
			range = map(strength, s_r2 - s_t2, s_r3, 0.0, 1.0);
			p = vec2(lightmap_rgb.x, lightmap_rgb.y);
			rnum = random(p);
			if (rnum < range) {
				strength = s_l2;
			} else {
				strength = s_l1;
			}
		} else {
			strength = 0.0;
		}

		SPECULAR_LIGHT += LIGHT_COLOR * strength;
	} else {
		DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
		//DIFFUSE_LIGHT += DIFFUSE_PASS;
		//SPECULAR_LIGHT += SPECULAR_PASS;
	}
}