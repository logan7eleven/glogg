extends Node

@export var bullet_scene: PackedScene

var bullet_instances = []
var pool_parent: Node  # Store reference to level

func _ready():
	pool_parent = get_parent()
	# Preload bullets
	for i in range(100):
		var bullet = bullet_scene.instantiate()
		bullet.init_pool(self)  # Store pool reference
		bullet.visible = false
		bullet_instances.append(bullet)
		add_child(bullet)

func get_bullet():
	for bullet in bullet_instances:
		if not bullet.visible:
			bullet.visible = true
			bullet.reparent(pool_parent)
			return bullet
	return null

func return_to_pool(bullet: Node):
	if bullet.get_parent() != self:
		bullet.reparent(self)
	bullet.visible = false
