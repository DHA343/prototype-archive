extends "res://experiments/missiles/missile.gd"
## 演出込み計測用。加速度制御を揃え、追加の追尾処理だけを除く。


func _advance_flight(delta: float) -> void:
	_steering_direction = (_get_target_position() - position).normalized()
	_move_with_acceleration(delta, clampf(desired_speed, 0.0, speed))
