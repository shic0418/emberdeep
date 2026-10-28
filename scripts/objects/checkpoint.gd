class_name Checkpoint
extends Area2D
## Ember Shrine. Touching it lights the brazier, fully heals the player and
## makes it the respawn point.

signal activated

@export var checkpoint_id: StringName = &""

var lit := false
var _time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	lit = checkpoint_id != &"" and GameState.checkpoint_id == checkpoint_id


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var player := body as Player
	if player.state == Player.State.DEAD:
		return
	player.health.restore_full()
	if not lit or GameState.checkpoint_id != checkpoint_id:
		GameState.activate_checkpoint(checkpoint_id, global_position)
		lit = true
		activated.emit()


func _process(delta: float) -> void:
	_time += delta
	# Another shrine may have taken over as the respawn point.
	if lit and GameState.checkpoint_id != checkpoint_id:
		lit = false
	queue_redraw()


func _draw() -> void:
	# Stone pillar with a brazier bowl (origin at the base).
	draw_rect(Rect2(-5, -22, 10, 22), Color("3a3646"))
	draw_rect(Rect2(-7, -2, 14, 2), Color("4a4658"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -26), Vector2(9, -26), Vector2(5, -21), Vector2(-5, -21)]), Color("5a5266"))
	if lit:
		var flick := sin(_time * 12.0) * 1.5
		draw_circle(Vector2(0, -30), 14.0, Color(1.0, 0.6, 0.2, 0.12))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6, -26), Vector2(0, -40 - flick), Vector2(6, -26)]), Color("ff9a3c"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-3, -26), Vector2(0, -33 - flick * 0.5), Vector2(3, -26)]), Color("ffe39a"))
	else:
		draw_circle(Vector2(0, -27), 2.0, Color("7a4a3a"))
