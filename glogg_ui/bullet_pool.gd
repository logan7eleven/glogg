# bullet_pool.gd (Original v1 Logic - Cleaned)
extends Node

@export var bullet_scene: PackedScene # Assign bullet.tscn in inspector

var bullet_instances = []
var pool_parent: Node # Reference to the Level node

func _ready():
	pool_parent = get_parent()
	if not is_instance_valid(pool_parent):
		printerr("BulletPool Error: Must be parented to the Level node!")
		return
	if not is_instance_valid(bullet_scene):
		printerr("BulletPool Error: Bullet Scene not set in inspector!")
		return

	# Preload bullets
	for i in range(100): # Adjust pool size as needed
		var bullet = bullet_scene.instantiate()
		if bullet.has_method("init_pool"):
			bullet.init_pool(self)
			bullet.visible = false
			bullet_instances.append(bullet)
			add_child(bullet) # Keep inactive bullets under the pool node
		else:
			printerr("BulletPool Error: Instantiated bullet scene lacks init_pool method!")
			bullet.queue_free() # Clean up invalid instance

func get_bullet():
	for bullet in bullet_instances:
		if not bullet.visible:
			bullet.visible = true
			if bullet.get_parent() != pool_parent: # Reparent if not already under level
				bullet.reparent(pool_parent)
			return bullet

	printerr("BulletPool Error: No available bullets!") # Pool depleted
	return null

func return_to_pool(bullet: Node):
	if not is_instance_valid(bullet) or not bullet is Area2D: return

	# Reparent back to the pool node if it's currently under the level
	if bullet.get_parent() == pool_parent:
		bullet.reparent(self)
	# If already under pool or somewhere else, just ensure hidden
	elif bullet.get_parent() != self:
		pass # Avoid reparenting if already child of pool or invalid parent

	bullet.visible = false
