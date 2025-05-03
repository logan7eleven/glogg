# level.gd (Countdown, Boss Placeholder, Win State - Cleaned)
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
var v1_crawler_positions: Array[Vector2] = []
var next_crawler_id: int = 0

# --- Game State ---
var game_is_over: bool = false # Covers both win and loss
var original_process_mode: ProcessMode
var is_boss_fight: bool = false
var current_boss_num: int = 0
var boss_placeholder: Area2D = null # Placeholder for boss target
var countdown_value: int = 3

# --- Scene Preloads ---
const CRAWLER_SCENE = preload("res://crawler.tscn") # Ensure extends EnemyBase
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

	# Define fixed spawn positions
	var viewport_size = get_viewport_rect().size
	v1_crawler_positions = [ Vector2(100, 100), Vector2(viewport_size.x - 100, 100), Vector2(100, viewport_size.y - 100), Vector2(viewport_size.x - 100, viewport_size.y - 100) ]

	spawn_player()

	# Connect signals
	if not slot_manager.is_connected("slots_initialized", Callable(GlobalState, "initialize_slot_upgrades")):
		slot_manager.connect("slots_initialized", Callable(GlobalState, "initialize_slot_upgrades"))

	start_level_countdown()


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
	await get_tree().create_timer(0.25).timeout
	game_over_label.hide()


func _start_wave_actual():
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if player: # Simple null check
		player.can_move = true # Enable player movement

	start_next_wave()


func spawn_player():
	var player = PLAYER_SCENE.instantiate() as Area2D
	player.slot_manager = slot_manager # Direct assignment
	player.position = Vector2(600, 400)
	add_child(player)


func start_next_wave():
	if game_is_over or is_boss_fight: return
	cleanup_wave_entities()
	var num_enemies = base_enemy_count + current_wave
	GlobalState.set_next_wave_threshold(num_enemies)
	GlobalState.reset_enemies_destroyed()
	spawn_enemies(num_enemies, current_wave == 0)
	current_wave += 1


func get_current_wave() -> int: return current_wave


func spawn_enemies(count: int, use_fixed_positions: bool):
	var scene_to_spawn = CRAWLER_SCENE
	for i in range(count):
		var enemy_instance = scene_to_spawn.instantiate() # Instantiate first
		# --- CORRECTED CHECK ---
		if not enemy_instance is EnemyBase: # Check if it inherits correctly
			if enemy_instance.has_method("apply_status_effect"): # Fallback check
				pass # Assume okay if methods exist
			else:
				printerr("Spawn Error: Instanced scene does not extend EnemyBase or have required methods!")
				enemy_instance.queue_free() # Clean up invalid instance
				continue # Skip to next enemy
		# --- END CORRECTION ---

		# Assign Type-Specific ID
		# Use 'in' check which is safer for script variables
		if "crawler_id" in enemy_instance: enemy_instance.crawler_id = next_crawler_id; next_crawler_id += 1
		# elif "scooter_id" in enemy_instance: enemy_instance.scooter_id = next_scooter_id; next_scooter_id += 1

		# Set position
		if use_fixed_positions and i < v1_crawler_positions.size(): enemy_instance.position = v1_crawler_positions[i]
		else: enemy_instance.position = _get_random_border_position()

		# Connect signals
		if not enemy_instance.is_connected("damaged", Callable(slot_manager, "record_damage")):
			enemy_instance.connect("damaged", Callable(slot_manager, "record_damage"))
		if not enemy_instance.is_connected("killed", Callable(slot_manager, "record_kill")):
			enemy_instance.connect("killed", Callable(slot_manager, "record_kill"))

		add_child(enemy_instance)

func _get_random_border_position() -> Vector2:
	var viewport_rect = get_viewport_rect()
	var margin = 50.0; var spawn_pos = Vector2.ZERO; var side = randi() % 4
	match side:
		0: spawn_pos = Vector2(randf_range(margin, viewport_rect.size.x - margin), margin)
		1: spawn_pos = Vector2(randf_range(margin, viewport_rect.size.x - margin), viewport_rect.size.y - margin)
		2: spawn_pos = Vector2(margin, randf_range(margin, viewport_rect.size.y - margin))
		3: spawn_pos = Vector2(viewport_rect.size.x - margin, randf_range(margin, viewport_rect.size.y - margin))
	return spawn_pos


func cleanup_wave_entities():
	get_tree().call_group("enemies", "queue_free") # Removes nodes in "enemies" group
	# Deactivate bullets currently active in the Level scene
	var children_to_check = get_children()
	for child in children_to_check:
		if child.is_in_group("bullets") and child.visible:
			child.deactivate() # Assume deactivate exists and works


func cleanup_all_entities():
	cleanup_wave_entities()
	var player = get_tree().get_first_node_in_group("players")
	if player: player.queue_free() # Simple null check
	if boss_placeholder: boss_placeholder.queue_free(); boss_placeholder = null


func start_boss_fight(boss_num: int):
	if game_is_over: return
	is_boss_fight = true; current_boss_num = boss_num
	cleanup_wave_entities()
	
	# Display Boss Text
	game_over_label.text = "BOSS!"; game_over_label.show()
	# Ensure player can move
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if player: player.can_move = true

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
	print("Level: Boss %d Placeholder Hit/Skipped! Proceeding..." % current_boss_num)
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
	if is_boss_fight and not game_is_over and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled() # Consume the input
		boss_hit() # Call the same function as shooting the boss
		return # Stop further input processing for this event
	if game_is_over and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled() # Handle input first
		process_mode = original_process_mode
		game_is_over = false
		if get_tree().paused: SceneLoader.resume_game() # Unpause tree
		get_tree().change_scene_to_file("res://UI_MainMenu.tscn")
