@tool
extends Node2D
## 加速度制限と切り替え可能な断続的操舵誤差を伴う、エルミート曲線による追尾。

signal impacted(point: Vector2, tint: Color)
signal exhausted(point: Vector2, velocity: Vector2, tint: Color)

enum ApproachFrame {
	WORLD,
	TARGET_RELATIVE,
}

enum ErrorPhase {
	RISE,
	HOLD,
	FALL,
	REST,
}

const CURVE_STEPS: int = 256

@export_group("Flight")
@export_range(70.0, 260.0, 1.0, "suffix:px/s") var speed: float = 230.0
@export_range(5.0, 100.0, 1.0, "suffix:px/s") var launch_speed: float = 80.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var ignition_delay: float = 0.6
@export_range(0.2, 1.5, 0.05, "suffix:s") var acceleration_time: float = 0.45
@export_range(0.1, 20.0, 0.1, "suffix:s") var lifetime: float = 5.0
@export_range(1.0, 20.0, 0.5, "suffix:px") var hit_radius: float = 6.0
@export_group("Approach", "approach_")
@export var approach_frame: ApproachFrame = ApproachFrame.TARGET_RELATIVE
@export_range(-180.0, 180.0, 1.0, "suffix:°") var approach_angle: float = 0.0
@export_range(0.0, 180.0, 1.0, "suffix:°") var approach_spread: float = 60.0
@export_range(1.0, 120.0, 1.0, "suffix:px") var approach_departure_length: float = 40.0
@export_range(0.0, 6.0, 0.1) var approach_arrival_scale: float = 1.5
@export_range(1.0, 120.0, 1.0, "suffix:px") var approach_lookahead: float = 32.0
@export_group("Acceleration", "acceleration_")
@export_range(100.0, 6000.0, 100.0, "suffix:px/s²") var acceleration_limit: float = 1800.0
@export_range(0.02, 1.0, 0.01, "suffix:s") var acceleration_response_time: float = 0.08
@export_group("Instability", "error_")
@export var error_enabled: bool = true:
	set(value):
		error_enabled = value
		notify_property_list_changed()
## 誤差イベントごとに、この範囲内から符号付きの最大操舵角を一様抽選する。
@export_range(0.0, 90.0, 1.0, "suffix:°") var error_angle: float = 45.0
@export_range(0.0, 0.5, 0.01, "suffix:s") var error_rise_time: float = 0.04
## 立ち上がりが終わってから、最大誤差を保持する時間。
@export_range(0.0, 0.8, 0.01, "suffix:s") var error_hold_min: float = 0.02
@export_range(0.0, 0.8, 0.01, "suffix:s") var error_hold_max: float = 0.12
@export_range(0.0, 0.5, 0.01, "suffix:s") var error_fall_time: float = 0.08
@export_range(0.0, 1.0, 0.01, "suffix:s") var error_rest_min: float = 0.03
@export_range(0.0, 1.0, 0.01, "suffix:s") var error_rest_max: float = 0.20
## 個々の誤差イベントとは独立して、追尾開始から誤差全体の影響を線形に立ち上げる。
@export_range(0.0, 0.6, 0.01, "suffix:s") var error_fade_in: float = 0.15
## この距離から命中半径までの間で、誤差の影響を線形に0へ近づける。
@export_range(8.0, 120.0, 1.0, "suffix:px") var error_capture_distance: float = 45.0
@export_group("Appearance")
@export var tint: Color = Color("e99cff")

var _target: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _forward_speed: float = 0.0
var _launch_direction: Vector2 = Vector2.DOWN
var _arrival_direction: Vector2 = Vector2.UP
var _relative_arrival_angle: float = 0.0
var _target_direction: Vector2 = Vector2.UP
var _age: float = 0.0
var _emission_distance: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO
var _start_tangent: Vector2 = Vector2.ZERO
var _end_tangent: Vector2 = Vector2.ZERO
var _guide_position: Vector2 = Vector2.ZERO
var _path: PackedVector2Array = PackedVector2Array()
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _error_phase: ErrorPhase = ErrorPhase.REST
var _phase_elapsed: float = 0.0
var _phase_duration: float = 0.0
var _peak_error: float = 0.0
var _error_angle: float = 0.0
var _applied_error: float = 0.0
var _desired_direction: Vector2 = Vector2.ZERO

@onready var _visuals: Node2D = $Visuals


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(_target):
		_finish_flight(false)
		return
	var previous := position
	var launch_delta := minf(delta, maxf(ignition_delay - _age, 0.0))
	if launch_delta > 0.0:
		position += _launch_direction * minf(launch_speed, speed) * launch_delta
		_velocity = _launch_direction * minf(launch_speed, speed)
		_age += launch_delta
	var guidance_delta := delta - launch_delta
	if guidance_delta > 0.0:
		_forward_speed = _speed_at_age(_age + guidance_delta)
		_plan_guidance()
		if error_enabled:
			_advance_error(guidance_delta)
		var angle := _error_angle * _error_envelope(_age + guidance_delta) if error_enabled else 0.0
		var direction := (_guide_position - position).normalized().rotated(angle)
		_applied_error = angle
		_desired_direction = direction
		var response := 1.0 - exp(-guidance_delta / acceleration_response_time)
		var change := (direction * _forward_speed - _velocity) * response
		var before := _velocity
		_velocity += change.limit_length(acceleration_limit * guidance_delta)
		_velocity = _velocity.limit_length(_forward_speed)
		position += (before + _velocity) * (0.5 * guidance_delta)
		_age += guidance_delta
	_emit_exhaust(previous)
	var target_position := _target_position()
	var closest := Geometry2D.get_closest_point_to_segment(target_position, previous, position)
	if closest.distance_squared_to(target_position) <= hit_radius * hit_radius:
		_finish_flight(true)
	elif _age > lifetime:
		_finish_flight(false)
	queue_redraw()


func _validate_property(property: Dictionary) -> void:
	var property_name: String = property.name
	if property_name.begins_with("error_") and property_name != "error_enabled" and not error_enabled:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func launch(
	origin: Vector2, direction: Vector2, target: Node2D, seed_value: float,
	arrival_direction: Vector2 = Vector2.UP, relative_arrival_angle: float = 0.0,
) -> void:
	position = origin
	_target = target
	_launch_direction = direction.normalized()
	_velocity = _launch_direction * minf(launch_speed, speed)
	_forward_speed = minf(launch_speed, speed)
	_arrival_direction = arrival_direction.normalized()
	_relative_arrival_angle = relative_arrival_angle
	_target_direction = _launch_direction
	_age = 0.0
	_emission_distance = 0.0
	_random.seed = int(seed_value * 1000000.0) + 173
	_error_phase = ErrorPhase.REST
	_phase_elapsed = 0.0
	_phase_duration = _random_range(error_rest_min, error_rest_max)
	_peak_error = 0.0
	_error_angle = 0.0
	_applied_error = 0.0
	_desired_direction = Vector2.ZERO
	_path.clear()
	if is_instance_valid(_visuals):
		_visuals.follow(self, get_velocity, seed_value, tint)


func get_velocity() -> Vector2:
	return _velocity


func get_guidance_snapshot() -> Dictionary:
	if _path.is_empty():
		return {}
	return {
		"curved": is_curved_guidance(),
		"path": _path.duplicate(), "start": _start, "end": _end,
		"start_tangent": _start_tangent, "end_tangent": _end_tangent,
		"guide": _guide_position, "direction": _desired_direction,
		"error": _applied_error,
		"phase": ErrorPhase.keys()[_error_phase] if error_enabled else "OFF",
	}


func is_curved_guidance() -> bool:
	return true


func refresh_guidance() -> void:
	# 停止中の表示更新では狙い点を再計算するが、方向未確定時の代替状態は変更しない。
	if _path.is_empty():
		return
	var saved_direction := _target_direction
	_plan_guidance()
	_target_direction = saved_direction
	_applied_error = _error_angle * _error_envelope(_age) if error_enabled else 0.0
	_desired_direction = (_guide_position - _start).normalized().rotated(_applied_error)


func _plan_guidance() -> void:
	_start = position
	_end = _target_position()
	var direction := _velocity.normalized() if not _velocity.is_zero_approx() else _launch_direction
	_start_tangent = direction * approach_departure_length
	var displacement := _end - _start
	if not displacement.is_zero_approx():
		_target_direction = displacement.normalized()
	var arrival := _arrival_direction
	if approach_frame == ApproachFrame.TARGET_RELATIVE:
		arrival = _target_direction.rotated(_relative_arrival_angle)
	_end_tangent = arrival * displacement.length() * approach_arrival_scale
	_path.clear()
	for index in range(CURVE_STEPS + 1):
		var t := float(index) / CURVE_STEPS
		var t2 := t * t
		var t3 := t2 * t
		var point := (2.0 * t3 - 3.0 * t2 + 1.0) * _start
		point += (t3 - 2.0 * t2 + t) * _start_tangent
		point += (-2.0 * t3 + 3.0 * t2) * _end
		point += (t3 - t2) * _end_tangent
		_path.append(point)
	var remaining := approach_lookahead
	_guide_position = _start
	for index in range(1, _path.size()):
		var length := _path[index - 1].distance_to(_path[index])
		if length > remaining:
			_guide_position = _path[index - 1].lerp(_path[index], remaining / length)
			break
		_guide_position = _path[index]
		remaining -= length


func _advance_error(delta: float) -> void:
	# 長さ0の段階は許容する。ただし全段階が0の周期では誤差を加えない。
	var cycle_max := error_rise_time + maxf(error_hold_min, error_hold_max)
	cycle_max += error_fall_time + maxf(error_rest_min, error_rest_max)
	if cycle_max <= 0.0:
		_error_angle = 0.0
		return
	var remaining := delta
	while remaining > 0.0:
		if _phase_elapsed >= _phase_duration:
			_next_error_phase()
			continue
		var step := minf(remaining, _phase_duration - _phase_elapsed)
		_phase_elapsed += step
		remaining -= step
	var fraction := 0.0 if _phase_duration <= 0.0 else _phase_elapsed / _phase_duration
	match _error_phase:
		ErrorPhase.RISE:
			_error_angle = _peak_error * smoothstep(0.0, 1.0, fraction)
		ErrorPhase.HOLD:
			_error_angle = _peak_error
		ErrorPhase.FALL:
			_error_angle = _peak_error * (1.0 - smoothstep(0.0, 1.0, fraction))
		ErrorPhase.REST:
			_error_angle = 0.0


func _next_error_phase() -> void:
	_phase_elapsed = 0.0
	match _error_phase:
		ErrorPhase.REST:
			_error_phase = ErrorPhase.RISE
			_peak_error = deg_to_rad(error_angle) * _random.randf_range(-1.0, 1.0)
			_phase_duration = error_rise_time
		ErrorPhase.RISE:
			_error_phase = ErrorPhase.HOLD
			_phase_duration = _random_range(error_hold_min, error_hold_max)
		ErrorPhase.HOLD:
			_error_phase = ErrorPhase.FALL
			_phase_duration = error_fall_time
		ErrorPhase.FALL:
			_error_phase = ErrorPhase.REST
			_phase_duration = _random_range(error_rest_min, error_rest_max)


func _random_range(first: float, second: float) -> float:
	return _random.randf_range(minf(first, second), maxf(first, second))


func _error_envelope(age: float) -> float:
	var onset := 1.0
	if error_fade_in > 0.0:
		onset = clampf((age - ignition_delay) / error_fade_in, 0.0, 1.0)
	var capture := maxf(error_capture_distance, hit_radius + 0.001)
	var distance := position.distance_to(_target_position())
	return onset * clampf((distance - hit_radius) / (capture - hit_radius), 0.0, 1.0)


func _speed_at_age(age: float) -> float:
	var t := clampf((age - ignition_delay) / acceleration_time, 0.0, 1.0)
	return lerpf(minf(launch_speed, speed), speed, t * t * (3.0 - 2.0 * t))


func _target_position() -> Vector2:
	if _target.get_parent() == get_parent():
		return _target.position
	var parent := get_parent() as Node2D
	return parent.to_local(_target.global_position) if parent != null else _target.global_position


func _emit_exhaust(previous: Vector2) -> void:
	var distance := previous.distance_to(position)
	var direction := _velocity.normalized()
	var offset := 1.0 - _emission_distance
	while offset <= distance:
		exhausted.emit(previous.lerp(position, offset / distance) - direction * 3.0, _velocity, tint)
		offset += 1.0
	_emission_distance = fmod(_emission_distance + distance, 1.0)


func _finish_flight(hit: bool) -> void:
	if hit:
		impacted.emit(position, tint)
	if is_instance_valid(_visuals):
		_visuals.finish(hit)
	queue_free()


