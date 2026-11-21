class_name PlayerShot
extends Area2D

const HOMING_TURN_RATE := 6.0        # radians per second
const HOMING_RETARGET_TIME := 0.15   # seconds between searches for the nearest enemy

## How much HP this shot removes from an enemy it hits.
var damage := 1.0

## Travel direction and speed in pixels per second. The player sets this when firing.
var velocity := Vector2(0, -900)

## True = this shot steers toward the nearest enemy.
var homing := false

var _target: Node2D
var _retarget_in := 0.0

## Steers (if homing), moves the shot every frame and deletes it once it leaves the playfield.
func _process(delta: float) -> void:
	if homing:
		_steer(delta)
	position += velocity * delta
	# Delete the shot once it leaves the playfield (angled shots can exit through the sides)
	if not Game.PLAYFIELD.grow(20.0).has_point(position):
		queue_free()

## Turns the velocity toward the current target by at most HOMING_TURN_RATE,
## and refreshes the target when it is gone or the retarget timer runs out.
func _steer(delta: float) -> void:
	_retarget_in -= delta
	if _retarget_in <= 0.0 or not is_instance_valid(_target) or _target.is_queued_for_deletion():
		_target = _find_nearest_enemy()
		_retarget_in = HOMING_RETARGET_TIME
	if _target == null:
		return

	var current := velocity.angle()
	var desired := (_target.global_position - global_position).angle()
	var max_turn := HOMING_TURN_RATE * delta
	var turn := clampf(angle_difference(current, desired), -max_turn, max_turn)
	velocity = Vector2.from_angle(current + turn) * velocity.length()
	rotation = velocity.angle() + PI / 2.0   # the shot art points up at rotation 0

## Returns the closest living enemy that is inside the playfield, or null if there is none.
func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d2 := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		if not Game.PLAYFIELD.has_point(enemy.global_position):
			continue
		var d2 := global_position.distance_squared_to(enemy.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = enemy
	return best

## Draws the shot as a small bar: light blue normally, pink for homing amulets.
func _draw() -> void:
	var color := Color(1.0, 0.6, 0.8) if homing else Color(0.6, 0.9, 1.0)
	draw_rect(Rect2(-3, -8, 6, 16), color)
