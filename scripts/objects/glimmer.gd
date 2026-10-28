class_name Glimmer
extends Area2D
## Collectible crystal shard tucked into side routes. Collection persists
## through respawns via GameState.

signal collected

@export var pickup_id: StringName = &""

var _time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		GameState.collect(pickup_id)
		collected.emit()
		queue_free()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_time * 3.0) * 2.0
	draw_circle(Vector2(0, bob), 9.0, Color(0.45, 0.85, 0.95, 0.15))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -6 + bob), Vector2(4, bob), Vector2(0, 6 + bob), Vector2(-4, bob)]),
		Color("8fe8f5"))
	draw_line(Vector2(0, -6 + bob), Vector2(0, 6 + bob), Color("e8fbff"), 1.0)
