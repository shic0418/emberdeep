class_name Player
extends CharacterBody2D
## The Wick: a small lantern-spirit. Handles movement, dash, melee and taking hits.
## Drawing lives in PlayerVisual; the attack hitbox and hurtbox are child scenes.

signal died

enum State { NORMAL, DASH, HURT, DEAD }

const PLATFORM_LAYER := 1 << 6  # physics layer 7, "one_way_platforms"
## Horizontal distance of the "feet" probes used to validate safe ground.
const SAFE_FOOT_OFFSET := 6.0

@export_group("Run")
@export var run_speed := 150.0
@export var ground_accel := 1600.0
@export var ground_decel := 2000.0
@export var air_accel := 1200.0
@export_group("Jump")
@export var jump_height := 72.0
@export var rise_gravity := 1400.0
@export var fall_gravity := 2000.0
@export var max_fall_speed := 460.0
## Upward velocity is multiplied by this when jump is released early.
@export var jump_cut_multiplier := 0.4
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
@export var drop_through_time := 0.25
@export_group("Dash")
@export var dash_speed := 330.0
@export var dash_duration := 0.15
@export var dash_cooldown := 0.4
@export_group("Combat")
@export var attack_active_time := 0.1
@export var attack_cooldown := 0.3
@export var attack_recoil := 120.0
@export var hurt_knockback := Vector2(170.0, -190.0)
@export var hurt_stun_time := 0.3
@export var hazard_freeze_time := 0.45
@export var invulnerability_time := 1.0
## Hit-stop on a successful melee hit: real seconds, and the time scale held meanwhile.
@export var hit_stop_duration := 0.06
@export var hit_stop_time_scale := 0.05
@export var impact_effect: PackedScene
@export_group("Down Strike")
## Upward speed after a down strike connects. Fixed height: releasing jump doesn't cut it.
@export var pogo_bounce_speed := 340.0
## How far the down strike's hitbox sits below the side/up attack pivot. Extra
## reach lets a strike made mid-fall connect before the body meets contact damage.
@export var down_strike_offset := 8.0

var state := State.NORMAL
var facing := 1
## Direction of the current/last attack: Vector2.RIGHT/LEFT/UP/DOWN. Read by the visual.
var attack_direction := Vector2.RIGHT
var attack_visual_time := 0.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _is_jumping := false
var _drop_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _can_air_dash := true
var _attack_timer := 0.0
var _attack_cooldown_timer := 0.0
var _can_pogo := false  # one bounce per down-strike activation
var _pivot_origin := Vector2.ZERO
var _hurt_timer := 0.0
var _invuln_timer := 0.0
var _hazard_respawn_pending := false
var _safe_position := Vector2.ZERO
var _grounded_time := 0.0

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Hitbox = $AttackPivot/AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackPivot/AttackHitbox/CollisionShape2D
@onready var camera: GameCamera = $Camera


func _ready() -> void:
	add_to_group("player")
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	attack_hitbox.hit_landed.connect(_on_attack_landed)
	attack_hitbox.active = false
	_pivot_origin = attack_pivot.position
	_safe_position = global_position


func is_invulnerable() -> bool:
	return _invuln_timer > 0.0 or state == State.DEAD


func is_attacking() -> bool:
	return _attack_timer > 0.0


func jump_velocity() -> float:
	return -sqrt(2.0 * rise_gravity * jump_height)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	match state:
		State.NORMAL:
			_process_normal(delta)
		State.DASH:
			_process_dash()
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			_apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
	move_and_slide()
	_track_safe_ground(delta)
	hurtbox.invulnerable = is_invulnerable()


func _tick_timers(delta: float) -> void:
	_coyote_timer -= delta
	_jump_buffer_timer -= delta
	_dash_cooldown_timer -= delta
	_attack_cooldown_timer -= delta
	attack_visual_time -= delta
	_invuln_timer -= delta
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			collision_mask |= PLATFORM_LAYER
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()


func _process_normal(delta: float) -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	if input_x != 0.0 and not is_attacking():
		facing = 1 if input_x > 0.0 else -1

	var on_floor := is_on_floor()
	var accel := air_accel
	if on_floor:
		accel = ground_accel if input_x != 0.0 else ground_decel
	velocity.x = move_toward(velocity.x, input_x * run_speed, accel * delta)

	if on_floor:
		_coyote_timer = coyote_time
		_can_air_dash = true
		_is_jumping = false
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	if _jump_buffer_timer > 0.0:
		if on_floor and Input.is_action_pressed("move_down") and _is_standing_on_platform():
			_drop_through()
		elif _coyote_timer > 0.0:
			_jump()

	_apply_gravity(delta)
	# Variable jump height: letting go of jump while rising cuts the ascent.
	if _is_jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut_multiplier
		_is_jumping = false

	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0 \
			and (on_floor or _can_air_dash):
		_start_dash(input_x)
	elif Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_start_attack(on_floor)


func _process_dash() -> void:
	_dash_timer -= get_physics_process_delta_time()
	velocity = Vector2(facing * dash_speed, 0.0)
	if _dash_timer <= 0.0 or is_on_wall():
		state = State.NORMAL
		velocity.x = facing * run_speed


func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	if _hazard_respawn_pending:
		velocity = Vector2.ZERO
		if _hurt_timer <= 0.0:
			_hazard_respawn_pending = false
			global_position = _safe_position
			camera.reset_smoothing()
			state = State.NORMAL
		return
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_decel * 0.25 * delta)
	if _hurt_timer <= 0.0:
		state = State.NORMAL


func _apply_gravity(delta: float) -> void:
	var gravity := rise_gravity if velocity.y < 0.0 else fall_gravity
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _jump() -> void:
	velocity.y = jump_velocity()
	_is_jumping = true
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _drop_through() -> void:
	_jump_buffer_timer = 0.0
	collision_mask &= ~PLATFORM_LAYER
	_drop_timer = drop_through_time
	position.y += 1.0


func _is_standing_on_platform() -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as CollisionObject2D
		if body and collision.get_normal().y < -0.7 and body.collision_layer & PLATFORM_LAYER:
			return true
	return false


func _start_dash(input_x: float) -> void:
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	if not is_on_floor():
		_can_air_dash = false
	state = State.DASH
	_is_jumping = false
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown


## Up aims up; Down aims down only in the air (on the ground it would just hit the floor).
func _start_attack(on_floor: bool) -> void:
	attack_pivot.position = _pivot_origin
	if Input.is_action_pressed("move_up"):
		attack_direction = Vector2.UP
		attack_pivot.scale = Vector2.ONE
		attack_pivot.rotation = -PI / 2.0
	elif Input.is_action_pressed("move_down") and not on_floor:
		attack_direction = Vector2.DOWN
		attack_pivot.scale = Vector2.ONE
		attack_pivot.rotation = PI / 2.0
		attack_pivot.position.y += down_strike_offset
	else:
		attack_direction = Vector2(facing, 0.0)
		attack_pivot.scale = Vector2(facing, 1.0)
		attack_pivot.rotation = 0.0
	attack_hitbox.knockback_direction = attack_direction
	attack_hitbox.active = true
	_can_pogo = attack_direction == Vector2.DOWN
	_attack_timer = attack_active_time
	_attack_cooldown_timer = attack_cooldown
	attack_visual_time = 0.15


func _end_attack() -> void:
	_attack_timer = 0.0
	_can_pogo = false
	attack_hitbox.active = false


func _on_attack_landed(target: Hurtbox) -> void:
	camera.shake(2.0, 0.1)
	GameState.hit_stop(hit_stop_duration, hit_stop_time_scale)
	_spawn_impact(target)
	if attack_direction.x != 0.0:
		velocity.x = -attack_direction.x * attack_recoil
	elif _can_pogo:
		# Bounce off whatever the down strike hit. The air dash is not refunded,
		# so pogoing can't chain into extra air mobility.
		_can_pogo = false
		velocity.y = -pogo_bounce_speed
		_is_jumping = false


func _spawn_impact(target: Hurtbox) -> void:
	if impact_effect == null or get_parent() == null:
		return
	var target_center := target.global_position
	for child in target.get_children():
		if child is CollisionShape2D:
			target_center = (child as Node2D).global_position
			break
	var burst: ImpactBurst = impact_effect.instantiate()
	burst.direction = attack_direction
	get_parent().add_child(burst)
	burst.global_position = attack_shape.global_position.lerp(target_center, 0.6)


func _on_hit_received(hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	health.take_damage(hitbox.damage)
	_invuln_timer = invulnerability_time
	hurtbox.invulnerable = true
	_end_attack()
	camera.shake(5.0, 0.25)
	if health.is_dead():
		return  # _on_died already switched state
	state = State.HURT
	_is_jumping = false
	if hitbox.is_hazard:
		_hazard_respawn_pending = true
		_hurt_timer = hazard_freeze_time
	else:
		var dir := hitbox.knockback_for(global_position)
		var side := signf(dir.x) if dir.x != 0.0 else float(-facing)
		velocity = Vector2(side * hurt_knockback.x, hurt_knockback.y)
		_hurt_timer = hurt_stun_time


func _on_died() -> void:
	state = State.DEAD
	_hazard_respawn_pending = false
	hurtbox.invulnerable = true
	died.emit()


## Remembers where the player last stood on solid footing, for hazard respawns.
## Both feet must be supported, so a respawn never lands on a crumbling lip.
func _track_safe_ground(delta: float) -> void:
	if state == State.NORMAL and is_on_floor() and _is_fully_supported():
		_grounded_time += delta
		if _grounded_time >= 0.1:
			_safe_position = global_position
	else:
		_grounded_time = 0.0


func _is_fully_supported() -> bool:
	var space := get_world_2d().direct_space_state
	for side in [-SAFE_FOOT_OFFSET, SAFE_FOOT_OFFSET]:
		var from := global_position + Vector2(side, -2.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 6), collision_mask)
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return false
	return true
