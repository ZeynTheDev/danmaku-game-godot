class_name Enemy
extends Area2D

## Emitted when the enemy's HP reaches zero (not when it just leaves the screen).
signal died(enemy: Enemy)

## STRAIGHT: moves along its velocity.
## SINE: moves along its velocity while swaying left and right.
## HOVER: descends to hover_y, stays for hover_time seconds, then leaves back upward.
enum PathType { STRAIGHT, SINE, HOVER }

const BODY_RADIUS := 14.0      # default body size (a config can override it with "radius")
const FLASH_TIME := 0.08       # seconds the body turns white after a hit
const MAX_LIFETIME := 60.0     # failsafe: remove enemies that somehow never leave

var max_hp := 10.0
var hp := 10.0
var score_value := 100
## Items that always drop on death, e.g. {"power": 1, "bomb": 1}. Names: power, point, bomb, life.
var guaranteed := {}
## Optional random drops, e.g. {"rolls": 2, "entries": [{"drop": "point", "weight": 50}, {"drop": "power", "weight": 50}]}.
## Each roll picks one entry by weight. An entry named "none" means nothing drops for that roll.
var drop_table := {}
## Bosses are always chosen first by the bomb's orbs.
var is_boss := false
## Body size in pixels. Bigger enemies are preferred by the bomb after bosses.
var body_radius := BODY_RADIUS
var path_type: PathType = PathType.STRAIGHT
var velocity := Vector2(0, 90)
var sway_amplitude := 60.0
var sway_frequency := 2.0
var hover_y := 160.0
var hover_time := 4.0
var body_color := Color(0.7, 0.4, 0.9)

var _emitter: PatternEmitter
var _age := 0.0
var _base_pos := Vector2.ZERO   # path position without the sine sway
var _hover_phase := 0           # 0 = descending, 1 = hovering, 2 = leaving
var _hover_left := 0.0
var _flash := 0.0
var _dead := false

## Reads the enemy's settings from a config dictionary (missing keys use defaults)
## and creates the child PatternEmitter that fires its bullets. Call before add_child().
func setup(config: Dictionary, bullet_manager: BulletManager, target_node: Node2D) -> void:
	max_hp = config.get("hp", 10)
	hp = max_hp
	score_value = config.get("score", 100)
	guaranteed = config.get("guaranteed", {})
	drop_table = config.get("drop_table", {})
	is_boss = config.get("boss", false)
	body_radius = config.get("radius", BODY_RADIUS)
	path_type = config.get("path", PathType.STRAIGHT)
	velocity = config.get("velocity", Vector2(0, 90))
	sway_amplitude = config.get("sway_amplitude", 60.0)
	sway_frequency = config.get("sway_frequency", 2.0)
	hover_y = config.get("hover_y", 160.0)
	hover_time = config.get("hover_time", 4.0)
	body_color = config.get("color", Color(0.7, 0.4, 0.9))
	_hover_left = hover_time

	_emitter = PatternEmitter.new()
	_emitter.pattern = config.get("pattern", PatternEmitter.Pattern.RING)
	_emitter.fire_interval = config.get("interval", 1.0)
	_emitter.bullet_speed = config.get("bullet_speed", 140.0)
	_emitter.bullet_count = config.get("count", 8)
	_emitter.spread_deg = config.get("spread", 40.0)
	_emitter.spin_deg = config.get("spin", 7.0)
	_emitter.bullet_radius = config.get("bullet_radius", 5.0)
	_emitter.bullet_color = config.get("bullet_color", Color(1.0, 0.35, 0.45))
	_emitter.start_delay = config.get("start_delay", 0.5)
	_emitter.manager = bullet_manager
	_emitter.target = target_node
	add_child(_emitter)

## Builds the collision circle in code, joins the "enemies" group (used by homing shots and bombs),
## and starts listening for player shots.
func _ready() -> void:
	add_to_group("enemies")

	var shape := CircleShape2D.new()
	shape.radius = body_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	_base_pos = position
	area_entered.connect(_on_area_entered)

## Runs every frame: follows its path, updates the hit flash, handles leaving the field,
## and only lets the emitter fire while the enemy is inside the playfield.
func _process(delta: float) -> void:
	_age += delta
	_move(delta)
	_update_flash(delta)
	_emitter.active = Game.PLAYFIELD.has_point(global_position)

	# Remove the enemy once it has left the (slightly enlarged) playfield
	if _age > MAX_LIFETIME or not Game.PLAYFIELD.grow(60.0).has_point(global_position):
		queue_free()

## Reduces HP, flashes the body, and handles death (emits `died`, then removes the enemy).
func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	_flash = FLASH_TIME
	queue_redraw()
	if hp <= 0.0:
		_dead = true
		died.emit(self)
		queue_free()

## Called when another Area2D overlaps the enemy. Only player shots matter: they deal damage and vanish.
func _on_area_entered(area: Area2D) -> void:
	if _dead or not (area is PlayerShot):
		return
	take_damage((area as PlayerShot).damage)
	area.queue_free()

## Dispatches to the movement code for this enemy's path type.
func _move(delta: float) -> void:
	match path_type:
		PathType.STRAIGHT:
			position += velocity * delta
		PathType.SINE:
			_base_pos += velocity * delta
			position = _base_pos + Vector2(sin(_age * sway_frequency) * sway_amplitude, 0.0)
		PathType.HOVER:
			_move_hover(delta)

## HOVER path: descend, wait in place, then retrace the path upward and leave.
func _move_hover(delta: float) -> void:
	match _hover_phase:
		0:
			position += velocity * delta
			if position.y >= hover_y:
				_hover_phase = 1
		1:
			_hover_left -= delta
			if _hover_left <= 0.0:
				_hover_phase = 2
		2:
			position -= velocity * delta

## Counts down the white hit-flash and redraws once it ends.
func _update_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			queue_redraw()

## Draws the body (white while flashing) and a small HP bar once the enemy is damaged.
func _draw() -> void:
	var color := Color.WHITE if _flash > 0.0 else body_color
	draw_circle(Vector2.ZERO, body_radius, color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)
	if hp < max_hp:
		var width := body_radius * 2.0
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		var top := -body_radius - 10.0
		draw_rect(Rect2(-width / 2.0, top, width, 3.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-width / 2.0, top, width * ratio, 3.0), Color(0.4, 1.0, 0.4))

## Works out what this enemy drops: everything in `guaranteed`, plus one weighted random pick per roll
## in `drop_table`. Returns a dictionary like {"power": 2, "point": 1}. Call it once, when the enemy dies.
func roll_drops() -> Dictionary:
	var result := guaranteed.duplicate()
	var entries: Array = drop_table.get("entries", [])
	for i in drop_table.get("rolls", 0):
		var pick := _pick_weighted(entries)
		if pick != "" and pick != "none":
			result[pick] = result.get(pick, 0) + 1
	return result

## Picks one entry's "drop" name at random. An entry with weight 50 is five times as likely as one with
## weight 10. Returns "" when there are no entries or every weight is zero.
func _pick_weighted(entries: Array) -> String:
	var total := 0.0
	for entry in entries:
		total += entry.get("weight", 1.0)
	if total <= 0.0:
		return ""
	var roll := randf() * total
	for entry in entries:
		roll -= entry.get("weight", 1.0)
		if roll < 0.0:
			return entry["drop"]
	return entries.back()["drop"]
