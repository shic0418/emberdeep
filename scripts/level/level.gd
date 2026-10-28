class_name Level
extends Node2D
## Builds a playable area from a LevelLayout: terrain, the player (at the
## active checkpoint if one is set), enemies, shrines and pickups. Also wires
## the HUD and handles death -> respawn.

const PlayerScene := preload("res://scenes/player/player.tscn")
const GloomshellScene := preload("res://scenes/enemies/gloomshell.tscn")
const CheckpointScene := preload("res://scenes/objects/checkpoint.tscn")
const GlimmerScene := preload("res://scenes/objects/glimmer.tscn")

@export var layout: LevelLayout

var player: Player

@onready var renderer: TerrainRenderer = $TerrainRenderer
@onready var actors: Node2D = $Actors
@onready var hud: Hud = $HUD


func _ready() -> void:
	assert(layout != null, "Level needs a LevelLayout")
	GameState.cancel_hit_stop()  # a reload must always start at normal speed
	renderer.layout = layout
	renderer.queue_redraw()
	TerrainBuilder.build(layout, $Terrain)
	_spawn_objects()
	_spawn_player()


func _spawn_objects() -> void:
	for cell in layout.find_cells(LevelLayout.CHECKPOINT):
		var checkpoint: Checkpoint = CheckpointScene.instantiate()
		checkpoint.checkpoint_id = _object_id("shrine", cell)
		checkpoint.position = LevelLayout.cell_to_feet(cell)
		actors.add_child(checkpoint)
	for cell in layout.find_cells(LevelLayout.GLIMMER):
		var id := _object_id("glimmer", cell)
		if GameState.is_collected(id):
			continue
		var glimmer: Glimmer = GlimmerScene.instantiate()
		glimmer.pickup_id = id
		glimmer.position = LevelLayout.cell_to_center(cell)
		actors.add_child(glimmer)
	for cell in layout.find_cells(LevelLayout.ENEMY):
		var enemy: Gloomshell = GloomshellScene.instantiate()
		enemy.position = LevelLayout.cell_to_feet(cell)
		actors.add_child(enemy)


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	if GameState.has_checkpoint():
		player.position = GameState.checkpoint_position
	else:
		var starts := layout.find_cells(LevelLayout.PLAYER_START)
		assert(not starts.is_empty(), "Layout has no player start 'P'")
		player.position = LevelLayout.cell_to_feet(starts[0])
	actors.add_child(player)
	player.camera.set_bounds(layout.get_pixel_rect())
	player.died.connect(_on_player_died)
	hud.bind_player(player)


func _object_id(kind: String, cell: Vector2i) -> StringName:
	return StringName("%s/%s_%d_%d" % [layout.level_id, kind, cell.x, cell.y])


func _on_player_died() -> void:
	await get_tree().create_timer(GameState.RESPAWN_DELAY).timeout
	GameState.respawn()
