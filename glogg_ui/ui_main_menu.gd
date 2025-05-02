# ui_main_menu.gd (Focus Handling - Cleaned)
extends Control

@onready var start_button = $MenuOptions/SinglePlayerButton
# @onready var exit_button = $MenuOptions/ExitButton # If you have one

func _ready() -> void:
	if is_instance_valid(start_button):
		start_button.pressed.connect(_on_start_pressed)
		call_deferred("grab_initial_focus") # Wait a frame for UI readiness
	else:
		printerr("Main Menu: Start button not found!")

	# Connect exit button if it exists
	var exit_button = get_node_or_null("MenuOptions/ExitButton")
	if is_instance_valid(exit_button):
		if not exit_button.is_connected("pressed", Callable(get_tree(), "quit")):
			exit_button.connect("pressed", Callable(get_tree(), "quit"))

func grab_initial_focus():
	if is_instance_valid(start_button):
		start_button.grab_focus()

func _on_start_pressed() -> void:
	# Ensure game isn't paused if returning from game over
	if get_tree().paused: get_tree().paused = false
	# Reset SceneLoader state if needed? Usually okay on scene change.
	# if SceneLoader: SceneLoader.is_game_paused = false
	get_tree().change_scene_to_file("res://level.tscn")
