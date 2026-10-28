extends Node
## Session state that must survive scene reloads (death/restart):
## the active checkpoint and which pickups have been collected.
## Also owns hit-stop, because Engine.time_scale outlives any scene.

signal glimmers_changed(count: int)

var checkpoint_id: StringName = &""
var checkpoint_position := Vector2.INF
var _collected: Dictionary = {}  # pickup id (StringName) -> true

## Delay between the player's death and the level reload.
const RESPAWN_DELAY := 1.2

var _hit_stop_left := 0.0  # real seconds until normal speed returns


func _ready() -> void:
	# Keep ticking while the tree is paused so hit-stop can never outlive its duration.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Counts real time in physics ticks. Time scale shrinks each tick's delta but not
## how many ticks run, and a delta computed before the hit started would end a
## hit-stop early, so the delta argument is deliberately ignored.
func _physics_process(_delta: float) -> void:
	if _hit_stop_left <= 0.0:
		return
	_hit_stop_left -= 1.0 / Engine.physics_ticks_per_second
	if _hit_stop_left <= 0.0:
		cancel_hit_stop()


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


## Slows the whole game to time_scale for duration real seconds. Overlapping
## requests extend to the longest remaining duration; they never add up.
func hit_stop(duration: float, time_scale: float) -> void:
	if duration <= 0.0:
		return
	_hit_stop_left = maxf(_hit_stop_left, duration)
	Engine.time_scale = clampf(time_scale, 0.0, 1.0)


## Ends any hit-stop immediately and restores normal speed.
func cancel_hit_stop() -> void:
	_hit_stop_left = 0.0
	Engine.time_scale = 1.0


func is_hit_stopped() -> bool:
	return _hit_stop_left > 0.0


## Reloads the current level; the level places the player at the active checkpoint.
func respawn() -> void:
	cancel_hit_stop()
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()


## Clears all progress. Used by tests and a future "new game" flow.
func reset() -> void:
	checkpoint_id = &""
	checkpoint_position = Vector2.INF
	_collected.clear()
	cancel_hit_stop()
	glimmers_changed.emit(0)
