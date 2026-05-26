# File: res://SceneLoader.gd
extends Node

var is_game_paused := false
var ALL_EFFECTS: Array[Resource] = []

const EFFECT_DATA_PATH = "res://status_effects/"

func _ready() -> void:
	_load_all_effects()

func _load_all_effects():
	ALL_EFFECTS.clear()
	var dir = DirAccess.open(EFFECT_DATA_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var resource = load(EFFECT_DATA_PATH + file_name)
				if resource:
					ALL_EFFECTS.append(resource)
			file_name = dir.get_next()
	else:
		printerr("SceneLoader Error: Could not open directory: %s" % EFFECT_DATA_PATH)

func pause_game():
	get_tree().paused = true
	is_game_paused = true

func resume_game():
	get_tree().paused = false
	is_game_paused = false

func _transition_to_planning_phase():
	var level_node = get_tree().current_scene
	if is_instance_valid(level_node) and level_node.get("game_is_over") == true:
		return
		
	# Skip the old popup and go straight to the grid
	get_tree().change_scene_to_file("res://planning_phase/PlanningPhase.tscn")

func post_boss_victory(boss_num: int):
	pass # Implement your post-boss transition logic here
