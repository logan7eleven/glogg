# level.gd (Countdown, Boss Placeholder, Win State - Cleaned & Updated Spawn/Movement)
extends Node2D

# --- Node References ---
@onready var projectile_pool = $BulletPool
@onready var slot_manager = $SlotManager
@onready var game_over_label = $GameOverLabel # Displays Game Over & Countdown
@onready var game_win_label = $GameWinLabel   # Separate Label for Win
@onready var countdown_timer = $CountdownTimer # Timer node for countdown

# --- Wave Management ---
var current_wave: int = 0 # 0-indexed
var base_enemy_count = 4
var next_enemy_id: int = 1
var next_crawler_id: int = 1
var next_scooter_id: int = 1 # Keep for future use

# --- Game State ---
var game_is_over: bool = false # Covers both win and loss
var original_process_mode: ProcessMode
var is_boss_fight: bool = false
var current_boss_num: int = 0
var boss_placeholder: Area2D = null # Placeholder for boss target
var countdown_value: int = 3
var player_spawn_position: Vector2 = Vector2(600, 400) # Store player spawn pos

# --- Scene Preloads ---
const CRAWLER_SCENE = preload("res://crawler.tscn") # Ensure extends EnemyBase
# const SCOOTER_SCENE = preload("res://scooter.tscn") # Keep commented out for now
const PLAYER_SCENE = preload("res://glogg.tscn")

# --- Engine Methods ---
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	original_process_mode = process_mode

	# Setup Labels & Timer (Assume nodes exist via @onready)
	_configure_center_label(game_over_label); game_over_label.hide()
	_configure_center_label(game_win_label); game_win_label.hide()
	countdown_timer.wait_time = 1.0; countdown_timer.one_shot = false
	if not countdown_timer.is_connected("timeout", Callable(self, "_on_countdown_tick")):
		countdown_timer.connect("timeout", Callable(self, "_on_countdown_tick"))

	spawn_player()

	# Connect signals
	if not slot_manager.is_connected("slots_initialized", Callable(GlobalState, "initialize_slot_upgrades")):
		slot_manager.connect("slots_initialized", Callable(GlobalState, "initialize_slot_upgrades"))

	# Start the first wave setup immediately (spawns enemies, then starts countdown)
	start_next_wave()


func _configure_center_label(label: Label):
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 150)


func start_level_countdown():
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if player: # Simple null check
		player.can_move = false # Disable player movement

	# Enemies are already spawned but have can_move = false in EnemyBase

	countdown_value = 3
	_show_countdown_value()
	countdown_timer.start()


func _on_countdown_tick():
	countdown_value -= 1
	_show_countdown_value()
	if countdown_value <= 0:
		countdown_timer.stop()
		_start_wave_actual()


func _show_countdown_value():
	game_over_label.text = str(countdown_value) if countdown_value > 0 else "GO!"
	game_over_label.show()
	# Use a short timer for the "GO!" message visibility
	if countdown_value <= 0:
		await get_tree().create_timer(0.5).timeout # Show "GO!" for half a second
		game_over_label.hide() # Hide after the short delay


func _start_wave_actual():
	print("Starting Wave %d" % current_wave)
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if player: # Simple null check
		player.can_move = true

	# Enable enemy movement by setting the flag on all enemies in the group
	for enemy in get_tree().get_nodes_in_group("enemies_physics"):
		if enemy is EnemyBase: # Type check for safety
			enemy.can_move = true

	# Wave logic already started in start_next_wave


func spawn_player():
	var player = PLAYER_SCENE.instantiate() as Area2D
	player.slot_manager = slot_manager # Direct assignment
	player.position = player_spawn_position # Use stored variable
	add_child(player)


func start_next_wave():
	if game_is_over or is_boss_fight: return
	cleanup_wave_entities() # Clear previous wave enemies first
	
	next_enemy_id = 1
	next_crawler_id = 1
	next_scooter_id = 1 

	var num_enemies = base_enemy_count + current_wave
	GlobalState.set_next_wave_threshold(num_enemies)
	GlobalState.reset_enemies_destroyed()

	# Spawn enemies for the upcoming wave
	spawn_enemies(num_enemies)

	current_wave += 1

	# Start the countdown which will enable movement later
	start_level_countdown()


func get_current_wave() -> int: return current_wave


func spawn_enemies(count: int):
	# Currently only spawning crawlers
	var scene_to_spawn = CRAWLER_SCENE
	for i in range(count):
		# If adding more enemy types, add logic here to choose scene_to_spawn
		# scene_to_spawn = CRAWLER_SCENE if i % 2 == 0 else SCOOTER_SCENE

		var enemy_instance = scene_to_spawn.instantiate()

		# Check if it inherits correctly from EnemyBase
		if not enemy_instance is EnemyBase:
			printerr("Spawn Error: Instanced scene '%s' does not extend EnemyBase!" % scene_to_spawn.resource_path)
			enemy_instance.queue_free()
			continue

		# Assign IDs
		enemy_instance.enemy_id = next_enemy_id
		next_enemy_id += 1
		if enemy_instance is Crawler: # Check specific type if needed
			enemy_instance.crawler_id = next_crawler_id
			next_crawler_id += 1
		# Add elif for other types like scooter when ready
		# elif enemy_instance is Scooter:
		# 	enemy_instance.scooter_id = next_scooter_id
		# 	next_scooter_id += 1

		# Set position using the new random logic
		enemy_instance.position = _get_random_spawn_position()

		# Connect signals (already checked it's EnemyBase)
		if not enemy_instance.is_connected("damaged", Callable(slot_manager, "record_damage")):
			enemy_instance.connect("damaged", Callable(slot_manager, "record_damage"))
		if not enemy_instance.is_connected("killed", Callable(slot_manager, "record_kill")):
			enemy_instance.connect("killed", Callable(slot_manager, "record_kill"))

		# Add to scene (enemies start with can_move = false by default in EnemyBase)
		add_child(enemy_instance)


# RENAMED and MODIFIED function for random spawn away from player start
func _get_random_spawn_position() -> Vector2:
	var viewport_rect = get_viewport_rect()
	var margin = 50.0 # Keep a small margin from edge
	var min_distance_from_player = 300.0
	var spawn_pos = Vector2.ZERO
	var attempts = 0
	var max_attempts = 50 # Safety break

	while attempts < max_attempts:
		attempts += 1
		spawn_pos.x = randf_range(margin, viewport_rect.size.x - margin)
		spawn_pos.y = randf_range(margin, viewport_rect.size.y - margin)

		if spawn_pos.distance_to(player_spawn_position) >= min_distance_from_player:
			return spawn_pos # Found a valid position

	printerr("Level: Could not find valid spawn position after %d attempts. Using last attempt." % max_attempts)
	return spawn_pos # Return last generated position if loop fails


func cleanup_wave_entities():
	# Use the group added in EnemyBase._ready() to remove enemies
	get_tree().call_group("enemies_physics", "queue_free")
	# Bullet cleanup is now handled separately by cleanup_active_bullets


# ADDED: Specific function for bullet cleanup called by SceneLoader/Level
func cleanup_active_bullets():
	# Deactivate bullets currently active in the Level scene
	# Check children of the Level node itself
	for child in get_children():
		# Check group AND visibility to only affect active bullets
		if child.is_in_group("bullets") and child.visible:
			if child.has_method("deactivate"):
				child.deactivate()
			else:
				printerr("Level: Bullet node missing deactivate method!")
				child.queue_free() # Fallback


func cleanup_all_entities():
	cleanup_wave_entities() # Removes enemies
	cleanup_active_bullets() # Removes active bullets
	var player = get_tree().get_first_node_in_group("players")
	if player: player.queue_free()
	if boss_placeholder: boss_placeholder.queue_free(); boss_placeholder = null


func start_boss_fight(boss_num: int):
	if game_is_over: return
	is_boss_fight = true; current_boss_num = boss_num
	cleanup_wave_entities() # Clear regular enemies
	cleanup_active_bullets() # Clear bullets

	# Display Boss Text
	game_over_label.text = "BOSS!"; game_over_label.show()
	# Ensure player can move
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if player: player.can_move = true

	# --- BOSS SPAWN LOGIC (Placeholder) ---
	boss_placeholder = Area2D.new()
	boss_placeholder.add_to_group("boss_target") # Group for bullet collision
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 50
	boss_placeholder.add_child(shape)
	boss_placeholder.position = Vector2(get_viewport_rect().size.x / 2, 150) # Example position
	add_child(boss_placeholder)
	# --- END BOSS SPAWN ---


func game_over(message: String = "GAME OVER"):
	if game_is_over: return
	game_is_over = true; is_boss_fight = false
	SceneLoader.print_final_slot_stats()
	cleanup_all_entities()
	var label_to_show = game_over_label
	var text_to_show = "GAME OVER"
	if message == "YOU WIN!":
		label_to_show = game_win_label # Use the win label
		text_to_show = "YOU WIN!"
	label_to_show.text = text_to_show; label_to_show.show()
	process_mode = Node.PROCESS_MODE_ALWAYS # Allow input
	if not get_tree().paused: SceneLoader.pause_game()


func boss_hit():
	if not is_boss_fight: return
	print("Boss %d Placeholder Hit! Next Stage..." % current_boss_num)
	is_boss_fight = false # Clear flag

	# Clean up placeholder and text
	if is_instance_valid(boss_placeholder):
		boss_placeholder.queue_free(); boss_placeholder = null
	if is_instance_valid(game_over_label):
		game_over_label.hide()

	# Tell SceneLoader boss is defeated
	# Ensure SceneLoader exists (it's an autoload, should be fine)
	SceneLoader.post_boss_victory(current_boss_num)


func _unhandled_input(event):
	# Allow skipping boss via accept button (for testing)
	if is_boss_fight and not game_is_over and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled() # Consume the input
		boss_hit() # Call the same function as shooting the boss
		return # Stop further input processing for this event

	# Handle return to menu on game over/win
	if game_is_over and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled() # Handle input first
		process_mode = original_process_mode
		game_is_over = false
		if get_tree().paused: SceneLoader.resume_game() # Unpause tree
		get_tree().change_scene_to_file("res://UI_MainMenu.tscn")
