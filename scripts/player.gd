class_name Player
extends Area2D

## Emitted after the player is placed back at the spawn point (also on the first spawn).
signal respawned
## Emitted when the last life is lost.
signal died

const HITBOX_RADIUS := 3.0
const SHOT_SCENE := preload("res://scenes/player_shot.tscn")
const SHOT_SPEED := 900.0
const MAX_POWER := 100
## Power values at which the player gains one extra shot (tiers 1, 2 and 3).
const POWER_TIERS := [25, 50, 80]

@export var speed_normal := 300.0
@export var speed_focus := 130.0
@export var fire_rate := 12.0   # shots per second
@export var margin := 14.0      # keeps the sprite inside the playfield edge
@export var start_lives := 3
@export var respawn_invincibility := 2.0   # seconds

var lives := 0
var power := 0
var spawn_position := Vector2.ZERO

var _fire_cooldown := 0.0
var _focused := false
var _invincible_timer := 0.0

## Sets the starting lives and draws the player above enemies and items.
func _ready() -> void:
	lives = start_lives
	z_index = 2

## Runs every frame: updates invincibility, focus, movement and shooting (skipped once dead).
func _process(delta: float) -> void:
	if lives <= 0:
		return
	_update_invincibility(delta)
	_update_focus()
	_move(delta)
	_handle_shooting(delta)

## True when a bullet is allowed to hurt the player (alive and not invincible).
func is_vulnerable() -> bool:
	return lives > 0 and _invincible_timer <= 0.0

## Called when a bullet hits the hitbox: costs a life, then respawns or ends the run.
func take_hit() -> void:
	if not is_vulnerable():
		return
	lives -= 1
	if lives <= 0:
		visible = false
		died.emit()
	else:
		respawn()

## Moves the player back to the spawn point and starts the invincibility timer.
func respawn() -> void:
	position = spawn_position
	_invincible_timer = respawn_invincibility
	respawned.emit()

## Adds power (capped at MAX_POWER). Higher power unlocks more shots, see get_power_tier().
func add_power(amount: int) -> void:
	power = mini(power + amount, MAX_POWER)

## Returns 0-3: how many entries of POWER_TIERS the current power has reached.
func get_power_tier() -> int:
	var tier := 0
	for threshold in POWER_TIERS:
		if power >= threshold:
			tier += 1
	return tier

## Counts down the invincibility timer and makes the ship blink while it runs.
func _update_invincibility(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		# Blink while invincible
		modulate.a = 0.35 if int(_invincible_timer * 12.0) % 2 == 0 else 1.0
		if _invincible_timer <= 0.0:
			modulate.a = 1.0

## Tracks the focus key and only redraws when the look changes (hitbox shown or hidden).
func _update_focus() -> void:
	var now_focused := Input.is_action_pressed("focus")
	if now_focused != _focused:
		_focused = now_focused
		queue_redraw()

## Moves the player from input (slower while focused) and clamps it inside the playfield.
func _move(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := speed_focus if _focused else speed_normal
	position += dir * speed * delta

	var min_pos := Game.PLAYFIELD.position + Vector2(margin, margin)
	var max_pos := Game.PLAYFIELD.end - Vector2(margin, margin)
	position = position.clamp(min_pos, max_pos)

## Fires shots at fire_rate while the shoot key is held, using a cooldown timer.
func _handle_shooting(delta: float) -> void:
	_fire_cooldown -= delta
	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		_fire_cooldown = 1.0 / fire_rate
		_shoot()

## Fires 2 + power tier shots in a row. Unfocused shots fan out slightly,
## and focused shots are packed tight and straight for concentrated damage.
func _shoot() -> void:
	var count := 2 + get_power_tier()
	var spacing := 8.0 if _focused else 16.0    # horizontal gap between shots
	var fan_deg := 0.0 if _focused else 4.0     # angle between neighbouring shots
	for i in count:
		# t is the shot's slot, centered on zero: -0.5/+0.5 for two shots, -1/0/+1 for three...
		var t := i - (count - 1) / 2.0
		var shot := SHOT_SCENE.instantiate()
		shot.position = position + Vector2(t * spacing, -16)
		shot.rotation = deg_to_rad(t * fan_deg)
		shot.velocity = Vector2.UP.rotated(shot.rotation) * SHOT_SPEED
		get_tree().current_scene.add_child(shot)

## Draws the ship, plus the white hitbox marker while focusing.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 12, Color(0.9, 0.3, 0.4))
	if _focused:
		# Show the hitbox while focusing
		draw_circle(Vector2.ZERO, 4, Color.WHITE)
		draw_arc(Vector2.ZERO, 4, 0.0, TAU, 24, Color(1, 0.2, 0.2), 1.5)
