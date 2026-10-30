extends SceneTree

const Missile = preload("res://experiments/missiles/missile.gd")
const Visuals = preload("res://experiments/missiles/visuals.gd")
const SCENE = preload("res://experiments/missiles/missile.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.position = Vector2(40, 20)
	world.rotation = 0.4
	root.add_child(world)
	var missile := SCENE.instantiate() as Missile
	missile.get_node("Visuals").set_script(RecordingVisuals)
	world.add_child(missile)
	missile.launch(Vector2.ZERO, Vector2.DOWN, null, 1.7, 80.0)
	var visuals := missile.get_node("Visuals") as Node2D
	for tick in range(45):
		missile._physics_process(1.0 / 60.0)
		visuals._physics_process(1.0 / 60.0)
	assert(missile.state == Missile.State.STRAIGHT, "Missile changed state without an external command")
	assert(not missile.is_queued_for_deletion(), "Straight flight requires a target")
	assert(not visuals.requests.is_empty(), "Standalone missile has no exhaust or smoke")
	assert(visuals._trace.size() > 1, "Standalone missile has no trail")
	assert(visuals._body_position.distance_to(missile.global_position) < 0.001,
		"Visuals do not follow the transformed missile")

	var before := missile.get_velocity()
	missile.desired_speed = 0.0
	missile._physics_process(1.0 / 60.0)
	assert(missile.get_velocity().length() > 0.0, "Speed command bypassed deceleration")
	assert((missile.get_velocity() - before).length() <= missile.acceleration_limit / 60.0 + 0.001,
		"Speed command exceeded acceleration limit")

	var target := Node2D.new()
	world.add_child(target)
	target.position = Vector2(180, -100)
	missile.start_homing(target)
	missile.desired_speed = missile.speed
	missile._physics_process(1.0 / 60.0)
	assert(missile.state == Missile.State.HOMING and not missile.get_guidance_state().is_empty(),
		"External homing command did not take effect")
	target.free()
	missile._physics_process(1.0 / 60.0)
	assert(missile.is_queued_for_deletion(), "Lost homing target did not end flight")
	assert(visuals.get_parent() == world, "Visual tail remains attached to the missile")
	missile.free()
	assert(is_instance_valid(visuals), "Missile deletion removed its visual tail")
	for tick in range(180):
		visuals._physics_process(1.0 / 60.0)
		if visuals.is_queued_for_deletion():
			break
	assert(visuals.is_queued_for_deletion(), "Visual tail does not expire")
	await process_frame
	assert(not is_instance_valid(visuals), "Expired visual tail was not freed")

	var impact_target := Node2D.new()
	world.add_child(impact_target)
	impact_target.position = Vector2(105, 100)
	var impact_missile := SCENE.instantiate() as Missile
	impact_missile.get_node("Visuals").set_script(RecordingVisuals)
	world.add_child(impact_missile)
	impact_missile.launch(Vector2(100, 100), Vector2.RIGHT, impact_target, 2.0, 80.0)
	var impact_visuals := impact_missile.get_node("Visuals") as Node2D
	impact_missile._physics_process(0.1)
	assert(impact_visuals.get_parent() == world and impact_visuals.requests.size() >= 44,
		"Standalone missile has no independent impact effect")
	world.free()
	print("Missile: two external modes, bounded speed commands, standalone visuals and tail lifetime verified.")
	quit()


class RecordingVisuals extends Visuals:
	var requests: Array[Dictionary] = []

	func _add_particle(point: Vector2, velocity: Vector2, tint: Color, duration: float, smoke: bool) -> void:
		requests.append({"point": point, "velocity": velocity, "tint": tint,
			"duration": duration, "smoke": smoke})
