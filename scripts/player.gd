extends Area2D

const SHOT_SCENE := preload("res://scenes/player_shot.tscn")

@export var speed_normal := 300.0
@export var speed_focus := 130.0
@export var fire_rate := 16.0   # shots per second
@export var margin := 14.0      # keeps the sprite inside the playfield edge

var _fire_cooldown := 0.0
var _focused := false

func _process(delta: float) -> void:
	_update_focus()
	_move(delta)
	_handle_shooting(delta)

func _update_focus() -> void:
	var now_focused := Input.is_action_pressed("focus")
	if now_focused != _focused:
		_focused = now_focused
		queue_redraw()  # only redraw when the look changes

func _move(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := speed_focus if _focused else speed_normal
	position += dir * speed * delta

	var min_pos := Game.PLAYFIELD.position + Vector2(margin, margin)
	var max_pos := Game.PLAYFIELD.end - Vector2(margin, margin)
	position = position.clamp(min_pos, max_pos)

func _handle_shooting(delta: float) -> void:
	_fire_cooldown -= delta
	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		_fire_cooldown = 1.0 / fire_rate
		_shoot()

func _shoot() -> void:
	# Shots are wider apart normally and tighter when focused
	var offset := 5.0 if _focused else 12.0
	for side in [-1, 1]:
		var shot := SHOT_SCENE.instantiate()
		shot.position = position + Vector2(side * offset, -16)
		get_tree().current_scene.add_child(shot)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12, Color(0.9, 0.3, 0.4))
	if _focused:
		# Show the hitbox while focusing
		draw_circle(Vector2.ZERO, 4, Color.WHITE)
		draw_arc(Vector2.ZERO, 4, 0.0, TAU, 24, Color(1, 0.2, 0.2), 1.5)
