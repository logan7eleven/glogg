# File: res://BulletPool.gd
extends Node

# Make sure this path exactly matches where your bullet scene is saved
const BULLET_SCENE = preload("res://player/bullet.tscn")

var pool: Array[Node2D] = []

func get_bullet() -> Node2D:
	# Look for an inactive bullet in the pool to recycle
	for bullet in pool:
		if not bullet.visible and not bullet.get("is_active"):
			return bullet
			
	# If no bullets are available, create a new one
	var new_bullet = BULLET_SCENE.instantiate()
	
	# Ensure the bullet starts deactivated before we hand it over
	if new_bullet.has_method("deactivate"):
		new_bullet.deactivate()
		
	add_child(new_bullet)
	pool.append(new_bullet)
	
	return new_bullet
