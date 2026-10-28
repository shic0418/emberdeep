class_name HealthDisplay
extends Control
## Draws one ember per hit point: bright when full, a dim socket when lost.
## Briefly flashes the most recently lost ember.

const SPACING := 18.0
const FULL := Color("ff9a3c")
const CORE := Color("ffe39a")
const EMPTY := Color("3a3044")
const OUTLINE := Color("e8e2d4")

var current := 0
var maximum := 0
var _lost_flash := 0.0


func set_values(new_current: int, new_maximum: int) -> void:
	if new_current < current:
		_lost_flash = 0.3
	current = new_current
	maximum = new_maximum
	custom_minimum_size = Vector2(maximum * SPACING, 20)
	queue_redraw()


func _process(delta: float) -> void:
	if _lost_flash > 0.0:
		_lost_flash -= delta
		queue_redraw()


func _draw() -> void:
	for i in maximum:
		var c := Vector2(9 + i * SPACING, 10)
		var shape := PackedVector2Array([
			c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)])
		var filled := i < current
		var color := FULL if filled else EMPTY
		if i == current and _lost_flash > 0.0:
			color = Color.WHITE
		draw_colored_polygon(shape, color)
		draw_polyline(shape + PackedVector2Array([shape[0]]), OUTLINE, 1.0)
		if filled:
			draw_circle(c + Vector2(0, 1), 2.0, CORE)
