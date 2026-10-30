uniform sampler2D screen_texture : hint_screen_texture, source_color, repeat_disable, filter_linear;
#ifndef LAB_NO_STRENGTH
uniform float strength : hint_range(0.0, 1.0, 0.01) = 1.0;
#endif

vec2 lab_pixel_size() {
	return 1.0 / vec2(textureSize(screen_texture, 0));
}

float lab_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float lab_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec3 lab_sample(vec2 uv) {
	return texture(screen_texture, clamp(uv, lab_pixel_size() * 0.5, vec2(1.0) - lab_pixel_size() * 0.5)).rgb;
}

mat2 lab_rotate(float angle) {
	return mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
}

vec3 lab_blur(vec2 uv, float radius) {
	vec3 result = lab_sample(uv) * 4.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x != 0 || y != 0) {
				result += lab_sample(uv + vec2(float(x), float(y)) * radius * lab_pixel_size());
			}
		}
	}
	return result / 12.0;
}

vec2 lab_sobel(vec2 uv, float radius) {
	vec2 p = lab_pixel_size() * radius;
	float a = lab_luma(lab_sample(uv + p * vec2(-1.0, -1.0)));
	float b = lab_luma(lab_sample(uv + p * vec2(0.0, -1.0)));
	float c = lab_luma(lab_sample(uv + p * vec2(1.0, -1.0)));
	float d = lab_luma(lab_sample(uv + p * vec2(-1.0, 0.0)));
	float e = lab_luma(lab_sample(uv + p * vec2(1.0, 0.0)));
	float f = lab_luma(lab_sample(uv + p * vec2(-1.0, 1.0)));
	float g = lab_luma(lab_sample(uv + p * vec2(0.0, 1.0)));
	float h = lab_luma(lab_sample(uv + p * vec2(1.0, 1.0)));
	return vec2(c + 2.0 * e + h - a - 2.0 * d - f, f + 2.0 * g + h - a - 2.0 * b - c);
}
