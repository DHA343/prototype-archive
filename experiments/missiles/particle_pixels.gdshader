shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;

uniform bool show_halo = true;
varying flat vec4 particle_data;
varying flat vec4 particle_tint;

void vertex() {
	particle_data = INSTANCE_CUSTOM;
	particle_tint = COLOR;
	vec2 particle_origin = round(MODEL_MATRIX[3].xy);
	if (INSTANCE_CUSTOM.z > 0.5) {
		VERTEX = particle_origin + UV * INSTANCE_CUSTOM.w;
	} else {
		VERTEX = particle_origin + UV * 3.0 - vec2(1.0);
	}
}

void fragment() {
	float fraction = clamp(1.0 - particle_data.y / particle_data.x, 0.0, 1.0);
	if (particle_data.z > 0.5) {
		vec3 smoke_color = mix(vec3(37.0, 35.0, 50.0) / 255.0,
			particle_tint.rgb * 0.3, fraction * 0.3);
		COLOR = vec4(smoke_color, min(fraction * 1.8, 0.4));
	} else {
		bool core_pixel = all(greaterThanEqual(UV, vec2(1.0 / 3.0)))
			&& all(lessThan(UV, vec2(2.0 / 3.0)));
		if (core_pixel) {
			vec3 spark_color = particle_tint.rgb * (1.0 - (1.0 - fraction) * 0.75);
			if (fraction > 0.72) {
				spark_color = mix(particle_tint.rgb, vec3(255.0, 247.0, 221.0) / 255.0,
					(fraction - 0.72) / 0.28);
			}
			COLOR = vec4(spark_color, min(1.0, fraction * 4.0));
		} else if (show_halo && fraction > 0.6) {
			COLOR = vec4(particle_tint.rgb, 0.07 * fraction);
		} else {
			COLOR = vec4(0.0);
		}
	}
}
