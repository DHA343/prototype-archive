@tool
extends Node2D

const Ball = preload("res://experiments/pinball/ball.gd")
const Bumper = preload("res://experiments/pinball/bumper.gd")
const Flipper = preload("res://experiments/pinball/flipper.gd")
const Missile = preload("res://experiments/missiles/missile.gd")
const Styles = preload("res://experiments/pinball/styles.gd")
const Aim = preload("res://experiments/pinball/aim.gd")
const EditorAid = preload("res://experiments/pinball/editor_aid.gd")
const MISSILE_SCENE: PackedScene = preload("res://experiments/missiles/missile.tscn")
const ACCENT: Color = Color("a78bca")
const MISSILE_COLOR: Color = Color("a78bca")
const MAX_STEP: float = 1.0 / 240.0

@export var show_shot_guide: bool = true
@export_group("Editor")
@export_enum("4 px:4", "8 px:8", "16 px:16") var grid_size: int = 8
@export_tool_button("直線の壁を追加") var add_wall: Callable = _editor_add_wall
@export_tool_button("曲線の壁を追加") var add_curve: Callable = _editor_add_curve
@export_tool_button("バンパーを追加") var add_bumper: Callable = _editor_add_bumper

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _missile_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _trail: Array[Vector2] = []
var _particles: Array[Dictionary] = []
var _flippers_pressed: bool = false
var _target_flash: float = 0.0
var _style: Dictionary = Styles.MONOCHROME
var _floor_shape: PackedVector2Array = PackedVector2Array()
var _floor_checks: Array[PackedVector2Array] = []
var _aim: Dictionary = {}

@onready var _ball: Ball = $Ball
@onready var _left_flipper: Flipper = $LeftFlipper
@onready var _right_flipper: Flipper = $RightFlipper
@onready var _bumpers: Node2D = $Bumpers
@onready var _target: Node2D = $Target
@onready var _missiles: Node2D = $Missiles


func _ready() -> void:
	_build_floor()
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process_input(false)
		queue_redraw()
		return
	set_process(false)
	_random.seed = 20261029
	_missile_random.seed = 20261030
	_ball.collided.connect(_on_ball_collided)
	_ball.reset.connect(_on_ball_reset)
	get_window().focus_exited.connect(_on_focus_exited)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func editor_grid_size() -> int:
	return grid_size


func _editor_add_wall() -> void:
	EditorAid.add_part(self, "line")


func _editor_add_curve() -> void:
	EditorAid.add_part(self, "curve")


func _editor_add_bumper() -> void:
	EditorAid.add_part(self, "bumper")


func _physics_process(delta: float) -> void:
	_target_flash = maxf(0.0, _target_flash - delta * 4.0)
	_left_flipper.pressed = _flippers_pressed
	_right_flipper.pressed = _flippers_pressed
	# 回転する先端も球の半径より細かく動かし、移動後の重なりも判定する。
	var steps := maxi(1, ceili(delta / MAX_STEP))
	var step_delta := delta / float(steps)
	for index in range(steps):
		_left_flipper.step(step_delta)
		_right_flipper.step(step_delta)
		_ball.step(step_delta)
	_aim = Aim.predict(_ball, [_left_flipper, _right_flipper]) if show_shot_guide else {}
	_trail.append(_ball.position)
	if _trail.size() > 12:
		_trail.pop_front()
	for index in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		particle.life -= delta
		if particle.life <= 0.0:
			_particles.remove_at(index)
			continue
		particle.velocity *= exp(-3.0 * delta)
		particle.velocity += Vector2.DOWN * 40.0 * delta
		particle.point += particle.velocity * delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if key.keycode == KEY_SPACE:
		_flippers_pressed = key.pressed
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_R and key.pressed:
		_ball.reset_ball()


func _draw() -> void:
	if not is_node_ready():
		return
	draw_rect(Rect2(0, 0, 640, 360), _style.outside)
	draw_colored_polygon(_floor_shape, _style.floor)
	for tile in _floor_checks:
		draw_colored_polygon(tile, _style.checker)
	_draw_aim()
	var ball_point := _ball.position.round()
	var ball_radius := _ball.get_radius()
	# 球の影は盤面に落とし、フリッパーの上面へ重ねない。
	_draw_ellipse(ball_point + Vector2(2, 4), Vector2(ball_radius + 1.0, 4.0), Color(0, 0, 0, 0.35))
	_draw_target()
	for index in range(_trail.size()):
		var alpha := float(index + 1) / float(_trail.size())
		draw_rect(Rect2(_trail[index].round(), Vector2.ONE),
			Color(_ball.get_color(), alpha * 0.25))
	for particle in _particles:
		var tint: Color = particle.tint
		var life: float = particle.life / particle.duration
		tint = tint.lerp(Color("f1f0ea"), maxf(0.0, life - 0.6) * 2.5)
		tint.a = minf(1.0, life * 3.0)
		var point: Vector2 = particle.point
		draw_rect(Rect2(point.round(), Vector2.ONE), tint)


func _on_ball_collided(body: Node) -> void:
	var bumper := body as Bumper
	var tint := _ball.get_color()
	if bumper != null:
		bumper.hit()
		tint = bumper.tint
		_launch_missile.call_deferred(bumper.position)
	elif _ball.velocity.length() < 70.0:
		return
	var count := 24 if bumper != null else 6
	for index in range(count):
		var duration := _random.randf_range(0.12, 0.35)
		_particles.append({
			"point": _ball.position,
			"velocity": Vector2.from_angle(_random.randf_range(0.0, TAU))
				* _random.randf_range(20.0, 110.0),
			"tint": tint, "life": duration, "duration": duration,
		})


func _on_ball_reset() -> void:
	_trail.clear()
	_particles.clear()
	_aim = {}


func _on_focus_exited() -> void:
	_flippers_pressed = false


func _on_missile_impacted(_point: Vector2, _tint: Color) -> void:
	_target_flash = 1.0


func _launch_missile(origin: Vector2) -> void:
	var missile := MISSILE_SCENE.instantiate() as Missile
	missile.tint = MISSILE_COLOR
	missile.impacted.connect(_on_missile_impacted)
	_missiles.add_child(missile)
	var direction := Vector2.UP.rotated(_missile_random.randf_range(-0.4, 0.4))
	missile.launch(origin, direction, _target, _missile_random.randf_range(0.0, TAU), 80.0)
	missile.start_homing(_target)
	missile.desired_speed = missile.speed


func _draw_target() -> void:
	var point := _target.position.round()
	var tint := ACCENT.lightened(_target_flash * 0.3)
	var shape := PackedVector2Array([
		point + Vector2(0, -7), point + Vector2(7, 0),
		point + Vector2(0, 7), point + Vector2(-7, 0), point + Vector2(0, -7),
	])
	draw_colored_polygon(shape, tint)


func _draw_ellipse(center: Vector2, size: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in range(48):
		points.append(center + Vector2.from_angle(TAU * index / 48.0) * size)
	draw_colored_polygon(points, tint)


func _draw_aim() -> void:
	if _aim.is_empty():
		return
	var line := PackedVector2Array()
	var draw_offset := _ball.position.round() - _ball.position
	for point: Vector2 in _aim.points:
		line.append(to_local(point) + draw_offset)
	if line.size() < 2:
		return
	draw_polyline(line, Color(Color("f1f0ea"), 0.8), 1.5, true)
	var end := line[-1]
	var direction := (end - line[-2]).normalized()
	draw_polyline(PackedVector2Array([
		end - direction.rotated(0.55) * 7.0, end, end - direction.rotated(-0.55) * 7.0,
	]), Color(Color("f1f0ea"), 0.8), 1.5, true)


func _curve(start: Vector2, first: Vector2, second: Vector2, end: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(33):
		points.append(start.bezier_interpolate(first, second, end, index / 32.0))
	return points


func _build_floor() -> void:
	# 床は配置部品と分離し、天井の削除や壁の追加でも輪郭を壊さない。
	_floor_shape = _curve(Vector2(32, 30), Vector2(224, -1), Vector2(416, -1), Vector2(608, 30))
	_floor_shape.append(Vector2(608, 360))
	_floor_shape.append(Vector2(32, 360))
	for row in range(15):
		for column in range(24):
			if (row + column) % 2 == 0:
				continue
			var corner := Vector2(32 + column * 24, row * 24)
			var cell := PackedVector2Array([
				corner, corner + Vector2(24, 0), corner + Vector2(24, 24), corner + Vector2(0, 24),
			])
			for tile: PackedVector2Array in Geometry2D.intersect_polygons(_floor_shape, cell):
				_floor_checks.append(tile)
