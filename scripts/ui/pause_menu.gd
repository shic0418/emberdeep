class_name PauseMenu
extends CanvasLayer
## Toggles with the "pause" action. Runs while the tree is paused.

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close)
	restart_button.pressed.connect(_on_restart)
	quit_button.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_restart() -> void:
	close()
	GameState.respawn()


func _on_quit() -> void:
	get_tree().quit()
