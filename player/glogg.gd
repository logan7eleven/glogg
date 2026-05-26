# File: res://glogg.gd
extends Area2D

@export var pixels_per_step = 200
@onready var gun = $cannon/gun
@onready var cockpit = $cockpit
@onready var cannon = $cannon

var min_pos: Vector2
var max_pos: Vector2
var aim_direction = Vector2.ZERO
var target_angle = 0.0
var cockpit_target_angle = 0.0
var rotation_speed = 50.0
var can_move: bool = false
var movement_queued = false

const ANGLE_INCREMENT = PI / 12.0
const LOOT_PICKUP_RANGE = 120.0
const DROPPED_BLOCK_SCENE = preload("res://blocks/DroppedBlock.tscn")

func _ready():
	var viewport_size = get_viewport_rect().size
	var sprite_radius = 23 * scale.x 
	add_to_group("players")
	min_pos = Vector2(sprite_radius, sprite_radius)
	max_pos = Vector2(viewport_size.x - sprite_radius, viewport_size.y - sprite_radius)

func _process(_delta):
	if not can_move: return 
	var aim_x = Input.get_axis("aimL", "aimR")
	var aim_y = Input.get_axis("aimU", "aimD")
	aim_direction = Vector2(aim_x, aim_y)
	if aim_direction != Vector2.ZERO:
		target_angle = round(aim_direction.angle() / ANGLE_INCREMENT) * ANGLE_INCREMENT

func _physics_process(delta):
	if not can_move: return 
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
			
	if movement_queued:
		cockpit.rotation = lerp_angle(cockpit.rotation, cockpit_target_angle, rotation_speed * delta)
		if abs(wrapf(cockpit_target_angle - cockpit.rotation, -PI, PI)) <= 0.03:
			movement_queued = false
			
	if aim_direction != Vector2.ZERO:
		cannon.rotation = lerp_angle(cannon.rotation, target_angle, rotation_speed * delta)

func _unhandled_input(event):
	if not can_move: return
	if event.is_action_pressed("ui_accept"): # R2
		_attempt_loot_pickup()
	if event.is_action_pressed("ui_swap_storage"): # L2
		_swap_temp_and_perm_storage()

func _attempt_loot_pickup():
	var nearest_drop: Node2D = null
	var min_dist: float = INF
	
	for drop in get_tree().get_nodes_in_group("drops"):
		var dist = global_position.distance_to(drop.global_position)
		if dist < LOOT_PICKUP_RANGE and dist < min_dist:
			min_dist = dist
			nearest_drop = drop
			
	if nearest_drop != null and nearest_drop.stored_block != null:
		var new_block = nearest_drop.stored_block
		
		# Eject old block if Temp Storage is full
		if GlobalState.master_temp_storage.size() > 0:
			var ejected_block = GlobalState.master_temp_storage.pop_back()
			var drop_instance = DROPPED_BLOCK_SCENE.instantiate()
			get_parent().add_child(drop_instance)
			drop_instance.global_position = global_position
			drop_instance.setup(ejected_block)
		
		GlobalState.master_temp_storage.append(new_block)
		nearest_drop.queue_free()

func _swap_temp_and_perm_storage():
	var current_temp = null
	if GlobalState.master_temp_storage.size() > 0:
		current_temp = GlobalState.master_temp_storage.pop_back()
		
	var current_perm = GlobalState.master_perm_storage
	
	GlobalState.master_perm_storage = current_temp
	if current_perm != null:
		GlobalState.master_temp_storage.append(current_perm)

func get_gun_position() -> Vector2: return gun.global_position
func get_aim_angle() -> float: return round(cannon.rotation / ANGLE_INCREMENT) * ANGLE_INCREMENT
