extends SceneTree
## 移動処理のみのCPU計測。描画・粒子・生成・ノード更新の配信は含めない。

const Missile = preload("res://experiments/missiles/missile.gd")
const SCENE = preload("res://experiments/missiles/missile.tscn")
const LABELS: Array[String] = ["direct_instant", "direct_acceleration", "current"]
const STEPS: int = 100
const TRIALS: int = 9


func _initialize() -> void:
	var target := Node2D.new()
	var template := SCENE.instantiate() as Missile
	print("CPU benchmark: Godot ", Engine.get_version_info().string)
	for count: int in [100, 1000]:
		var groups: Array[Array] = []
		var samples: Array[Array] = []
		for mode in range(LABELS.size()):
			var missiles: Array[Missile] = []
			samples.append([])
			for index in range(count):
				var missile: Missile
				if mode == 0:
					missile = InstantPursuit.new()
				elif mode == 1:
					missile = AcceleratedPursuit.new()
				else:
					missile = SCENE.instantiate() as Missile
				missile.speed = template.speed
				missile.hit_radius = template.hit_radius
				missile.acceleration_limit = template.acceleration_limit
				missile.acceleration_response_time = template.acceleration_response_time
				missile.lifetime = 100.0
				missile.launch(Vector2.ZERO, Vector2.RIGHT, target, float(index) + 0.25, 80.0)
				missile.start_homing(target)
				missile.desired_speed = missile.speed
				missiles.append(missile)
			groups.append(missiles)
		# キャッシュを暖め、計測順を交代して順序による偏りを抑える。
		for group in groups:
			_measure(group, target)
		for trial in range(TRIALS):
			for offset in range(groups.size()):
				var mode := (trial + offset) % groups.size()
				samples[mode].append(_measure(groups[mode], target))
		for mode in range(groups.size()):
			samples[mode].sort()
			print(JSON.stringify({
				"mode": LABELS[mode], "count": count, "trials": TRIALS,
				"median_ms_per_tick": samples[mode][TRIALS / 2],
				"min_ms_per_tick": samples[mode].front(),
				"max_ms_per_tick": samples[mode].back(),
			}))
			for missile: Missile in groups[mode]:
				assert(not missile.is_queued_for_deletion(), "Benchmark missile ended early")
				assert(missile.position.is_finite(), "Invalid benchmark position")
				missile.free()
	template.free()
	target.free()
	quit()


func _measure(missiles: Array, target: Node2D) -> float:
	var elapsed: int = 0
	for step in range(STEPS):
		target.position = Vector2(340.0 + 300.0 * sin(float(step) * 0.13), 20.0 + 20.0 * sin(float(step) * 0.2))
		# 距離と速度条件を揃え、状態の再設定は計測時間へ含めない。
		for index in range(missiles.size()):
			var missile: Missile = missiles[index]
			missile.position = Vector2(float(index % 20), float(index % 13))
			missile._velocity = Vector2(80.0, -160.0).rotated(float(index % 9) * 0.3)
			missile._age = 2.0
		var started := Time.get_ticks_usec()
		for missile: Missile in missiles:
			missile._physics_process(1.0 / 60.0)
		elapsed += Time.get_ticks_usec() - started
	return float(elapsed) / (1000.0 * STEPS)


class InstantPursuit extends Missile:
	func _advance_flight(delta: float) -> void:
		_velocity = (_get_target_position() - position).normalized() * clampf(desired_speed, 0.0, speed)
		position += _velocity * delta


class AcceleratedPursuit extends Missile:
	func _advance_flight(delta: float) -> void:
		_steering_direction = (_get_target_position() - position).normalized()
		_move_with_acceleration(delta, clampf(desired_speed, 0.0, speed))

