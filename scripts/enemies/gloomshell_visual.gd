extends Node2D
## Placeholder art for the Gloomshell: a domed, segmented shell on short legs
## with a single lamp-like eye. The eye and shell glow hot while it telegraphs.

const SHELL := Color("2f4f4f")
const SHELL_RIDGE := Color("4c7a72")
const BELLY := Color("1b2626")
const EYE_CALM := Color("7fe0d0")
const EYE_ANGRY := Color("ff5a3c")
const WARN := Color(1.0, 0.35, 0.2)

var _time := 0.0
@onready var enemy: Gloomshell = get_parent()


func _process(delta: float) -> void:
	_time += delta
	if enemy.state == Gloomshell.State.DEAD:
		modulate.a = maxf(0.0, 1.0 - enemy.state_time / 0.9)
	queue_redraw()


func _draw() -> void:
	var d := float(enemy.direction)
	var state := enemy.state
	var shake := Vector2.ZERO
	var tilt := 0.0
	if state == Gloomshell.State.TELEGRAPH:
		shake.x = sin(_time * 70.0) * 1.2
		tilt = -0.25 * d  # rears its front up
	elif state == Gloomshell.State.CHARGE:
		tilt = 0.12 * d
	if state == Gloomshell.State.DEAD:
		draw_set_transform(Vector2(0, -6), PI, Vector2.ONE)  # flipped belly-up
	else:
		draw_set_transform(shake, tilt, Vector2.ONE)

	# Legs (scuttle while moving).
	var step := sin(_time * (24.0 if state == Gloomshell.State.CHARGE else 10.0)) * 2.0
	for i in 3:
		var x := -7.0 + i * 7.0
		var s := step if i % 2 == 0 else -step
		draw_line(Vector2(x, -4), Vector2(x + s, 0), BELLY, 2.0)

	# Shell dome.
	var shell := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		shell.append(Vector2(cos(a) * 13.0, -4.0 + sin(a) * 11.0))
	var shell_color := SHELL
	if state == Gloomshell.State.TELEGRAPH:
		shell_color = SHELL.lerp(WARN, 0.35 + 0.35 * sin(_time * 30.0))
	if enemy.flash_time > 0.0:
		shell_color = Color.WHITE
	draw_colored_polygon(shell, shell_color)
	draw_rect(Rect2(-13, -5, 26, 2), BELLY)
	for x in [-5.0, 2.0]:
		draw_line(Vector2(x, -14), Vector2(x + 2, -5), SHELL_RIDGE, 1.0)

	# Eye at the front.
	var angry := state == Gloomshell.State.TELEGRAPH or state == Gloomshell.State.CHARGE
	draw_circle(Vector2(d * 10.0, -8), 2.2, EYE_ANGRY if angry else EYE_CALM)

	draw_set_transform(Vector2.ZERO)
	if state == Gloomshell.State.TELEGRAPH:
		# Exclamation mark warning above the shell.
		draw_rect(Rect2(-1, -32, 2, 7), WARN)
		draw_rect(Rect2(-1, -23, 2, 2), WARN)
