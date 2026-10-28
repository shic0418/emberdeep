class_name GameCamera
extends Camera2D
## Follow camera with trauma-style screen shake.

var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_duration := 0.0


func shake(strength: float, duration: float) -> void:
	if strength >= _shake_strength * (_shake_time / maxf(_shake_duration, 0.001)):
		_shake_strength = strength
		_shake_time = duration
		_shake_duration = duration


func set_bounds(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)
	reset_smoothing()


func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_time -= delta
	var falloff := _shake_time / _shake_duration
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength * falloff
