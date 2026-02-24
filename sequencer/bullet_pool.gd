extends Node

@export var bullet_scene: PackedScene 

var bullet_instances = []
var pool_parent: Node 

func _ready():
	pool_parent = get_parent()
	for i in range(100): 
		var bullet = bullet_scene.instantiate()
		bullet.init_pool(self)
		bullet.visible = false
		bullet_instances.append(bullet)
		add_child(bullet) 

func get_bullet():
	for bullet in bullet_instances:
		if not bullet.visible:
			bullet.visible = true
			if bullet.get_parent() != pool_parent:
				bullet.reparent(pool_parent)
			return bullet
	printerr("BulletPool Error: No available bullets!") 
	return null

func return_to_pool(bullet: Node):
	if bullet.get_parent() == pool_parent:
		bullet.reparent(self)
	elif bullet.get_parent() != self:
		pass 
	bullet.visible = false
