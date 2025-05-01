#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
// layout(rgba16f, set = 0, binding = 1) uniform image2D normal_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;

// see: https://github.com/godotengine/godot-docs/issues/9591
vec4 normal_roughness_compatibility(vec4 p_normal_roughness) {
	float roughness = p_normal_roughness.w;
	if (roughness > 0.5) {
		roughness = 1.0 - roughness;
	}
	roughness /= (127.0 / 255.0);
	return vec4(normalize(p_normal_roughness.xyz * 2.0 - 1.0) * 0.5 + 0.5, roughness);
}

// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	// Read from our color buffer.
	vec4 color = imageLoad(color_image, uv);
    // vec4 normal = normal_roughness_compatibility(imageLoad(normal_image, uv));
	vec4 normal = vec4(0.0, 0.0, 0.0, 1.0);

	// Apply our changes.
	color.rgba = normal.rgba;

	// Write back to our color buffer.
	imageStore(color_image, uv, color);
}
