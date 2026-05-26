# File: res://level.gd
extends Node2D

# --- Node References ---
@onready var projectile_pool = $BulletPool
@onready var sequencer_manager = $SequencerManager 
@onready var game_over_label = $GameOverLabel
@onready var game_win_label = $GameWinLabel 
@onready var countdown_timer = $CountdownTimer

# --- Local State ---
var next_enemy_id: int = 1
var next_crawler_id: int = 1
var game_is_over: bool = false 
var original_process_mode: ProcessMode
var countdown_value: int = 3
var player_spawn_position: Vector2 = Vector2(600, 400)
var waiting_for_drops: bool = false
var blocks_dropped_this_wave: int = 0
var enemies_remaining_this_wave: int = 0

# --- Scene Preloads ---
const PLAYER_SCENE = preload("res://player/glogg.tscn")
const DROPPED_BLOCK_SCENE = preload("res://blocks/DroppedBlock.tscn")

signal countdown_started(initial_countdown_value: int)
signal countdown_tick(current_countdown_value: int)
signal countdown_go
signal wave_combat_started
signal game_over_or_win_initiated

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
	
	GameManager.upgrades_ready.connect(_on_wave_cleared)
	
	# Listen for boss triggers from the GameManager
	GameManager.connect("boss_fight_starting", Callable(self, "_on_boss_fight_starting"))
		
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
	print("Starting Wave %d" % GameManager.current_wave)
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
	if game_is_over or GameManager.is_boss_fight: 
		return
		
	cleanup_wave_entities()
	next_enemy_id = 1
	blocks_dropped_this_wave = 0
	enemies_remaining_this_wave = 0
	
	var enemy_roster = GameManager.prepare_next_wave()
	spawn_enemies(enemy_roster)
	start_level_countdown()

func spawn_enemies(enemy_roster: Array[PackedScene]):
	var spawned_enemies = []
	
	for scene_to_spawn in enemy_roster:
		var enemy_instance = scene_to_spawn.instantiate()
		enemy_instance.enemy_id = next_enemy_id
		next_enemy_id += 1
		
		enemy_instance.position = _get_random_spawn_position()
		
		if not enemy_instance.is_connected("killed", Callable(self, "_on_enemy_killed")):
			enemy_instance.connect("killed", Callable(self, "_on_enemy_killed").bind(enemy_instance))
			
		add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)

	# Simply record how many enemies we have to kill this wave
	enemies_remaining_this_wave = spawned_enemies.size()

func _on_enemy_killed(source_block: BlockData, credit: float, enemy_node: Node2D):
	# 1. Update the remaining enemies
	enemies_remaining_this_wave -= 1
	var should_drop = false
	
	# 2. Roll a flat 30% chance for a drop
	if randf() <= 0.3:
		should_drop = true
		
	# 3. The Pity Timer: If this is the last enemy and you got ZERO drops, force one!
	if enemies_remaining_this_wave <= 0 and blocks_dropped_this_wave == 0:
		should_drop = true
		
	# If neither condition was met, abort
	if not should_drop:
		return 

	# 4. We are dropping a block! Count it, generate it, and spawn it.
	blocks_dropped_this_wave += 1
	var generated_block = BlockFactory.create_random_block(SceneLoader.ALL_EFFECTS)
	
	var drop = DROPPED_BLOCK_SCENE.instantiate()
	drop.global_position = enemy_node.global_position
	drop.setup(generated_block)
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

func _on_wave_cleared():
	# The last enemy died. Turn on the drop scanner!
	waiting_for_drops = true

func _process(_delta):
	# If the wave is over, constantly check if there is any loot left on the floor
	if waiting_for_drops:
		if get_tree().get_nodes_in_group("drops").size() == 0:
			# No drops left! Now we can safely load the next screen.
			waiting_for_drops = false
			SceneLoader._transition_to_planning_phase()

func _on_boss_fight_starting(boss_num: int):
	if game_is_over: 
		return
	cleanup_wave_entities() 
	cleanup_active_bullets() 
	game_over_label.text = "BOSS!"
	game_over_label.show()
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if is_instance_valid(player):
		player.can_move = true

func game_over(message: String = "GAME OVER"):
	if game_is_over: 
		return
	game_is_over = true
	GameManager.is_boss_fight = false
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
	if not GameManager.is_boss_fight: return
	game_over_label.hide()
	GameManager.end_boss_fight()

func _unhandled_input(event):
	if GameManager.is_boss_fight and not game_is_over and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled() 
		boss_hit()
		return 
	if game_is_over and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled() 
		process_mode = original_process_mode
		game_is_over = false
		if get_tree().paused: SceneLoader.resume_game() 
		get_tree().change_scene_to_file("res://UI_MainMenu.tscn")
