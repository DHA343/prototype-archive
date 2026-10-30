extends SceneTree

const Missile = preload("res://experiments/missiles/missile.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://experiments/missiles/preview.tscn") as PackedScene
	var plain := scene.instantiate() as Control
	var viewed := scene.instantiate() as Control
	root.add_child(plain)
	root.add_child(viewed)
	for preview in [plain, viewed]:
		for arena in preview.arenas:
			arena.launcher.auto_fire = false
			arena.launcher.fire()
	for tick in range(145):
		await physics_frame
		if tick % 7 == 0:
			_key(viewed, KEY_C)
		viewed._update_guidance_selection()
		for lane in range(viewed.arenas.size()):
			var first: Array = plain.arenas[lane].launcher._missiles
			var second: Array = viewed.arenas[lane].launcher._missiles
			assert(first.size() == second.size(), "Visualization changed missile lifetime")
			for index in range(first.size()):
				_assert_same_flight(first[index], second[index])
				_assert_guidance_snapshot(viewed, second[index])
	plain.queue_free()
	viewed._replay()
	for arena in viewed.arenas:
		arena.launcher.fire()
	viewed._show_guidance = true
	for tick in range(70):
		await physics_frame
	_key(viewed, KEY_P)
	viewed._update_guidance_selection()
	assert(viewed._selected_shot == 0, "Oldest pair was not selected")
	var selected: Node2D = viewed.arenas[0].launcher._missiles[0]
	selected.free()
	viewed._update_guidance_selection()
	assert(viewed._selected_shot == 1, "Selection did not advance after the missile finished")
	var states: Array[Dictionary] = []
	for arena in viewed.arenas:
		for missile in arena.launcher._missiles:
			states.append({"missile": missile, "position": missile.position,
				"velocity": missile._velocity, "age": missile._age,
				"rng": _instability_random_state(missile), "active": _instability_active(missile),
				"elapsed": _instability_elapsed_time(missile), "fallback": missile.get("_target_direction")})
	var cell: Control = viewed._cells[0]
	var viewport := cell.get_child(0) as SubViewport
	var target := Vector2(390, 100)
	var point: Vector2 = target - viewed.VIEW_CENTER + Vector2(viewport.size) * 0.5
	viewed._dragging = true
	viewed._pointer = cell.get_global_transform() * point
	viewed._process(0.0)
	for state in states:
		var missile: Node2D = state.missile
		assert(missile.position == state.position and missile._velocity == state.velocity,
			"Paused drag advanced motion")
		assert(missile._age == state.age and _instability_random_state(missile) == state.rng,
			"Paused drag advanced age or RNG")
		assert(_instability_active(missile) == state.active and _instability_elapsed_time(missile) == state.elapsed,
			"Paused drag advanced error events")
		assert(missile.get("_target_direction") == state.fallback, "Inspection changed controller fallback")
		var data: Dictionary = viewed._get_guidance_snapshot(missile)
		assert(data.start == missile.position and data.end.distance_to(target) < 0.001,
			"Paused drag did not refresh the actual guide")
		if not data.curved:
			if missile.get_script() == load("res://experiments/missiles/missile.gd"):
				assert(data.path.size() == 3 and data.path[1] == data.guide,
					"Offset guide was not refreshed")
			else:
				assert(data.guide == data.end and data.path.size() == 2, "Direct guide is not the target")
			continue
		var departure: Vector2 = data.start_tangent
		var arrival: Vector2 = data.end_tangent
		assert(absf(departure.length() - missile.approach_departure_length) < 0.001,
			"Start tangent was scaled for display")
		var expected: float = missile.position.distance_to(target) * missile.approach_arrival_scale
		assert(absf(arrival.length() - expected) < 0.001, "End tangent has incorrect length")
	viewed.queue_free()
	await process_frame
	print("Guidance view: flight/RNG invariance, actual vectors, selection lifetime and paused drag verified.")
	quit()


func _key(preview: Control, keycode: int) -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	preview._unhandled_key_input(key)


func _instability_random_state(missile: Node2D) -> int:
	return missile._instability_random.state if missile is Missile else missile._random.state


func _instability_elapsed_time(missile: Node2D) -> float:
	return missile._instability_elapsed if missile is Missile else missile._phase_elapsed


func _assert_same_flight(first: Node2D, second: Node2D) -> void:
	assert(first.position == second.position, "Visualization changed trajectory")
	assert(first._velocity == second._velocity, "Visualization changed velocity")
	assert(_instability_random_state(first) == _instability_random_state(second), "Visualization consumed RNG")


func _assert_guidance_snapshot(preview: Control, missile: Node2D) -> void:
	var data: Dictionary = preview._get_guidance_snapshot(missile)
	if data.is_empty():
		return

	var expected_departure: Vector2 = missile._start_tangent if data.curved else Vector2.ZERO
	var expected_arrival: Vector2 = missile._end_tangent if data.curved else Vector2.ZERO
	assert(data.start_tangent == expected_departure, "Incorrect start tangent")
	assert(data.end_tangent == expected_arrival, "Incorrect end tangent")

	var start: Vector2 = data.start
	var guide: Vector2 = data.guide
	var direction := (guide - start).normalized().rotated(data.error)
	assert(direction.distance_to(data.direction) < 0.000001, "Incorrect steering direction")

	var path: PackedVector2Array = data.path
	path[0] = Vector2(999, 999)
	var refreshed: Dictionary = preview._get_guidance_snapshot(missile)
	assert(refreshed.path[0] != path[0], "Snapshot aliases the live curve")


func _instability_active(missile: Node2D) -> bool:
	if missile is Missile:
		return missile._is_instability_active()
	return missile._error_phase != missile.ErrorPhase.REST
