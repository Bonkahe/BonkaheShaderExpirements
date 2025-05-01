shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;
uniform float Size : hint_range(0.0, 100.0) = 8.0;
uniform float Directions : hint_range(1.0, 32.0, 1.0) = 16.0; // BLUR DIRECTIONS (Default 16.0 - More is better but slower)
uniform float Quality : hint_range(2.0, 8.0, 2.0) = 4.0; // BLUR QUALITY (Default 4.0 - More is better but slower)


void vertex() {
  POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec4 blur(vec2 screenUV, vec2 resolution) {
	float Pi = 6.28318530718; // Pi*2

	vec2 Radius = Size/resolution.xy;
	vec4 Color = texture(screen_texture, screenUV);

	// Blur calculations
	for( float d=0.0; d<Pi; d+=Pi/Directions)
	{
		for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
		{
			Color += texture( screen_texture, screenUV+vec2(cos(d),sin(d))*Radius*i);
		}
	}
	Color /= Quality * Directions - 15.0;
	return Color;
}

void fragment() {

	vec3 color = blur(SCREEN_UV, VIEWPORT_SIZE).rgb;
	ALBEDO = color;
}