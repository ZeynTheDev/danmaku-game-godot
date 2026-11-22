extends Node2D

const POINT_ITEM_SCORE := 300
const POWER_ITEM_AMOUNT := 5
## Fraction of the power lost on death that comes back as power items (20 lost = 15 recovered).
const DEATH_DROP_RATIO := 0.75
const BULLET_WIPE_SCORE := 10          # points per bullet a bomb clears
const EXTEND_SCORE_INTERVAL := 10000   # the player earns a free life every time the score passes a multiple of this
const OVERFLOW_ITEM_SCORE := 2000      # bonus points when a life or bomb is earned at the cap

@onready var _player: Player = $Player
@onready var _bullets: BulletManager = $BulletManager
@onready var _spawner: WaveSpawner = $WaveSpawner

var _score := 0
var _next_extend := EXTEND_SCORE_INTERVAL
var _graze := 0
var _game_over := false
var _waves_done := false
var _collect_line_active := false
var _debug_label := Label.new()

## Connects all systems together (bullets, spawner, player signals) and spawns the player.
func _ready() -> void:
	# Temporary debug text, replaced by a real HUD in M7
	_debug_label.position = Vector2(680, 40)
	add_child(_debug_label)

	_bullets.player = _player
	_spawner.manager = _bullets
	_spawner.target = _player

	_bullets.player_hit.connect(_player.take_hit)
	_bullets.player_grazed.connect(_on_player_grazed)
	_player.respawned.connect(_bullets.clear)   # classic: dying clears the screen (no score for it)
	_player.died.connect(_on_player_died)
	_player.life_lost.connect(_on_player_life_lost)
	_player.bombed.connect(_on_player_bombed)
	_spawner.enemy_died.connect(_on_enemy_died)
	_spawner.waves_finished.connect(_on_waves_finished)

	_player.spawn_position = Vector2(Game.PLAYFIELD.get_center().x, Game.PLAYFIELD.end.y - 80)
	_player.respawn()

## Refreshes the debug text every frame, and redraws the collect line when collect-all turns on or off.
func _process(_delta: float) -> void:
	if _game_over:
		return

	var collect_active := _player.can_collect_all_items()
	if collect_active != _collect_line_active:
		_collect_line_active = collect_active
		queue_redraw()

	_debug_label.text = "Lives: %d\nBombs: %d\nPower: %d / %d%s\nScore: %d\nNext extend: %d\nGraze: %d\nBullets: %d\nFPS: %d%s" % [
		_player.lives, _player.bombs, _player.power, Player.MAX_POWER,
		"  MAX!" if _player.is_max_power() else "",
		_score, _next_extend, _graze, _bullets.bullets.size(), Engine.get_frames_per_second(),
		"\n\nWAVES CLEARED" if _waves_done else ""
	]

## Adds score and grants a free life each time the score passes the next extend threshold.
func _add_score(amount: int) -> void:
	_score += amount
	while _score >= _next_extend:
		_next_extend += EXTEND_SCORE_INTERVAL
		_grant_life()

## Gives the player one extra life, or a score bonus instead when the life cap is reached.
## (The bonus is added directly, so it can't trigger another extend in a loop.)
func _grant_life() -> void:
	if not _player.add_life():
		_score += OVERFLOW_ITEM_SCORE

## Counts a graze (a bullet that passed close to the player's hitbox).
func _on_player_grazed() -> void:
	_graze += 1

## Creates the bomb effect at the player's position when a bomb is activated, and scores the bullets it wipes.
func _on_player_bombed() -> void:
	var bomb := Bomb.new()
	bomb.player = _player
	bomb.bullets = _bullets
	bomb.position = _player.position
	bomb.bullets_wiped.connect(_on_bullets_wiped)
	add_child(bomb)

## Awards BULLET_WIPE_SCORE points for every bullet a bomb cleared.
func _on_bullets_wiped(count: int) -> void:
	_add_score(count * BULLET_WIPE_SCORE)

## Drops power items where the player died, worth DEATH_DROP_RATIO of the power that was lost.
func _on_player_life_lost(death_position: Vector2, power_lost: int) -> void:
	var count := floori(power_lost * DEATH_DROP_RATIO / POWER_ITEM_AMOUNT)
	for i in count:
		_spawn_item(Item.Kind.POWER, death_position + Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0)))

## Awards the kill score and creates the enemy's rolled drops (a dictionary like {"power": 2, "life": 1}),
## scattered a little around where it died. Unknown drop names are ignored.
func _on_enemy_died(pos: Vector2, drops: Dictionary, score: int) -> void:
	_add_score(score)
	for key in drops:
		if not Item.DROP_KEYS.has(key):
			continue
		for i in drops[key]:
			_spawn_item(Item.DROP_KEYS[key], pos + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0)))

## Creates one item at a position and listens for it being collected.
func _spawn_item(kind: Item.Kind, pos: Vector2) -> void:
	var item := Item.new()
	item.kind = kind
	item.player = _player
	item.position = pos
	item.collected.connect(_on_item_collected)
	add_child(item)

## Applies a collected item: power adds power, points add score, bombs and lives add a bomb or life
## (or a bonus if the player is already at the cap).
func _on_item_collected(kind: Item.Kind) -> void:
	match kind:
		Item.Kind.POWER:
			_player.add_power(POWER_ITEM_AMOUNT)
		Item.Kind.POINT:
			_add_score(POINT_ITEM_SCORE)
		Item.Kind.BOMB:
			if not _player.add_bomb():
				_score += OVERFLOW_ITEM_SCORE
		Item.Kind.LIFE:
			_grant_life()

## Remembers that every wave has been cleared (shown in the debug text for now).
func _on_waves_finished() -> void:
	_waves_done = true

## Shows the game-over text and reloads the scene after a short pause.
func _on_player_died() -> void:
	_game_over = true
	_debug_label.text = "GAME OVER\nRestarting..."
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

## Draws the playfield background and border, plus a dashed gold line at the collect line
## while the player has enough power for collect-all.
func _draw() -> void:
	draw_rect(Game.PLAYFIELD, Color(0.08, 0.08, 0.14))
	draw_rect(Game.PLAYFIELD, Color(0.4, 0.4, 0.6), false, 2.0)
	if _collect_line_active:
		var y := Game.PLAYFIELD.position.y + Item.COLLECT_LINE_HEIGHT
		draw_dashed_line(Vector2(Game.PLAYFIELD.position.x, y), Vector2(Game.PLAYFIELD.end.x, y),
			Color(1.0, 0.85, 0.3, 0.5), 1.5, 8.0)
