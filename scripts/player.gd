class_name Player
extends Area2D

## Emitted after the player is placed back at the spawn point (also on the first spawn).
signal respawned
## Emitted when the last life is lost.
signal died
## Emitted when a life is lost (after the death-bomb window ran out): where it happened and how much power was lost.
signal life_lost(death_position: Vector2, power_lost: int)
## Emitted when a bomb is activated (including death-bombs). The stage creates the bomb effect.
signal bombed

const HITBOX_RADIUS := 3.0
const SHOT_SCENE := preload("res://scenes/player_shot.tscn")
const SHOT_SPEED := 900.0
const MAX_POWER := 128
const POWER_LOSS_ON_DEATH := 20
const DEATHBOMB_WINDOW := 0.3   # seconds after a hit during which a bomb still saves the life
const BOMB_DURATION := 3.0      # how long a bomb lasts (seconds)
const BOMB_GRACE := 0.5         # extra invincibility after a bomb ends (seconds)
const MAX_LIVES := 5
const MAX_BOMBS := 7
const COLLECT_ALL_MIN_POWER := 100   # power needed for the "collect all items" line to work

@export var speed_normal := 300.0
@export var speed_focus := 130.0
@export var fire_rate := 12.0   # shots per second
@export var margin := 14.0      # keeps the sprite inside the playfield edge
@export var start_lives := 3
@export var start_bombs := 3
@export_range(0, 128) var start_power := 32   # handy for testing power levels (128 = MAX_POWER)
@export var respawn_invincibility := 2.0   # seconds

## Shot setup used by _shoot(). See player_kit.gd for the format.
var kit: Dictionary = PlayerKit.AMULET

var lives := 0
var bombs := 0
var power := 0
var spawn_position := Vector2.ZERO

var _fire_cooldown := 0.0
var _focused := false
var _invincible_timer := 0.0
var _bomb_timer := 0.0        # > 0 while a bomb is active
var _deathbomb_timer := 0.0   # > 0 while waiting to see if the player bombs after being hit

## Sets the starting lives, bombs and power, and draws the player above enemies and items.
func _ready() -> void:
	lives = start_lives
	bombs = start_bombs
	power = start_power
	z_index = 2

## Runs every frame: updates timers, handles the bomb key before the death-bomb window can expire,
## then focus, movement and shooting (skipped once dead).
func _process(delta: float) -> void:
	if lives <= 0:
		return
	_update_bomb_timer(delta)
	_update_invincibility(delta)
	_handle_bomb()
	_update_deathbomb(delta)
	if lives <= 0:
		return   # the death-bomb window may have just ended the run
	_update_focus()
	_move(delta)
	_handle_shooting(delta)

## True when a bullet is allowed to hurt the player (alive, not invincible, and not already hit).
func is_vulnerable() -> bool:
	return lives > 0 and _invincible_timer <= 0.0 and _deathbomb_timer <= 0.0

## True while the player is at MAX power (the kit's damage bonus applies).
func is_max_power() -> bool:
	return power >= MAX_POWER

## Called when a bullet hits the hitbox. Instead of losing the life immediately, this starts the
## short death-bomb window: a bomb pressed in time saves the life, otherwise _lose_life() runs.
func take_hit() -> void:
	if not is_vulnerable():
		return
	_deathbomb_timer = DEATHBOMB_WINDOW
	self_modulate = Color(1.0, 0.45, 0.45)   # red tint while the window is open

## Moves the player back to the spawn point and starts the invincibility timer.
func respawn() -> void:
	position = spawn_position
	_invincible_timer = respawn_invincibility
	respawned.emit()

## Adds power (capped at MAX_POWER). Higher power unlocks stronger shot levels, see get_power_level().
func add_power(amount: int) -> void:
	var before := power
	power = mini(power + amount, MAX_POWER)
	if power != before:
		queue_redraw()   # the gold MAX ring may need to appear

## Adds one life (up to MAX_LIVES). Returns false if the player is out of lives or already at the cap.
func add_life() -> bool:
	if lives <= 0 or lives >= MAX_LIVES:
		return false
	lives += 1
	return true

## Adds one bomb (up to MAX_BOMBS). Returns false if the player is already at the cap.
func add_bomb() -> bool:
	if bombs >= MAX_BOMBS:
		return false
	bombs += 1
	return true

## True when flying above the collect line pulls in every item. For now this needs COLLECT_ALL_MIN_POWER.
## A later stage-dependent rule (for example, ignoring the power requirement in late stages) belongs here.
func can_collect_all_items() -> bool:
	return power >= COLLECT_ALL_MIN_POWER

## Returns the index of the highest shot level in the kit that the current power has reached.
func get_power_level() -> int:
	var levels: Array = kit["levels"]
	var result := 0
	for i in levels.size():
		if power >= levels[i]["power"]:
			result = i
	return result

## Actually loses a life: removes power (up to POWER_LOSS_ON_DEATH), tells the stage (so it can drop
## power items), then either ends the run or respawns with bombs restored to at least start_bombs.
func _lose_life() -> void:
	var power_lost := mini(power, POWER_LOSS_ON_DEATH)
	power -= power_lost
	queue_redraw()   # the gold MAX ring may need to disappear
	life_lost.emit(position, power_lost)
	lives -= 1
	if lives <= 0:
		visible = false
		died.emit()
	else:
		bombs = maxi(bombs, start_bombs)
		respawn()

## Uses a bomb when the bomb key is pressed (and none is active). Makes the player invincible for the
## bomb's duration plus a short grace period. If pressed inside the death-bomb window, it cancels the hit.
func _handle_bomb() -> void:
	if not Input.is_action_just_pressed("bomb"):
		return
	if bombs <= 0 or _bomb_timer > 0.0:
		return
	bombs -= 1
	_bomb_timer = BOMB_DURATION
	_invincible_timer = maxf(_invincible_timer, BOMB_DURATION + BOMB_GRACE)
	if _deathbomb_timer > 0.0:
		_deathbomb_timer = 0.0
		self_modulate = Color.WHITE
	bombed.emit()

## Counts down the death-bomb window. When it runs out without a bomb, the life is lost.
func _update_deathbomb(delta: float) -> void:
	if _deathbomb_timer <= 0.0:
		return
	_deathbomb_timer -= delta
	if _deathbomb_timer <= 0.0:
		self_modulate = Color.WHITE
		_lose_life()

## Counts down the time a bomb stays active.
func _update_bomb_timer(delta: float) -> void:
	if _bomb_timer > 0.0:
		_bomb_timer -= delta

## Counts down the invincibility timer and makes the ship blink while it runs (not during a bomb).
func _update_invincibility(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		if _bomb_timer > 0.0:
			modulate.a = 1.0
		else:
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

## Fires every line of the kit's current power level. Each line has its own offset, angle, damage,
## speed and homing flag (see player_kit.gd). Focusing packs the lines tighter and straighter.
## At MAX power, all damage is multiplied by the kit's "max_power_damage_multiplier".
func _shoot() -> void:
	var level: Dictionary = kit["levels"][get_power_level()]
	var damage_mult: float = kit.get("max_power_damage_multiplier", 1.0) if is_max_power() else 1.0
	for line in level["lines"]:
		var x: float = line.get("focus_x", line["x"] * 0.5) if _focused else line["x"]
		var angle_deg: float = line.get("focus_angle", 0.0) if _focused else line.get("angle", 0.0)

		var shot := SHOT_SCENE.instantiate()
		shot.position = position + Vector2(x, -16)
		shot.rotation = deg_to_rad(angle_deg)
		shot.velocity = Vector2.UP.rotated(shot.rotation) * line.get("speed", SHOT_SPEED)
		shot.damage = line.get("damage", 1.0) * damage_mult
		shot.homing = line.get("homing", false)
		get_tree().current_scene.add_child(shot)

## Draws the ship, a gold ring at MAX power, and the white hitbox marker while focusing.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 12, Color(0.9, 0.3, 0.4))
	if is_max_power():
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.3), 2.0)
	if _focused:
		# Show the hitbox while focusing
		draw_circle(Vector2.ZERO, 4, Color.WHITE)
		draw_arc(Vector2.ZERO, 4, 0.0, TAU, 24, Color(1, 0.2, 0.2), 1.5)
