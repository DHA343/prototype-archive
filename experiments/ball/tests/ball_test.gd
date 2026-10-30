extends SceneTree

const BALL: PackedScene = preload("res://experiments/ball/ball.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ball := BALL.instantiate() as CharacterBody2D
	root.add_child(ball)
	_check(ball.is_physics_processing(), "Standalone ball must update without a table")
	ball.set_physics_process(false)
	var wall := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 400)
	collision.shape = shape
	wall.position = Vector2(300, 200)
	wall.add_child(collision)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	for gravity: float in [0.0, 600.0, 1100.0]:
		ball.gravity = gravity
		ball.position = Vector2(100, 100)
		ball.velocity = Vector2.ZERO
		for index in range(10):
			ball.step(1.0 / 240.0)
		_check(absf(ball.velocity.y - gravity / 24.0) < 0.01, "Configured gravity was not applied")
	ball.gravity = 0.0
	for restitution: float in [0.0, 0.3, 1.0]:
		ball.restitution = restitution
		ball.position = Vector2(280, 100)
		ball.velocity = Vector2(100, 70)
		for index in range(48):
			ball.step(1.0 / 240.0)
		_check(absf(ball.velocity.x + 100.0 * restitution) < 0.5,
			"Restitution %.2f produced velocity %s" % [restitution, ball.velocity])
		_check(absf(ball.velocity.y - 70.0) < 0.1, "Bounce must preserve tangential velocity")
		_check(ball.position.x <= 286.05, "Ball passed through the wall")
	ball.position = Vector2(100, 600)
	ball.velocity = Vector2.ZERO
	ball.step(1.0 / 240.0)
	_check(ball.position.is_equal_approx(Vector2(100, 600)), "Standalone ball must not use a pinball drain")
	ball.color = Color(0.2, 0.5, 0.8, 0.75)
	for intensity: float in [0.0, 0.5, 3.0]:
		ball.intensity = intensity
		var actual: Color = ball.get_color().srgb_to_linear()
		var expected: Color = ball.color.srgb_to_linear()
		_check(is_equal_approx(actual.r, expected.r * intensity)
			and is_equal_approx(actual.g, expected.g * intensity)
			and is_equal_approx(actual.b, expected.b * intensity), "Color intensity must scale linear RGB")
		_check(is_equal_approx(actual.a, ball.color.a), "Color intensity must preserve alpha")
	ball.gravity = 600.0
	ball.restitution = 0.65
	var packed := PackedScene.new()
	_check(packed.pack(ball) == OK, "Configured ball could not be packed")
	var copy := packed.instantiate() as CharacterBody2D
	_check(is_equal_approx(copy.gravity, 600.0) and is_equal_approx(copy.restitution, 0.65)
		and copy.color == ball.color and is_equal_approx(copy.intensity, 3.0),
		"Scene must retain gravity, restitution, color, and intensity")
	copy.free()
	ball.position = Vector2(100, 100)
	ball.velocity = Vector2.ZERO
	ball.set_physics_process(true)
	for index in range(4):
		await physics_frame
	ball.set_physics_process(false)
	_check(ball.position.y > 100.0 and ball.velocity.y > 0.0, "Standalone physics did not advance")
	wall.free()
	ball.free()
	print("Ball: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
