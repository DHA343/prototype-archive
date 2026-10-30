extends SceneTree

const TABLE: PackedScene = preload("res://experiments/pinball/table.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for fps: int in [30, 60, 120]:
		for policy: String in ["reactive", "timed"]:
			await _measure(fps, policy)
	print("Pinball layout: 6 runs of 20 seconds, %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _measure(fps: int, policy: String) -> void:
	var table := TABLE.instantiate() as Node2D
	root.add_child(table)
	table.set_physics_process(false)
	var ball: CharacterBody2D = table.get_node("Ball")
	var left: StaticBody2D = table.get_node("LeftFlipper")
	var right: StaticBody2D = table.get_node("RightFlipper")
	ball.collided.disconnect(table._on_ball_collided)
	var counts: Dictionary = {"bumper_hits": 0, "drains": 0, "outside": 0, "speed_violations": 0}
	ball.collided.connect(func(body: Node) -> void:
		if body.get_parent() == table.get_node("Bumpers"):
			counts.bumper_hits += 1)
	ball.reset.connect(func() -> void: counts.drains += 1)
	await physics_frame
	await physics_frame
	var delta := 1.0 / float(fps)
	var clearance: float = 4.0 + ball.get_radius() - 0.5
	var pulse := 0.0
	var cooldown := 0.0
	for frame in range(fps * 20):
		if policy == "timed":
			table._flippers_pressed = fmod(frame * delta + 0.08, 0.43) < 0.1
		else:
			pulse = maxf(0.0, pulse - delta)
			cooldown = maxf(0.0, cooldown - delta)
			if ball.velocity.y > 35.0 and cooldown <= 0.0:
				for flipper: StaticBody2D in [left, right]:
					var tip: Vector2 = flipper.position + Vector2.from_angle(flipper.rotation) * flipper.length
					var point := Geometry2D.get_closest_point_to_segment(
						ball.position, flipper.position, tip)
					if ball.position.distance_to(point) < 22.0:
						pulse = 0.11
						cooldown = 0.24
			table._flippers_pressed = pulse > 0.0
		table._physics_process(delta)
		if ball.position.x < 32.0 + clearance or ball.position.x > 608.0 - clearance \
				or ball.position.y < 6.5 + clearance:
			counts.outside += 1
		if ball.velocity.length() > ball.max_speed + 0.01:
			counts.speed_violations += 1
	print("%d Hz / %s: %s" % [fps, policy, counts])
	if counts.outside > 0 or counts.speed_violations > 0 or counts.bumper_hits < 2:
		_failures += 1
		push_error("Layout left the playfield, exceeded the speed limit, or missed the bumper area")
	table.free()
