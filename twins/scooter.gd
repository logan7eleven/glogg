extends CharacterBody2D

# --- Configuration ---
@export var pivot_degrees: float = 60.0 # Degrees to rotate each pivot step
const TARGET_UPDATE_INTERVAL: float = 1.0 # Used if configuring timer in code
const PIVOT_INTERVAL: float = 0.25 # Duration of one pivot animation
# const DEFAULT_ANIMATION_NAME: String = "sprite_cycle_and_flip"

# --- Node References ---
@onready var hitbox = $HitBox
@onready var sprite = $Sprite2D
@onready var pivot_container = $Pivots
@onready var target_timer = $TargetTimer # RENAMED Variable & Node Path
@onready var pivot_timer = $PivotTimer
@onready var animation_player = $AnimationPlayer

# --- State Variables ---
var player: Node2D = null
var target_position: Vector2 = Vector2.ZERO
var pivot_markers: Array[Marker2D] = []
var closest_pivot_marker: Marker2D = null
var second_closest_pivot_marker: Marker2D = null
var use_closest_pivot_next: bool = true
var crawler_id: int = -1

# --- Pivot Animation State ---
var is_pivoting: bool = false
var pivot_start_transform: Transform2D
var pivot_target_transform: Transform2D
var pivot_progress: float = 0.0 # Goes from 0.0 to 1.0 over PIVOT_INTERVAL

func _ready():
	add_to_group("enemies")

	# (Get Pivot Markers)
	if pivot_container:
		for child in pivot_container.get_children():
			if child is Marker2D:
				pivot_markers.append(child)
	if pivot_markers.size() < 2:
		printerr("Scooter Error: Found fewer than 2 Marker2D nodes under 'Pivots'. Disabling node.")
		process_mode = Node.PROCESS_MODE_DISABLED # <<< FIX: Disable node processing
		return

	call_deferred("_find_player_and_initial_setup")

	# (Connect Timer Signals - Assuming Autostart is ON in Editor)
	if is_instance_valid(target_timer) and not target_timer.is_connected("timeout", Callable(self, "_on_target_timer_timeout")):
		target_timer.timeout.connect(_on_target_timer_timeout)
	if is_instance_valid(pivot_timer) and not pivot_timer.is_connected("timeout", Callable(self, "_on_pivot_timer_timeout")):
		pivot_timer.timeout.connect(_on_pivot_timer_timeout)

	# (Error checking)
	if not target_timer: printerr("Error: TargetTimer node not found!")


func _find_player_and_initial_setup():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players") as Node2D
	if not is_instance_valid(player):
		printerr("Scooter Error: Could not find player node. Disabling node.")
		process_mode = Node.PROCESS_MODE_DISABLED # <<< FIX: Disable node processing
		# Stop timers explicitly if they might have started before player check failed
		if is_instance_valid(pivot_timer): pivot_timer.stop()
		if is_instance_valid(target_timer): target_timer.stop()
		return

	_update_target_and_select_pivots()
	use_closest_pivot_next = true
	pivot_start_transform = global_transform
	pivot_target_transform = global_transform
	# Removed set_process_physics(true) - physics process runs by default if mode allows


# --- Timer Callbacks ---

# Called every 1.0 second by TargetTimer
func _on_target_timer_timeout(): # RENAMED Function
	if not is_instance_valid(player): return
	_update_target_and_select_pivots()
	use_closest_pivot_next = true

# Called every 0.25 seconds by PivotTimer
func _on_pivot_timer_timeout():
	if not is_instance_valid(player) or is_pivoting:
		return

	var active_pivot_marker: Marker2D = null
	if use_closest_pivot_next:
		active_pivot_marker = closest_pivot_marker
	else:
		active_pivot_marker = second_closest_pivot_marker

	if not is_instance_valid(active_pivot_marker): return

	# --- Calculate TARGET Transform ---
	var pivot_point_global: Vector2 = active_pivot_marker.global_position
	var rotation_radians: float = deg_to_rad(pivot_degrees)
	var target_dir: Vector2 = (target_position - pivot_point_global).normalized()
	var current_forward_dir = global_transform.basis_xform(Vector2.RIGHT).normalized()
	var cross_product_z: float = current_forward_dir.cross(target_dir)
	var signed_rotation_angle = rotation_radians * -sign(cross_product_z)
	if abs(cross_product_z) < 0.01: signed_rotation_angle = rotation_radians

	var current_transform: Transform2D = global_transform
	var to_pivot_origin_tf := Transform2D(0.0, -pivot_point_global)
	var rotation_tf := Transform2D(signed_rotation_angle, Vector2.ZERO)
	var from_pivot_origin_tf := Transform2D(0.0, pivot_point_global)
	var final_transform = from_pivot_origin_tf * rotation_tf * to_pivot_origin_tf * current_transform

	# --- Start the Pivot Animation ---
	pivot_start_transform = global_transform
	pivot_target_transform = final_transform
	pivot_progress = 0.0
	is_pivoting = true

	# Toggle the pivot flag for the *next* pivot action
	use_closest_pivot_next = not use_closest_pivot_next


# --- Helper Function ---
# (_update_target_and_select_pivots remains the same)
func _update_target_and_select_pivots():
	if not is_instance_valid(player): return
	target_position = player.global_position
	if pivot_markers.is_empty(): return

	var min_dist_sq = INF
	var second_min_dist_sq = INF
	var temp_closest = null
	var temp_second_closest = null

	for marker in pivot_markers:
		if not is_instance_valid(marker): continue
		var dist_sq = marker.global_position.distance_squared_to(target_position)

		if dist_sq < min_dist_sq:
			second_min_dist_sq = min_dist_sq
			temp_second_closest = temp_closest
			min_dist_sq = dist_sq
			temp_closest = marker
		elif dist_sq < second_min_dist_sq:
			second_min_dist_sq = dist_sq
			temp_second_closest = marker

	closest_pivot_marker = temp_closest
	second_closest_pivot_marker = temp_second_closest

	if not is_instance_valid(closest_pivot_marker) or not is_instance_valid(second_closest_pivot_marker):
		printerr("Scooter Error: Could not determine two distinct closest pivot markers.")
		if is_instance_valid(closest_pivot_marker):
			second_closest_pivot_marker = closest_pivot_marker
		else:
			printerr("Scooter Error: Cannot even determine a single closest pivot marker.")
			if is_instance_valid(pivot_timer): pivot_timer.stop()


# --- Physics Process for Smooth Pivot Animation ---
func _physics_process(delta):
	if is_pivoting:
		pivot_progress += delta / PIVOT_INTERVAL
		pivot_progress = clamp(pivot_progress, 0.0, 1.0)

		global_transform = pivot_start_transform.interpolate_with(pivot_target_transform, pivot_progress)

		if pivot_progress >= 1.0:
			is_pivoting = false
			# Optional: Snap exactly to target
			# global_transform = pivot_target_transform

	# --- NO move_and_slide() here ---
