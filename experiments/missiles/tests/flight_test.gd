extends SceneTree

const Launcher = preload("res://experiments/missiles/launcher.gd")
const Missile = preload("res://experiments/missiles/missile.gd")


func _initialize() -> void:
	var results: Array[Dictionary] = []
	for preset in ["normal", "unstable", "direct", "offset"]:
		var adopted: bool = preset == "offset"
		var path: String = "missile" if preset == "offset" else "comparison/" + preset
		var scene := load("res://experiments/missiles/%s.tscn" % path) as PackedScene
		var cases := 0
		var hits := 0
		for rate in [30.0, 60.0, 120.0]:
			for scenario in range(3):
				for shot in range(20):
					var target := Node2D.new()
					root.add_child(target)
					target.position = Vector2(320, 90)
					var missile := scene.instantiate() as Node2D
					missile.process_mode = Node.PROCESS_MODE_DISABLED
					root.add_child(missile)
					var direction := Vector2.DOWN.rotated(lerpf(-0.78, 0.78, shot / 19.0))
					var arrival := lerpf(-PI / 3.0, PI / 3.0, shot / 19.0)
					var controller := Launcher.new()
					controller.position = Vector2(320, 239)
					controller.target = target
					if adopted:
						controller._start_missile(missile, {"seed": 0.31 + shot * 0.473}, direction)
					else:
						missile.launch(Vector2(320, 239), direction, target,
							0.31 + shot * 0.473, Vector2.UP, arrival)
					var delay: float = controller.tracking_delay if adopted else missile.ignition_delay
					var delta: float = 1.0 / rate
					for tick in range(int(rate * 5.1)):
						var time: float = (tick + 1) / rate
						if scenario == 1:
							target.position = Vector2(320 + sin(time * 0.9) * 32, 90 + sin(time * 1.3) * 13)
						elif scenario == 2 and time >= 1.2:
							target.position = Vector2(420, 150)
						var before: Vector2 = missile._velocity
						var position_before := missile.position
						var age: float = missile._age
						if adopted:
							controller._update_flights(delta)
						missile._physics_process(delta)
						assert(missile.position.is_finite() and missile._velocity.is_finite(), "Nonfinite motion")
						assert(missile._velocity.length() <= missile.speed + 0.001, "Cruise cap exceeded")
						assert((missile._velocity - before).length() <= missile.acceleration_limit * delta + 0.001,
							"Acceleration limit bypassed")
						if time <= delay:
							var expected: Vector2 = Vector2(320, 239) + direction * (controller.launch_speed if adopted else missile.launch_speed) * time
							assert(missile.position.distance_to(expected) < 0.01, "Launch changed")
						elif age >= delay:
							var movement: Vector2 = (before + missile._velocity) * (0.5 * delta)
							assert((missile.position - position_before).distance_to(movement) < 0.001,
								"Motion is not integrated from velocity")
							var latest_target: Vector2 = missile._guidance_target if adopted else missile._end
							assert(latest_target.distance_to(target.position) < 0.01, "Stale target")
						if missile.is_queued_for_deletion():
							if missile._age < missile.lifetime:
								hits += 1
							break
					cases += 1
					missile.free()
					target.free()
					controller.free()
		assert(hits == cases, "Default comparison must hit in sampled conditions")
		results.append({"preset": preset, "cases": cases, "hits": hits})
	print(JSON.stringify(results))
	quit()
