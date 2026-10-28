extends Node
## Headless gameplay test suite. Drives the real scenes with simulated input.
##
## Run:  <godot> --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed, 1 = failures.
##
## Timing: tests resume on the physics_frame signal, before nodes run their
## _physics_process. An Input.action_press() made there is first seen by nodes
## one physics step later, so "press, then await frames(2)" is the earliest
## point at which the player has reacted.

const PlayerScene := preload("res://scenes/player/player.tscn")
const GloomshellScene := preload("res://scenes/enemies/gloomshell.tscn")
const CheckpointScene := preload("res://scenes/objects/checkpoint.tscn")
const GlimmerScene := preload("res://scenes/objects/glimmer.tscn")
const CavernScene := preload("res://scenes/levels/cavern_01.tscn")
const CavernLayout := preload("res://levels/cavern_01_layout.tres")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "dash", "pause"]

var _failures: PackedStringArray = []
var _test_failed := false
var _current := ""
var _arena: Node2D


func _ready() -> void:
	await get_tree().process_frame
	await _run("layout_is_valid", test_layout_is_valid)
	await _run("merge_rects", test_merge_rects)
	await _run("health_component", test_health_component)
	await _run("terrain_builder", test_terrain_builder)
	await _run("run_and_facing", test_run_and_facing)
	await _run("variable_jump_height", test_variable_jump_height)
	await _run("coyote_time", test_coyote_time)
	await _run("coyote_time_expires", test_coyote_time_expires)
	await _run("jump_buffer", test_jump_buffer)
	await _run("dash", test_dash)
	await _run("single_air_dash", test_single_air_dash)
	await _run("one_way_platform", test_one_way_platform)
	await _run("attack_hits_once_and_kills", test_attack_hits_once_and_kills)
	await _run("up_attack", test_up_attack)
	await _run("down_strike_hits_and_bounces", test_down_strike_hits_and_bounces)
	await _run("down_strike_from_full_fall", test_down_strike_from_full_fall)
	await _run("down_strike_miss_no_bounce", test_down_strike_miss_no_bounce)
	await _run("down_strike_hits_once_per_activation", test_down_strike_hits_once_per_activation)
	await _run("down_attack_on_ground_is_forward", test_down_attack_on_ground_is_forward)
	await _run("pogo_does_not_refund_air_dash", test_pogo_does_not_refund_air_dash)
	await _run("hit_stop_restores_timing", test_hit_stop_restores_timing)
	await _run("hit_stop_cleared_by_pause_and_reload", test_hit_stop_cleared_by_pause_and_reload)
	await _run("contact_damage_knockback_iframes", test_contact_damage_knockback_iframes)
	await _run("spikes_respawn_to_safe_ground", test_spikes_respawn_to_safe_ground)
	await _run("player_death", test_player_death)
	await _run("enemy_telegraph_charge_cycle", test_enemy_telegraph_charge_cycle)
	await _run("enemy_patrol_turns_at_ledges", test_enemy_patrol_turns_at_ledges)
	await _run("enemy_charge_ignores_stagger", test_enemy_charge_ignores_stagger)
	await _run("checkpoint_heals_and_sets_spawn", test_checkpoint_heals_and_sets_spawn)
	await _run("glimmer_pickup", test_glimmer_pickup)
	await _run("level_loads", test_level_loads)
	await _run("level_spawns_at_checkpoint", test_level_spawns_at_checkpoint)
	await _run("pause_menu", test_pause_menu)

	print("")
	if _failures.is_empty():
		print("ALL TESTS PASSED")
	else:
		print("%d FAILURE(S):" % _failures.size())
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- harness ---------------------------------------------------------------

func _run(test_name: String, test: Callable) -> void:
	_current = test_name
	_test_failed = false
	GameState.reset()
	get_tree().paused = false
	_arena = Node2D.new()
	_arena.name = "Arena"
	add_child(_arena)
	await test.call()
	for action in ACTIONS:
		Input.action_release(action)
	_arena.queue_free()
	get_tree().paused = false
	GameState.cancel_hit_stop()
	await get_tree().physics_frame
	await get_tree().physics_frame
	print(("FAIL " if _test_failed else "PASS ") + test_name)


func check(condition: bool, message: String) -> void:
	if not condition:
		_test_failed = true
		_failures.append("%s: %s" % [_current, message])


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func press(action: String) -> void:
	Input.action_press(action)


func release(action: String) -> void:
	Input.action_release(action)


## Solid floor whose top surface is y = 0, spanning [from_x, to_x].
func add_floor(from_x := -400.0, to_x := 400.0, top := 0.0) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(to_x - from_x, 32)
	shape.shape = rect
	shape.position = Vector2((from_x + to_x) * 0.5, top + 16)
	body.add_child(shape)
	_arena.add_child(body)


func spawn_player(pos := Vector2.ZERO) -> Player:
	var player: Player = PlayerScene.instantiate()
	player.position = pos
	_arena.add_child(player)
	return player


## Enemy that stands still and ignores the player unless told otherwise.
func spawn_passive_enemy(pos: Vector2) -> Gloomshell:
	var enemy: Gloomshell = GloomshellScene.instantiate()
	enemy.position = pos
	enemy.patrol_speed = 0.0
	enemy.detection_range = 0.0
	_arena.add_child(enemy)
	return enemy


func count_bursts() -> int:
	return _arena.get_children().filter(func(n): return n is ImpactBurst).size()


## Presses Down + Attack, then follows the player for count frames.
## Returns the most upward (most negative) vertical speed seen.
func down_strike(player: Player, count: int) -> float:
	press("move_down")
	press("attack")
	var min_vy := player.velocity.y
	for i in count:
		await get_tree().physics_frame
		min_vy = minf(min_vy, player.velocity.y)
	release("attack")
	release("move_down")
	return min_vy


func make_layout(map: String) -> LevelLayout:
	var layout := LevelLayout.new()
	layout.map = map
	return layout


# --- layout & components ---------------------------------------------------

func test_layout_is_valid() -> void:
	var layout: LevelLayout = CavernLayout
	check(layout.get_size() == Vector2i(80, 30), "cavern size is %s" % layout.get_size())
	check(layout.find_invalid_chars().is_empty(), "invalid chars %s" % layout.find_invalid_chars())
	check(layout.find_cells("P").size() == 1, "exactly one player start")
	check(layout.find_cells("C").size() == 2, "two checkpoints")
	check(layout.find_cells("E").size() == 2, "two enemies")
	check(layout.find_cells("*").size() == 2, "two glimmers")
	for c in ["P", "C", "E"]:
		for cell in layout.find_cells(c):
			check(layout.is_solid(cell + Vector2i.DOWN), "%s at %s must stand on rock" % [c, cell])


func test_merge_rects() -> void:
	var layout := make_layout("##.\n##.\n..#\n#=#")
	var rects := layout.merge_rects("#")
	check(rects.has(Rect2i(0, 0, 2, 2)), "2x2 block merged: %s" % [rects])
	check(rects.has(Rect2i(2, 2, 1, 2)), "matching 1-wide runs merge vertically: %s" % [rects])
	check(rects.has(Rect2i(0, 3, 1, 1)), "run split by a platform stays separate")
	var area := 0
	for r in rects:
		area += r.get_area()
	check(area == 7, "rects cover every solid cell exactly (area %d)" % area)
	check(make_layout("a\nbbb").get_size() == Vector2i(3, 2), "ragged rows are padded")


func test_health_component() -> void:
	var health := Health.new()
	health.max_health = 3
	_arena.add_child(health)
	var deaths := [0]
	health.died.connect(func(): deaths[0] += 1)
	health.take_damage(2)
	check(health.current == 1, "3 - 2 = 1")
	health.take_damage(5)
	check(health.current == 0 and health.is_dead(), "clamped at 0")
	health.take_damage(1)
	check(deaths[0] == 1, "died emitted exactly once, got %d" % deaths[0])
	health.heal(1)
	check(health.current == 0, "cannot heal the dead")
	health.restore_full()
	check(health.current == 3, "restore_full")


func test_terrain_builder() -> void:
	TerrainBuilder.build(CavernLayout, _arena)
	var solids: StaticBody2D = _arena.get_node("Solids")
	var platforms: StaticBody2D = _arena.get_node("Platforms")
	check(solids.get_child_count() > 4, "rock collision shapes created")
	check(platforms.get_child_count() == 8, "8 one-way platforms, got %d" % platforms.get_child_count())
	for shape: CollisionShape2D in platforms.get_children():
		check(shape.one_way_collision, "platform is one-way")
	check(_arena.get_node("Hazards").get_child_count() == 2, "2 spike strips")


# --- movement --------------------------------------------------------------

func test_run_and_facing() -> void:
	add_floor()
	var player := spawn_player()
	await frames(5)
	check(player.is_on_floor(), "starts grounded")
	press("move_right")
	await frames(30)
	check(player.position.x > 50.0, "ran right (x=%.1f)" % player.position.x)
	check(player.facing == 1, "faces right")
	release("move_right")
	press("move_left")
	await frames(5)
	check(player.facing == -1, "turns left")


func test_variable_jump_height() -> void:
	add_floor()
	var player := spawn_player()
	await frames(5)
	# Tap: press for one physics frame.
	press("jump")
	await frames(1)
	release("jump")
	var tap := await _peak_height(player, 60)
	await frames(10)
	press("jump")
	var held := await _peak_height(player, 60)
	release("jump")
	check(held > 60.0, "held jump reaches full height (%.1f)" % held)
	check(tap > 4.0 and tap < held * 0.5, "tapped jump is short (%.1f vs %.1f)" % [tap, held])


func _peak_height(player: Player, count: int) -> float:
	var start := player.position.y
	var best := start
	for i in count:
		await get_tree().physics_frame
		best = minf(best, player.position.y)
	return start - best


func test_coyote_time() -> void:
	add_floor(-400, 0)
	add_floor(-400, 400, 300)
	var player := spawn_player(Vector2(-20, 0))
	await frames(5)
	press("move_right")
	for i in 60:
		await get_tree().physics_frame
		if not player.is_on_floor():
			break
	check(not player.is_on_floor(), "walked off the ledge")
	await frames(1)
	press("jump")  # reaches the player 3 frames (0.05 s) after leaving the ledge
	await frames(2)
	check(player.velocity.y < -100.0, "late jump still fires (vy=%.1f)" % player.velocity.y)


func test_coyote_time_expires() -> void:
	add_floor(-400, 0)
	add_floor(-400, 400, 300)
	var player := spawn_player(Vector2(-20, 0))
	await frames(5)
	press("move_right")
	for i in 60:
		await get_tree().physics_frame
		if not player.is_on_floor():
			break
	await frames(12)  # 0.2 s, past the 0.1 s coyote window
	press("jump")
	await frames(1)
	check(player.velocity.y > 0.0, "no jump after coyote window (vy=%.1f)" % player.velocity.y)


func test_jump_buffer() -> void:
	add_floor()
	var player := spawn_player(Vector2(0, -40))
	var pressed_in_air := false
	for i in 60:
		await get_tree().physics_frame
		if player.velocity.y > 0.0 and player.position.y > -14.0:
			pressed_in_air = not player.is_on_floor()
			press("jump")
			break
	check(pressed_in_air, "jump pressed while still airborne")
	var jumped := false
	for i in 10:
		await get_tree().physics_frame
		if player.velocity.y < -200.0:
			jumped = true
	check(jumped, "buffered jump fired on landing")


func test_dash() -> void:
	add_floor()
	var player := spawn_player()
	await frames(5)
	var start := player.position
	press("dash")
	await frames(2)
	check(player.state == Player.State.DASH, "entered dash")
	await frames(9)
	check(player.position.x - start.x > 40.0, "dash covers ground (%.1f)" % (player.position.x - start.x))
	check(absf(player.position.y - start.y) < 1.0, "dash is horizontal")
	await frames(5)
	check(player.state == Player.State.NORMAL, "dash ends")


func test_single_air_dash() -> void:
	add_floor()
	var player := spawn_player()
	player.dash_cooldown = 0.0  # isolate the one-dash-per-airtime rule from the cooldown
	await frames(5)
	press("jump")
	await frames(10)
	press("dash")
	await frames(2)
	check(not player.is_on_floor() and player.state == Player.State.DASH, "first air dash works")
	release("dash")
	await frames(10)
	check(player.state == Player.State.NORMAL, "first dash finished")
	check(not player.is_on_floor(), "still airborne for second attempt")
	press("dash")
	await frames(2)
	check(player.state != Player.State.DASH, "second air dash refused")
	for i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	release("dash")
	await frames(2)
	press("dash")
	await frames(2)
	check(player.state == Player.State.DASH, "landing restores the dash")


func test_one_way_platform() -> void:
	TerrainBuilder.build(make_layout(".....\n.....\n=====\n.....\n#####"), _arena)
	var player := spawn_player(Vector2(40, 32))
	await frames(8)
	check(player.is_on_floor() and absf(player.position.y - 32.0) < 1.0,
		"stands on platform (y=%.1f)" % player.position.y)
	press("move_down")
	press("jump")
	await frames(20)
	release("jump")
	release("move_down")
	check(player.position.y > 60.0, "dropped through (y=%.1f)" % player.position.y)
	await frames(10)
	press("jump")
	await frames(70)
	release("jump")
	await frames(10)
	check(player.is_on_floor() and absf(player.position.y - 32.0) < 1.0,
		"jumped up through and landed on top (y=%.1f)" % player.position.y)


# --- combat ----------------------------------------------------------------

func test_attack_hits_once_and_kills() -> void:
	add_floor()
	var player := spawn_player()
	var enemy := spawn_passive_enemy(Vector2(26, 0))
	await frames(5)
	press("attack")
	await frames(3)
	release("attack")
	check(enemy.health.current == 2, "first hit lands (hp=%d)" % enemy.health.current)
	check(enemy.state == Gloomshell.State.HURT, "enemy staggered")
	await frames(10)
	check(enemy.health.current == 2, "one swing hits only once")
	for i in 2:
		await frames(20)  # cooldown runs in game time, which hit-stop slows
		enemy.position = player.position + Vector2(26, 0)
		await frames(1)
		press("attack")
		await frames(3)
		release("attack")
	check(enemy.health.current == 0, "three hits kill (hp=%d)" % enemy.health.current)
	check(enemy.state == Gloomshell.State.DEAD, "enemy dead state")
	await frames(70)
	check(not is_instance_valid(enemy), "corpse removed")


func test_up_attack() -> void:
	add_floor()
	var player := spawn_player()
	var enemy := spawn_passive_enemy(Vector2(0, -34))
	enemy.gravity = 0.0
	await frames(5)
	press("move_up")
	press("attack")
	await frames(3)
	check(player.attack_direction == Vector2.UP, "attack aimed up")
	check(enemy.health.current == 2, "upward strike lands (hp=%d)" % enemy.health.current)


func test_down_strike_hits_and_bounces() -> void:
	add_floor()
	var enemy := spawn_passive_enemy(Vector2.ZERO)
	var player := spawn_player(Vector2(0, -24))
	var min_vy := await down_strike(player, 4)
	check(player.attack_direction == Vector2.DOWN, "attack aimed down")
	check(enemy.health.current == 2, "down strike lands (hp=%d)" % enemy.health.current)
	check(min_vy <= -player.pogo_bounce_speed * 0.95, "bounced upward (min vy=%.1f)" % min_vy)
	check(player.health.current == 5, "bounce kept the player clear of contact damage")
	check(count_bursts() == 1, "one impact burst spawned (%d)" % count_bursts())
	await frames(40)
	check(count_bursts() == 0, "impact burst freed itself")


func test_down_strike_from_full_fall() -> void:
	add_floor()
	var enemy := spawn_passive_enemy(Vector2.ZERO)
	var player := spawn_player(Vector2(0, -220))
	# Strike a few frames before the body would reach the enemy's contact box.
	for i in 120:
		await get_tree().physics_frame
		if player.position.y > -64.0:
			break
	check(player.velocity.y >= player.max_fall_speed * 0.9, "falling fast (vy=%.1f)" % player.velocity.y)
	var min_vy := await down_strike(player, 6)
	check(enemy.health.current == 2, "strike lands mid-fall (hp=%d)" % enemy.health.current)
	check(min_vy <= -player.pogo_bounce_speed * 0.95, "bounced (min vy=%.1f)" % min_vy)
	check(player.health.current == 5, "strike beat the contact damage (hp=%d)" % player.health.current)


func test_down_strike_miss_no_bounce() -> void:
	add_floor()
	var player := spawn_player(Vector2(0, -80))
	var min_vy := await down_strike(player, 10)
	check(player.attack_direction == Vector2.DOWN, "attack aimed down")
	check(min_vy >= 0.0, "no bounce on a miss (min vy=%.1f)" % min_vy)
	check(not GameState.is_hit_stopped() and Engine.time_scale == 1.0, "no hit-stop on a miss")
	check(count_bursts() == 0, "no impact effect on a miss")


func test_down_strike_hits_once_per_activation() -> void:
	add_floor()
	var enemy := spawn_passive_enemy(Vector2.ZERO)
	var player := spawn_player(Vector2(0, -24))
	await down_strike(player, 4)
	check(enemy.health.current == 2, "first strike lands (hp=%d)" % enemy.health.current)
	check(player.is_attacking(), "activation still live for the overlap check")
	# Hold the player over the enemy for the rest of the activation.
	var held := 0
	while player.is_attacking() and held < 60:
		player.position = Vector2(0, -24)
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame
		held += 1
	check(not player.is_attacking() and not player.attack_hitbox.active, "activation ended and hitbox reset")
	check(enemy.health.current == 2, "one activation damaged it only once (hp=%d)" % enemy.health.current)
	# Hover clear of contact damage until the cooldown and the enemy's stagger pass.
	for i in 25:
		player.position = Vector2(0, -60)
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame
	player.position = Vector2(enemy.position.x, -24)
	await down_strike(player, 4)
	check(enemy.health.current == 1, "a new activation can hit again (hp=%d)" % enemy.health.current)


func test_down_attack_on_ground_is_forward() -> void:
	add_floor()
	var player := spawn_player()
	await frames(5)
	await down_strike(player, 3)
	check(player.attack_direction == Vector2(player.facing, 0), "grounded Down+Attack swings forward")
	check(player.is_on_floor() and absf(player.position.y) < 1.0, "player stayed on the floor")


func test_pogo_does_not_refund_air_dash() -> void:
	add_floor()
	spawn_passive_enemy(Vector2.ZERO).gravity = 0.0
	var player := spawn_player(Vector2(0, -24))
	player.dash_cooldown = 0.0
	player._can_air_dash = false  # as if the air dash was already spent
	var min_vy := await down_strike(player, 4)
	check(min_vy < -200.0, "bounced (min vy=%.1f)" % min_vy)
	await frames(6)
	check(not player.is_on_floor(), "still airborne after the bounce")
	press("dash")
	await frames(2)
	check(player.state != Player.State.DASH, "pogo did not refund the spent air dash")


func test_hit_stop_restores_timing() -> void:
	add_floor()
	var player := spawn_player()
	spawn_passive_enemy(Vector2(26, 0))
	await frames(5)
	check(Engine.time_scale == 1.0, "normal speed before the hit")
	press("attack")
	var stopped := false
	for i in 6:
		await get_tree().physics_frame
		if GameState.is_hit_stopped():
			stopped = true
			break
	release("attack")
	check(stopped, "a landed hit starts hit-stop")
	check(is_equal_approx(Engine.time_scale, player.hit_stop_time_scale),
		"time slowed to %.2f (got %.2f)" % [player.hit_stop_time_scale, Engine.time_scale])
	var waited := 0
	while GameState.is_hit_stopped() and waited < 60:
		await get_tree().physics_frame
		waited += 1
	var expected := ceili(player.hit_stop_duration * 60.0)
	check(Engine.time_scale == 1.0, "time scale restored")
	check(absi(waited - expected) <= 2, "hit-stop lasted ~%d frames (got %d)" % [expected, waited])


func test_hit_stop_cleared_by_pause_and_reload() -> void:
	# Overlapping requests take the longest remaining duration; they never add up.
	GameState.hit_stop(0.05, 0.1)
	GameState.hit_stop(0.05, 0.1)
	await frames(6)
	check(Engine.time_scale == 1.0, "overlapping hit-stops don't stack")
	GameState.hit_stop(0.0, 0.1)
	check(Engine.time_scale == 1.0, "zero duration is a no-op")
	# Expires even while the tree is paused.
	get_tree().paused = true
	GameState.hit_stop(0.05, 0.1)
	for i in 6:
		await get_tree().process_frame
	check(Engine.time_scale == 1.0, "hit-stop expires while paused")
	get_tree().paused = false
	# A level (re)load always starts at normal speed.
	GameState.hit_stop(30.0, 0.1)
	var level: Level = CavernScene.instantiate()
	_arena.add_child(level)
	check(Engine.time_scale == 1.0 and not GameState.is_hit_stopped(), "level load clears hit-stop")
	await frames(3)
	# Opening the pause menu cancels it.
	GameState.hit_stop(30.0, 0.1)
	var menu: PauseMenu = level.get_node("PauseMenu")
	menu.open()
	check(Engine.time_scale == 1.0 and not GameState.is_hit_stopped(), "pause clears hit-stop")
	menu.close()
	check(not get_tree().paused, "unpaused")
	# Dying mid hit-stop leaves nothing stuck.
	GameState.hit_stop(0.05, 0.1)
	var hitbox := Hitbox.new()
	hitbox.damage = 99
	_arena.add_child(hitbox)
	level.player.hurtbox.receive_hit(hitbox)
	await frames(8)
	check(level.player.state == Player.State.DEAD and Engine.time_scale == 1.0, "death leaves normal speed")
	GameState.hit_stop(30.0, 0.1)
	GameState.reset()
	check(Engine.time_scale == 1.0, "reset clears hit-stop")


func test_contact_damage_knockback_iframes() -> void:
	add_floor()
	var player := spawn_player()
	await frames(5)
	spawn_passive_enemy(Vector2(10, 0))
	await frames(3)
	check(player.health.current == 4, "contact deals 1 (hp=%d)" % player.health.current)
	check(player.state == Player.State.HURT, "player stunned")
	check(player.is_invulnerable(), "invulnerable after hit")
	await frames(20)
	check(player.position.x < -15.0, "knocked away from enemy (x=%.1f)" % player.position.x)
	player.position.x = 10.0  # shove back into the enemy during i-frames
	await frames(10)
	check(player.health.current == 4, "no damage during invulnerability")
	await frames(40)
	check(not player.is_invulnerable(), "invulnerability wears off")


func test_spikes_respawn_to_safe_ground() -> void:
	TerrainBuilder.build(make_layout("............\n............\n............\n#####^^^####\n############"), _arena)
	var player := spawn_player(Vector2(24, 48))
	await frames(10)
	press("move_right")
	for i in 120:
		await get_tree().physics_frame
		if player.health.current < 5:
			break
	release("move_right")
	check(player.health.current == 4, "spikes deal 1 (hp=%d)" % player.health.current)
	await frames(40)
	check(player.state == Player.State.NORMAL, "control returns after respawn")
	check(player.position.x < 5 * 16 + 6, "back on the ledge (x=%.1f)" % player.position.x)
	await frames(5)
	check(player.is_on_floor() and absf(player.position.y - 48.0) < 1.0,
		"standing on safe ground (y=%.1f)" % player.position.y)


func test_player_death() -> void:
	add_floor()
	var player := spawn_player()
	var died := [false]
	player.died.connect(func(): died[0] = true)
	await frames(5)
	var hitbox := Hitbox.new()
	hitbox.damage = 99
	_arena.add_child(hitbox)
	player.hurtbox.receive_hit(hitbox)
	check(died[0], "died emitted")
	check(player.state == Player.State.DEAD, "dead state")
	await frames(2)
	check(player.hurtbox.invulnerable, "corpse ignores hits")


func test_enemy_telegraph_charge_cycle() -> void:
	add_floor()
	var player := spawn_player(Vector2(-100, 0))
	var enemy: Gloomshell = GloomshellScene.instantiate()
	_arena.add_child(enemy)
	var seen: Array[int] = []
	for i in 170:
		await get_tree().physics_frame
		if seen.is_empty() or seen[-1] != enemy.state:
			seen.append(enemy.state)
	var expected := [Gloomshell.State.TELEGRAPH, Gloomshell.State.CHARGE, Gloomshell.State.RECOVER]
	var idx := 0
	for s in seen:
		if idx < expected.size() and s == expected[idx]:
			idx += 1
	check(idx == expected.size(), "telegraph -> charge -> recover (saw %s)" % [seen])
	check(player.health.current < 5, "charge hits the player")


func test_enemy_patrol_turns_at_ledges() -> void:
	add_floor(-60, 60)
	add_floor(-400, 400, 300)
	var enemy: Gloomshell = GloomshellScene.instantiate()
	enemy.detection_range = 0.0
	_arena.add_child(enemy)
	var turns := 0
	var last_dir := enemy.direction
	for i in 300:
		await get_tree().physics_frame
		if enemy.direction != last_dir:
			turns += 1
			last_dir = enemy.direction
	check(turns >= 2, "turned at both ledges (%d turns)" % turns)
	check(absf(enemy.position.y) < 1.0, "never fell off (y=%.1f)" % enemy.position.y)


func test_enemy_charge_ignores_stagger() -> void:
	add_floor()
	var enemy := spawn_passive_enemy(Vector2.ZERO)
	await frames(3)
	enemy._change_state(Gloomshell.State.CHARGE)
	var hitbox := Hitbox.new()
	_arena.add_child(hitbox)
	enemy.hurtbox.receive_hit(hitbox)
	check(enemy.health.current == 2, "charge still takes damage")
	check(enemy.state == Gloomshell.State.CHARGE, "charge is not interrupted")


# --- world objects ---------------------------------------------------------

func test_checkpoint_heals_and_sets_spawn() -> void:
	add_floor()
	var player := spawn_player(Vector2(-60, 0))
	await frames(3)
	player.health.take_damage(3)
	var checkpoint: Checkpoint = CheckpointScene.instantiate()
	checkpoint.checkpoint_id = &"test/shrine"
	checkpoint.position = Vector2(-60, 0)
	_arena.add_child(checkpoint)
	await frames(4)
	check(checkpoint.lit, "shrine lit")
	check(GameState.checkpoint_id == &"test/shrine", "respawn point set")
	check(GameState.checkpoint_position == Vector2(-60, 0), "respawn position stored")
	check(player.health.current == player.health.max_health, "fully healed")


func test_glimmer_pickup() -> void:
	add_floor()
	spawn_player()
	var glimmer: Glimmer = GlimmerScene.instantiate()
	glimmer.pickup_id = &"test/glimmer"
	glimmer.position = Vector2(0, -10)
	_arena.add_child(glimmer)
	await frames(4)
	check(GameState.is_collected(&"test/glimmer"), "collected")
	check(GameState.glimmer_count() == 1, "count is 1")
	check(not is_instance_valid(glimmer), "pickup removed")


# --- full level ------------------------------------------------------------

func test_level_loads() -> void:
	var level: Level = CavernScene.instantiate()
	_arena.add_child(level)
	await frames(30)
	var player := level.player
	check(is_instance_valid(player), "player spawned")
	check(player.is_on_floor(), "player lands at the start")
	check(player.position.distance_to(LevelLayout.cell_to_feet(Vector2i(3, 26))) < 2.0,
		"player at P (%s)" % player.position)
	check(get_tree().get_nodes_in_group("enemies").size() == 2, "2 enemies")
	var checkpoints := level.actors.get_children().filter(func(n): return n is Checkpoint)
	var glimmers := level.actors.get_children().filter(func(n): return n is Glimmer)
	check(checkpoints.size() == 2, "2 shrines")
	check(glimmers.size() == 2, "2 glimmers")
	check(player.camera.limit_right == 1280 and player.camera.limit_bottom == 480, "camera bounded to map")
	var display: HealthDisplay = level.hud.health_display
	check(display.current == 5 and display.maximum == 5, "HUD shows 5/5")
	player.health.take_damage(1)
	check(display.current == 4, "HUD follows damage")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		check((enemy as Gloomshell).is_on_floor(), "enemy %s on floor" % enemy.position)


func test_level_spawns_at_checkpoint() -> void:
	var spawn := LevelLayout.cell_to_feet(Vector2i(77, 22))
	GameState.activate_checkpoint(&"cavern_01/shrine_77_22", spawn)
	GameState.collect(&"cavern_01/glimmer_10_11")
	var level: Level = CavernScene.instantiate()
	_arena.add_child(level)
	await frames(5)
	check(level.player.position.distance_to(spawn) < 2.0, "spawned at shrine (%s)" % level.player.position)
	var glimmers := level.actors.get_children().filter(func(n): return n is Glimmer)
	check(glimmers.size() == 1, "collected glimmer stays collected")
	var lit := level.actors.get_children().filter(func(n): return n is Checkpoint and n.lit)
	check(lit.size() == 1, "only the active shrine is lit")


func test_pause_menu() -> void:
	var level: Level = CavernScene.instantiate()
	_arena.add_child(level)
	await frames(5)
	var menu: PauseMenu = level.get_node("PauseMenu")
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().paused and menu.visible, "pause action opens menu")
	var x := level.player.position.x
	press("move_right")
	await frames(10)
	release("move_right")
	check(level.player.position.x == x, "world frozen while paused")
	var unpause := InputEventAction.new()
	unpause.action = "pause"
	unpause.pressed = true
	Input.parse_input_event(unpause)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not get_tree().paused and not menu.visible, "pause action closes menu")
