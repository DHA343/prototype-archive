extends Node
## 実行中の盤面へ同じ操作を送り、配置調整の前後を比較する。

var result: Dictionary = {}
var running: bool = false


func run(table: Node2D, duration: float, policy: String) -> Dictionary:
	running = true
	var ball: CharacterBody2D = table.get_node("Ball")
	var left: StaticBody2D = table.get_node("LeftFlipper")
	var right: StaticBody2D = table.get_node("RightFlipper")
	ball.reset_ball()
	await table.get_tree().physics_frame
	await table.get_tree().physics_frame
	var counts: Dictionary = {"bumper_hits": 0, "flipper_hits": 0, "drains": 0}
	var bumpers: Dictionary = {}
	var collision_callback := func(body: Node) -> void:
		if body.get_parent() == table.get_node("Bumpers"):
			counts.bumper_hits += 1
			bumpers[body.name] = int(bumpers.get(body.name, 0)) + 1
		elif body == left or body == right:
			counts.flipper_hits += 1
	var reset_callback := func() -> void: counts.drains += 1
	ball.collided.connect(collision_callback)
	ball.reset.connect(reset_callback)
	var elapsed := 0.0
	var pulse := 0.0
	var cooldown := 0.0
	var top := ball.position.y
	var speed := 0.0
	var stalled := 0.0
	while elapsed < duration:
		var delta := table.get_physics_process_delta_time()
		if policy == "timed":
			table._flippers_pressed = fmod(elapsed + 0.08, 0.43) < 0.1
		else:
			pulse = maxf(0.0, pulse - delta)
			cooldown = maxf(0.0, cooldown - delta)
			if ball.velocity.y > 35.0 and cooldown <= 0.0:
				for flipper: StaticBody2D in [left, right]:
					var tip: Vector2 = flipper.position + Vector2.from_angle(flipper.rotation) * flipper.length
					var closest := Geometry2D.get_closest_point_to_segment(
						ball.position, flipper.position, tip)
					if ball.position.distance_to(closest) < 22.0:
						pulse = 0.11
						cooldown = 0.24
			table._flippers_pressed = pulse > 0.0
		await table.get_tree().physics_frame
		elapsed += delta
		top = minf(top, ball.position.y)
		speed = maxf(speed, ball.velocity.length())
		if ball.velocity.length() < 12.0:
			stalled += delta
	ball.collided.disconnect(collision_callback)
	ball.reset.disconnect(reset_callback)
	table._flippers_pressed = false
	result = {"seconds": snappedf(elapsed, 0.01), "policy": policy, "counts": counts,
		"bumpers": bumpers, "top_y": top, "max_speed": speed, "stalled_seconds": stalled}
	running = false
	return result
