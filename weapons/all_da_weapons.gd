extends RefCounted
# every extra weapon u can get from leveling up
# they stack w the disk n each other. picking one u already got levels it up (till max_level)
# overcharge = +1 dmg to all of them
#
# new weapon? make a script in here (copy spinny_blades.gd), add it to this list, done
# the menu n HUD figure it out by themselves

const WEAPONS = {
	"orbit": {
		"name": "Orbit Blades",
		"script": preload("res://weapons/spinny_blades.gd"),
		"max_level": 8,
		"new": "Blades spin around you, slicing enemies",
		"up": "+1 blade, spins faster",
	},
	"laser": {
		"name": "Ricochet Laser",
		"script": preload("res://weapons/pew_pew_laser.gd"),
		"max_level": 8,
		"new": "Auto-fires a laser that bounces off walls",
		"up": "+1 bounce, fires faster",
	},
	"zap": {
		"name": "Chain Zap",
		"script": preload("res://weapons/zappy_zap.gd"),
		"max_level": 8,
		"new": "Lightning jumps between enemies",
		"up": "+1 jump, zaps faster",
	},
	"shockwave": {
		"name": "Shockwave",
		"script": preload("res://weapons/big_boom.gd"),
		"max_level": 8,
		"new": "Blasts nearby enemies away from you",
		"up": "Bigger blast, more often",
	},
	"mines": {
		"name": "Drift Mines",
		"script": preload("res://weapons/drifty_mines.gd"),
		"max_level": 8,
		"new": "Drift fast to drop proximity mines",
		"up": "Bigger boom, more mines",
	},
	# ---- ricochet / bounce-back weapons ----
	"boomerang": {
		"name": "Boomerang",
		"script": preload("res://weapons/boomerang.gd"),
		"max_level": 8,
		"new": "Ricochets off walls, then flies back to you",
		"up": "More boomerangs, longer throws",
	},
	"pinball": {
		"name": "Pinball",
		"script": preload("res://weapons/pinball.gd"),
		"max_level": 8,
		"new": "Steel balls bounce off walls AND enemies",
		"up": "More balls, they last longer",
	},
	"scatter": {
		"name": "Scatter Shot",
		"script": preload("res://weapons/shotgun_ish.gd"),
		"max_level": 8,
		"new": "Fires a spread of pellets that ricochet",
		"up": "+1 pellet, more bounces",
	},
	"rebound": {
		"name": "Rebound Burst",
		"script": preload("res://weapons/bounce_back_burst.gd"),
		"max_level": 8,
		"new": "Wall-bouncing blasts out ricochet shards",
		"up": "+2 shards, more damage",
	},
}
