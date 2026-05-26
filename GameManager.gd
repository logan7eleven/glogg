# File: res://GameManager.gd
extends Node

signal upgrades_ready
signal boss_fight_starting(boss_num: int)

# --- Wave Management (Budget System) ---
var current_wave: int = 0
var budget_per_wave: float = 3.5
var enemies_destroyed_this_wave: int = 0
var enemies_required_this_wave: int = 0
var blocks_dropped_this_wave: int = 0

# --- Enemy Catalog ---
var enemy_catalog = [
	{"path": "res://enemies/crawler.tscn", "cost": 1.0},
	{"path": "res://enemies/scooter.tscn", "cost": 2.0},
	{"path": "res://enemies/slider.tscn", "cost": 3.0}
]

# --- Game State ---
var is_boss_fight: bool = false
var current_boss_num: int = 0

func start_new_run():
	current_wave = 0
	is_boss_fight = false
	GlobalState.reset_for_new_game()

func prepare_next_wave() -> Array[PackedScene]:
	current_wave += 1
	enemies_destroyed_this_wave = 0
	blocks_dropped_this_wave = 0
	
	var current_budget = current_wave * budget_per_wave
	var wave_roster: Array[PackedScene] = []
	
	# Keep buying enemies until we can't afford even the cheapest one (cost 1.0)
	while current_budget >= 1.0:
		var affordable_enemies = []
		
		# Find who we can afford
		for enemy in enemy_catalog:
			if enemy.cost <= current_budget:
				affordable_enemies.append(enemy)
				
		if affordable_enemies.is_empty():
			break
			
		# Pick randomly, deduct cost, add to roster
		var chosen_enemy = affordable_enemies.pick_random()
		current_budget -= chosen_enemy.cost
		wave_roster.append(load(chosen_enemy.path))
		
	# Tell the manager how many kills to expect before ending the wave
	enemies_required_this_wave = wave_roster.size()
	
	return wave_roster

func record_enemy_death():
	if is_boss_fight:
		return
		
	enemies_destroyed_this_wave += 1
	if enemies_destroyed_this_wave >= enemies_required_this_wave:
		trigger_planning_phase()

func roll_for_block_drop() -> bool:
	if is_boss_fight:
		return false # Bosses usually have their own custom drop rules!

	# How many enemies are left alive in this wave?
	var remaining_enemies = enemies_required_this_wave - enemies_destroyed_this_wave
	
	# If this is the very last enemy, and NO blocks have dropped yet, force it to true!
	var guarantee_drop = (remaining_enemies <= 1 and blocks_dropped_this_wave == 0)
	
	# randf() generates a decimal between 0.0 and 1.0. 
	# Checking if it is <= 0.3 gives us exactly a 30% chance.
	if guarantee_drop or randf() <= 0.3:
		blocks_dropped_this_wave += 1
		return true
		
	return false

func trigger_planning_phase():
	emit_signal("upgrades_ready")

func start_boss_fight(boss_num: int):
	is_boss_fight = true
	current_boss_num = boss_num
	emit_signal("boss_fight_starting", boss_num)

func end_boss_fight():
	is_boss_fight = false
	SceneLoader.post_boss_victory(current_boss_num)
