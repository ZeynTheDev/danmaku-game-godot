extends Node2D

const POINT_ITEM_SCORE := 300
const POWER_ITEM_AMOUNT := 5

@onready var _player: Player = $Player
@onready var _bullets: BulletManager = $BulletManager
@onready var _spawner: WaveSpawner = $WaveSpawner

var _score := 0
var _graze := 0
var _game_over := false
var _waves_done := false
var _debug_label := Label.new()

## Connects all systems together (bullets, spawner, player signals) and spawns the player.
func _ready() -> void:
	# Temporary debug text, replaced by a real HUD in M5
	_debug_label.position = Vector2(680, 40)
	add_child(_debug_label)

	_bullets.player = _player
	_spawner.manager = _bullets
	_spawner.target = _player

	_bullets.player_hit.connect(_player.take_hit)
	_bullets.player_grazed.connect(_on_player_grazed)
	_player.respawned.connect(_bullets.clear)   # classic: dying clears the screen
	_player.died.connect(_on_player_died)
	_spawner.enemy_died.connect(_on_enemy_died)
	_spawner.waves_finished.connect(_on_waves_finished)

	_player.spawn_position = Vector2(Game.PLAYFIELD.get_center().x, Game.PLAYFIELD.end.y - 80)
	_player.respawn()

## Refreshes the debug text every frame (lives, power, score, graze, bullet count, FPS).
func _process(_delta: float) -> void:
	if _game_over:
		return
	_debug_label.text = "Lives: %d\nPower: %d / %d\nScore: %d\nGraze: %d\nBullets: %d\nFPS: %d%s" % [
		_player.lives, _player.power, Player.MAX_POWER, _score, _graze,
		_bullets.bullets.size(), Engine.get_frames_per_second(),
		"\n\nWAVES CLEARED" if _waves_done else ""
	]

## Counts a graze (a bullet that passed close to the player's hitbox).
func _on_player_grazed() -> void:
	_graze += 1

## Awards the kill score and creates the enemy's drops, scattered a little around where it died.
func _on_enemy_died(pos: Vector2, drops: Dictionary, score: int) -> void:
	_score += score
	for i in drops.get("power", 0):
		_spawn_item(Item.Kind.POWER, pos + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0)))
	for i in drops.get("point", 0):
		_spawn_item(Item.Kind.POINT, pos + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0)))

## Creates one item at a position and listens for it being collected.
func _spawn_item(kind: Item.Kind, pos: Vector2) -> void:
	var item := Item.new()
	item.kind = kind
	item.player = _player
	item.position = pos
	item.collected.connect(_on_item_collected)
	add_child(item)

## Applies a collected item: power items add power, point items add score.
func _on_item_collected(kind: Item.Kind) -> void:
	match kind:
		Item.Kind.POWER:
			_player.add_power(POWER_ITEM_AMOUNT)
		Item.Kind.POINT:
			_score += POINT_ITEM_SCORE

## Remembers that every wave has been cleared (shown in the debug text for now).
func _on_waves_finished() -> void:
	_waves_done = true

## Shows the game-over text and reloads the scene after a short pause.
func _on_player_died() -> void:
	_game_over = true
	_debug_label.text = "GAME OVER\nRestarting..."
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

## Draws the playfield background and border.
func _draw() -> void:
	draw_rect(Game.PLAYFIELD, Color(0.08, 0.08, 0.14))
	draw_rect(Game.PLAYFIELD, Color(0.4, 0.4, 0.6), false, 2.0)
