shader_type canvas_item;
render_mode unshaded;
#define LAB_NO_STRENGTH
#include "../_shared/common.gdshaderinc"

uniform float speed : hint_range(0.0, 4.0, 0.05) = 1.0;
uniform float frame_rate : hint_range(15.0, 60.0, 1.0) = 30.0;
uniform float signal_lines : hint_range(240.0, 576.0, 1.0) = 480.0;
uniform float luma_blur : hint_range(0.0, 4.0, 0.1) = 0.0;
// Radius retains the previous tap spacing, in output pixels.
uniform float radius : hint_range(0.0, 16.0, 0.5) = 4.0;
uniform float chroma_offset : hint_range(-16.0, 16.0, 0.1) = 0.0;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform float amount : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform int row_group_size : hint_range(1, 32, 1) = 1;
uniform float time_smoothing : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float dropout_amount : hint_range(0.0, 0.1, 0.001) = 0.0;
uniform float dropout_length : hint_range(4.0, 128.0, 1.0) = 32.0;
uniform float dropout_shift : hint_range(0.0, 64.0, 0.5) = 16.0;


vec3 to_yiq(vec3 color) {
	return vec3(dot(color, vec3(0.299, 0.587, 0.114)),
		dot(color, vec3(0.596, -0.274, -0.322)),
		dot(color, vec3(0.211, -0.523, 0.312)));
}


vec3 from_yiq(vec3 signal) {
	return vec3(signal.x + 0.956 * signal.y + 0.621 * signal.z,
		signal.x - 0.272 * signal.y - 0.647 * signal.z,
		signal.x - 1.106 * signal.y + 1.703 * signal.z);
}


vec3 filter_signal(vec2 uv, vec2 pixel_size) {
	if (luma_blur == 0.0 && chroma_offset == 0.0 && saturation == 1.0) {
		vec3 signal = to_yiq(lab_sample(uv));
		vec2 chroma = vec2(0.0);
		for (int index = -4; index <= 4; index++) {
			chroma += to_yiq(lab_sample(uv
				+ vec2(float(index) * radius * lab_pixel_size().x, 0.0))).yz;
		}
		return from_yiq(vec3(signal.x, chroma / 9.0));
	}
	vec3 base = lab_sample(uv);
	vec3 signal = to_yiq(base);
	float luminance = signal.x;
	if (luma_blur > 0.0) {
		luminance = 0.0;
		float total_weight = 0.0;
		for (int index = -2; index <= 2; index++) {
			float weight = exp(-0.5 * float(index * index));
			vec2 offset = vec2(float(index) * luma_blur * pixel_size.x, 0.0);
			luminance += to_yiq(lab_sample(uv + offset)).x * weight;
			total_weight += weight;
		}
		luminance /= total_weight;
	}

	vec2 chroma_uv = uv - vec2(chroma_offset * pixel_size.x, 0.0);
	vec2 chroma = vec2(0.0);
	// Preserve the original nine equally weighted samples and tap spacing.
	for (int index = -4; index <= 4; index++) {
		vec2 offset = vec2(float(index) * radius * pixel_size.x, 0.0);
		chroma += to_yiq(lab_sample(chroma_uv + offset)).yz;
	}
	return from_yiq(vec3(luminance, chroma / 9.0 * saturation));
}


void fragment() {
	vec4 screen_color = texture(screen_texture, SCREEN_UV);
	vec2 pixel_size = lab_pixel_size();
	float row = floor(SCREEN_UV.y / pixel_size.y);
	float row_index = floor(SCREEN_UV.y * signal_lines);
	float tape_time = TIME * speed;
	float update_time = tape_time * frame_rate;
	float frame = floor(update_time);
	float group_row = floor(row / float(row_group_size)) * float(row_group_size);
	float displacement = lab_hash(vec2(group_row, frame));
	if (time_smoothing > 0.0) {
		float next_displacement = lab_hash(vec2(group_row, frame + 1.0));
		float phase = smoothstep(0.0, 1.0, fract(update_time));
		displacement = mix(displacement,
			mix(displacement, next_displacement, phase), time_smoothing);
	}
	float jitter = (displacement - 0.5) * amount * pixel_size.x * 8.0;

	vec2 uv = SCREEN_UV;
	// Keep the original direction, output-pixel row hashing and coupled sine wave.
	uv.x += jitter + sin(row * 0.03 + tape_time) * amount * pixel_size.x * 3.0;
	// Displace short sections of the original signal instead of painting bright bars.
	if (dropout_amount > 0.0) {
		float segment_x = SCREEN_UV.x / (pixel_size.x * dropout_length);
		vec2 segment = vec2(floor(segment_x), row_index);
		float event_frame = floor(frame * 0.25);
		float dropout = step(1.0 - dropout_amount,
			lab_hash(segment + vec2(event_frame * 13.0, event_frame * 29.0)));
		float phase = fract(segment_x);
		float envelope = smoothstep(0.0, 0.15, phase) * (1.0 - smoothstep(0.85, 1.0, phase));
		float direction = lab_hash(segment + vec2(event_frame + 47.0, 91.0)) < 0.5 ? -1.0 : 1.0;
		uv.x -= dropout * envelope * direction * dropout_shift * pixel_size.x;
	}
	vec3 result = filter_signal(uv, pixel_size);
	COLOR = vec4(max(result, vec3(0.0)), screen_color.a);
}
