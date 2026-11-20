extends Node2D

func _ready() -> void:
	$Player.position = Vector2(
		Game.PLAYFIELD.get_center().x,
		Game.PLAYFIELD.end.y - 80
	)

func _draw() -> void:
	draw_rect(Game.PLAYFIELD, Color(0.08, 0.08, 0.14))
	draw_rect(Game.PLAYFIELD, Color(0.4, 0.4, 0.6), false, 2.0)
