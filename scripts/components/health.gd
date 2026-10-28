class_name Health
extends Node
## Hit points for any actor. Emits signals; owners decide how to react.

signal changed(current: int, maximum: int)
signal damaged(amount: int)
signal died

@export var max_health := 5

var current := 0


func _ready() -> void:
	current = max_health


func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current = maxi(current - amount, 0)
	damaged.emit(amount)
	changed.emit(current, max_health)
	if current == 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)


func restore_full() -> void:
	current = max_health
	changed.emit(current, max_health)


func is_dead() -> bool:
	return current <= 0
