# File: res://ui/CombatStorageUI.gd
extends Control

@onready var perm_rect = $PermRect
@onready var temp_rect = $TempRect
@onready var temp_label = $TempLabel
@onready var perm_label = $PermLabel
@onready var perm_indicator: Label

func _ready():
	# Visual layout setup
	perm_rect.size = Vector2(30, 30)
	perm_rect.position = Vector2(10, 10)
	
	temp_rect.size = Vector2(30, 30)
	temp_rect.position = Vector2(10, 50)
	
	temp_label.position = Vector2(50, 55)
	temp_label.add_theme_font_size_override("font_size", 12)

	# --- 1. PERMANENT STORAGE LABELS ---
	perm_label = Label.new()
	perm_label.position = Vector2(50, 15)
	perm_label.add_theme_font_size_override("font_size", 12)
	add_child(perm_label)
	
	perm_indicator = Label.new()
	perm_indicator.text = "[PERM]"
	perm_indicator.modulate = Color.GOLD
	perm_indicator.position = Vector2(0, -15)
	perm_indicator.add_theme_font_size_override("font_size", 10)
	perm_rect.add_child(perm_indicator)

	# --- 2. TEMPORARY STORAGE LABELS ---
	var temp_indicator = Label.new()
	temp_indicator.text = "[TEMP]"
	temp_indicator.modulate = Color.LIGHT_BLUE
	temp_indicator.position = Vector2(0, -15)
	temp_indicator.add_theme_font_size_override("font_size", 10)
	temp_rect.add_child(temp_indicator)

	# --- 3. LEVEL CONTROLS HINT ---
	var level_controls_hint = Label.new()
	level_controls_hint.text = "[X] Pick Up Drop    [Triangle] Swap Storage"
	level_controls_hint.position = Vector2(10, 95) # Sits right below the Temp Storage box
	level_controls_hint.modulate = Color(0.7, 0.7, 0.7) # Light gray so it isn't distracting
	level_controls_hint.add_theme_font_size_override("font_size", 12)
	add_child(level_controls_hint)

func _process(_delta):
	var perm = GlobalState.master_perm_storage
	
	# Look at the top of the stack for Temp Storage
	var temp = null
	if GlobalState.master_temp_storage.size() > 0:
		temp = GlobalState.master_temp_storage.back()
	
	# Update Permanent Storage Slot
	if perm != null:
		perm_rect.color = perm.color
		perm_label.text = perm.display_name
	else:
		perm_rect.color = Color(0.2, 0.2, 0.2, 0.5) 
		perm_label.text = "EMPTY"
		
	# Update Temporary Storage Slot & Text
	if temp != null:
		temp_rect.color = temp.color
		temp_label.text = "%s (%.1fs)" % [temp.display_name, temp.remaining_integrity]
	else:
		temp_rect.color = Color(0.2, 0.2, 0.2, 0.5)
		temp_label.text = "EMPTY"
