class_name Gloomshell
extends CharacterBody2D
## Armored cave crawler. Patrols a ledge; when the player comes close on the
## same level it rears up (telegraph), then charges. Its shell makes it ignore
## stagger while charging, and it is left exposed for a moment afterward.

signal defeated

enum State { PATROL, TELEGRAPH, CHARGE, RECOVER, HURT, DEAD }

@export var patrol_speed := 32.0
@export var charge_speed := 230.0
@export var detection_range := 140.0
@export var detection_height := 40.0
@export var telegraph_time := 0.55
@export var charge_time := 0.8
@export var recover_time := 0.8
@export var attack_cooldown := 1.0
@export var hurt_time := 0.22
@export var hurt_knockback := 150.0
@export var gravity := 1400.0

var state := State.PATROL
var direction := -1
var state_time := 0.0  # seconds spent in the current state
var flash_time := 0.0  # damage flash, read by the visual

var _cooldown_timer := 0.0

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox
@onready var ledge_check: RayCast2D = $LedgeCheck


func _ready() -> void:
	add_to_group("enemies")
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	_update_ledge_check()


func _physics_process(delta: float) -> void:
	state_time += delta
	_cooldown_timer -= delta
	flash_time -= delta
	velocity.y = minf(velocity.y + gravity * delta, 500.0)

	match state:
		State.PATROL:
			velocity.x = direction * patrol_speed
			if is_on_floor() and _blocked_ahead():
				_turn_around()
			elif _cooldown_timer <= 0.0 and _player_in_range():
				_face_player()
				_change_state(State.TELEGRAPH)
		State.TELEGRAPH:
			velocity.x = 0.0
			if state_time >= telegraph_time:
				_change_state(State.CHARGE)
		State.CHARGE:
			velocity.x = direction * charge_speed
			if state_time >= charge_time or (is_on_floor() and _blocked_ahead()):
				velocity.x = 0.0
				_change_state(State.RECOVER)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if state_time >= recover_time:
				_cooldown_timer = attack_cooldown
				_change_state(State.PATROL)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if state_time >= hurt_time:
				_cooldown_timer = attack_cooldown * 0.5
				_change_state(State.PATROL)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

	move_and_slide()


func _change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0


func _blocked_ahead() -> bool:
	return is_on_wall() or not ledge_check.is_colliding()


func _turn_around() -> void:
	direction = -direction
	_update_ledge_check()


func _update_ledge_check() -> void:
	ledge_check.position.x = direction * 9.0
	ledge_check.force_raycast_update()


func _find_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _player_in_range() -> bool:
	var player := _find_player()
	if player == null or player.state == Player.State.DEAD:
		return false
	var offset := player.global_position - global_position
	return absf(offset.x) <= detection_range and absf(offset.y) <= detection_height


func _face_player() -> void:
	var player := _find_player()
	var side := 1 if player.global_position.x >= global_position.x else -1
	if side != direction:
		_turn_around()


func _on_hit_received(hitbox: Hitbox) -> void:
	health.take_damage(hitbox.damage)
	flash_time = 0.12
	if health.is_dead():
		return
	# The shell holds firm mid-charge; otherwise the hit staggers it.
	if state == State.CHARGE:
		return
	var push := hitbox.knockback_for(global_position)
	velocity.x = signf(push.x) * hurt_knockback if push.x != 0.0 else 0.0
	velocity.y = -90.0 if push.y >= 0.0 else -180.0
	_change_state(State.HURT)


func _on_died() -> void:
	_change_state(State.DEAD)
	contact_hitbox.active = false
	hurtbox.set_deferred("monitorable", false)
	velocity.y = -160.0
	defeated.emit()
	get_tree().create_timer(0.9).timeout.connect(queue_free)
