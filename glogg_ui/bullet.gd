extends Area2D

@export var bullet_speed = 450
@onready var animated_sprite = $AnimatedSprite2D

var direction: Vector2 = Vector2.ZERO
var bullet_pool: Node
var has_collided = false
var slot_index: int = -1

func init_pool(pool: Node):
	bullet_pool = pool

func _ready():
	monitoring = false
	monitorable = false
	animated_sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))
	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		connect("area_entered", Callable(self, "_on_area_entered"))
	add_to_group("bullets")

func _physics_process (delta):
	position += direction * bullet_speed * delta

func fire(pos: Vector2, angle: float, from_slot: int):
	has_collided = false
	monitoring = true
	monitorable = true
	position = pos
	rotation = angle
	direction = Vector2.RIGHT.rotated(rotation)
	visible = true
	slot_index = from_slot
	animated_sprite.frame = 0
	animated_sprite.play("default")

func _on_animation_finished():
	animated_sprite.stop()

func deactivate():
	if has_collided: 
		return
	has_collided = true
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	animated_sprite.stop()
	animated_sprite.frame = 0
	if bullet_pool:
		call_deferred("_safe_return_to_pool")

func _safe_return_to_pool():
	bullet_pool.return_to_pool(self)

func _on_area_entered(area: Area2D):
	if has_collided: 
		return
	if area.is_in_group("bounds"):
		deactivate()
		return
	if area.is_in_group("enemies"):
		if slot_index == -1: 
			deactivate()
			return
		var target_enemy = area.owner if area.owner else area.get_parent()
		var upgrade_data = GlobalState.get_slot_upgrade_data(slot_index)
		var effect_resource = upgrade_data["resource"] as StatusEffectData
		var effect_level = upgrade_data["level"]
		if is_instance_valid(effect_resource):
			target_enemy.apply_status_effect(effect_resource, effect_level, slot_index)
		else:
			target_enemy.take_damage(GlobalState.BASE_DAMAGE, slot_index)
		deactivate() 
		return
