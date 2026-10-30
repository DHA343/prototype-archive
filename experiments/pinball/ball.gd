@tool
extends "res://experiments/ball/ball.gd"

signal reset

const Bumper = preload("res://experiments/pinball/bumper.gd")
const Flipper = preload("res://experiments/pinball/flipper.gd")

@export_group("Flipper")
@export_range(400.0, 700.0, 10.0, "suffix:px/s") var strike_speed: float = 550.0

var _spawn: Vector2 = Vector2.ZERO
var _reset_requested: bool = true


func _ready() -> void:
	_spawn = position
	# フリッパーと同じ刻みでTableから進めるため、自動更新は止める。
	set_physics_process(false)


func step(delta: float) -> void:
	if _reset_requested or position.y > 356.0:
		position = _spawn
		velocity = Vector2(20, 0)
		_reset_requested = false
		queue_redraw()
		reset.emit()
		return
	super.step(delta)


func reset_ball() -> void:
	_reset_requested = true


func get_shot_velocity(flipper: Flipper, point: Vector2, angle_at_contact: float) -> Vector2:
	var speed := strike_speed * flipper.get_shot_strength_at(point, angle_at_contact)
	return flipper.get_shot_direction_at(point, angle_at_contact) * clampf(speed, 0.0, max_speed)


func _respond(collision: KinematicCollision2D) -> void:
	var normal := collision.get_normal()
	var body := collision.get_collider() as Node
	var flipper := body as Flipper
	var bumper := body as Bumper
	var surface_velocity := Vector2.ZERO
	var bounce := restitution
	if flipper != null:
		# 打球済みの同じスイングで、回転面から重ねて加速されないようにする。
		if flipper.is_striking():
			surface_velocity = flipper.get_surface_velocity(collision.get_position())
		bounce = 0.08
	var relative_velocity := velocity - surface_velocity
	var incoming_speed := -relative_velocity.dot(normal)
	if incoming_speed <= 0.0:
		return

	var outgoing := relative_velocity + normal * incoming_speed * (1.0 + bounce)
	if bumper != null and incoming_speed > 15.0:
		# 反発へ一定の加速を足し続けず、法線方向の最低離脱速度だけを保証する。
		outgoing += normal * maxf(0.0, bumper.kick_speed - outgoing.dot(normal))
	velocity = (outgoing + surface_velocity).limit_length(max_speed)
	if flipper != null and flipper.is_striking() and incoming_speed > 15.0:
		# 打球方向は振り上げ中の面の角度から切り離し、当たった位置で決める。
		velocity = get_shot_velocity(flipper, collision.get_position(), flipper.rotation)
		flipper.consume_strike()
	if incoming_speed > 15.0:
		collided.emit(body)
