extends Node
## Session state that must survive scene reloads (death/restart):
## the active checkpoint and which pickups have been collected.

signal glimmers_changed(count: int)

var checkpoint_id: StringName = &""
var checkpoint_position := Vector2.INF
var _collected: Dictionary = {}  # pickup id (StringName) -> true

## Delay between the player's death and the level reload.
const RESPAWN_DELAY := 1.2


func has_checkpoint() -> bool:
	return checkpoint_position != Vector2.INF


func activate_checkpoint(id: StringName, spawn_position: Vector2) -> void:
	checkpoint_id = id
	checkpoint_position = spawn_position


func collect(id: StringName) -> void:
	if _collected.has(id):
		return
	_collected[id] = true
	glimmers_changed.emit(glimmer_count())


func is_collected(id: StringName) -> bool:
	return _collected.has(id)


func glimmer_count() -> int:
	return _collected.size()


## Reloads the current level; the level places the player at the active checkpoint.
func respawn() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()


## Clears all progress. Used by tests and a future "new game" flow.
func reset() -> void:
	checkpoint_id = &""
	checkpoint_position = Vector2.INF
	_collected.clear()
	glimmers_changed.emit(0)
