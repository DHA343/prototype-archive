extends Node2D

const TINT: Color = Color("e99cff")
const Visuals = preload("res://experiments/missiles/visuals.gd")


var show_traces: bool = true:
	set(value):
		show_traces = value
		for effect in _effects:
			var visuals := effect.get_ref() as Visuals
			if visuals != null:
				visuals.show_traces = value
var _effects: Array[WeakRef] = []
var moving_target: bool = true
var target_override: Vector2 = Vector2(-1.0, -1.0)
var target: Node2D
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


var _clock: float = 0.0

var _flash: float = 0.0
var _stars: PackedVector2Array = PackedVector2Array()
var _guidance: Dictionary = {}


@onready var launcher: Node2D = $Launcher


func _ready() -> void:
	launcher.missile_launched.connect(_on_missile_launched)
	target = Node2D.new()
	target.name = "Target"
	target.position = Vector2(320, 90)
	add_child(target)
	launcher.target = target
	_random.seed = 142857
	for index in range(110):
		_stars.append(Vector2(_random.randf_range(8, 632), _random.randf_range(42, 326)))


func _physics_process(delta: float) -> void:
	_clock += delta
	var offset := Vector2.ZERO
	if target_override.x >= 0.0:
		target.position = target_override
	else:
		if moving_target:
			offset = Vector2(sin(_clock * 0.9) * 32.0, sin(_clock * 1.3) * 13.0)
		target.position = Vector2(320, 90) + offset
	_flash = maxf(0.0, _flash - delta)
	for index in range(_effects.size() - 1, -1, -1):
		if _effects[index].get_ref() == null:
			_effects.remove_at(index)
	queue_redraw()


func _draw() -> void:
	var top_left := get_canvas_transform().affine_inverse() * Vector2.ZERO
	draw_rect(Rect2(top_left, get_viewport_rect().size), Color("090c17"))
	for star in _stars:
		draw_rect(Rect2(star.round(), Vector2.ONE), Color("1e2636"))
	_draw_launcher(launcher.position - Vector2(0, 4))
	_draw_target()
	_draw_guidance()


func set_guidance(snapshot: Dictionary) -> void:
	_guidance = snapshot
	queue_redraw()


func refresh_guidance() -> void:
	for missile in launcher._missiles:
		if is_instance_valid(missile) and not missile.is_queued_for_deletion():
			missile.refresh_guidance()
	queue_redraw()


func fire() -> void:
	launcher.fire()


func reset() -> void:
	launcher.reset()
	for effect in _effects:
		var visuals := effect.get_ref() as Visuals
		if visuals != null:
			visuals.queue_free()
	_effects.clear()
	_clock = 0.0
	_flash = 0.0
	_guidance = {}


func _draw_guidance() -> void:
	if _guidance.is_empty():
		return
	var path: PackedVector2Array = _guidance.path
	var start: Vector2 = _guidance.start
	var end: Vector2 = _guidance.end
	var departure: Vector2 = _guidance.start_tangent
	var arrival: Vector2 = _guidance.end_tangent
	var guide: Vector2 = _guidance.guide
	var direction: Vector2 = _guidance.direction
	draw_polyline(path, Color("59dfff"), 1.0)
	draw_circle(start, 2.0, Color("59dfff"))
	draw_circle(end, 2.0, Color("59dfff"))
	if _guidance.curved:
		_draw_arrow(start, start + departure, Color("a9f563"))
		_draw_arrow(end - arrival, end, Color("ff983e"))
	draw_line(start, guide, Color("ffe57a"), 1.0)
	draw_circle(guide, 2.5, Color("ffe57a"))
	_draw_arrow(start, start + direction * start.distance_to(guide), Color("ff79c8"))
	if _guidance.curved:
		var font := ThemeDB.fallback_font
		draw_string(font, start + departure + Vector2(3, -3),
			"Start %.1f px" % departure.length(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a9f563"))
		draw_string(font, end - arrival + Vector2(3, -3),
			"End %.1f px" % arrival.length(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("ff983e"))


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 1.0)
	if from.is_equal_approx(to):
		return
	var direction := (to - from).normalized()
	var tip_length := minf(5.0, from.distance_to(to) * 0.3)
	draw_line(to, to - direction.rotated(0.45) * tip_length, color, 1.0)
	draw_line(to, to - direction.rotated(-0.45) * tip_length, color, 1.0)


func _on_missile_launched(missile: Node2D) -> void:
	missile.z_index = 2
	var visuals := missile.get_node("Visuals") as Visuals
	visuals.show_traces = show_traces
	_effects.append(weakref(visuals))
	missile.impacted.connect(_on_impacted)


func _on_impacted(_point: Vector2, _tint: Color) -> void:
	_flash = 0.14


func _draw_launcher(point: Vector2) -> void:
	for row in range(7):
		var half_width := floorf(float(row) * 0.6)
		draw_rect(Rect2(point + Vector2(-half_width, row - 3), Vector2(half_width * 2 + 1, 1)), Color("637288"))
	draw_rect(Rect2(point + Vector2(0, -2), Vector2(1, 6)), Color("dae4e5"))


func _draw_target() -> void:
	var center := target.position.round()
	var flash := _flash / 0.14
	var tint := TINT.lerp(Color.WHITE, flash)
	for offset in [Vector2(-10, -5), Vector2(8, -5), Vector2(-10, 4), Vector2(8, 4)]:
		draw_rect(Rect2(center + offset, Vector2(3, 1)), tint.darkened(0.3))
	draw_rect(Rect2(center - Vector2(3, 3), Vector2(7, 7)), tint.darkened(0.6))
	draw_rect(Rect2(center - Vector2(1, 2), Vector2(3, 5)), tint)
	draw_rect(Rect2(center, Vector2.ONE), Color("fff5e4"))
