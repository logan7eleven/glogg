extends Node2D

@export var grid_width = 150
@export var grid_height = 100
@export var cell_size = 8

@onready var projectile_pool = $BulletPool

var player_keys

func _ready():
	var players = {
		1: Vector2(600, 400)
	}

	player_keys = players.keys()

	for i in player_keys.size():
		var player: CharacterBody2D = load("res://glogg.tscn").instantiate()
		player.position = players[player_keys[i]]
		add_child(player)
