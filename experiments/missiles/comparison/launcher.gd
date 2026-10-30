extends "res://experiments/missiles/launcher.gd"
## 比較条件を維持するため、従来の発射条件とエルミート用の発射引数を保つ。


func _make_profile(index: int) -> Dictionary:
	return {
		"shot_id": _next_shot_id, "delay": index * shot_interval,
		"heading": deg_to_rad(random.randf_range(-spread, spread)),
		"approach": random.randf_range(-1.0, 1.0),
		"seed": random.randf_range(0.0, TAU),
	}


func _start_missile(missile: Node2D, profile: Dictionary, direction: Vector2) -> void:
	if missile is Missile:
		super._start_missile(missile, profile, direction)
		return
	var angle := deg_to_rad(missile.approach_angle + profile.approach * missile.approach_spread)
	var arrival_direction := Vector2.UP.rotated(angle)
	var parent := get_parent() as Node2D
	if parent != null:
		arrival_direction = parent.to_local(parent.global_position + arrival_direction).normalized()
	missile.launch(position, direction, target, profile.seed, arrival_direction, angle)


