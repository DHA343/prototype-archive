@tool
extends Node2D
## 横ずれした狙い点への追尾、加速度制限、断続的な操舵誤差を扱う。

signal impacted(point: Vector2, tint: Color)

enum State {
	STRAIGHT,
	HOMING,
}

const Visuals = preload("res://experiments/missiles/visuals.gd")

const SEED_SCALE: float = 1000000.0
const INSTABILITY_SEED_OFFSET: int = 173
const OFFSET_SEED_OFFSET: int = 7919

@export_group("Flight")
@export_range(1.0, 500.0, 1.0, "suffix:px/s") var speed: float = 250.0
@export_range(0.1, 20.0, 0.1, "suffix:s") var lifetime: float = 5.0
@export_range(1.0, 20.0, 0.1, "suffix:px") var hit_radius: float = 6.0
@export_group("Acceleration", "acceleration_")
## 旋回も含めた、実速度の1秒あたりの最大変化量。
@export_range(100.0, 6000.0, 100.0, "suffix:px/s²") var acceleration_limit: float = 1800.0
@export_range(0.02, 1.0, 0.01, "suffix:s") var acceleration_response_time: float = 0.08
@export_group("Speed Control", "speed_control_")
## 旋回角がTurn Angle以上のときに使う、指示速度に対する割合。100%で旋回減速を無効にする。
@export_range(10.0, 100.0, 1.0, "suffix:%") var speed_control_turn_speed: float = 45.0
## 現在の速度方向と操舵方向の差がこの角度で、旋回減速を最大にする。
@export_range(1.0, 180.0, 1.0, "suffix:°") var speed_control_turn_angle: float = 90.0
@export_group("Offset", "offset_")
@export_range(0.0, 300.0, 5.0, "suffix:px") var offset_max_distance: float = 120.0
@export_range(10.0, 500.0, 10.0, "suffix:px") var offset_fade_distance: float = 180.0
## 実目標までの距離がこの値以下なら、横ずれを0にする。
## Fade Distance以上に設定すると減衰区間がなくなり、この距離を境に切り替わる。
@export_range(0.0, 500.0, 1.0, "suffix:px") var offset_zero_distance: float = 0.0
## 距離比に適用する指数。1で線形、2で二乗。大きいほど接近時の横ずれを早く小さくする。
@export_range(0.1, 4.0, 0.1) var offset_power: float = 2.0
## 横ずれを加えずに目標を直接狙う確率。操舵誤差は引き続き適用する。
@export_range(0.0, 100.0, 1.0, "suffix:%") var offset_direct_chance: float = 25.0

@export_group("Instability", "instability_")
@export var instability_enabled: bool = true:
	set(value):
		instability_enabled = value
		notify_property_list_changed()
## 誤差イベントごとに、この範囲内から符号付きの最大操舵角を一様抽選する。
@export_range(0.0, 90.0, 1.0, "suffix:°") var instability_angle: float = 45.0
## 抽選した角度を保持する時間。
@export_range(0.0, 0.8, 0.01, "suffix:s") var instability_hold_min: float = 0.02
@export_range(0.0, 0.8, 0.01, "suffix:s") var instability_hold_max: float = 0.12
@export_range(0.0, 1.0, 0.01, "suffix:s") var instability_rest_min: float = 0.03
@export_range(0.0, 1.0, 0.01, "suffix:s") var instability_rest_max: float = 0.20
## 個々の誤差イベントとは独立して、追尾開始から誤差全体の影響を線形に立ち上げる。
@export_range(0.0, 0.6, 0.01, "suffix:s") var instability_fade_in: float = 0.15
## この距離から命中半径までの間で、誤差の影響を線形に0へ近づける。
@export_range(8.0, 120.0, 1.0, "suffix:px") var instability_capture_distance: float = 45.0
@export_group("Appearance")
@export var tint: Color = Color("e99cff")

var state: State = State.STRAIGHT
var desired_speed: float = 0.0

var _launched: bool = false
var _homing_elapsed: float = 0.0
var _visual_seed: float = 0.0
var _target: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _straight_direction: Vector2 = Vector2.DOWN
var _age: float = 0.0

var _has_guidance: bool = false
var _guidance_origin: Vector2 = Vector2.ZERO
var _guidance_target: Vector2 = Vector2.ZERO
var _aim_position: Vector2 = Vector2.ZERO
var _offset_factor: float = 0.0
var _steering_direction: Vector2 = Vector2.ZERO
var _applied_instability_angle: float = 0.0

var _instability_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _instability_elapsed: float = 0.0
var _instability_rest_duration: float = 0.0
var _instability_hold_duration: float = 0.0
var _sampled_instability_angle: float = 0.0
var _instability_angle: float = 0.0

@onready var _visuals: Visuals = $Visuals


func _ready() -> void:
	if _launched:
		_start_visuals()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _launched:
		return
	if state == State.HOMING and not is_instance_valid(_target):
		_finish_flight(false)
		return

	var previous_position := position
	_advance_flight(delta)
	_age += delta

	if is_instance_valid(_target):
		var target_position := _get_target_position()
		var closest_position := Geometry2D.get_closest_point_to_segment(
			target_position, previous_position, position)
		if closest_position.distance_squared_to(target_position) <= hit_radius * hit_radius:
			_finish_flight(true)
			return

	if _age > lifetime:
		_finish_flight(false)


func _validate_property(property: Dictionary) -> void:
	var property_name: String = property.name
	if property_name.begins_with("instability_") and property_name != "instability_enabled" and not instability_enabled:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func launch(
	origin: Vector2, direction: Vector2, target: Node2D, seed_value: float, initial_speed: float,
) -> void:
	position = origin
	_target = target
	_visual_seed = seed_value
	_velocity = direction.normalized() * clampf(initial_speed, 0.0, speed)
	desired_speed = clampf(initial_speed, 0.0, speed)
	_age = 0.0
	_homing_elapsed = 0.0
	_launched = true
	fly_straight(direction)
	_reset_instability(seed_value)
	_choose_lateral_offset(seed_value)
	_start_visuals()


func fly_straight(direction: Vector2) -> void:
	state = State.STRAIGHT
	_straight_direction = direction.normalized()
	_steering_direction = _straight_direction
	_has_guidance = false
	_applied_instability_angle = 0.0


func start_homing(target: Node2D) -> void:
	_target = target
	if state != State.HOMING:
		_homing_elapsed = 0.0
	state = State.HOMING


func get_velocity() -> Vector2:
	return _velocity


func refresh_guidance() -> void:
	# 停止中も狙い点を更新するが、飛行・誤差イベント・乱数は進めない。
	if state != State.HOMING or not _has_guidance:
		return

	_update_aim_position()
	_update_steering_direction(_homing_elapsed)


## 直前の追尾計算に使った状態を返す。移動後の位置から狙い点を再計算しない。
func get_guidance_state() -> Dictionary:
	if not _has_guidance:
		return {}

	return {
		"origin": _guidance_origin,
		"target": _guidance_target,
		"aim": _aim_position,
		"direction": _steering_direction,
		"instability_angle": _applied_instability_angle,
		"instability_active": _is_instability_active(),
		"instability_enabled": instability_enabled,
	}


func _advance_flight(delta: float) -> void:
	if state == State.HOMING:
		_update_aim_position()
		if instability_enabled:
			_update_instability(delta)
		_homing_elapsed += delta
		_update_steering_direction(_homing_elapsed)
	else:
		_steering_direction = _straight_direction

	var commanded_speed := clampf(desired_speed, 0.0, speed)
	var target_speed := _get_homing_speed(commanded_speed) if state == State.HOMING else commanded_speed
	_move_with_acceleration(delta, target_speed)


func _get_homing_speed(commanded_speed: float) -> float:
	var turn_speed := commanded_speed
	if not _velocity.is_zero_approx():
		var turn_angle := absf(_velocity.angle_to(_steering_direction))
		var turn_ratio := clampf(turn_angle / deg_to_rad(speed_control_turn_angle), 0.0, 1.0)
		turn_speed *= lerpf(1.0, speed_control_turn_speed / 100.0, turn_ratio)

	return turn_speed


func _move_with_acceleration(delta: float, desired_speed: float) -> void:
	var desired_velocity := _steering_direction * desired_speed
	var response := 1.0 - exp(-delta / acceleration_response_time)
	var velocity_change := (desired_velocity - _velocity) * response

	var previous_velocity := _velocity
	_velocity += velocity_change.limit_length(acceleration_limit * delta)
	_velocity = _velocity.limit_length(speed)
	position += (previous_velocity + _velocity) * (0.5 * delta)


func _choose_lateral_offset(seed_value: float) -> void:
	# 狙い点の抽選を操舵誤差のイベントから独立させるため、別の乱数列を使う。
	var offset_random := RandomNumberGenerator.new()
	offset_random.seed = int(seed_value * SEED_SCALE) + OFFSET_SEED_OFFSET
	var aims_directly := offset_random.randf() < offset_direct_chance / 100.0
	_offset_factor = 0.0 if aims_directly else offset_random.randf_range(-1.0, 1.0)


func _update_aim_position() -> void:
	_guidance_origin = position
	_guidance_target = _get_target_position()

	var displacement := _guidance_target - _guidance_origin
	var distance := displacement.length()
	var distance_ratio := 0.0
	if distance > offset_zero_distance:
		distance_ratio = 1.0
		if offset_fade_distance > offset_zero_distance:
			distance_ratio = clampf(
				(distance - offset_zero_distance) / (offset_fade_distance - offset_zero_distance), 0.0, 1.0)
	var lateral_distance := offset_max_distance * pow(distance_ratio, offset_power)
	var lateral_direction := displacement.normalized().orthogonal()
	_aim_position = _guidance_target + lateral_direction * lateral_distance * _offset_factor
	_has_guidance = true


func _get_target_position() -> Vector2:
	if _target.get_parent() == get_parent():
		return _target.position
	var parent := get_parent() as Node2D
	return parent.to_local(_target.global_position) if parent != null else _target.global_position


func _update_steering_direction(homing_time: float) -> void:
	_applied_instability_angle = 0.0
	if instability_enabled:
		_applied_instability_angle = _instability_angle * _get_instability_influence(homing_time)

	var aim_direction := (_aim_position - _guidance_origin).normalized()
	_steering_direction = aim_direction.rotated(_applied_instability_angle)


func _reset_instability(seed_value: float) -> void:
	_instability_random.seed = int(seed_value * SEED_SCALE) + INSTABILITY_SEED_OFFSET
	_instability_elapsed = 0.0
	_instability_angle = 0.0
	_sample_instability_cycle()


func _sample_instability_cycle() -> void:
	_instability_rest_duration = _random_instability_duration(instability_rest_min, instability_rest_max)
	_sampled_instability_angle = deg_to_rad(instability_angle) * _instability_random.randf_range(-1.0, 1.0)
	_instability_hold_duration = _random_instability_duration(instability_hold_min, instability_hold_max)


func _update_instability(delta: float) -> void:
	var max_cycle_duration := maxf(instability_rest_min, instability_rest_max)
	max_cycle_duration += maxf(instability_hold_min, instability_hold_max)
	if max_cycle_duration <= 0.0:
		_instability_angle = 0.0
		return

	_instability_elapsed += delta
	var cycle_duration := _instability_rest_duration + _instability_hold_duration
	while _instability_elapsed >= cycle_duration:
		# 周期の余り時間を引き継ぐため、更新頻度で抽選時刻が変わらない。
		_instability_elapsed -= cycle_duration
		_sample_instability_cycle()
		cycle_duration = _instability_rest_duration + _instability_hold_duration

	_instability_angle = _sampled_instability_angle if _is_instability_active() else 0.0


func _is_instability_active() -> bool:
	return _instability_hold_duration > 0.0 and _instability_elapsed >= _instability_rest_duration


func _random_instability_duration(min_duration: float, max_duration: float) -> float:
	return _instability_random.randf_range(
		minf(min_duration, max_duration), maxf(min_duration, max_duration))


func _get_instability_influence(homing_time: float) -> float:
	var onset_weight := 1.0
	if instability_fade_in > 0.0:
		onset_weight = clampf(homing_time / instability_fade_in, 0.0, 1.0)

	var fade_start_distance := maxf(instability_capture_distance, hit_radius + 0.001)
	var distance := position.distance_to(_get_target_position())
	var distance_weight := clampf(
		(distance - hit_radius) / (fade_start_distance - hit_radius), 0.0, 1.0)
	return onset_weight * distance_weight


func _start_visuals() -> void:
	if is_instance_valid(_visuals):
		_visuals.follow(self, get_velocity, _visual_seed, tint)


func _finish_flight(hit: bool) -> void:
	if hit:
		impacted.emit(position, tint)
	if is_instance_valid(_visuals):
		_visuals.finish(hit)
	queue_free()
