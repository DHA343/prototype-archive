extends Control
## 描画を伴う負荷計測。通常のプレビューやミサイルの設定は変更しない。

const MISSILE = preload("res://experiments/missiles/missile.tscn")
const MEASURED_VISUALS = preload("res://experiments/missiles/tests/render_visuals.gd")
const DIRECT = preload("res://experiments/missiles/tests/render_direct.gd")
const CASES: Array[Dictionary] = [
	{"mode": "empty", "count": 0, "visuals": false},
	{"mode": "current", "count": 10, "visuals": true},
	{"mode": "current", "count": 30, "visuals": true},
	{"mode": "current", "count": 60, "visuals": true},
	{"mode": "current", "count": 100, "visuals": true},
	{"mode": "current", "count": 100, "visuals": false},
	{"mode": "direct", "count": 100, "visuals": true},
]

var results: Array[Dictionary] = []
var done: bool = false
var _viewport: SubViewport
var _world: Node2D
var _target: Node2D
var _cell: SubViewportContainer
var _label: Label
var _case: int = -1
var _phase_start: int = 0
var _physics_start: int = 0
var _last_frame: int = 0
var _sequence: int = 0
var _missiles: Array[Node2D] = []
var _frames: Array[float] = []
var _physics: Array[float] = []
var _draw_times: Array[float] = []
var _gpu: Array[float] = []
var _render_cpu: Array[float] = []
var _spawns: int = 0
var _impacts: int = 0


func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	process_physics_priority = -1000
	_cell = SubViewportContainer.new()
	_cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_cell)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_cell.add_child(_viewport)
	RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), true)
	_world = Node2D.new()
	_viewport.add_child(_world)
	_target = Node2D.new()
	_world.add_child(_target)
	var probe := PhysicsProbe.new()
	probe.recorder = self
	probe.process_physics_priority = 1000
	add_child(probe)
	_label = Label.new()
	add_child(_label)
	resized.connect(_layout)
	_layout()
	_next_case()


func _layout() -> void:
	_cell.scale = Vector2.ONE * minf(size.x / 640.0, size.y / 360.0)


func _physics_process(_delta: float) -> void:
	if done:
		return
	_physics_start = Time.get_ticks_usec()
	var time := float(Time.get_ticks_usec() - _phase_start) * 0.000001
	_target.position = Vector2(320 + sin(time * 0.9) * 100, 90 + sin(time * 1.3) * 30)
	for index in range(_missiles.size() - 1, -1, -1):
		if not is_instance_valid(_missiles[index]) or _missiles[index].is_queued_for_deletion():
			_missiles.remove_at(index)
	while _missiles.size() < CASES[_case].count:
		_spawn()


func _process(_delta: float) -> void:
	if done:
		return
	var now := Time.get_ticks_usec()
	var elapsed := now - _phase_start
	if elapsed > 2500000 and _last_frame > 0:
		_frames.append(float(now - _last_frame) / 1000.0)
		if MEASURED_VISUALS.draw_usec > 0:
			_draw_times.append(float(MEASURED_VISUALS.draw_usec) / 1000.0)
		var rid := _viewport.get_viewport_rid()
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		_render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	MEASURED_VISUALS.draw_usec = 0
	_last_frame = now
	if elapsed >= 8000000:
		_finish_case.call_deferred()
		set_process(false)


func _spawn() -> void:
	var missile := MISSILE.instantiate() as Node2D
	if CASES[_case].mode == "direct":
		var settings: Dictionary = {}
		for property in missile.get_property_list():
			if (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (property.usage & PROPERTY_USAGE_EDITOR):
				settings[property.name] = missile.get(property.name)
		missile.set_script(DIRECT)
		for key in settings:
			missile.set(key, settings[key])
	if not CASES[_case].visuals:
		missile.get_node("Visuals").set_physics_process(false)
		missile.get_node("Visuals").visible = false
	if CASES[_case].visuals:
		missile.get_node("Visuals").set_script(MEASURED_VISUALS)
	_world.add_child(missile)
	if not CASES[_case].visuals:
		missile._visuals = null
	var seed_value := float(_sequence) * 0.473 + 0.31
	var origin := Vector2(100 + (_sequence % 20) * 22, 239)
	var direction := Vector2.DOWN.rotated(sin(seed_value) * 0.78)
	missile.launch(origin, direction, _target, seed_value, 80.0)
	missile.start_homing(_target)
	missile.desired_speed = missile.speed
	missile.impacted.connect(_on_impact)
	_missiles.append(missile)
	_sequence += 1
	_spawns += 1


func _on_impact(_point: Vector2, _tint: Color) -> void:
	_impacts += 1


func _record_physics() -> void:
	if not done and Time.get_ticks_usec() - _phase_start > 2500000:
		_physics.append(float(Time.get_ticks_usec() - _physics_start) / 1000.0)


func _finish_case() -> void:
	var particles := 0
	var effects := 0
	for child in _world.get_children():
		if child.get_script() == MEASURED_VISUALS:
			effects += 1
			particles += child.get_node("Particles").amount
		elif child.has_node("Visuals") and CASES[_case].visuals:
			effects += 1
			particles += child.get_node("Visuals/Particles").amount
	var result: Dictionary = CASES[_case].duplicate()
	result.merge({
		"frame_median_ms": _percentile(_frames, 0.5),
		"frame_p95_ms": _percentile(_frames, 0.95),
		"draw_script_median_ms": _percentile(_draw_times, 0.5),
		"physics_median_ms": _percentile(_physics, 0.5),
		"gpu_median_ms": _percentile(_gpu, 0.5),
		"render_cpu_median_ms": _percentile(_render_cpu, 0.5),
		"frame_samples": _frames.size(), "physics_samples": _physics.size(),
		"redraw_samples": _draw_times.size(),
		"particle_capacity_end": particles, "effects_end": effects,
		"spawns": _spawns, "impacts": _impacts,
		"window_size": str(get_window().size),
	})
	results.append(result)
	print("RENDER_BENCH ", JSON.stringify(result))
	var file := FileAccess.open("res://experiments/missiles/tests/render_gpu_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	for child in _world.get_children():
		if child != _target:
			child.free()
	_missiles.clear()
	_next_case()


func _next_case() -> void:
	_case += 1
	if _case >= CASES.size():
		done = true
		_label.text = "Benchmark complete"
		return
	_label.text = str(CASES[_case])
	MEASURED_VISUALS.draw_usec = 0
	_frames.clear()
	_physics.clear()
	_draw_times.clear()
	_gpu.clear()
	_render_cpu.clear()
	_sequence = 0
	_spawns = 0
	_impacts = 0
	_phase_start = Time.get_ticks_usec()
	_last_frame = 0
	set_process(true)


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	return values[mini(int(values.size() * fraction), values.size() - 1)]


class PhysicsProbe extends Node:
	var recorder: Control

	func _physics_process(_delta: float) -> void:
		recorder._record_physics()
