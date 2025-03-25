extends Area2D

@export var bullet_speed = 48
var direction: Vector2
var initial_position: Vector2
var bullet_pool: Node

var _min_collision_size: float
var _substeps: int = 1

func init_pool(pool: Node):
	bullet_pool = pool

func _ready():
	initial_position = position
	var collision_shape = $CollisionShape2D
	var shape_size = collision_shape.shape.size
	_min_collision_size = min(shape_size.x, shape_size.y)
	_update_substeps()
	monitoring = false
	monitorable = false

func _update_substeps():
	_substeps = ceili(bullet_speed / (_min_collision_size * 0.8)) + 1
	_substeps = clampi(_substeps, 1, 8)

func _physics_process(_delta):
	if not visible:
		return
		
	var step_size = bullet_speed as float / _substeps
	
	for _i in range(_substeps):
		var step = direction * step_size
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(
			position,
			position + step,
			collision_mask,
			[self]
		)
		
		var result = space_state.intersect_ray(query)
		if result and result.collider.is_in_group("bounds"):
			deactivate()
			return
		
		position += step

func fire(pos: Vector2, angle: float):
	monitoring = true
	monitorable = true
	position = pos
	rotation = angle
	direction = Vector2.RIGHT.rotated(rotation)
	visible = true
	_update_substeps()

func set_speed(speed: float):
	bullet_speed = speed
	_update_substeps()

func deactivate():
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if bullet_pool:
		call_deferred("_safe_return_to_pool")

func _safe_return_to_pool():
	bullet_pool.return_to_pool(self)

func _on_area_entered(area: Area2D):
	if area.is_in_group("bounds"):
		print("bound hit")
		deactivate()
