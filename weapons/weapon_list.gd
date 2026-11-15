extends RefCounted
# Every extra weapon you can get from the level-up menu.
# They all stack with the disk (and each other). Picking one you already
# have levels it up instead, up to max_level. The Overcharge upgrade adds
# +1 damage to all of them at once.
#
# To add a new weapon: write a script in this folder (copy orbit_blades.gd as
# a starting point), then add an entry here. That's it - the menu and HUD
# pick it up automatically.

const WEAPONS = {
	"orbit": {
		"name": "Orbit Blades",
		"script": preload("res://weapons/orbit_blades.gd"),
		"max_level": 8,
		"new": "Blades spin around you, slicing enemies",
		"up": "+1 blade, spins faster",
	},
	"laser": {
		"name": "Ricochet Laser",
		"script": preload("res://weapons/ricochet_laser.gd"),
		"max_level": 8,
		"new": "Auto-fires a laser that bounces off walls",
		"up": "+1 bounce, fires faster",
	},
	"zap": {
		"name": "Chain Zap",
		"script": preload("res://weapons/chain_zap.gd"),
		"max_level": 8,
		"new": "Lightning jumps between enemies",
		"up": "+1 jump, zaps faster",
	},
	"shockwave": {
		"name": "Shockwave",
		"script": preload("res://weapons/shockwave.gd"),
		"max_level": 8,
		"new": "Blasts nearby enemies away from you",
		"up": "Bigger blast, more often",
	},
	"mines": {
		"name": "Drift Mines",
		"script": preload("res://weapons/drift_mines.gd"),
		"max_level": 8,
		"new": "Drift fast to drop proximity mines",
		"up": "Bigger boom, more mines",
	},
}
