extends Area2D

@export var bullet_speed = 800.0 
var direction: Vector2 = Vector2.ZERO
var is_active: bool = false
var source_block: BlockData = null
var payload: Array = []

# NEW: Variable to hold the calculated damage
var damage_amount: float = 0.0

func _ready():
	add_to_group("bullets")
	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		connect("area_entered", Callable(self, "_on_area_entered"))

func _physics_process(delta):
	if not is_active: return
	position += direction * bullet_speed * delta

# NEW: Added 'damage: float' to signature
func fire(start_pos: Vector2, aim_angle: float, damage: float, effects: Array, block: BlockData):
	global_position = start_pos
	rotation = aim_angle
	direction = Vector2.RIGHT.rotated(aim_angle)
	
	# STORE THE DAMAGE!
	damage_amount = damage
	
	payload = effects
	source_block = block
	is_active = true
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func deactivate():
	is_active = false
	visible = false
	source_block = null
	payload.clear()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func _on_area_entered(area: Area2D):
	if not is_active: return
	
	if area.is_in_group("bounds"):
		deactivate()
		return
	
	if area.is_in_group("enemies") or area.is_in_group("enemies_physics"):
		var target_enemy = area.owner if area.owner else area.get_parent()
		
		if is_instance_valid(target_enemy):
			if target_enemy.has_method("process_bullet_hit"):
				target_enemy.process_bullet_hit(self, source_block, payload)
				
			if source_block:
				# UPDATE: Record the actual damage instead of 1.0!
				source_block.record_damage(damage_amount)
				
			deactivate()
