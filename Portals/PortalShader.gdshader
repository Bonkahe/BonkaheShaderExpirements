shader_type spatial;
render_mode unshaded;

uniform sampler2D portal_viewport_texture : source_color;


void fragment() {
	ALBEDO = texture(portal_viewport_texture, SCREEN_UV).rgb;
}
