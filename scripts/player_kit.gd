class_name PlayerKit
extends RefCounted

## Shot setup for one playable character, read by Player._shoot().
##
## "max_power_damage_multiplier": damage multiplier applied while the player is at MAX power.
##
## "levels" is a list of power levels. The player uses the highest level whose "power" is
## at or below their current power. Each level lists the shot "lines" fired together:
##   x            horizontal offset from the ship (pixels)
##   angle        starting angle in degrees, 0 = straight up, negative = left (optional, default 0)
##   damage       damage per hit (optional, default 1)
##   speed        shot speed in pixels per second (optional, default Player.SHOT_SPEED)
##   homing       true = steers toward the nearest enemy (optional, default false)
##   focus_x      x offset while focusing (optional, default x * 0.5, so focus packs shots tighter)
##   focus_angle  angle while focusing (optional, default 0)
const AMULET := {
	"name": "Amulet",
	"max_power_damage_multiplier": 2.0,
	"levels": [
		# Level 0: a single line
		{"power": 0, "lines": [
			{"x": 0.0},
		]},
		# Level 1: two lines
		{"power": 32, "lines": [
			{"x": -8.0},
			{"x": 8.0},
		]},
		# Level 2: three lines that fan out slightly
		{"power": 64, "lines": [
			{"x": -12.0, "angle": -4.0},
			{"x": 0.0},
			{"x": 12.0, "angle": 4.0},
		]},
		# Level 3: four main lines plus two homing amulets
		{"power": 96, "lines": [
			{"x": -6.0, "angle": -2.0},
			{"x": 6.0, "angle": 2.0},
			{"x": -16.0, "angle": -7.0},
			{"x": 16.0, "angle": 7.0},
			{"x": -24.0, "angle": -25.0, "focus_angle": -10.0, "homing": true, "speed": 520.0},
			{"x": 24.0, "angle": 25.0, "focus_angle": 10.0, "homing": true, "speed": 520.0},
		]},
	],
}
