extends Node

@export var bullet_scene: PackedScene  # Assign your "bullet.tscn" here

var bullet_instances = []

func _ready():
	# Preload some bullets (adjust the number as needed)
	for i in range(100):
		var bullet = bullet_scene.instantiate()
		bullet.visible = false
		bullet_instances.append(bullet)
		add_child(bullet)

func get_bullet():
	for bullet in bullet_instances:
		if not bullet.visible:
			bullet.visible = true
			bullet.reparent(get_parent())  # Reparent to level scene when retrieved
			return bullet
