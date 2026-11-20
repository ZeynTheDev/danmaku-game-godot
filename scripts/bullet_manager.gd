class_name BulletManager
extends Node2D

signal player_hit
signal player_grazed

const GRAZE_DISTANCE := 14.0
const MAX_BULLETS := 4000          # extra spawns are ignored beyond this
const FLOATS_PER_INSTANCE := 12    # 8 for the 2D transform + 4 for the color
const CORE_SCALE := 0.55           # size of the white core relative to the body

class Bullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var radius := 5.0
	var color := Color.WHITE
	var grazed := false

var player: Player
var bullets: Array = []

var _field: Rect2
var _body_mm: MultiMesh
var _core_mm: MultiMesh
var _body_buf := PackedFloat32Array()
var _core_buf := PackedFloat32Array()

func _ready() -> void:
	z_index = 10   # enemy bullets draw above the player and player shots
	_field = Game.PLAYFIELD.grow(8.0)

	var tex := _make_circle_texture()
	_body_mm = _make_layer(tex)   # added first, so it draws underneath
	_core_mm = _make_layer(tex)   # white cores on top

	# Buffers are filled with zeros; only the non-zero slots get written each frame
	_body_buf.resize(MAX_BULLETS * FLOATS_PER_INSTANCE)
	_core_buf.resize(MAX_BULLETS * FLOATS_PER_INSTANCE)

	# Core color never changes, so set it to white once
	for n in MAX_BULLETS:
		var base := n * FLOATS_PER_INSTANCE
		_core_buf[base + 8] = 1.0
		_core_buf[base + 9] = 1.0
		_core_buf[base + 10] = 1.0
		_core_buf[base + 11] = 1.0

func spawn(pos: Vector2, vel: Vector2, radius := 5.0, color := Color(1.0, 0.35, 0.45)) -> void:
	if bullets.size() >= MAX_BULLETS:
		return
	var b := Bullet.new()
	b.pos = pos
	b.vel = vel
	b.radius = radius
	b.color = color
	bullets.append(b)

func clear() -> void:
	bullets.clear()

func _process(delta: float) -> void:
	var hit := false
	var can_hit := player != null and player.is_vulnerable()
	var player_pos := player.global_position if player != null else Vector2.ZERO

	# Iterate backwards so we can remove bullets safely as we go
	var i := bullets.size() - 1
	while i >= 0:
		var b: Bullet = bullets[i]
		b.pos += b.vel * delta

		if not _field.has_point(b.pos):
			_remove_at(i)
		elif player != null:
			var d2 := b.pos.distance_squared_to(player_pos)
			var hit_r := b.radius + Player.HITBOX_RADIUS
			if can_hit and d2 <= hit_r * hit_r:
				hit = true
			elif not b.grazed:
				var graze_r := hit_r + GRAZE_DISTANCE
				if d2 <= graze_r * graze_r:
					b.grazed = true
					player_grazed.emit()
		i -= 1

	# Emit after the loop, because the hit handler clears the bullet array
	if hit:
		player_hit.emit()

	_update_render()

# Swap-and-pop removal: O(1) instead of shifting the whole array
func _remove_at(i: int) -> void:
	bullets[i] = bullets[bullets.size() - 1]
	bullets.pop_back()

# Copies bullet data into the MultiMesh buffers.
# Per instance layout: [sx, 0, 0, x,  0, sy, 0, y,  r, g, b, a]
func _update_render() -> void:
	var count := mini(bullets.size(), MAX_BULLETS)
	var o := 0
	for n in count:
		var b: Bullet = bullets[n]
		var d := b.radius * 2.0
		var cd := d * CORE_SCALE

		_body_buf[o] = d
		_body_buf[o + 3] = b.pos.x
		_body_buf[o + 5] = d
		_body_buf[o + 7] = b.pos.y
		_body_buf[o + 8] = b.color.r
		_body_buf[o + 9] = b.color.g
		_body_buf[o + 10] = b.color.b
		_body_buf[o + 11] = b.color.a

		_core_buf[o] = cd
		_core_buf[o + 3] = b.pos.x
		_core_buf[o + 5] = cd
		_core_buf[o + 7] = b.pos.y

		o += FLOATS_PER_INSTANCE

	_body_mm.buffer = _body_buf
	_core_mm.buffer = _core_buf
	_body_mm.visible_instance_count = count
	_core_mm.visible_instance_count = count

# One MultiMesh layer: a 1x1 quad that gets scaled and tinted per instance
func _make_layer(tex: Texture2D) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D   # these two must be set
	mm.use_colors = true                           # before instance_count
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = MAX_BULLETS
	mm.visible_instance_count = 0

	var inst := MultiMeshInstance2D.new()
	inst.multimesh = mm
	inst.texture = tex
	inst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(inst)
	return mm

# A white soft-edged disc, generated in code so no asset file is needed
func _make_circle_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / (size / 2.0)
			var a := clampf((1.0 - d) / 0.08, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
