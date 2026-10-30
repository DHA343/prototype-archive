@tool
extends StaticBody2D

const STRIKE_WINDOW: float = 0.10
const EditorAid = preload("res://experiments/pinball/editor_aid.gd")
const Styles = preload("res://experiments/pinball/styles.gd")

@export var right_side: bool = false:
	set(value):
		right_side = value
		_refresh()
@export_range(40.0, 160.0, 1.0, "suffix:px") var length: float = 90.0:
	set(value):
		length = value
		_refresh()
@export_range(-45.0, 65.0, 1.0, "suffix:°") var rest_angle: float = 20.0:
	set(value):
		rest_angle = value
		_refresh()
@export_range(-60.0, 30.0, 1.0, "suffix:°") var raised_angle: float = 0.0:
	set(value):
		raised_angle = value
		queue_redraw()
@export_range(4.0, 12.0, 0.5, "suffix:rad/s") var rise_speed: float = 10.0
@export_range(2.0, 10.0, 0.5, "suffix:rad/s") var return_speed: float = 7.0
@export_group("Shot angles", "shot_angle_")
@export_range(-80.0, 80.0, 1.0, "suffix:°") var shot_angle_root: float = -16.0:
	set(value):
		shot_angle_root = value
		queue_redraw()
@export_range(-80.0, 80.0, 1.0, "suffix:°") var shot_angle_middle: float = 16.0:
	set(value):
		shot_angle_middle = value
		queue_redraw()
@export_range(-80.0, 80.0, 1.0, "suffix:°") var shot_angle_tip: float = 48.0:
	set(value):
		shot_angle_tip = value
		queue_redraw()
@export_group("Shot strengths", "shot_strength_")
@export_range(0.1, 1.5, 0.05) var shot_strength_root: float = 1.0:
	set(value):
		shot_strength_root = value
		queue_redraw()
@export_range(0.1, 1.5, 0.05) var shot_strength_middle: float = 1.0:
	set(value):
		shot_strength_middle = value
		queue_redraw()
@export_range(0.1, 1.5, 0.05) var shot_strength_tip: float = 1.0:
	set(value):
		shot_strength_tip = value
		queue_redraw()
@export_group("Editor")
@export_node_path("StaticBody2D") var mirror_path: NodePath
@export_tool_button("位置をグリッドに揃える") var snap_position: Callable = _snap_position
@export_tool_button("対称側へ反映 / 作成") var mirror_part: Callable = _mirror_part

var shot_angles: Vector3:
	get:
		return Vector3(shot_angle_root, shot_angle_middle, shot_angle_tip)
	set(value):
		shot_angle_root = value.x
		shot_angle_middle = value.y
		shot_angle_tip = value.z
var shot_strengths: Vector3:
	get:
		return Vector3(shot_strength_root, shot_strength_middle, shot_strength_tip)
	set(value):
		shot_strength_root = value.x
		shot_strength_middle = value.y
		shot_strength_tip = value.z

var pressed: bool = false
var outline: PackedVector2Array = PackedVector2Array()
var _angular_velocity: float = 0.0
var _strike_left: float = 0.0
var _was_pressed: bool = false
var _updating: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		set_notify_local_transform(true)
		EditorInterface.get_selection().selection_changed.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and Engine.is_editor_hint() \
		and is_node_ready() and not _updating:
		var angle := wrapf(PI - rotation if right_side else rotation, -PI, PI)
		if not is_equal_approx(angle, deg_to_rad(rest_angle)):
			rest_angle = clampf(rad_to_deg(angle), -45, 65)
		queue_redraw()


func _draw() -> void:
	if outline.is_empty():
		return
	var tint: Color = Styles.MONOCHROME.flipper
	draw_colored_polygon(outline, tint.lightened(0.12 if pressed else 0.0))
	if not Engine.is_editor_hint() or not EditorInterface.get_selection().get_selected_nodes().has(self):
		return
	for index in range(3):
		var start := Vector2(length * index * 0.5, 0)
		var point := to_global(start)
		var direction := get_shot_direction(point).rotated(-global_rotation)
		var end := start + direction * (24 + shot_strengths[index] * 28)
		draw_line(start, end, Color("d9dce3"), 0.8, true)
		draw_polyline(PackedVector2Array([
			end - direction.rotated(0.5) * 5, end, end - direction.rotated(-0.5) * 5,
		]), Color("d9dce3"), 0.8, true)
	var raised_tip := Vector2.from_angle(_angle(true) - rotation) * length
	draw_dashed_line(Vector2.ZERO, raised_tip, Color(1, 1, 1, 0.3), 0.8, 4)


func editor_values() -> Dictionary:
	return {"right_side": right_side, "length": length, "rest_angle": rest_angle,
		"raised_angle": raised_angle, "rise_speed": rise_speed, "return_speed": return_speed,
		"shot_angle_root": shot_angle_root, "shot_angle_middle": shot_angle_middle,
		"shot_angle_tip": shot_angle_tip, "shot_strength_root": shot_strength_root,
		"shot_strength_middle": shot_strength_middle, "shot_strength_tip": shot_strength_tip}


func _refresh() -> void:
	if is_node_ready():
		rebuild()


func _snap_position() -> void:
	EditorAid.snap_position(self)


func _mirror_part() -> void:
	EditorAid.mirror(self)


func rebuild() -> void:
	_updating = true
	# 長さを変えても両端の丸みは引き伸ばさず、接線でつなぐ。
	var root_radius := 7.0313
	var tip_radius := 2.8125
	var center := length - tip_radius
	var tangent := acos((root_radius - tip_radius) / center)
	outline.clear()
	outline.append(Vector2.from_angle(-tangent) * root_radius)
	for index in range(13):
		outline.append(Vector2(center, 0) + Vector2.from_angle(
			lerpf(-tangent, tangent, index / 12.0)) * tip_radius)
	for index in range(24):
		outline.append(Vector2.from_angle(lerpf(tangent, TAU - tangent, index / 24.0)) * root_radius)
	(_collision.shape as ConvexPolygonShape2D).points = outline
	pressed = false
	_was_pressed = false
	_strike_left = 0.0
	_angular_velocity = 0.0
	rotation = _angle(false)
	force_update_transform()
	_updating = false
	queue_redraw()


func step(delta: float) -> void:
	if pressed and not _was_pressed:
		_strike_left = STRIKE_WINDOW
	_was_pressed = pressed
	_strike_left = maxf(0.0, _strike_left - delta) if pressed else 0.0
	var speed := rise_speed if pressed else return_speed
	var previous := rotation
	rotation = rotate_toward(rotation, _angle(pressed), speed * delta)
	force_update_transform()
	_angular_velocity = angle_difference(previous, rotation) / delta
	queue_redraw()


func get_surface_velocity(point: Vector2) -> Vector2:
	var offset := point - global_position
	return Vector2(-offset.y, offset.x) * _angular_velocity


func is_striking() -> bool:
	return pressed and _strike_left > 0.0


func consume_strike() -> void:
	_strike_left = 0.0


func predict_angle(seconds: float) -> float:
	return rotate_toward(rotation, _angle(true), rise_speed * seconds)


func get_shot_direction(point: Vector2) -> Vector2:
	return get_shot_direction_at(point, rotation)


func get_shot_direction_at(point: Vector2, angle_at_contact: float) -> Vector2:
	var progress := get_progress(point, angle_at_contact)
	# 外側の根元から中央の先端へ滑るほど、打球も中央へ向く。
	var angle := deg_to_rad(_sample(shot_angles, progress))
	return Vector2(sin(angle) * (-1.0 if right_side else 1.0), -cos(angle))


func get_shot_strength_at(point: Vector2, angle_at_contact: float) -> float:
	return _sample(shot_strengths, get_progress(point, angle_at_contact))


func get_progress(point: Vector2, angle_at_contact: float) -> float:
	var offset := (point - global_position).rotated(-angle_at_contact)
	return clampf(offset.x / length, 0.0, 1.0)


func _sample(values: Vector3, progress: float) -> float:
	return lerpf(values.x, values.y, progress * 2.0) if progress <= 0.5 \
		else lerpf(values.y, values.z, (progress - 0.5) * 2.0)


func _angle(raised: bool) -> float:
	var angle := deg_to_rad(raised_angle if raised else rest_angle)
	return PI - angle if right_side else angle
