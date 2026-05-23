# File: res://level.gd
extends Node2D

# --- Node References ---
@onready var projectile_pool = $BulletPool
@onready var sequencer_manager = $SequencerManager 
@onready var game_over_label = $GameOverLabel
@onready var game_win_label = $GameWinLabel 
@onready var countdown_timer = $CountdownTimer

# --- Wave Management ---
var current_wave: int = 0
var base_enemy_count = 4
var enemy_increment_per_wave = 4
var next_enemy_id: int = 1
var next_crawler_id: int = 1

# --- Game State ---
var game_is_over: bool = false 
var original_process_mode: ProcessMode
var is_boss_fight: bool = false
var current_boss_num: int = 0
var countdown_value: int = 3
var player_spawn_position: Vector2 = Vector2(600, 400)

# --- Scene Preloads ---
const CRAWLER_SCENE = preload("res://crawler.tscn")
const PLAYER_SCENE = preload("res://glogg.tscn")
const DROPPED_BLOCK_SCENE = preload("res://loot/DroppedBlock.tscn")

signal countdown_started(initial_countdown_value: int)
signal countdown_tick(current_countdown_value: int)
signal countdown_go
signal wave_combat_started
signal game_over_or_win_initiated
signal boss_fight_starting

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	original_process_mode = process_mode
	_configure_center_label(game_over_label)
	game_over_label.hide()
	_configure_center_label(game_win_label)
	game_win_label.hide()
	
	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	if not countdown_timer.is_connected("timeout", Callable(self, "_on_countdown_tick")):
		countdown_timer.connect("timeout", Callable(self, "_on_countdown_tick"))
		
	spawn_player()
	start_next_wave()

func _configure_center_label(label: Label):
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 150)

func start_level_countdown():
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if is_instance_valid(player):
		player.can_move = false
	countdown_value = 3
	emit_signal("countdown_started", countdown_value)
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
	if countdown_value > 0:
		emit_signal("countdown_tick", countdown_value)
	else: 
		emit_signal("countdown_go")
	if countdown_value <= 0:
		await get_tree().create_timer(0.5).timeout
		game_over_label.hide()

func _start_wave_actual():
	print("Starting Wave %d" % current_wave)
	emit_signal("wave_combat_started")
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if is_instance_valid(player):
		player.can_move = true
	for enemy in get_tree().get_nodes_in_group("enemies_physics"):
		enemy.can_move = true

func spawn_player():
	var player = PLAYER_SCENE.instantiate() as Area2D
	player.position = player_spawn_position 
	add_child(player)

func start_next_wave():
	if game_is_over or is_boss_fight: 
		return
	cleanup_wave_entities()
	next_enemy_id = 1
	next_crawler_id = 1
	var num_enemies = base_enemy_count + (current_wave * enemy_increment_per_wave)
	GlobalState.set_next_wave_threshold(num_enemies)
	GlobalState.reset_enemies_destroyed()
	spawn_enemies(num_enemies)
	current_wave += 1
	start_level_countdown()

func get_current_wave() -> int: 
	return current_wave

func spawn_enemies(count: int):
	var spawned_enemies = []
	
	for i in range(count):
		var enemy_instance = CRAWLER_SCENE.instantiate()
		enemy_instance.enemy_id = next_enemy_id
		next_enemy_id += 1
		if enemy_instance.get("crawler_id") != null:
			enemy_instance.crawler_id = next_crawler_id
			next_crawler_id += 1
			
		enemy_instance.position = _get_random_spawn_position()
		enemy_instance.set_meta("held_drop", null)
		
		# Bind the enemy_instance to the signal so the kill function knows where to spawn the drop
		if not enemy_instance.is_connected("killed", Callable(self, "_on_enemy_killed")):
			enemy_instance.connect("killed", Callable(self, "_on_enemy_killed").bind(enemy_instance))
			
		add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)

	# --- LEVEL BUDGETER LOGIC ---
	var drops_to_assign = 3 + current_wave
	drops_to_assign = min(drops_to_assign, spawned_enemies.size())
	
	spawned_enemies.shuffle()
	
	for i in range(drops_to_assign):
		var generated_block = BlockFactory.create_random_block(SceneLoader.ALL_EFFECTS)
		spawned_enemies[i].set_meta("held_drop", generated_block)

func _on_enemy_killed(source_block: BlockData, credit: float, enemy_node: Node2D):
	# 1. Instantiate the physical drop item
	var drop = DROPPED_BLOCK_SCENE.instantiate()
	drop.global_position = enemy_node.global_position
	
	# 2. Generate a random block for the player to pick up
	var new_block = BlockData.new()
	new_block.display_name = "Looted Block"
	new_block.color = Color(randf(), randf(), randf()) # Random color
	new_block.width = 1
	new_block.height = 1
	new_block.remaining_integrity = 5.0
	
	# Assign the basic shoot behavior so it actually works when placed
	new_block.behavior = GlobalState.BASIC_SHOOT_BEHAVIOR 
	new_block.initialize()
	
	# 3. Store the block inside the drop and add it to the level
	drop.setup(new_block)
	call_deferred("add_child", drop)

func _get_random_spawn_position() -> Vector2:
	var viewport_rect = get_viewport_rect()
	var margin = 50.0 
	var min_distance_from_player = 300.0
	var spawn_pos = Vector2.ZERO
	var attempts = 0
	var max_attempts = 50 
	while attempts < max_attempts:
		attempts += 1
		spawn_pos.x = randf_range(margin, viewport_rect.size.x - margin)
		spawn_pos.y = randf_range(margin, viewport_rect.size.y - margin)
		if spawn_pos.distance_to(player_spawn_position) >= min_distance_from_player:
			return spawn_pos
	return spawn_pos

func cleanup_wave_entities():
	get_tree().call_group("enemies", "queue_free")

func cleanup_active_bullets():
	for child in get_children():
		if child.is_in_group("bullets") and child.visible:
			if child.has_method("deactivate"):
				child.deactivate()

func cleanup_all_entities():
	cleanup_wave_entities() 
	cleanup_active_bullets() 
	var player = get_tree().get_first_node_in_group("players")
	if is_instance_valid(player):
		player.queue_free()

func start_boss_fight(boss_num: int):
	if game_is_over: 
		return
	is_boss_fight = true
	current_boss_num = boss_num
	cleanup_wave_entities() 
	cleanup_active_bullets() 
	game_over_label.text = "BOSS!"
	game_over_label.show()
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if is_instance_valid(player):
		player.can_move = true
	emit_signal("boss_fight_starting")

func game_over(message: String = "GAME OVER"):
	if game_is_over: 
		return
	game_is_over = true
	is_boss_fight = false
	cleanup_all_entities()
	var label_to_show = game_over_label
	var text_to_show = "GAME OVER"
	if message == "YOU WIN!":
		label_to_show = game_win_label 
		text_to_show = "YOU WIN!"
	label_to_show.text = text_to_show
	label_to_show.show()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().paused: SceneLoader.pause_game()
	emit_signal("game_over_or_win_initiated")

func boss_hit():
	if not is_boss_fight: return
	is_boss_fight = false 
	game_over_label.hide()
	SceneLoader.post_boss_victory(current_boss_num)

func _unhandled_input(event):
	if is_boss_fight and not game_is_over and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled() 
		boss_hit()
		return 
	if game_is_over and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled() 
		process_mode = original_process_mode
		game_is_over = false
		if get_tree().paused: SceneLoader.resume_game() 
		get_tree().change_scene_to_file("res://UI_MainMenu.tscn")
