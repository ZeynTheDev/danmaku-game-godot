extends Node2D

@onready var _player: Player = $Player
@onready var _bullets: BulletManager = $BulletManager
@onready var _emitter: PatternEmitter = $Emitter

var _graze := 0
var _game_over := false
var _debug_label := Label.new()

func _ready() -> void:
	# Temporary debug text, replaced by a real HUD in M5
	_debug_label.position = Vector2(680, 40)
	add_child(_debug_label)

	_bullets.player = _player
	_emitter.manager = _bullets
	_emitter.target = _player
	_emitter.position = Vector2(Game.PLAYFIELD.get_center().x, Game.PLAYFIELD.position.y + 100)

	_bullets.player_hit.connect(_player.take_hit)
	_bullets.player_grazed.connect(_on_player_grazed)
	_player.respawned.connect(_bullets.clear)   # classic: dying clears the screen
	_player.died.connect(_on_player_died)

	_player.spawn_position = Vector2(Game.PLAYFIELD.get_center().x, Game.PLAYFIELD.end.y - 80)
	_player.respawn()

func _process(_delta: float) -> void:
	if _game_over:
		return
	_debug_label.text = "Lives: %d\nGraze: %d\nBullets: %d\nFPS: %d" % [
		_player.lives, _graze, _bullets.bullets.size(), Engine.get_frames_per_second()
	]

func _on_player_grazed() -> void:
	_graze += 1

func _on_player_died() -> void:
	_game_over = true
	_debug_label.text = "GAME OVER\nRestarting..."
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _draw() -> void:
	draw_rect(Game.PLAYFIELD, Color(0.08, 0.08, 0.14))
	draw_rect(Game.PLAYFIELD, Color(0.4, 0.4, 0.6), false, 2.0)
