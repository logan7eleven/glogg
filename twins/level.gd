extends Node2D

@onready var projectile_pool = $bullet_pool
@onready var game_over_label = $game_over

func _ready():
	# Set up fixed 30 FPS timestep
	Engine.physics_ticks_per_second = 30
	Engine.max_fps = 30
	
	game_over_label.hide()
	
	var players = {
		1: Vector2(600, 400)
	}

	for i in players.keys():
		var player: Area2D = load("res://glogg.tscn").instantiate()
		player.position = players[i]
		add_child(player)

# Spawn crawlers in bottom corners
	var viewport_size = get_viewport_rect().size
	var crawler_positions = [
		Vector2(50, viewport_size.y - 50),  # Bottom left
		Vector2(viewport_size.x - 50, viewport_size.y - 50)  # Bottom right
	]

	for pos in crawler_positions:
		var crawler = load("res://crawler.tscn").instantiate()
		crawler.position = pos
		add_child(crawler)
		
func game_over():
	get_tree().paused = true
	game_over_label.show()
	set_process_input(true)
