extends Node2D

signal missile_launched(missile: Node2D)

const Missile = preload("res://experiments/missiles/missile.gd")

@export_group("Firing")
@export var missile_scene: PackedScene
@export var auto_fire: bool = true
@export var wait_for_clear: bool = false
@export_range(1, 9, 1) var volley_size: int = 5
@export_range(0.0, 80.0, 1.0, "suffix:°") var spread: float = 60.0
@export_range(0.4, 6.0, 0.1, "suffix:s") var volley_interval: float = 1.9
@export_range(0.01, 0.5, 0.01, "suffix:s") var shot_interval: float = 0.09

@export_group("Flight")
@export_range(5.0, 100.0, 1.0, "suffix:px/s") var launch_speed: float = 80.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var tracking_delay: float = 0.6
@export_range(0.0, 1.5, 0.05, "suffix:s") var speed_ramp_time: float = 0.45

var target: Node2D
var random: RandomNumberGenerator = RandomNumberGenerator.new()

var _controlled_flights: Array[Dictionary] = []
var _cooldown: float = 0.35
var _pending_shots: Array[Dictionary] = []
var _missiles: Array[Node2D] = []
var _next_shot_id: int = 0


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	var can_fire := not wait_for_clear or (_missiles.is_empty() and _pending_shots.is_empty())
	if auto_fire and can_fire and _cooldown <= 0.0:
		fire()

	for index in range(_pending_shots.size() - 1, -1, -1):
		_pending_shots[index].delay -= delta
		if _pending_shots[index].delay <= 0.0:
			_launch_shot(_pending_shots[index])
			_pending_shots.remove_at(index)

	_update_flights(delta)


func fire() -> void:
	_cooldown = volley_interval
	for index in range(volley_size):
		_pending_shots.append(_make_profile(index))
		_next_shot_id += 1


func reset() -> void:
	for missile in _missiles.duplicate():
		missile.queue_free()
	_controlled_flights.clear()
	_pending_shots.clear()
	_cooldown = 0.35
	_next_shot_id = 0


func _launch_shot(profile: Dictionary) -> void:
	var missile := missile_scene.instantiate() as Node2D
	missile.set_meta("shot_id", profile.shot_id)
	_missiles.append(missile)
	missile.tree_exited.connect(func() -> void: _missiles.erase(missile))
	missile_launched.emit(missile)
	get_parent().add_child(missile)

	var direction := (transform * Vector2.DOWN.rotated(profile.heading) - position).normalized()
	_start_missile(missile, profile, direction)


func _make_profile(index: int) -> Dictionary:
	return {
		"shot_id": _next_shot_id, "delay": index * shot_interval,
		"heading": deg_to_rad(random.randf_range(-spread, spread)),
		"seed": random.randf_range(0.0, TAU),
	}


func _start_missile(missile: Node2D, profile: Dictionary, direction: Vector2) -> void:
	missile.launch(position, direction, target, profile.seed, launch_speed)
	_controlled_flights.append({"missile": weakref(missile), "elapsed": 0.0, "homing": false})


func _update_flights(delta: float) -> void:
	for index in range(_controlled_flights.size() - 1, -1, -1):
		var flight: Dictionary = _controlled_flights[index]
		var missile := flight.missile.get_ref() as Missile
		if missile == null or missile.is_queued_for_deletion():
			_controlled_flights.remove_at(index)
			continue

		var elapsed: float = flight.elapsed
		if elapsed >= tracking_delay or is_equal_approx(elapsed, tracking_delay):
			if not flight.homing:
				missile.start_homing(target)
				flight.homing = true
			var progress := 1.0
			if speed_ramp_time > 0.0:
				progress = clampf((elapsed + delta - tracking_delay) / speed_ramp_time, 0.0, 1.0)
			var ramp := progress * progress * (3.0 - 2.0 * progress)
			missile.desired_speed = lerpf(minf(launch_speed, missile.speed), missile.speed, ramp)
			if progress >= 1.0:
				_controlled_flights.remove_at(index)
		else:
			missile.desired_speed = minf(launch_speed, missile.speed)
		flight.elapsed += delta


