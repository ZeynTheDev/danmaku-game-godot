class_name WaveSpawner
extends Node2D

## Emitted when a spawned enemy is killed. The stage uses it to award score and create drops.
signal enemy_died(position: Vector2, drops: Dictionary, score: int)
## Emitted once every wave has spawned and every enemy is gone (killed or escaped).
signal waves_finished

var manager: BulletManager
var target: Node2D

## Reusable enemy presets. Keys match the config read by Enemy.setup().
var enemy_types := {
	# Falls straight down and shoots a fan of bullets at the player
	"fairy_aimed": {
		"hp": 8, "score": 100,
		"drops": {"point": 1},
		"path": Enemy.PathType.STRAIGHT,
		"velocity": Vector2(0, 70),
		"pattern": PatternEmitter.Pattern.AIMED,
		"interval": 1.2, "count": 3, "spread": 30.0, "bullet_speed": 170.0,
		"color": Color(0.4, 0.7, 1.0), "bullet_color": Color(0.5, 0.8, 1.0),
	},
	# Sways side to side while dropping small rings
	"fairy_sine": {
		"hp": 10, "score": 150,
		"drops": {"point": 1},
		"path": Enemy.PathType.SINE,
		"velocity": Vector2(0, 80),
		"sway_amplitude": 80.0, "sway_frequency": 2.0,
		"pattern": PatternEmitter.Pattern.RING,
		"interval": 1.5, "count": 8, "bullet_speed": 120.0,
		"color": Color(0.5, 0.9, 0.5), "bullet_color": Color(0.6, 1.0, 0.6),
	},
	# Tougher: stops, fires a spiral for a few seconds, then leaves. Drops power.
	"fairy_hover": {
		"hp": 60, "score": 500,
		"drops": {"power": 3, "point": 3},
		"path": Enemy.PathType.HOVER,
		"velocity": Vector2(0, 100), "hover_y": 150.0, "hover_time": 6.0,
		"pattern": PatternEmitter.Pattern.SPIRAL,
		"interval": 0.08, "count": 3, "spin": 11.0, "bullet_speed": 130.0,
		"color": Color(0.9, 0.5, 0.7), "bullet_color": Color(1.0, 0.6, 0.8),
	},
}

## The stage script. Each wave spawns `count` enemies of `type`, `interval` seconds apart.
## x is where the first enemy appears across the playfield (0 = left edge, 1 = right edge),
## and x_step shifts each following enemy. `override` changes any preset setting for this wave only.
var waves := [
	{"time": 1.0, "type": "fairy_aimed", "count": 5, "interval": 0.6, "x": 0.2, "x_step": 0.15},
	{"time": 7.0, "type": "fairy_sine", "count": 6, "interval": 0.5, "x": 0.5},
	{"time": 14.0, "type": "fairy_hover", "count": 2, "interval": 2.0, "x": 0.3, "x_step": 0.4},
	{"time": 24.0, "type": "fairy_aimed", "count": 8, "interval": 0.4, "x": 0.1, "x_step": 0.1,
		"override": {"bullet_speed": 220.0}},
]

var _events: Array = []   # every single enemy spawn, sorted by time
var _time := 0.0
var _next := 0            # index of the next event to spawn
var _alive := 0
var _finished := false

## Expands the wave list into individual spawn events.
func _ready() -> void:
	_build_events()

## Advances the stage timer, spawns enemies that are due, and checks whether the stage is finished.
func _process(delta: float) -> void:
	_time += delta
	while _next < _events.size() and _events[_next]["time"] <= _time:
		_spawn_enemy(_events[_next])
		_next += 1
	_check_finished()

## Turns each wave into one event per enemy (time, x position, type, overrides) and sorts them by time.
func _build_events() -> void:
	for wave in waves:
		for i in wave["count"]:
			_events.append({
				"time": wave["time"] + i * wave.get("interval", 0.5),
				"x": wave.get("x", 0.5) + i * wave.get("x_step", 0.0),
				"type": wave["type"],
				"override": wave.get("override", {}),
			})
	_events.sort_custom(func(a, b): return a["time"] < b["time"])

## Creates one enemy from its preset (plus overrides) just above the top edge of the playfield.
func _spawn_enemy(event: Dictionary) -> void:
	var config: Dictionary = enemy_types[event["type"]].duplicate(true)
	config.merge(event["override"], true)

	var enemy := Enemy.new()
	enemy.setup(config, manager, target)
	enemy.position = Vector2(
		Game.PLAYFIELD.position.x + event["x"] * Game.PLAYFIELD.size.x,
		Game.PLAYFIELD.position.y - Enemy.BODY_RADIUS - 4.0
	)
	enemy.died.connect(_on_enemy_died)
	enemy.tree_exiting.connect(_on_enemy_gone)
	add_child(enemy)
	_alive += 1

## Forwards an enemy's death (position, drops, score) to whoever listens, i.e. the stage.
func _on_enemy_died(enemy: Enemy) -> void:
	enemy_died.emit(enemy.global_position, enemy.drops, enemy.score_value)

## Counts enemies down whenever one is removed (killed or left the screen).
func _on_enemy_gone() -> void:
	_alive -= 1

## Emits waves_finished once, after the last enemy has spawned and none are left alive.
func _check_finished() -> void:
	if _finished:
		return
	if _next >= _events.size() and _alive <= 0:
		_finished = true
		waves_finished.emit()
