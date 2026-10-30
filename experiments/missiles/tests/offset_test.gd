extends SceneTree


func _initialize() -> void:
	var scene := load("res://experiments/missiles/missile.tscn") as PackedScene
	var direct_scene := load("res://experiments/missiles/missile.tscn") as PackedScene
	var target := Node2D.new()
	var offset := scene.instantiate() as Node2D
	var direct := direct_scene.instantiate() as Node2D
	direct.offset_max_distance = 0.0
	var sides: Array[float] = []
	for seed_value in range(200):
		offset.launch(Vector2.ZERO, Vector2.DOWN, target, float(seed_value), 80.0)
		sides.append(offset._offset_factor)
		assert(absf(offset._offset_factor) <= 1.0, "Offset exceeds the configured maximum")
	assert(sides.min() < -0.5 and sides.max() > 0.5 and sides.has(0.0),
		"Aim variation does not include both sides and direct pursuit")
	assert(sides.any(func(value: float) -> bool: return absf(value) > 0.0 and absf(value) < 0.2),
		"Aim variation does not include small offsets")
	for seed_value in range(200):
		offset.launch(Vector2.ZERO, Vector2.DOWN, target, float(seed_value), 80.0)
		assert(offset._offset_factor == sides[seed_value], "Aim variation is not reproducible")
	offset.offset_direct_chance = 0.0
	for missile in [offset, direct]:
		missile.launch(Vector2.ZERO, Vector2.DOWN, target, 1.7, 80.0)
	var side: float = offset._offset_factor
	for zero_distance in [0.0, 20.0]:
		offset.offset_zero_distance = zero_distance
		for power in [0.1, 0.5, 1.0, 2.0, 4.0]:
			offset.offset_power = power
			for distance: float in [360.0, 180.0, 100.0, 90.0, 45.0, 20.0, 1.0, 0.0]:
				target.position = Vector2(distance, 0.0)
				offset.position = Vector2.ZERO
				offset._update_aim_position()
				var actual: Vector2 = offset._aim_position - target.position
				var fraction := clampf((distance - zero_distance) / (offset.offset_fade_distance - zero_distance), 0.0, 1.0)
				assert(absf(actual.length() - offset.offset_max_distance * pow(fraction, offset.offset_power) * absf(side)) < 0.001,
					"Offset does not match the configured power")
				assert(absf(actual.dot(target.position)) < 0.001, "Offset is not lateral")
				assert(offset._offset_factor == side and offset._aim_position.is_finite(), "Invalid offset state")
	for zero_distance in [180.0, 200.0]:
		offset.offset_zero_distance = zero_distance
		for distance in [zero_distance - 1.0, zero_distance, zero_distance + 1.0]:
			target.position = Vector2(distance, 0)
			offset._update_aim_position()
			var actual: Vector2 = offset._aim_position - target.position
			var expected_length: float = offset.offset_max_distance * absf(side) if distance > zero_distance else 0.0
			assert(actual.is_finite() and absf(actual.length() - expected_length) < 0.001,
				"Equal or reversed fade bounds produce an invalid offset")
	offset.offset_zero_distance = 0.0
	offset.offset_power = 2.0
	# 位置関係を回転させた場合、ワールド固定の左右ではなく狙い点も同じだけ回転する。

	for angle in [0.0, 0.7, 2.0]:
		target.position = Vector2(100, 0).rotated(angle)
		offset._update_aim_position()
		var expected := Vector2(100, -offset.offset_max_distance * pow(100.0 / 180.0, 2) * side)
		assert(offset._aim_position.distance_to(expected.rotated(angle)) < 0.001,
			"Offset uses a world-fixed direction")
	# 横ずれなしの場合、操舵誤差を含めた飛行が直接追尾と一致することを確認する。
	offset.offset_direct_chance = 100.0
	for missile in [offset, direct]:
		missile.launch(Vector2.ZERO, Vector2.DOWN, target, 1.7, 80.0)
	for missile in [offset, direct]:
		missile.start_homing(target)
		missile.desired_speed = missile.speed
	assert(offset._offset_factor == 0.0, "Direct Chance 100% still produces an offset")
	for tick in range(80):
		target.position = Vector2(sin(float(tick) * 0.03) * 20.0, -200)
		for missile in [offset, direct]:
			missile._physics_process(1.0 / 60.0)
		assert(offset.position == direct.position and offset._velocity == direct._velocity,
			"Zero offset differs from direct pursuit")
		assert(offset._instability_random.state == direct._instability_random.state, "Offset consumed steering-error RNG")
	for missile in [offset, direct]:
		missile.free()
	target.free()
	print("Offset pursuit: distance fade, relative side, shared controller and RNG verified.")
	quit()
