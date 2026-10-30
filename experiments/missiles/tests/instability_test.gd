extends SceneTree

const Launcher = preload("res://experiments/missiles/launcher.gd")
const Missile = preload("res://experiments/missiles/missile.gd")


func _initialize() -> void:
	var reference := _instability_samples(120, 1.7)
	for rate in [30, 60]:
		var samples := _instability_samples(rate, 1.7)
		for index in range(samples.size()):
			assert(absf(samples[index] - reference[index]) < 0.000001, "Event timing depends on FPS")
	assert(_instability_samples(120, 1.7) == reference, "Seed is not reproducible")
	assert(_instability_samples(120, 3.2) != reference, "Different seeds share error events")
	var target := Node2D.new()
	target.position = Vector2(0, -300)
	var missile := Missile.new()
	missile.launch(Vector2.ZERO, Vector2.DOWN, target, 1.7, 80.0)
	missile.instability_hold_min = 0.0
	missile.instability_hold_max = 0.0
	missile.instability_rest_min = 0.0
	missile.instability_rest_max = 0.0
	missile._update_instability(1.0)
	assert(missile._instability_angle == 0.0, "Zero-length cycle is not disabled")
	missile.free()
	target.free()
	var normal := _flight(false)
	assert(_difference(normal, _flight(true, 0.0)) < 0.001, "Zero strength changes normal flight")
	var full := _flight(true, 45.0)
	assert(_difference(normal, full) > 2.0, "Instability has no visible effect")
	assert(_difference(normal, _flight(true, 22.5)) < _difference(normal, full),
		"Lower strength does not reduce deviation")
	assert(_difference(full, _flight(true, 45.0, 1.2)) < 0.05, "World axes affect error")
	print("Instability: event timing, zero cycles, seed independence, strength and rotation verified.")
	quit()


func _instability_samples(rate: int, seed_value: float) -> PackedFloat64Array:
	var target := Node2D.new()
	target.position = Vector2(0, -300)
	var missile := Missile.new()
	missile.launch(Vector2.ZERO, Vector2.DOWN, target, seed_value, 80.0)
	# 長さ0の段階と大小が逆の範囲を含め、境界処理を確認する。
	missile.instability_hold_min = 0.12
	missile.instability_hold_max = 0.02
	missile.instability_rest_min = 0.20
	missile.instability_rest_max = 0.03
	var samples := PackedFloat64Array()
	for tick in range(rate * 6):
		missile._update_instability(1.0 / rate)
		assert(missile._instability_angle == 0.0 or missile._instability_angle == missile._sampled_instability_angle,
			"Instability command still interpolates")
		assert(absf(missile._instability_angle) <= deg_to_rad(missile.instability_angle) + 0.000001,
			"Error exceeds configured angle")
		if (tick + 1) % (rate / 30) == 0:
			samples.append(missile._instability_angle)
	missile.free()
	target.free()
	return samples


func _flight(enabled: bool, strength: float = 45.0, rotation_angle: float = 0.0) -> PackedVector2Array:
	var target := Node2D.new()
	target.position = Vector2(0, -149).rotated(rotation_angle)
	var missile := Missile.new()
	missile.offset_max_distance = 0.0
	missile.instability_enabled = enabled
	missile.instability_angle = strength
	var controller := Launcher.new()
	controller.target = target
	controller._start_missile(missile, {"seed": 1.7}, Vector2.DOWN.rotated(0.35 + rotation_angle))
	var points := PackedVector2Array()
	for tick in range(96):
		controller._update_flights(1.0 / 60.0)
		missile._physics_process(1.0 / 60.0)
		points.append(missile.position.rotated(-rotation_angle))
	missile.free()
	target.free()
	controller.free()
	return points


func _difference(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var peak := 0.0
	for index in range(first.size()):
		peak = maxf(peak, first[index].distance_to(second[index]))
	return peak
