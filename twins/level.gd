extends Node2D

@onready var projectile_pool = $bullet_pool
@onready var game_over_label = $game_over
@onready var slot_manager = $slot_manager

func _ready():
	game_over_label.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var players = {
		1: Vector2(600, 400)
	}

	for i in players.keys():
		var player: Area2D = load("res://glogg.tscn").instantiate()
		player.slot_manager = slot_manager
		player.position = players[i]
		add_child(player)

# Spawn crawlers in bottom corners
	var viewport_size = get_viewport_rect().size
	var crawler_positions = [
		Vector2(viewport_size.x - 1100, viewport_size.y - 700),
		Vector2(viewport_size.x - 100, viewport_size.y - 700),
		Vector2(viewport_size.x - 1100, viewport_size.y - 100),
		Vector2(viewport_size.x - 100, viewport_size.y - 100)
	]

	for pos in crawler_positions:
		var crawler = load("res://crawler.tscn").instantiate()
		crawler.position = pos
		add_child(crawler)
		
func game_over():
	game_over_label.show()
	get_tree().paused = true
	set_process_input(true)
	for player in get_tree().get_nodes_in_group("players"):
		player.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for bullet in projectile_pool.bullet_instances:
		bullet.deactivate()
