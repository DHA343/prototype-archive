extends SceneTree

const PREVIEW: PackedScene = preload("res://experiments/pinball/preview.tscn")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var preview := PREVIEW.instantiate() as Control
	var table: Node2D = preview.get_node("Display/Viewport/Table")
	root.add_child(preview)
	table.set_physics_process(false)
	var viewport: SubViewport = preview.get_node("Display/Viewport")
	var display: SubViewportContainer = preview.get_node("Display")
	for screen: Vector2i in [
		Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440),
		Vector2i(3840, 2160), Vector2i(1366, 768), Vector2i(320, 180),
	]:
		root.size = screen
		await process_frame
		await process_frame
		var stretch := root.get_stretch_transform().get_scale()
		var scale := display.scale * stretch
		var extent := Vector2(viewport.size) * scale
		var offset := display.position * stretch
		_check(viewport.size == Vector2i(640, 360), "Internal resolution must stay 640 by 360")
		_check(is_equal_approx(scale.x, scale.y), "Display must preserve the aspect ratio")
		_check(offset.x >= -0.01 and offset.y >= -0.01
			and extent.x + offset.x <= screen.x + 0.01
			and extent.y + offset.y <= screen.y + 0.01, "Display was cropped")
		if screen.x >= 640 and screen.y >= 360:
			_check(is_equal_approx(scale.x, floorf(scale.x)), "Dots must use integer screen pixels")
		_check(offset.is_equal_approx(offset.round()), "Display must align to screen pixels")
		print("%s: scale %s, offset %s" % [screen, scale, offset])
	for names: Array in [
		["UpperLeft", "UpperRight"], ["MiddleLeft", "MiddleRight"], ["LowerLeft", "LowerRight"],
	]:
		var left: StaticBody2D = table.get_node("Bumpers/" + names[0])
		var right: StaticBody2D = table.get_node("Bumpers/" + names[1])
		_check(is_equal_approx(left.position.x + right.position.x, 640.0)
			and is_equal_approx(left.position.y, right.position.y)
			and is_equal_approx(left.radius, right.radius), "Bumpers must remain symmetric")
	for path: String in ["Ball", "LeftFlipper", "RightFlipper", "Walls"]:
		var body: Node2D = table.get_node(path)
		_check(body.scale == Vector2.ONE, "Physics bodies must not be visually squashed")
	preview.free()
	print("Pinball preview: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
