@tool
extends StaticBody2D

const PULSE_ATTACK: float = 0.012
const PULSE_DURATION: float = 0.11
const EditorAid = preload("res://experiments/pinball/editor_aid.gd")
const Styles = preload("res://experiments/pinball/styles.gd")

@export_range(50.0, 700.0, 10.0, "suffix:px/s") var kick_speed: float = 480.0
@export_range(14.0, 32.0, 1.0, "suffix:px") var radius: float = 24.0:
	set(value):
		radius = value
		if is_node_ready():
			(_collision.shape as CircleShape2D).radius = radius
		queue_redraw()
@export var tint: Color = Styles.MONOCHROME.bumper:
	set(value):
		tint = value
		queue_redraw()
@export_group("Editor")
@export_node_path("StaticBody2D") var mirror_path: NodePath
@export_tool_button("位置をグリッドに揃える") var snap_position: Callable = _snap_position
@export_tool_button("対称側へ反映 / 作成") var mirror_part: Callable = _mirror_part

var flash: float = 0.0
var pulse: float = 0.0
var _hit_elapsed: float = PULSE_DURATION

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	(_collision.shape as CircleShape2D).radius = radius
	set_physics_process(not Engine.is_editor_hint())
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius * (1.0 + pulse * 0.12),
		tint.lightened(flash * 0.16), true, -1, true)


func editor_values() -> Dictionary:
	return {"radius": radius, "kick_speed": kick_speed, "tint": tint}


func _snap_position() -> void:
	EditorAid.snap_position(self)


func _mirror_part() -> void:
	EditorAid.mirror(self)


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 12.0)
	_hit_elapsed = minf(PULSE_DURATION, _hit_elapsed + delta)
	if _hit_elapsed < PULSE_ATTACK:
		pulse = 1.0 - pow(1.0 - _hit_elapsed / PULSE_ATTACK, 2.0)
	else:
		var release := (PULSE_DURATION - _hit_elapsed) / (PULSE_DURATION - PULSE_ATTACK)
		pulse = maxf(0.0, release) * maxf(0.0, release)
	queue_redraw()


func hit() -> void:
	flash = 1.0
	_hit_elapsed = 0.0
