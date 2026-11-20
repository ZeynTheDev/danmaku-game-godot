extends Area2D

var velocity := Vector2(0, -900)

func _process(delta: float) -> void:
	position += velocity * delta
	# Delete the shot once it leaves the top of the playfield
	if position.y < Game.PLAYFIELD.position.y - 20:
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-3, -8, 6, 16), Color(0.6, 0.9, 1.0))
