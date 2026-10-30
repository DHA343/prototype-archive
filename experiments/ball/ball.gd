@tool
extends CharacterBody2D
## 描画と重力・反射を持つ、盤面に依存しないボール。

signal collided(body: Node)

const CONTACT_LIMIT: int = 8
const MAX_STEP: float = 1.0 / 240.0

@export_group("Appearance")
@export var color: Color = Color("fff2da"):
	set(value):
		color = value
		queue_redraw()
@export_range(0.0, 32.0, 0.1) var intensity: float = 1.0:
	set(value):
		intensity = value
		queue_redraw()
@export_group("Motion")
@export_range(0.0, 1600.0, 10.0, "suffix:px/s²") var gravity: float = 1100.0
@export_range(0.0, 1.0, 0.01) var restitution: float = 0.3
@export_range(300.0, 1000.0, 10.0, "suffix:px/s") var max_speed: float = 840.0

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var steps := maxi(1, ceili(delta / MAX_STEP))
	for index in range(steps):
		step(delta / float(steps))


func _draw() -> void:
	var center := position.round() - position
	var radius := get_radius()
	var tint := get_color()
	draw_circle(center, radius, tint.darkened(0.18))
	draw_circle(center - Vector2.ONE, radius - 1.0, tint)


func step(delta: float) -> void:
	queue_redraw()
	velocity = (velocity + Vector2.DOWN * gravity * delta).limit_length(max_speed)
	var remaining := delta
	for index in range(CONTACT_LIMIT):
		var motion := velocity * remaining
		var collision := move_and_collide(motion, false, 0.02, true)
		if collision == null:
			return
		var travel_fraction := 0.0
		if not motion.is_zero_approx():
			travel_fraction = clampf(collision.get_travel().dot(motion) / motion.length_squared(), 0.0, 1.0)
		remaining *= 1.0 - travel_fraction
		_respond(collision)
		if remaining < 0.000001:
			return
	# 多重接触を解消できない場合は、残りの移動を破棄してすり抜けを避ける。


func get_radius() -> float:
	return (_collision.shape as CircleShape2D).radius


func get_color() -> Color:
	var lit := color.srgb_to_linear()
	lit.r *= intensity
	lit.g *= intensity
	lit.b *= intensity
	return lit.linear_to_srgb()


func _respond(collision: KinematicCollision2D) -> void:
	var normal := collision.get_normal()
	var incoming_speed := -velocity.dot(normal)
	if incoming_speed <= 0.0:
		return
	velocity = (velocity + normal * incoming_speed * (1.0 + restitution)).limit_length(max_speed)
	if incoming_speed > 15.0:
		collided.emit(collision.get_collider() as Node)
