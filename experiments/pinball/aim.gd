extends RefCounted
## 実物を移動せず、今押した場合の打球方向を調べる。

const Ball = preload("res://experiments/pinball/ball.gd")
const Flipper = preload("res://experiments/pinball/flipper.gd")
const STEP: float = 1.0 / 240.0
const LOOKAHEAD: float = Flipper.STRIKE_WINDOW - STEP
const GUIDE_LENGTH: float = 155.0


static func predict(ball: Ball, flippers: Array[Flipper]) -> Dictionary:
	if ball.velocity.y < 20.0:
		return {}
	var point := ball.global_position
	var velocity := ball.velocity
	var collision := KinematicCollision2D.new()
	for index in range(1, ceili(LOOKAHEAD / STEP) + 1):
		var seconds := index * STEP
		velocity = (velocity + Vector2.DOWN * ball.gravity * STEP).limit_length(ball.max_speed)
		var motion := velocity * STEP
		var next := point + motion
		for flipper in flippers:
			if flipper.pressed:
				continue
			var angle := flipper.predict_angle(seconds)
			var pose := Transform2D(angle, flipper.global_position)
			var nearest := Vector2.ZERO
			var distance := INF
			for edge in range(flipper.outline.size()):
				var start := pose * flipper.outline[edge]
				var end := pose * flipper.outline[(edge + 1) % flipper.outline.size()]
				var contact := Geometry2D.get_closest_point_to_segment(next, start, end)
				var gap := next.distance_squared_to(contact)
				if gap < distance:
					distance = gap
					nearest = contact
			if distance <= pow(ball.get_radius() + 0.1, 2.0) and next.y < nearest.y:
				var shot := ball.get_shot_velocity(flipper, nearest, angle)
				var origin := ball.global_position
				return {"origin": origin, "velocity": shot, "flipper": flipper,
					"points": PackedVector2Array([origin, origin + shot.normalized() * GUIDE_LENGTH]),
					"seconds": seconds}
		# 先に壁やバンパーへ当たるなら、その先の打球を約束しない。
		if ball.test_move(Transform2D(0.0, point), motion, collision, 0.02, true):
			if not collision.get_collider() is Flipper:
				return {}
		point = next
	return {}
