extends Control

@onready var start_button = $MenuOptions/SinglePlayerButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	call_deferred("grab_initial_focus") 
	var exit_button = get_node("MenuOptions/ExitButton")
	exit_button.connect("pressed", Callable(get_tree(), "quit"))

func grab_initial_focus():
	start_button.grab_focus()

func _on_start_pressed() -> void:
	if get_tree().paused: 
		get_tree().paused = false
	GlobalState.reset_for_new_game()
	get_tree().change_scene_to_file("res://level.tscn")
