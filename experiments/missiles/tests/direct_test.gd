extends SceneTree


func _initialize() -> void:
	var scene := load("res://experiments/missiles/comparison/direct.tscn") as PackedScene
	var curved_scene := load("res://experiments/missiles/comparison/unstable.tscn") as PackedScene
	var target := Node2D.new()
	target.position = Vector2(0, -149)
	var direct := scene.instantiate() as Node2D
	var altered := scene.instantiate() as Node2D
	var curved := curved_scene.instantiate() as Node2D
	altered.approach_departure_length = 120.0
	altered.approach_arrival_scale = 6.0
	altered.approach_lookahead = 1.0
	altered.approach_frame = 0
	for missile in [direct, altered, curved]:
		missile.launch(Vector2.ZERO, Vector2.DOWN.rotated(0.35), target, 1.7, Vector2.UP, 0.7)
	for tick in range(75):
		target.position.x = sin(float(tick) / 60.0) * 20.0
		for missile in [direct, altered, curved]:
			missile._physics_process(1.0 / 60.0)
		assert(direct.position == altered.position and direct._velocity == altered._velocity,
			"Hermite settings affect direct pursuit")
		assert(direct._random.state == curved._random.state,
			"Direct pursuit changes the steering-error random sequence")
		assert(direct._error_angle == curved._error_angle,
			"Direct pursuit changes the steering-error timeline")
		var data: Dictionary = direct.get_guidance_snapshot()
		if data.is_empty():
			continue
		assert(not data.curved and data.path.size() == 2, "Direct pursuit evaluated a curve")
		assert(data.guide == target.position, "Direct guide is not the current target")
		assert(data.start_tangent == Vector2.ZERO and data.end_tangent == Vector2.ZERO,
			"Direct pursuit retained Hermite tangents")
	for property in direct.get_property_list():
		if String(property.name).begins_with("approach_"):
			assert((property.usage & PROPERTY_USAGE_EDITOR) == 0, "Unused curve control is exposed")
	for missile in [direct, altered, curved]:
		missile.free()
	target.free()
	print("Direct pursuit: no Hermite dependency, current target and shared error sequence verified.")
	quit()
