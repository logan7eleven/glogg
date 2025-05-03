# glogg.gd (Cleaned with can_move flag)
extends Area2D

@export var pixels_per_step = 200
@onready var gun = $cannon/gun
@onready var cockpit = $cockpit
@onready var cannon = $cannon

# Stage-based fire rates
var shots_per_second = { 1: 4, 2: 8, 3: 12 }
var fire_rates = {}
var current_stage = 1
var current_fire_rate = 0.0

var time_since_last_fire: float = 0.0
var min_pos: Vector2
var max_pos: Vector2
var aim_direction = Vector2.ZERO
var target_angle = 0.0
var fire_queued = false
var cockpit_target_angle = 0.0
var movement_queued = false
var rotation_speed = 50.0

var slot_manager: Node # Assigned by Level
var can_move: bool = false # Start disabled until countdown ends

const ROTATION_TOLERANCE = 0.03

func _ready():
	# slot_manager should be assigned by level.gd's spawn_player
	if not is_instance_valid(slot_manager):
		printerr("Glogg Error: Slot Manager not assigned by Level!")

	if not GlobalState.is_connected("slots_unlocked", Callable(self, "_on_slots_unlocked")):
		GlobalState.connect("slots_unlocked", Callable(self, "_on_slots_unlocked"))

	var viewport_size = get_viewport_rect().size
	var sprite_radius = 23 * scale.x # Adjust if needed
	add_to_group("players")

	min_pos = Vector2(sprite_radius, sprite_radius)
	max_pos = Vector2(viewport_size.x - sprite_radius, viewport_size.y - sprite_radius)

	fire_rates.clear()
	for stage in shots_per_second:
		fire_rates[stage] = 1.0 / shots_per_second[stage]

	current_fire_rate = fire_rates[current_stage]
	if is_instance_valid(slot_manager):
		slot_manager.initialize_slots(GlobalState.unlocked_slots)

# Called by GlobalState when slots are unlocked after boss
func _on_slots_unlocked(new_slot_count: int):
	if is_instance_valid(slot_manager):
		slot_manager.initialize_slots(new_slot_count)

func _process(delta):
	if not can_move: return # Respect countdown/pause

	# Aiming input and queuing fire
	var aim_x = Input.get_axis("aimL", "aimR")
	var aim_y = Input.get_axis("aimU", "aimD")
	aim_direction = Vector2(aim_x, aim_y)

	if aim_direction != Vector2.ZERO and not fire_queued:
		time_since_last_fire += delta
		if time_since_last_fire >= current_fire_rate:
			fire_queued = true
			target_angle = round(aim_direction.angle() / (PI / 12)) * (PI / 12)

func _physics_process(delta):
	if not can_move: return # Respect countdown/pause

	# Movement Input & Execution
	var move_x = Input.get_axis("moveL", "moveR")
	var move_y = Input.get_axis("moveU", "moveD")
	var movement = Vector2(move_x, move_y)

	if movement != Vector2.ZERO:
		movement = movement.normalized()
		var target_pos = position + movement * pixels_per_step * delta
		target_pos.x = clamp(target_pos.x, min_pos.x, max_pos.x)
		target_pos.y = clamp(target_pos.y, min_pos.y, max_pos.y)
		position = target_pos
		if not movement_queued:
			cockpit_target_angle = movement.angle()
			movement_queued = true

	# Cockpit Rotation
	if movement_queued:
		cockpit.rotation = lerp_angle(cockpit.rotation, cockpit_target_angle, rotation_speed * delta)
		if abs(wrapf(cockpit_target_angle - cockpit.rotation, -PI, PI)) <= ROTATION_TOLERANCE:
			movement_queued = false

	# Cannon Aiming & Firing Execution
	if aim_direction != Vector2.ZERO or fire_queued:
		cannon.rotation = lerp_angle(cannon.rotation, target_angle, rotation_speed * delta)
		if fire_queued and abs(wrapf(target_angle - cannon.rotation, -PI, PI)) <= ROTATION_TOLERANCE:
			try_fire(target_angle)
			time_since_last_fire = 0.0
			fire_queued = false

# Called by SceneLoader after boss defeat
func advance_stage():
	current_stage = min(current_stage + 1, 3) # Max 3 stages for fire rate
	current_fire_rate = fire_rates[current_stage]
	time_since_last_fire = 0.0
	print("Glogg: Advanced to Stage %d - Fire Rate: %.3f shots/sec" % [current_stage, 1.0/current_fire_rate])

func try_fire(aim_angle: float):
	var level = get_parent()
	if not is_instance_valid(level) or not level.has_node("BulletPool"): return

	var bullet_pool = level.get_node("BulletPool")
	var bullet = bullet_pool.get_bullet()

	if bullet and is_instance_valid(slot_manager):
		var current_slot_index = slot_manager.get_next_slot()
		if current_slot_index != -1:
			bullet.fire(gun.global_position, aim_angle, current_slot_index)
		else: # Fallback if slot manager fails
			if bullet.has_method("deactivate"): bullet.deactivate()
			else: bullet.queue_free()
	elif bullet: # Fallback if no slot manager
		if bullet.has_method("deactivate"): bullet.deactivate()
		else: bullet.queue_free()
