extends Node2D

@onready var projectile_pool = $BulletPool

func _ready():
	# Set up fixed 30 FPS timestep
	Engine.physics_ticks_per_second = 30
	Engine.max_fps = 30
	
	var players = {
		1: Vector2(600, 400)
	}

	for i in players.keys():
		var player: Area2D = load("res://glogg.tscn").instantiate()
		player.position = players[i]
		add_child(player)
