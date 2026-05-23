# File: res://ui/CombatStorageUI.gd
extends Control

@onready var perm_rect = $PermRect
@onready var temp_rect = $TempRect
@onready var temp_label = $TempLabel

func _ready():
	# Visual layout setup
	perm_rect.size = Vector2(30, 30)
	perm_rect.position = Vector2(10, 10)
	
	temp_rect.size = Vector2(30, 30)
	temp_rect.position = Vector2(10, 50)
	
	temp_label.position = Vector2(50, 55)
	temp_label.add_theme_font_size_override("font_size", 12)

func _process(_delta):
	var perm = GlobalState.master_perm_storage
	var temp = GlobalState.master_temp_storage
	
	# Update Permanent Storage Slot
	if perm != null:
		perm_rect.color = perm.color
	else:
		perm_rect.color = Color(0.2, 0.2, 0.2, 0.5) # Dark empty slot
		
	# Update Temporary Storage Slot & Text
	if temp != null:
		temp_rect.color = temp.color
		# Display name + remaining integrity time
		temp_label.text = "%s (%.1fs)" % [temp.display_name, temp.remaining_integrity]
	else:
		temp_rect.color = Color(0.2, 0.2, 0.2, 0.5)
		temp_label.text = "TEMP: EMPTY"
