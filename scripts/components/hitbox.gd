class_name Hitbox
extends Area2D
## Deals damage to Hurtboxes it overlaps while active.
##
## Overlaps are polled every physics frame instead of relying on area_entered,
## so a hitbox switched on while already overlapping a target still connects.
## One-shot hitboxes (attacks) hit each target once per activation; continuous
## ones (contact damage, hazards) keep trying, and the target's invulnerability
## window throttles them.

signal hit_landed(hurtbox: Hurtbox)

@export var damage := 1
@export var knockback_force := 200.0
@export var active := true:
	set = set_active
@export var continuous := false
## Hazards (spikes) send the player back to the last safe ground instead of knocking them back.
@export var is_hazard := false

## Direction of knockback applied to targets. Zero means "away from knockback_origin".
var knockback_direction := Vector2.ZERO
## Node whose position knockback pushes away from. Defaults to the parent.
var knockback_origin: Node2D

var _already_hit: Array[Area2D] = []


func _ready() -> void:
	monitorable = false
	if knockback_origin == null and get_parent() is Node2D:
		knockback_origin = get_parent()
	set_active(active)


func set_active(value: bool) -> void:
	active = value
	_already_hit.clear()
	if is_inside_tree():
		set_deferred("monitoring", value)


func _physics_process(_delta: float) -> void:
	if not active or not monitoring:
		return
	for area in get_overlapping_areas():
		if not area is Hurtbox:
			continue
		if not continuous and _already_hit.has(area):
			continue
		if (area as Hurtbox).receive_hit(self):
			_already_hit.append(area)
			hit_landed.emit(area)


## Knockback direction for a target at target_position.
func knockback_for(target_position: Vector2) -> Vector2:
	if knockback_direction != Vector2.ZERO:
		return knockback_direction.normalized()
	var origin := knockback_origin.global_position if knockback_origin else global_position
	var side := signf(target_position.x - origin.x)
	return Vector2(side if side != 0.0 else 1.0, 0.0)
