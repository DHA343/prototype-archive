extends SceneTree

const Missile = preload("res://experiments/missiles/missile.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://experiments/missiles/preview.tscn") as PackedScene
	var preview := scene.instantiate() as Control
	root.add_child(preview)
	preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(1336, 752)
	preview._layout()
	assert(preview.arenas.size() == 1, "Expected the current missile only")
	assert(preview.launcher_scene.resource_path == "res://experiments/missiles/launcher.tscn",
		"Preview uses a historical launcher")
	assert(preview.missiles[0].resource_path == "res://experiments/missiles/missile.tscn",
		"Preview uses a historical missile")
	for focus in [-1, 0]:
		preview._focus = focus
		preview._layout()
		var index: int = 0 if focus < 0 else focus
		var cell: Control = preview._cells[index]
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		var viewport := cell.get_child(0) as SubViewport
		var point: Vector2 = Vector2(300, 150) - preview.VIEW_CENTER + Vector2(viewport.size) * 0.5
		mouse.position = cell.get_global_transform() * point
		preview._input(mouse)
		preview._process(0.0)
		for arena in preview.arenas:
			assert(arena.target_override.distance_to(Vector2(300, 150)) < 0.001,
				"Drag coordinates differ in grid and focused views")
		mouse.pressed = false
		preview._input(mouse)
		preview._process(0.0)
		assert(preview.arenas[0].target_override.x < 0.0, "Released drag is still active")
	preview._focus = -1
	preview._layout()
	for window_size in [Vector2(1336, 752), Vector2(1920, 1080), Vector2(1000, 1000)]:
		preview.size = window_size
		preview._layout()
		var cell: Control = preview._cells[0]
		var viewport := cell.get_child(0) as SubViewport
		assert(viewport.size == Vector2i(640, 360), "Render resolution changes with window size")
		var available := preview.size - Vector2(0, 28)
		var extent := Vector2(640, 360) * minf(available.x / 640.0, available.y / 360.0)
		assert(cell.position.distance_to((available - extent) * 0.5) < 0.001,
			"Preview is not centered with its aspect ratio preserved")
	preview.size = Vector2(1336, 752)
	preview._layout()
	for index in range(1):
		var focus_key := InputEventKey.new()
		focus_key.pressed = true
		focus_key.keycode = KEY_1 + index
		preview._unhandled_key_input(focus_key)
		assert(preview._focus == index, "Focus number differs from display order")
	var seeds: Array[int] = []
	for replay in range(3):
		preview._replay()
		for tick in range(45):
			await physics_frame
		for lane in range(preview.arenas.size()):
			var arena: Node2D = preview.arenas[lane]
			var launcher: Node2D = arena.launcher
			assert(launcher._missiles.size() == 3, "Volley conditions differ")
			for shot in range(3):
				var missile: Node2D = launcher._missiles[shot]
				var instability_random: RandomNumberGenerator = missile._instability_random if missile is Missile else missile._random
				if seeds.size() < 3:
					seeds.append(instability_random.seed)
				assert(is_equal_approx(seeds[shot], instability_random.seed), "Replay or method changed seed")
				for property in missile.get_property_list():
					if lane == 0 and String(property.name).begins_with("error_") and property.name != "error_enabled":
						assert((property.usage & PROPERTY_USAGE_EDITOR) == 0, "Disabled instability settings are exposed")
	for keycode in [KEY_P, KEY_P, KEY_S, KEY_S, KEY_0]:
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = keycode
		preview._unhandled_key_input(key)
	assert(not preview._paused and not preview._slow and preview._focus == -1,
		"Preview left paused, slow or focused")
	assert(is_equal_approx(Engine.time_scale, 1.0), "Time scale not restored")
	preview.queue_free()
	await process_frame
	print("Preview: current missile, full-screen layout, drag, replay and pause/slow verified.")
	quit()
