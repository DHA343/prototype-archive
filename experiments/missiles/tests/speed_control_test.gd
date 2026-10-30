extends SceneTree

const Missile = preload("res://experiments/missiles/missile.gd")
const SCENE = preload("res://experiments/missiles/missile.tscn")


func _initialize() -> void:
	var missile := SCENE.instantiate() as Missile
	missile.speed_control_turn_speed = 45.0
	missile.speed = 260.0
	missile._guidance_origin = Vector2.ZERO
	missile._steering_direction = Vector2.RIGHT
	missile._velocity = Vector2.RIGHT * 260.0
	for distance in [360.0, 180.0, 93.0, 6.0]:
		missile._guidance_target = Vector2(distance, 0)
		assert(is_equal_approx(missile._get_homing_speed(260.0), 260.0),
			"Target distance changes the speed command")
	assert(is_equal_approx(missile._get_homing_speed(50.0), 50.0),
		"External speed command is ignored")
	assert(is_zero_approx(missile._get_homing_speed(0.0)), "Stop command is ignored")

	missile._guidance_target = Vector2(360, 0)
	for angle in [0.0, 45.0, 90.0, 180.0, -90.0]:
		missile._steering_direction = Vector2.RIGHT.rotated(deg_to_rad(angle))
		var expected := 260.0 * lerpf(1.0, 0.45, minf(absf(angle) / 90.0, 1.0))
		assert(is_equal_approx(missile._get_homing_speed(260.0), expected),
			"Turn speed is not symmetric or does not saturate at the configured angle")
	missile.speed_control_turn_speed = 100.0
	assert(is_equal_approx(missile._get_homing_speed(260.0), 260.0),
		"Disabled speed control still reduces the command")
	missile.free()

	# 直進では減速せず、追尾へ切り替えた後だけ加速度制限を通して減速する。
	for rate in [30.0, 60.0, 120.0]:
		var target := Node2D.new()
		target.position = Vector2(0, 60)
		missile = SCENE.instantiate() as Missile
		missile.instability_enabled = false
		missile.offset_max_distance = 0.0
		missile.launch(Vector2.ZERO, Vector2.RIGHT, target, 1.0, missile.speed)
		missile._advance_flight(1.0 / rate)
		assert(is_equal_approx(missile.get_velocity().length(), missile.speed),
			"Speed control changes straight flight")
		missile.start_homing(target)
		var previous_velocity := missile.get_velocity()
		missile._advance_flight(1.0 / rate)
		assert(missile.get_velocity().length() < previous_velocity.length(),
			"Turn does not reduce actual speed")
		assert((missile.get_velocity() - previous_velocity).length() <= missile.acceleration_limit / rate + 0.001,
			"Speed control bypasses the acceleration limit")
		missile.free()
		target.free()
	print("Speed control: distance independence, turns, external commands and acceleration verified.")
	quit()
