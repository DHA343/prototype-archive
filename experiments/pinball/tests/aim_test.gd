extends SceneTree

const TABLE: PackedScene = preload("res://experiments/pinball/table.tscn")
const Aim = preload("res://experiments/pinball/aim.gd")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var table := TABLE.instantiate() as Node2D
	root.add_child(table)
	table.set_physics_process(false)
	table.show_shot_guide = false
	var ball: CharacterBody2D = table.get_node("Ball")
	var left: StaticBody2D = table.get_node("LeftFlipper")
	var right: StaticBody2D = table.get_node("RightFlipper")
	await physics_frame
	await physics_frame
	ball.step(1.0 / 240.0)
	for paddle: StaticBody2D in [left, right]:
		for fraction: float in [0.2, 0.5, 0.9]:
			for horizontal: float in [-140.0, 0.0, 140.0]:
				for flipper: StaticBody2D in [left, right]:
					flipper.pressed = false
					flipper.step(0.2)
				var direction := Vector2.from_angle(paddle.rotation)
				var normal := direction.orthogonal()
				if normal.y > 0.0:
					normal = -normal
				ball.position = paddle.position + direction * float(paddle.length) * fraction + normal * 26.0
				ball.velocity = Vector2(horizontal, 300)
				var original_position := ball.position
				var original_velocity := ball.velocity
				var original_angle := paddle.rotation
				var prediction := Aim.predict(ball, [left, right])
				_check(ball.position == original_position and ball.velocity == original_velocity
					and is_equal_approx(paddle.rotation, original_angle), "Prediction changed live physics")
				_check(not prediction.is_empty(), "Missing reachable flipper prediction")
				if prediction.is_empty():
					continue
				var points: PackedVector2Array = prediction.points
				_check(points.size() == 2 and points[0].is_equal_approx(ball.global_position),
					"Guide must be a straight line starting at the current ball center")
				var guide := points[-1] - points[0]
				var predicted_velocity: Vector2 = prediction.velocity
				_check(absf(guide.angle_to(predicted_velocity)) < 0.0001,
					"Guide must show the initial strike direction without gravity curvature")
				var shot: Array[Vector2] = []
				var callback := func(body: Node) -> void:
					if body == paddle and shot.is_empty():
						shot.append(ball.velocity)
				ball.collided.connect(callback)
				table._flippers_pressed = true
				for index in range(24):
					table._physics_process(1.0 / 240.0)
					if not shot.is_empty():
						break
				ball.collided.disconnect(callback)
				_check(not shot.is_empty(), "Predicted strike did not occur")
				if not shot.is_empty():
					var expected: Vector2 = prediction.velocity
					_check(absf(expected.angle_to(shot[0])) < deg_to_rad(2.0), "Guide disagrees with strike direction")
					_check(absf(shot[0].length() - ball.strike_speed) < 0.1, "Strike speed is inconsistent")
	# 静止したフリッパー上を実際に滑らせ、線が外向きから中央向きへ変わることを確かめる。
	for paddle: StaticBody2D in [left, right]:
		for flipper: StaticBody2D in [left, right]:
			flipper.pressed = false
			flipper.step(0.2)
		table._flippers_pressed = false
		var tangent := Vector2.from_angle(paddle.rotation)
		var normal := tangent.orthogonal()
		if normal.y > 0.0:
			normal = -normal
		ball.position = paddle.position + tangent * float(paddle.length) * 0.1 + normal * 13.0
		ball.velocity = tangent * 60.0
		var angles: Array[float] = []
		var ordered := true
		for index in range(180):
			table._physics_process(1.0 / 240.0)
			var offset := (ball.global_position - paddle.global_position).rotated(-paddle.rotation)
			if offset.x > paddle.length * 0.85:
				break
			var prediction := Aim.predict(ball, [left, right])
			if prediction.is_empty():
				continue
			var velocity: Vector2 = prediction.velocity
			var inward := -1.0 if paddle.right_side else 1.0
			var angle := rad_to_deg(atan2(velocity.x * inward, -velocity.y))
			if not angles.is_empty() and angle < angles[-1] - 0.5:
				ordered = false
			angles.append(angle)
		_check(angles.size() > 20, "Guide must remain available while sliding")
		if not angles.is_empty():
			_check(angles[0] < -3.0, "Outer root must aim outward")
			_check(angles[-1] > 25.0, "Inner tip must aim toward the center")
			_check(ordered, "Sliding inward must turn the guide continuously toward the center")
			print("Slide right=%s: %.1f to %.1f degrees / %d predictions"
				% [paddle.right_side, angles[0], angles[-1], angles.size()])
	ball.position = Vector2(320, 120)
	ball.velocity = Vector2.DOWN * 300.0
	_check(Aim.predict(ball, [left, right]).is_empty(), "Guide must stay hidden in the upper field")
	ball.position = Vector2(260, 280)
	ball.velocity = Vector2.UP * 300.0
	_check(Aim.predict(ball, [left, right]).is_empty(), "Guide must stay hidden while rising")
	for flipper: StaticBody2D in [left, right]:
		flipper.pressed = true
		flipper.step(0.2)
	ball.position = Vector2(260, 280)
	ball.velocity = Vector2.DOWN * 300.0
	_check(Aim.predict(ball, [left, right]).is_empty(), "Holding must not promise a fresh strike")
	for flipper: StaticBody2D in [left, right]:
		flipper.pressed = false
		flipper.step(0.2)
	ball.position = Vector2(260, 240)
	ball.velocity = Vector2.DOWN * 100.0
	_check(Aim.predict(ball, [left, right]).is_empty(), "Guide must respect the strike window")
	table.free()
	print("Pinball aim: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
