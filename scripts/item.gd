class_name Item
extends Node2D

## Emitted when the player picks the item up, just before it removes itself.
signal collected(kind: Kind)

enum Kind { POWER, POINT, BOMB, LIFE }

## Maps the item names used in drop configs ("power", "point", "bomb", "life") to item kinds.
const DROP_KEYS := {
	"power": Kind.POWER,
	"point": Kind.POINT,
	"bomb": Kind.BOMB,
	"life": Kind.LIFE,
}

const GRAVITY := 380.0
const MAX_FALL_SPEED := 130.0
const POP_SPEED := 160.0          # upward speed when the item first appears
const SIDE_DRAG := 120.0          # how quickly the sideways drift fades out
const PICKUP_RADIUS := 18.0
const MAGNET_RADIUS := 90.0       # items this close to the player get pulled in
const MAGNET_SPEED := 420.0
## While the player is within this distance of the top of the playfield (and has enough power, see
## Player.can_collect_all_items()), every item is pulled in.
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

## Starts pulling the item toward the player when the player is close, or when the player is above the
## collect line with enough power for collect-all. Once attracted, the item stays attracted.
func _update_attraction() -> void:
	var above_line := player.global_position.y < Game.PLAYFIELD.position.y + COLLECT_LINE_HEIGHT
	var collect_all := above_line and player.can_collect_all_items()
	var close := global_position.distance_squared_to(player.global_position) <= MAGNET_RADIUS * MAGNET_RADIUS
	if collect_all or close:
		_attracted = true

## Draws a red square for power, a blue diamond for points, a green star for bombs and a pink heart for lives.
func _draw() -> void:
	match kind:
		Kind.POWER:
			draw_rect(Rect2(-7, -7, 14, 14), Color(1.0, 0.3, 0.3))
			draw_rect(Rect2(-7, -7, 14, 14), Color.WHITE, false, 1.5)
		Kind.POINT:
			var diamond := PackedVector2Array([Vector2(0, -9), Vector2(7, 0), Vector2(0, 9), Vector2(-7, 0)])
			draw_colored_polygon(diamond, Color(0.4, 0.7, 1.0))
		Kind.BOMB:
			draw_colored_polygon(_star_points(11.0, 5.0), Color(0.4, 0.9, 0.5))
		Kind.LIFE:
			var pink := Color(1.0, 0.45, 0.65)
			draw_circle(Vector2(-4.5, -3.0), 5.0, pink)
			draw_circle(Vector2(4.5, -3.0), 5.0, pink)
			draw_colored_polygon(PackedVector2Array([Vector2(-9.0, -1.0), Vector2(9.0, -1.0), Vector2(0.0, 10.0)]), pink)

## Returns the corners of a five-pointed star with the given outer and inner radius (one tip pointing up).
func _star_points(outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(Vector2.from_angle(angle) * radius)
	return points
