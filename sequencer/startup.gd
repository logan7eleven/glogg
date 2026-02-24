# File: Startup.gd
extends Node

# This function is called automatically when the game launches.
func _ready():
	# Define your game's native "designed-for" resolution.
	var base_game_size = Vector2(1200, 800)

	# Get the size of the user's primary monitor.
	var screen_size = DisplayServer.screen_get_size()

	# Check if the screen is smaller than our game's base size in either dimension.
	if screen_size.x < base_game_size.x or screen_size.y < base_game_size.y:
		
		# --- This is the smart-scaling logic ---
		
		# Calculate how much we need to scale down on each axis.
		var scale_x = float(screen_size.x) / base_game_size.x
		var scale_y = float(screen_size.y) / base_game_size.y
		
		# To maintain the aspect ratio, we must use the *smaller* of the two scales.
		# This ensures the window fits within both the width and height of the screen.
		var scale_factor = min(scale_x, scale_y)
		
		# Apply a small margin (e.g., 95%) so the window isn't pressed right up
		# against the screen edges, which can look odd or interfere with OS toolbars.
		scale_factor *= 0.95 

		# Calculate the new, safe window size.
		var new_window_size = base_game_size * scale_factor
		
		# Set the new window size. It must be an integer (Vector2i).
		get_window().size = Vector2i(new_window_size)
		
		# It's good practice to center the newly resized window.
		get_window().position = (screen_size - new_window_size) / 2
		
	else:
		# If the screen is large enough, just center the default 1200x800 window.
		get_window().position = (screen_size - base_game_size) / 2
