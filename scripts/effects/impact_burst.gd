class_name ImpactBurst
extends Node2D
## One-shot strike effect: a white-hot flash, an ember ring and a spray of
## sparks thrown along the attack direction. Drawn procedurally in the Wick's
## flame colors; frees itself when the last spark burns out.

const EMBER_DARK := Color("b8361e")

@export var lifetime := 0.35
@export var spark_count := 9
@export var spark_speed_min := 70.0
@export var spark_speed_max := 190.0
## Radians either side of the attack direction the sparks may fly.
@export var spark_spread := 1.0
@export var spark_gravity := 380.0
@export var spark_drag := 4.0
@export var flash_time := 0.07
@export var ring_radius := 13.0

## Direction of the strike that caused the impact. Set before adding to the tree.
var direction := Vector2.RIGHT

var _time := 0.0
var _positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _lifetimes := PackedFloat32Array()


func _ready() -> void:
	z_index = 10
	var base := direction.angle()
	for i in spark_count:
		var angle := base + randf_range(-spark_spread, spark_spread)
		_positions.append(Vector2.ZERO)
		_velocities.append(Vector2.from_angle(angle) * randf_range(spark_speed_min, spark_speed_max))
		_lifetimes.append(lifetime * randf_range(0.55, 1.0))


func _process(delta: float) -> void:
	_time += delta
	if _time >= lifetime:
		queue_free()
		return
	var damping := maxf(0.0, 1.0 - spark_drag * delta)
	for i in _positions.size():
		_velocities[i] = Vector2(_velocities[i].x * damping, _velocities[i].y * damping + spark_gravity * delta)
		_positions[i] += _velocities[i] * delta
	queue_redraw()


func _draw() -> void:
	var t := _time / lifetime
	# White-hot core flash, then an ember ring opening outward.
	if _time < flash_time:
		var k := 1.0 - _time / flash_time
		draw_circle(Vector2.ZERO, 3.0 + 5.0 * k, Color(PlayerVisual.FLAME_CORE, 0.95 * k))
		draw_circle(Vector2.ZERO, 2.0 + 2.0 * k, Color(1, 1, 1, k))
	var ring_t := clampf(_time / (lifetime * 0.6), 0.0, 1.0)
	if ring_t < 1.0:
		var radius := lerpf(4.0, ring_radius, 1.0 - pow(1.0 - ring_t, 3.0))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(PlayerVisual.FLAME, 1.0 - ring_t), 1.5)
	# Short streaks across the strike line sell the direction.
	if t < 0.4:
		var along := direction * (6.0 + 10.0 * t)
		var across := direction.orthogonal() * 4.0 * (1.0 - t / 0.4)
		draw_line(-along, along, Color(PlayerVisual.FLAME_CORE, 1.0 - t / 0.4), 1.5)
		draw_line(-across, across, Color(PlayerVisual.FLAME_CORE, 1.0 - t / 0.4), 1.0)
	# Sparks cool from pale gold through flame orange to a dull ember.
	for i in _positions.size():
		var life := _time / _lifetimes[i]
		if life >= 1.0:
			continue
		var color := PlayerVisual.FLAME_CORE.lerp(PlayerVisual.FLAME, minf(life * 2.0, 1.0))
		if life > 0.5:
			color = PlayerVisual.FLAME.lerp(EMBER_DARK, (life - 0.5) * 2.0)
		color.a = 1.0 - life * life
		var tail := _positions[i] - _velocities[i] * 0.03
		draw_line(tail, _positions[i], color, 1.5 if life < 0.5 else 1.0)
