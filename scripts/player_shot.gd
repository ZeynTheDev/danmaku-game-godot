class_name PlayerShot
extends Area2D

## How much HP this shot removes from an enemy it hits.
var damage := 1

## Travel direction and speed in pixels per second. The player sets this when firing.
var velocity := Vector2(0, -900)

## Moves the shot every frame and deletes it once it leaves the playfield.
func _process(delta: float) -> void:
	position += velocity * delta
	# Delete the shot once it leaves the playfield (angled shots can exit through the sides)
	if not Game.PLAYFIELD.grow(20.0).has_point(position):
		queue_free()

## Draws the shot as a small light-blue bar.
func _draw() -> void:
	draw_rect(Rect2(-3, -8, 6, 16), Color(0.6, 0.9, 1.0))
