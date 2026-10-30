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
	var left: StaticBody2D = table.get_node("LeftFlipper")
	var right: StaticBody2D = table.get_node("RightFlipper")
	var ball: CharacterBody2D = table.get_node("Ball")
	var guide: Path2D = table.get_node("Walls/LeftGuide")
	_check(table.get_node("Walls").get_child_count() == 5, "Walls must be authored scene nodes")
	for wall: Path2D in table.get_node("Walls").get_children():
		_check(wall.points.size() - 1 == wall._body.get_child_count(), "Rendered wall and colliders must agree")
	var before: Vector2 = guide.points[12]
	guide.curve.set_point_out(0, Vector2(64, -16))
	_check(guide.points[12] != before, "Editing a native Curve2D must rebuild the wall")
	left.length = 120
	left.rest_angle = 25
	left.raised_angle = -10
	left.shot_angles = Vector3(-30, 0, 40)
	left.shot_strengths = Vector3(0.6, 0.8, 1.5)
	_check(is_equal_approx(left.outline[7].x, 120), "Length must rebuild the visible and collision outline")
	_check((left.get_node("CollisionShape2D").shape as ConvexPolygonShape2D).points == left.outline,
		"Flipper drawing and collision must share the same shape")
	_check(right.length == 90, "An edited node must not mutate its sibling")
	var packed := PackedScene.new()
	_check(packed.pack(table) == OK, "Authored components must pack into a scene")
	var path := "user://pinball_authoring_test.tscn"
	_check(ResourceSaver.save(packed, path) == OK, "Standard scene saving must preserve the edits")
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var copy := saved.instantiate() as Node2D
	root.add_child(copy)
	copy.set_physics_process(false)
	_check(copy.get_node("LeftFlipper").length == 120, "Loading the scene must retain the length")
	_check(copy.get_node("LeftFlipper").shot_angle_middle == 0, "Loading must retain the named angle fields")
	_check(copy.get_node("LeftFlipper").shot_strength_tip == 1.5, "Loading must retain the strength fields")
	_check(copy.get_node("Walls/LeftGuide").curve.get_point_out(0) == Vector2(64, -16),
		"Loading must retain the native curve handles")
	copy.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for child in table.get_node("Walls").get_children():
		table.get_node("Walls").remove_child(child)
		child.free()
	for child in table.get_node("Bumpers").get_children():
		table.get_node("Bumpers").remove_child(child)
		child.free()
	for paddle: StaticBody2D in [left, right]:
		paddle.length = 120
		paddle.rest_angle = 25
		paddle.raised_angle = -10
		paddle.shot_angles = Vector3(-30, 0, 40)
		paddle.shot_strengths = Vector3(0.6, 0.8, 1.5)
	left.position = Vector2(180, 160)
	right.position = Vector2(460, 160)
	await physics_frame
	ball.step(1.0 / 240.0)
	for paddle: StaticBody2D in [left, right]:
		for fraction: float in [0, 0.25, 0.5, 0.75, 1]:
			var point := paddle.to_global(Vector2(float(paddle.length) * fraction, 0))
			var velocity: Vector2 = ball.get_shot_velocity(paddle, point, paddle.rotation)
			var angle := lerpf(-30, 0, fraction * 2) if fraction <= 0.5 else lerpf(0, 40, (fraction - 0.5) * 2)
			var strength := lerpf(0.6, 0.8, fraction * 2) if fraction <= 0.5 else lerpf(0.8, 1.5, (fraction - 0.5) * 2)
			var actual := rad_to_deg(atan2(velocity.x * (-1 if paddle.right_side else 1), -velocity.y))
			_check(absf(actual - angle) < 0.01, "Three-point angle interpolation must work on both sides")
			_check(absf(velocity.length() - minf(550 * strength, 600)) < 0.02,
				"Position-based strength must interpolate and respect the speed limit")
		for flipper: StaticBody2D in [left, right]:
			flipper.pressed = false
			flipper.step(0.2)
		var tangent := Vector2.from_angle(paddle.rotation)
		var normal := tangent.orthogonal()
		if normal.y > 0:
			normal = -normal
		ball.position = paddle.position + tangent * float(paddle.length) * 0.5 + normal * 26
		ball.velocity = Vector2(0, 300)
		var prediction := Aim.predict(ball, [left, right])
		_check(not prediction.is_empty(), "A repositioned flipper must predict an edited shot")
		var shots: Array[Vector2] = []
		var callback := func(body: Node) -> void:
			if body == paddle and shots.is_empty():
				shots.append(ball.velocity)
		ball.collided.connect(callback)
		table._flippers_pressed = true
		for step in range(24):
			table._physics_process(1.0 / 240.0)
			if not shots.is_empty():
				break
		ball.collided.disconnect(callback)
		_check(not shots.is_empty(), "An edited flipper must deliver the predicted strike")
		if not prediction.is_empty() and not shots.is_empty():
			var expected: Vector2 = prediction.velocity
			_check(absf(expected.angle_to(shots[0])) < deg_to_rad(2), "Edited prediction must match contact")
			_check(absf(expected.length() - shots[0].length()) < 10, "Prediction must share the edited strength")
	table.free()
	await process_frame
	print("Pinball authoring: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
