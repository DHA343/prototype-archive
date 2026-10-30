extends SceneTree

const BALL: PackedScene = preload("res://experiments/pinball/ball.tscn")
const FLIPPER: PackedScene = preload("res://experiments/pinball/flipper.tscn")
const BUMPER: PackedScene = preload("res://experiments/pinball/bumper.tscn")

var _failures: int = 0
var _cases: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var ball := BALL.instantiate() as CharacterBody2D
	arena.add_child(ball)
	ball.step(1.0 / 240.0)
	ball.gravity = 0.0
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 600)
	wall_shape.shape = box
	wall.position = Vector2(300, 250)
	wall.collision_layer = 1
	wall.collision_mask = 2
	wall.add_child(wall_shape)
	arena.add_child(wall)
	var bumper := BUMPER.instantiate() as StaticBody2D
	bumper.position = Vector2(140, 140)
	arena.add_child(bumper)
	var flipper := FLIPPER.instantiate() as StaticBody2D
	flipper.position = Vector2(120, 300)
	arena.add_child(flipper)
	var right_flipper := FLIPPER.instantiate() as StaticBody2D
	right_flipper.right_side = true
	right_flipper.position = Vector2(440, 300)
	arena.add_child(right_flipper)
	await physics_frame
	await physics_frame

	for fps: int in [30, 60, 120]:
		for speed: float in [100.0, 300.0, 520.0, 840.0]:
			ball.position = Vector2(280, 250)
			ball.velocity = Vector2(speed, 0)
			_step(ball, flipper, 1.0 / fps)
			_check(ball.position.x <= 294.1 - ball.get_radius(),
				"Wall tunneling at %d Hz / %.0f px/s" % [fps, speed])
			for index in range(ceili(fps * 0.3)):
				_step(ball, flipper, 1.0 / fps)
			_check(ball.velocity.x < 0.0, "Wall did not reflect")
			_check(absf(ball.velocity.x) <= speed * 0.31, "Passive bounce added energy")

	var bumper_hits: Array[int] = [0]
	ball.collided.connect(func(body: Node) -> void:
		if body == bumper:
			bumper_hits[0] += 1)
	for speed: float in [60.0, 200.0, 500.0, 840.0]:
		ball.position = bumper.position - Vector2(0, float(bumper.radius) + 12.0)
		ball.velocity = Vector2(0, speed)
		bumper_hits[0] = 0
		for index in range(30):
			_step(ball, flipper, 1.0 / 120.0)
		_check(absf(ball.velocity.y + bumper.kick_speed) <= 1.0, "Bumper kick stacked with bounce")
		_check(bumper_hits[0] == 1, "One bumper impact must emit exactly one hit")
	var original_radius: float = bumper.radius
	bumper.hit()
	bumper.step(0.012)
	_check(bumper.pulse > 0.99, "Bumper must expand immediately after impact")
	bumper.step(0.098)
	_check(bumper.pulse < 0.001, "Bumper expansion must settle after 0.11 seconds")
	var collision_radius: float = (bumper.get_node("CollisionShape2D").shape as CircleShape2D).radius
	_check(is_equal_approx(collision_radius, original_radius), "Visual pulse must not resize collision")

	ball.gravity = 630.0
	for fps: int in [30, 60, 120]:
		for paddle: StaticBody2D in [flipper, right_flipper]:
			var previous_angle := -PI * 0.5
			for fraction: float in [0.2, 0.5, 0.9]:
				paddle.pressed = false
				paddle.rotation = paddle._angle(false)
				paddle.step(1.0 / 240.0)
				var direction := Vector2.from_angle(paddle.rotation)
				var normal := direction.orthogonal()
				if normal.y > 0.0:
					normal = -normal
				ball.position = paddle.position + direction * float(paddle.length) * fraction \
					+ normal * (ball.get_radius() + 7.1)
				ball.velocity = Vector2(0, 80)
				paddle.pressed = true
				var upward_speed := 0.0
				var shot := Vector2.ZERO
				for index in range(ceili(fps * 0.15)):
					_step(ball, paddle, 1.0 / fps)
					upward_speed = minf(upward_speed, ball.velocity.y)
					if shot == Vector2.ZERO and ball.velocity.y < -40.0:
						shot = ball.velocity
					_check(ball.velocity.length() <= ball.max_speed + 0.01, "Speed limit exceeded")
				_check(upward_speed < -40.0,
					"Rotating flipper missed at %d Hz, right=%s, point=%.1f, upward=%.1f, position=%s"
					% [fps, paddle.right_side, fraction, upward_speed, ball.position])
				var inward := -1.0 if paddle.right_side else 1.0
				var horizontal := shot.x * inward
				_check((horizontal < 0.0 if fraction < 0.25 else horizontal > 0.0)
					and -shot.y > absf(shot.x), "Shot at %d Hz, right=%s, point=%.1f: %s"
					% [fps, paddle.right_side, fraction, shot])
				var shot_angle := atan2(horizontal, -shot.y)
				_check(shot_angle > previous_angle, "Inner contact must aim farther toward the center")
				previous_angle = shot_angle

	ball.gravity = 0.0
	for paddle: StaticBody2D in [flipper, right_flipper]:
		paddle.pressed = false
		paddle.step(0.2)
		paddle.pressed = true
		paddle.step(0.06)
		ball.position = paddle.position + Vector2.from_angle(paddle.rotation) * 45.0 + Vector2.UP * 12.0
		ball.velocity = Vector2(0, 80)
		for index in range(24):
			_step(ball, paddle, 1.0 / 240.0)
		_check(ball.velocity.y < -400.0, "Slightly early press must still strike after full raise")
		_check(not paddle.is_striking(), "A strike must consume the press window")
		paddle.step(0.2)
		ball.position = paddle.position + Vector2.from_angle(paddle.rotation) * 45.0 + Vector2.UP * 14.0
		ball.velocity = Vector2(0, 80)
		var held_speed := 0.0
		for index in range(72):
			_step(ball, paddle, 1.0 / 240.0)
			held_speed = maxf(held_speed, ball.velocity.length())
		_check(held_speed <= 80.01, "Holding the flipper must not add strike energy")

	ball.gravity = 630.0
	ball.position = Vector2(800, 300)
	ball.velocity = Vector2(0, -550)
	var apex_time := 0.0
	var apex_height := ball.position.y
	while ball.velocity.y < 0.0 and apex_time < 1.0:
		ball.step(1.0 / 240.0)
		apex_time += 1.0 / 240.0
		apex_height = minf(apex_height, ball.position.y)
	_check(apex_time < 0.9, "Strike must reach its apex promptly")
	_check(300.0 - apex_height > 225.0, "Strike must still reach the upper playfield")
	print("Strike apex: %.3f seconds / %.1f px rise" % [apex_time, 300.0 - apex_height])

	ball.position = Vector2(208, 362)
	ball.step(1.0 / 240.0)
	_check(ball.position.is_equal_approx(ball._spawn), "Drain reset failed")
	arena.free()
	print("Pinball physics: %d checks, %d failures" % [_cases, _failures])
	quit(1 if _failures > 0 else 0)


func _step(ball: CharacterBody2D, flipper: StaticBody2D, delta: float) -> void:
	var steps := ceili(delta * 240.0)
	for index in range(steps):
		flipper.step(delta / steps)
		ball.step(delta / steps)


func _check(condition: bool, message: String) -> void:
	_cases += 1
	if not condition:
		_failures += 1
		push_error(message)
