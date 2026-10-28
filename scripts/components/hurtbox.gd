class_name Hurtbox
extends Area2D
## Receives hits from Hitboxes. The owner listens to hit_received and applies
## damage/knockback; setting invulnerable makes hits bounce off.

signal hit_received(hitbox: Hitbox)

@export var invulnerable := false


func _ready() -> void:
	monitoring = false


## Returns true if the hit was accepted.
func receive_hit(hitbox: Hitbox) -> bool:
	if invulnerable:
		return false
	hit_received.emit(hitbox)
	return true
