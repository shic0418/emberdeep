extends Node
## Visual smoke test: loads the cavern in a real window, plays the opening
## route with scripted input, and saves screenshots.
##
## Run (not headless):
##   <godot> --path . --fixed-fps 60 res://tools/capture.tscn -- <output_dir>

const CavernScene := preload("res://scenes/levels/cavern_01.tscn")

var _out_dir := "user://captures"
var level: Level


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	GameState.reset()
	level = CavernScene.instantiate()
	add_child(level)
	await _frames(40)
	await _shot("01_start")
	await _play_opening_route()
	await _overview()
	print("CAPTURE DONE: player at %s, hp %d" % [level.player.position, level.player.health.current])
	get_tree().quit()


func _play_opening_route() -> void:
	var p := level.player
	Input.action_press("move_right")
	var jumped_step := false
	var jumped_pit := false
	var jumped_platform := false
	var pit_shot := false
	for i in 400:
		await get_tree().physics_frame
		if not jumped_step and p.position.x > 196.0:
			jumped_step = true
			await _hold_jump(18)
		elif not jumped_pit and p.position.x > 318.0 and p.is_on_floor():
			jumped_pit = true
			Input.action_press("jump")
		elif jumped_pit and not pit_shot and p.position.x > 370.0:
			pit_shot = true
			Input.action_release("jump")
			await _shot("02_over_pit")
		elif pit_shot and not jumped_platform and p.position.x > 462.0 and p.is_on_floor():
			jumped_platform = true
			await _hold_jump(20)
		elif jumped_platform and p.is_on_floor() and p.position.x > 560.0:
			break
	Input.action_release("move_right")
	print("route: step=%s pit=%s platform=%s pos=%s hp=%d" % [
		jumped_step, jumped_pit, jumped_platform, p.position, p.health.current])
	await _frames(20)
	await _shot("03_route")
	# Set the player down on the floor near the first Gloomshell so it notices them.
	var target := _nearest_enemy()
	# Place them to its right (left of it is the spike pit) and face it.
	p.global_position = Vector2(target.global_position.x + 100.0, target.global_position.y - 2.0)
	p.camera.reset_smoothing()
	Input.action_press("move_left")
	await _frames(2)
	Input.action_release("move_left")
	for i in 120:
		await get_tree().physics_frame
		var enemy := _nearest_enemy()
		if enemy and enemy.state == Gloomshell.State.TELEGRAPH and enemy.state_time > 0.2:
			break
	await _shot("04_telegraph")
	Input.action_press("attack")
	await _frames(4)
	Input.action_release("attack")
	await _shot("05_attack")
	await _frames(30)
	level.get_node("PauseMenu").open()
	await _frames(5)
	await _shot("06_pause")
	level.get_node("PauseMenu").close()


func _hold_jump(count: int) -> void:
	Input.action_press("jump")
	await _frames(count)
	Input.action_release("jump")


func _overview() -> void:
	var cam := Camera2D.new()
	level.add_child(cam)
	cam.zoom = Vector2(0.5, 0.5)
	cam.position = level.layout.get_pixel_rect().get_center()
	cam.make_current()
	level.hud.visible = false
	await _frames(5)
	await _shot("07_overview")


func _nearest_enemy() -> Gloomshell:
	var best: Gloomshell
	for e in get_tree().get_nodes_in_group("enemies"):
		if best == null or e.position.distance_to(level.player.position) < best.position.distance_to(level.player.position):
			best = e
	return best


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)
