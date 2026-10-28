class_name PlayerVisual
extends Node2D
## Placeholder art for the Wick, drawn procedurally: a cloaked body, a pale
## mask-like head with a flickering ember flame, and the slash arc.

const CLOAK := Color("2b3550")
const CLOAK_EDGE := Color("3f4d73")
const FACE := Color("e8e2d4")
const EYE := Color("1a1420")
const FLAME := Color("ff9a3c")
const FLAME_CORE := Color("ffe39a")
const SLASH := Color(1.0, 0.95, 0.85, 0.9)

var _time := 0.0
@onready var player: Player = get_parent()


func _process(delta: float) -> void:
	_time += delta
	# Blink while invulnerable; flash brightly right after a hit.
	if player.state == Player.State.DEAD:
		modulate = Color(0.6, 0.6, 0.7, 0.8)
	elif player.is_invulnerable():
		modulate.a = 0.35 if int(_time * 16.0) % 2 == 0 else 1.0
	else:
		modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	var f := float(player.facing)
	var dashing := player.state == Player.State.DASH
	var lean := -f * 3.0 if dashing else 0.0

	# Cloak (origin is at the feet).
	var cloak := PackedVector2Array([
		Vector2(-6 + lean, -12), Vector2(6 + lean, -12),
		Vector2(8, 0), Vector2(-8, 0),
	])
	draw_colored_polygon(cloak, CLOAK)
	draw_polyline(cloak + PackedVector2Array([cloak[0]]), CLOAK_EDGE, 1.0)

	# Head.
	var head := Vector2(lean, -16)
	draw_circle(head, 6.0, FACE)
	draw_circle(head + Vector2(2.0 * f, 0), 1.3, EYE)
	draw_circle(head + Vector2(-1.0 * f, 0), 1.3, EYE)

	# Ember flame on top, flickering.
	var flicker := sin(_time * 18.0) * 1.0
	var top := head + Vector2(-f * 1.5, -11.0 - flicker)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-3.5, -4), top, head + Vector2(3.5, -4)]), FLAME)
	draw_circle(head + Vector2(0, -6), 1.6, FLAME_CORE)

	if dashing:
		for i in 3:
			var y := -4.0 - i * 5.0
			draw_line(Vector2(-f * 10, y), Vector2(-f * 22, y), Color(FLAME, 0.5), 1.0)

	if player.attack_visual_time > 0.0:
		_draw_slash()


func _draw_slash() -> void:
	var dir := player.attack_direction
	var progress := 1.0 - player.attack_visual_time / 0.15
	var center := Vector2(0, -11) + dir * 6.0
	var a := dir.angle()
	var fade := 1.0 - progress * 0.7
	# Crescent: outer arc out to the hitbox's reach, inner arc closer in.
	var crescent := PackedVector2Array()
	for i in 13:
		var t := a + lerpf(-1.2, 1.2, i / 12.0)
		crescent.append(center + Vector2.from_angle(t) * 20.0)
	for i in range(12, -1, -1):
		var t := a + lerpf(-0.9, 0.9, i / 12.0)
		crescent.append(center + Vector2.from_angle(t) * 13.0 + dir * 2.0)
	draw_colored_polygon(crescent, Color(SLASH, 0.75 * fade))
	draw_arc(center, 20.0, a - 1.2, a + 1.2, 13, Color(1, 1, 1, fade), 1.5)
