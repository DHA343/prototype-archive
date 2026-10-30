@tool
extends Path2D
## Curve2Dの標準編集ハンドルと、表示・衝突で共有する輪郭。

const EditorAid = preload("res://experiments/pinball/editor_aid.gd")
const Styles = preload("res://experiments/pinball/styles.gd")

@export_node_path("Path2D") var mirror_path: NodePath
@export_group("Editor")
@export_tool_button("位置をグリッドに揃える") var snap_position: Callable = _snap_position
@export_tool_button("制御点をグリッドに揃える") var snap_points: Callable = _snap_points
@export_tool_button("対称側へ反映 / 作成") var mirror_part: Callable = _mirror_part

var points: PackedVector2Array = PackedVector2Array()
var _body: StaticBody2D
var _watched_curve: Curve2D


func _ready() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 2
	add_child(_body, false, Node.INTERNAL_MODE_BACK)
	_watch_curve()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	_watch_curve()


func _draw() -> void:
	if points.size() < 2:
		return
	var tint: Color = Styles.MONOCHROME.wall
	draw_polyline(points, tint, 8, true)
	draw_circle(points[0], 4, tint, true, -1, true)
	draw_circle(points[-1], 4, tint, true, -1, true)


func editor_values() -> Dictionary:
	return {"curve": curve}


func _watch_curve() -> void:
	if curve == _watched_curve:
		return
	if _watched_curve != null:
		_watched_curve.changed.disconnect(rebuild)
	_watched_curve = curve
	if curve != null:
		curve.changed.connect(rebuild)
	rebuild()


func rebuild() -> void:
	points.clear()
	if curve != null:
		for segment in range(curve.point_count - 1):
			var start := curve.get_point_position(segment)
			var end := curve.get_point_position(segment + 1)
			var first := start + curve.get_point_out(segment)
			var second := end + curve.get_point_in(segment + 1)
			if segment == 0:
				points.append(start)
			var count := 1 if first == start and second == end else 32
			for index in range(1, count + 1):
				points.append(start.bezier_interpolate(first, second, end, float(index) / count))
	if is_instance_valid(_body):
		for child in _body.get_children():
			_body.remove_child(child)
			child.queue_free()
		for index in range(points.size() - 1):
			var start := points[index]
			var end := points[index + 1]
			var shape := CapsuleShape2D.new()
			shape.radius = 4
			shape.height = start.distance_to(end) + 8
			var collision := CollisionShape2D.new()
			collision.shape = shape
			collision.position = (start + end) * 0.5
			collision.rotation = (end - start).angle() + PI * 0.5
			_body.add_child(collision)
	queue_redraw()


func _snap_position() -> void:
	EditorAid.snap_position(self)


func _snap_points() -> void:
	EditorAid.snap_curve(self)


func _mirror_part() -> void:
	EditorAid.mirror(self)
