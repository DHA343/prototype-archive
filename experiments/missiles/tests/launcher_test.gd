extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://experiments/missiles/launcher.tscn") as PackedScene
	var world := Node2D.new()
	root.add_child(world)
	var target := Node2D.new()
	world.add_child(target)
	var launcher := scene.instantiate() as Node2D
	world.add_child(launcher)
	launcher.auto_fire = false
	launcher.target = target
	launcher.set_physics_process(false)
	launcher.fire()
	for profile in launcher._pending_shots:
		assert(not profile.has("approach"), "Normal launcher still generates Hermite parameters")
	for tick in range(30):
		launcher._physics_process(1.0 / 60.0)
	assert(launcher._missiles.size() == launcher.volley_size, "Standalone launcher failed to fire")
	for missile in launcher._missiles:
		assert(missile.get_script() == load("res://experiments/missiles/missile.gd"),
			"Standalone launcher did not spawn the adopted missile")
		for property in missile.get_property_list():
			assert(not String(property.name).begins_with("approach_"), "Hermite settings remain")
	var first: Node2D = launcher._missiles[0]
	assert(first.state == first.State.STRAIGHT, "Launcher ended straight flight too early")
	for tick in range(60):
		launcher._physics_process(1.0 / 60.0)
	assert(first.state == first.State.HOMING, "Launcher did not command homing")
	assert(is_equal_approx(first.desired_speed, first.speed), "Launcher did not finish the speed ramp")
	world.free()
	print("Launcher: standalone adopted scene and external flight control without Hermite verified.")
	quit()
