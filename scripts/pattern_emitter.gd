class_name PatternEmitter
extends Node2D

enum Pattern { AIMED, RING, SPIRAL }

@export var pattern: Pattern = Pattern.RING
@export var fire_interval := 0.2     # seconds between shots (keep above 0)
@export var bullet_speed := 140.0
@export var bullet_count := 16       # ring: bullets per ring | aimed: bullets in fan | spiral: arms
@export var spread_deg := 40.0       # aimed: total fan width
@export var spin_deg := 7.0          # spiral: how far the angle advances each shot
@export var bullet_radius := 5.0
@export var bullet_color := Color(1.0, 0.35, 0.45)
@export var start_delay := 0.0       # seconds to wait before the first shot
@export var active := true           # when false, the emitter pauses (timer included)

var manager: BulletManager
var target: Node2D

var _timer := 0.0
var _spin := 0.0

## Applies the start delay so the first shot doesn't happen instantly.
func _ready() -> void:
	_timer = start_delay

## Counts down the fire timer and fires when it reaches zero (does nothing while inactive).
func _process(delta: float) -> void:
	if manager == null or not active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer += fire_interval
		_fire()

## Fires one volley of the selected pattern.
func _fire() -> void:
	match pattern:
		Pattern.AIMED:
			_fire_aimed()
		Pattern.RING:
			_fire_ring(0.0)
		Pattern.SPIRAL:
			_fire_ring(deg_to_rad(_spin))
			_spin += spin_deg

## A fan of bullets centered on the player
func _fire_aimed() -> void:
	if target == null:
		return
	var base := (target.global_position - global_position).angle()
	var spread := deg_to_rad(spread_deg)
	for i in bullet_count:
		var t := 0.5 if bullet_count == 1 else float(i) / (bullet_count - 1)
		var angle := base + lerpf(-spread / 2.0, spread / 2.0, t)
		_spawn(angle)

## Evenly spaced bullets around a circle (also the building block of spirals)
func _fire_ring(offset: float) -> void:
	for i in bullet_count:
		_spawn(offset + TAU * i / bullet_count)

## Spawns a single bullet at this emitter's position, flying in the given direction (radians).
func _spawn(angle: float) -> void:
	manager.spawn(global_position, Vector2.from_angle(angle) * bullet_speed, bullet_radius, bullet_color)
