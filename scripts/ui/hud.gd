class_name Hud
extends CanvasLayer
## Health embers (top-left) and glimmer count.

@onready var health_display: HealthDisplay = $Root/HealthDisplay
@onready var glimmer_label: Label = $Root/GlimmerLabel


func _ready() -> void:
	GameState.glimmers_changed.connect(_on_glimmers_changed)
	_on_glimmers_changed(GameState.glimmer_count())


func bind_player(player: Player) -> void:
	player.health.changed.connect(health_display.set_values)
	health_display.set_values(player.health.current, player.health.max_health)


func _on_glimmers_changed(count: int) -> void:
	glimmer_label.text = "Glimmers: %d" % count
