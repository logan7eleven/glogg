extends Area2D

@export var pixels_per_step = 48
var direction: Vector2
var initial_position: Vector2

func _ready():
	initial_position = position

func fire(pos: Vector2, angle: float):
	position = pos
	rotation = angle
	direction = Vector2.RIGHT.rotated(rotation)
	visible = true

func _physics_process(_delta):
	if visible:
		position += direction * pixels_per_step

func _on_area_entered(area: Area2D):
	if area.is_in_group("bounds"):
		print("Bounds collision detected") # Debug print
		deactivate()

func deactivate():
	visible = false
	position = initial_position
	var pool = get_parent().get_node_or_null("BulletPool")
	if pool:
		reparent(pool)
