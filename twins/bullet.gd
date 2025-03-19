extends RigidBody2D

signal bullet_hit

@export var speed = 1440.0  # Bullet speed (can be adjusted per bullet type)
var initial_position  # Store the initial position

func _ready():
	initial_position = position  # Store the initial position when the bullet is created

@warning_ignore("shadowed_variable_base_class")
func fire(position: Vector2, rotation: float):
	self.position = position
	self.rotation = rotation - PI / 2
	linear_velocity = Vector2(speed, 0).rotated(self.rotation)  # Use the speed defined in this script
	visible = true
	set_physics_process(true)  # Enable physics processing

func _physics_process(delta):
	# Sub-pixel movement for the bullet
	position += linear_velocity * delta

func _on_body_entered(_body):
	emit_signal("bullet_hit")
	print("hit")
	deactivate()

func deactivate():
	position = initial_position
	visible = false
	set_physics_process(false)  # Optionally disable physics processing
