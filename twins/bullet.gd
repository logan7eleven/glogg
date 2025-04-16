extends Area2D

@export var bullet_speed = 800
@onready var animated_sprite = $AnimatedSprite2D
var direction: Vector2
var initial_position: Vector2
var bullet_pool: Node
var has_collided = false
var slot_index: int = -1

func init_pool(pool: Node):
	bullet_pool = pool

func _ready():
	initial_position = position
	monitoring = false
	monitorable = false
	animated_sprite.animation_finished.connect(_on_animation_finished)
	add_to_group("bullets")

func _physics_process (delta):
	if not visible or has_collided:
		return
	position += direction * bullet_speed * delta

func fire(pos: Vector2, angle: float, from_slot: int):
	print("Bullet fired with slot: ", from_slot)
	has_collided = false
	monitoring = true
	monitorable = true
	position = pos
	rotation = angle
	direction = Vector2.RIGHT.rotated(rotation)
	visible = true
	animated_sprite.frame = 0
	animated_sprite.play()
	slot_index = from_slot

func _on_animation_finished():
	animated_sprite.stop()
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("default") - 1
	
func deactivate():
	if has_collided:
		return
	has_collided = true
	visible = false
	monitoring = false
	set_deferred("monitorable", false)
	animated_sprite.stop()
	animated_sprite.frame = 0
	if bullet_pool:
		call_deferred("_safe_return_to_pool")

func _safe_return_to_pool():
	bullet_pool.return_to_pool(self)

func _on_area_entered(area: Area2D):
	if area.is_in_group("bounds"):
		deactivate()
