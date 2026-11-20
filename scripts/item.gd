class_name Item
extends Node2D

## Emitted when the player picks the item up, just before it removes itself.
signal collected(kind: Kind)

enum Kind { POWER, POINT }

const GRAVITY := 380.0
const MAX_FALL_SPEED := 130.0
const POP_SPEED := 160.0          # upward speed when the item first appears
const SIDE_DRAG := 120.0          # how quickly the sideways drift fades out
const PICKUP_RADIUS := 18.0
const MAGNET_RADIUS := 90.0       # items this close to the player get pulled in
const MAGNET_SPEED := 420.0
## While the player is above this much distance from the top of the playfield, every item is pulled in.
const COLLECT_LINE_HEIGHT := 150.0

var kind: Kind = Kind.POINT
var player: Player

var _velocity := Vector2.ZERO
var _attracted := false

## Gives the item a small random pop upward and draws it above enemies.
func _ready() -> void:
	z_index = 1
	_velocity = Vector2(randf_range(-40.0, 40.0), -POP_SPEED)

## Runs every frame: falls or flies toward the player, checks pickup, and removes the item below the playfield.
func _process(delta: float) -> void:
	var player_alive := player != null and player.lives > 0
	if player_alive:
		_update_attraction()

	if _attracted and player_alive:
		_velocity = (player.global_position - global_position).normalized() * MAGNET_SPEED
	else:
		_velocity.y = minf(_velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		_velocity.x = move_toward(_velocity.x, 0.0, SIDE_DRAG * delta)
	position += _velocity * delta

	if player_alive and global_position.distance_squared_to(player.global_position) <= PICKUP_RADIUS * PICKUP_RADIUS:
		collected.emit(kind)
		queue_free()
	elif global_position.y > Game.PLAYFIELD.end.y + 20.0:
		queue_free()

## Starts pulling the item toward the player when the player is close or above the collect line.
## Once attracted, the item stays attracted.
func _update_attraction() -> void:
	var above_line := player.global_position.y < Game.PLAYFIELD.position.y + COLLECT_LINE_HEIGHT
	var close := global_position.distance_squared_to(player.global_position) <= MAGNET_RADIUS * MAGNET_RADIUS
	if above_line or close:
		_attracted = true

## Draws a red square for power items and a blue diamond for point items.
func _draw() -> void:
	match kind:
		Kind.POWER:
			draw_rect(Rect2(-7, -7, 14, 14), Color(1.0, 0.3, 0.3))
			draw_rect(Rect2(-7, -7, 14, 14), Color.WHITE, false, 1.5)
		Kind.POINT:
			var diamond := PackedVector2Array([Vector2(0, -9), Vector2(7, 0), Vector2(0, 9), Vector2(-7, 0)])
			draw_colored_polygon(diamond, Color(0.4, 0.7, 1.0))
