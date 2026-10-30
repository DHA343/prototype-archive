shader_type particles;
render_mode disable_force, disable_velocity;

// CUSTOM: 寿命、経過時間、煙かどうか、粒のサイズ。
void start() {
	if (RESTART_CUSTOM) {
		ACTIVE = false;
	}
}

void process() {
	CUSTOM.y += DELTA;
	if (CUSTOM.y >= CUSTOM.x) {
		ACTIVE = false;
	} else {
		float drag_rate = CUSTOM.z > 0.5 ? 2.0 : 3.8;
		float gravity_y = CUSTOM.z > 0.5 ? -4.0 : 24.0;
		VELOCITY *= exp(-drag_rate * DELTA);
		VELOCITY.y += gravity_y * DELTA;
		TRANSFORM[3].xy += VELOCITY.xy * DELTA;
	}
}
