shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture
	: hint_screen_texture, source_color, repeat_disable, filter_linear;

uniform int rgb_mode : hint_enum("Fixed", "Radial") = 0;
uniform vec2 rgb_red_offset = vec2(-2.0, 0.5);
uniform vec2 rgb_blue_offset = vec2(2.0, -0.5);
uniform float rgb_red_radial : hint_range(-8.0, 8.0, 0.1) = -2.0;
uniform float rgb_blue_radial : hint_range(-8.0, 8.0, 0.1) = 2.0;
uniform float rgb_strength : hint_range(0.0, 1.0, 0.01) = 0.3;


vec3 sample_offset(vec2 screen_uv, vec2 pixel_size, vec2 offset) {
	// Positive offsets move the visible image right / down, rather than the sampling point.
	vec2 sample_uv = clamp(screen_uv - offset * pixel_size,
		pixel_size * 0.5, vec2(1.0) - pixel_size * 0.5);
	return textureLod(screen_texture, sample_uv, 0.0).rgb;
}


vec2 radial_offset(vec2 screen_uv, vec2 pixel_size, float amount) {
	// One scale in pixel space: corner displacement equals amount at every aspect ratio.
	float corner_radius = length(vec2(0.5) / pixel_size);
	float image_scale = max(0.01, 1.0 + amount / corner_radius);
	return (screen_uv - vec2(0.5)) / pixel_size * (1.0 - 1.0 / image_scale);
}


void fragment() {
	vec4 screen_color = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 weighted_color = screen_color.rgb;
	float total_weight = 1.0;

	bool chromatic_active = rgb_mode == 0
		? (rgb_red_offset != vec2(0.0) || rgb_blue_offset != vec2(0.0))
		: (rgb_red_radial != 0.0 || rgb_blue_radial != 0.0);
	if (rgb_strength > 0.0 && chromatic_active) {
		vec2 red_offset = rgb_mode == 0 ? rgb_red_offset
			: radial_offset(SCREEN_UV, SCREEN_PIXEL_SIZE, rgb_red_radial);
		vec2 blue_offset = rgb_mode == 0 ? rgb_blue_offset
			: radial_offset(SCREEN_UV, SCREEN_PIXEL_SIZE, rgb_blue_radial);
		vec3 separated_color = screen_color.rgb;
		if (red_offset != vec2(0.0)) {
			separated_color.r = sample_offset(SCREEN_UV, SCREEN_PIXEL_SIZE, red_offset).r;
		}
		if (blue_offset != vec2(0.0)) {
			separated_color.b = sample_offset(SCREEN_UV, SCREEN_PIXEL_SIZE, blue_offset).b;
		}
		weighted_color += separated_color * rgb_strength;
		total_weight += rgb_strength;
	}
	// Normalized weights preserve constant colors and HDR levels without clipping.
	COLOR = vec4(weighted_color / total_weight, screen_color.a);
}
