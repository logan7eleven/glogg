# bullet.gd (Apply Damage OR Effect - Cleaned)
extends Area2D

@export var bullet_speed = 800
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
	if not animated_sprite.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		animated_sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))
	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		connect("area_entered", Callable(self, "_on_area_entered"))
	add_to_group("bullets")

func _physics_process (delta):
	if not visible or has_collided: return
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
	if has_collided: return
	has_collided = true
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	animated_sprite.stop()
	animated_sprite.frame = 0
	if bullet_pool:
		call_deferred("_safe_return_to_pool")

func _safe_return_to_pool():
	if is_instance_valid(bullet_pool) and bullet_pool.has_method("return_to_pool"):
		bullet_pool.return_to_pool(self)
	else:
		printerr("Bullet %d: Cannot return to pool. Destroying self." % get_instance_id())
		queue_free()

func _on_area_entered(area: Area2D):
	if has_collided: return

	# 1. Check for Bounds
	if area.is_in_group("bounds"):
		deactivate()
		return

	# 2. Check for Boss Target
	if area.is_in_group("boss_target"):
		var level = get_parent()
		if is_instance_valid(level) and level.has_method("boss_hit"):
			level.boss_hit()
		else: printerr("Bullet: Could not find level or boss_hit method!")
		deactivate()
		return

	# 3. Check for Enemy HitBox
	if area.is_in_group("enemies"):
		if slot_index == -1: deactivate(); return # Ignore invalid slot hits

		var target_enemy = area.owner if area.owner else area.get_parent()
		if not is_instance_valid(target_enemy) or not target_enemy is EnemyBase:
			deactivate(); return # Ignore invalid targets

		var upgrade_data = GlobalState.get_slot_upgrade_data(slot_index)
		var effect_resource = upgrade_data["resource"] as StatusEffectData # Use Data resource type
		var effect_level = upgrade_data["level"]

		# --- Decide: Apply Effect OR Base Damage ---
		if is_instance_valid(effect_resource):
			if target_enemy.has_method("apply_status_effect"):
				target_enemy.apply_status_effect(effect_resource, effect_level, slot_index) # Pass slot index too
			else: printerr("Bullet: Target enemy '%s' missing apply_status_effect method!" % target_enemy.name)
		else:
			var base_damage = GlobalState.BASE_DAMAGE
			if target_enemy.has_method("take_damage"):
				target_enemy.take_damage(base_damage, slot_index)
			else: printerr("Bullet: Target enemy '%s' missing take_damage method!" % target_enemy.name)

		deactivate()
		return
