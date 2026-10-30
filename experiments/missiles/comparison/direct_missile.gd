@tool
extends "res://experiments/missiles/comparison/missile.gd"
## 現在の目標を直接追尾し、共通の加速度制御と操舵誤差を使う。


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if String(property.name).begins_with("approach_"):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func is_curved_guidance() -> bool:
	return false


func _plan_guidance() -> void:
	_start = position
	_end = _target_position()
	_guide_position = _end
	_start_tangent = Vector2.ZERO
	_end_tangent = Vector2.ZERO
	# この線分は目標方向の可視化用で、エルミート曲線を評価したものではない。
	_path = PackedVector2Array([_start, _end])
