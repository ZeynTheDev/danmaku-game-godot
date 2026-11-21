class_name Bomb
extends Node2D

const GROW_TIME := 0.5            # seconds to reach full size
const FADE_TIME := 0.6            # the last seconds, during which everything fades out
const FIELD_FADE_TIME := 0.4      # how fast the field fades once every orb has launched
const START_RADIUS := 30.0
const MAX_RADIUS := 170.0         # visual size of the field
const WIPE_RADIUS_SCALE := 2.5    # bullets are cleared inside (field radius * this); the visual stays the same
const TICK_TIME := 0.1            # seconds between damage ticks
const DAMAGE_PER_TICK := 3.0      # 30 damage per second to each enemy inside the field
const ORB_COUNT := 6
const ORB_RADIUS := 9.0
const ORB_SPIN := 2.2             # radians per second while circling
const CIRCLE_TIME := 1.7          # seconds the orbs circle the player before the first one launches
const LAUNCH_STAGGER := 0.06      # delay between each orb's launch
const ORB_START_SPEED := 300.0
const ORB_ACCEL := 1800.0
const ORB_MAX_SPEED := 1200.0
const ORB_HIT_DAMAGE := 15.0
const ORB_WIPE_RADIUS := 50.0     # a flying orb clears bullets around itself
const BURST_TIME := 0.25          # how long the small flash at an orb's impact lasts

## One of the orbs that circle the player and then fly at an enemy.
class Orb:
	var pos := Vector2.ZERO    # world position
	var angle := 0.0           # starting angle on the circle
	var launch_at := 0.0       # bomb age at which this orb may launch
	var flying := false
	var speed := 0.0
	var done := false          # true after it hit something or fizzled out

var player: Player
var bullets: BulletManager

var _age := 0.0
var _tick := 0.0
var _radius := START_RADIUS
var _alpha := 1.0          # fades everything out near the end of the bomb
var _field_alpha := 1.0    # field strength, fades once every orb has launched
var _orbs: Array = []
var _target: Enemy
var _bursts: Array = []    # small flashes where orbs hit: {"pos": Vector2, "age": float}

## Draws the bomb above enemies and the player, and creates the orbs.
func _ready() -> void:
	z_index = 3
	for i in ORB_COUNT:
		var orb := Orb.new()
		orb.angle = TAU * i / ORB_COUNT
		orb.launch_at = CIRCLE_TIME + i * LAUNCH_STAGGER
		_orbs.append(orb)

## Runs every frame: follows the player, updates the field, clears bullets, damages enemies,
## moves the orbs, and removes itself once the bomb duration is over.
func _process(delta: float) -> void:
	_age += delta
	if player != null:
		position = player.position
	_update_shape()
	_update_field_alpha(delta)
	_wipe_bullets()
	_damage_enemies_in_field(delta)
	_update_orbs(delta)
	_update_bursts(delta)
	queue_redraw()
	if _age >= Player.BOMB_DURATION:
		queue_free()

## Computes the current radius (fast ease-out growth) and the fade-out alpha for the last moments.
func _update_shape() -> void:
	var grow := clampf(_age / GROW_TIME, 0.0, 1.0)
	_radius = lerpf(START_RADIUS, MAX_RADIUS, 1.0 - pow(1.0 - grow, 3.0))
	_alpha = clampf((Player.BOMB_DURATION - _age) / FADE_TIME, 0.0, 1.0)

## Keeps the field at full strength while any orb is still circling.
## Once every orb has launched (or finished), the field fades out.
func _update_field_alpha(delta: float) -> void:
	var circling := false
	for orb in _orbs:
		if not orb.flying and not orb.done:
			circling = true
			break
	if circling:
		_field_alpha = 1.0
	else:
		_field_alpha = maxf(0.0, _field_alpha - delta / FIELD_FADE_TIME)

## Removes bullets inside the (enlarged) wipe area around the player while the field is active,
## and around every flying orb.
func _wipe_bullets() -> void:
	if bullets == null:
		return
	if _field_alpha > 0.0:
		bullets.clear_in_circle(position, _radius * WIPE_RADIUS_SCALE)
	for orb in _orbs:
		if orb.flying and not orb.done:
			bullets.clear_in_circle(orb.pos, ORB_WIPE_RADIUS)

## Every TICK_TIME seconds, damages each enemy inside the visible field (while the field is active).
func _damage_enemies_in_field(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick += TICK_TIME
	if _field_alpha <= 0.0:
		return

	for enemy in _get_enemies():
		var reach := _radius + enemy.body_radius
		if enemy.global_position.distance_squared_to(global_position) <= reach * reach:
			enemy.take_damage(DAMAGE_PER_TICK)

## Moves every orb: circling ones follow the player and launch when it is their turn,
## flying ones chase the target.
func _update_orbs(delta: float) -> void:
	for orb in _orbs:
		if orb.done:
			continue
		if not orb.flying:
			orb.pos = global_position + Vector2.from_angle(_age * ORB_SPIN + orb.angle) * _radius * 0.7
			if _age >= orb.launch_at:
				_try_launch(orb)
		else:
			_fly(orb, delta)

## Launches an orb if there is something to hit. Otherwise it keeps circling and tries again next frame.
func _try_launch(orb: Orb) -> void:
	_refresh_target()
	if _target == null:
		return
	orb.flying = true
	orb.speed = ORB_START_SPEED

## Moves a flying orb toward the target, speeding up as it goes. On arrival it damages the target
## and bursts. If every enemy is gone mid-flight, the orb fizzles out.
func _fly(orb: Orb, delta: float) -> void:
	_refresh_target()
	if _target == null:
		orb.done = true
		_add_burst(orb.pos)
		return

	orb.speed = minf(orb.speed + ORB_ACCEL * delta, ORB_MAX_SPEED)
	var to_target := _target.global_position - orb.pos
	var step := orb.speed * delta
	if to_target.length() <= step + _target.body_radius:
		_target.take_damage(ORB_HIT_DAMAGE)
		orb.done = true
		_add_burst(orb.pos)
	else:
		orb.pos += to_target.normalized() * step

## Keeps the current target while it is alive and on screen; otherwise picks a new one.
func _refresh_target() -> void:
	if is_instance_valid(_target) and not _target.is_queued_for_deletion() \
			and Game.PLAYFIELD.has_point(_target.global_position):
		return
	_target = _pick_target()

## Picks the best enemy to attack: a boss first, otherwise the largest one, otherwise the nearest.
func _pick_target() -> Enemy:
	var best: Enemy = null
	for enemy in _get_enemies():
		if best == null or _is_better_target(enemy, best):
			best = enemy
	return best

## True if enemy `a` should be attacked before enemy `b`: boss first, then larger body, then closer to the bomb.
func _is_better_target(a: Enemy, b: Enemy) -> bool:
	if a.is_boss != b.is_boss:
		return a.is_boss
	if not is_equal_approx(a.body_radius, b.body_radius):
		return a.body_radius > b.body_radius
	return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)

## Returns every living enemy that is inside the playfield.
func _get_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		if not Game.PLAYFIELD.has_point(enemy.global_position):
			continue
		result.append(enemy)
	return result

## Starts a small expanding ring at the given world position (shown where an orb hits).
func _add_burst(pos: Vector2) -> void:
	_bursts.append({"pos": pos, "age": 0.0})

## Ages the impact flashes and removes finished ones.
func _update_bursts(delta: float) -> void:
	var i := _bursts.size() - 1
	while i >= 0:
		_bursts[i]["age"] += delta
		if _bursts[i]["age"] >= BURST_TIME:
			_bursts.remove_at(i)
		i -= 1

## Draws the translucent field with a bright rim, the orbs (circling or flying), and impact flashes.
func _draw() -> void:
	var field := _field_alpha * _alpha
	if field > 0.0:
		draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.5, 0.6, 0.12 * field))
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(1.0, 0.7, 0.8, 0.8 * field), 2.0)

	for orb in _orbs:
		if orb.done:
			continue
		var p := to_local(orb.pos)
		draw_circle(p, ORB_RADIUS, Color(1.0, 0.4, 0.5, 0.9 * _alpha))
		draw_circle(p, ORB_RADIUS * 0.55, Color(1.0, 1.0, 1.0, 0.9 * _alpha))

	for burst in _bursts:
		var t: float = burst["age"] / BURST_TIME
		draw_arc(to_local(burst["pos"]), 8.0 + 30.0 * t, 0.0, TAU, 24, Color(1.0, 0.8, 0.9, 1.0 - t), 2.0)
