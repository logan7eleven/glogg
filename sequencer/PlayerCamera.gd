extends Camera2D

@export var follow_smoothing: float = 4.0
@export var gameplay_zoom_level: float = 1.0 / 0.8
@export var overview_zoom_level: float = 1.0  
@export var zoom_transition_speed: float = 1.0 

var player: Node2D = null
var game_bounds_rect: Rect2 = Rect2()
var viewport_actual_size: Vector2 = Vector2()
var level_node_ref: Node2D = null
var target_zoom_scalar: float
var target_is_overview_mode: bool 
var process_state = InternalCameraProcessState.IDLE

enum InternalCameraProcessState { IDLE, TRANSITIONING }

func _ready():
	viewport_actual_size = get_viewport_rect().size
	game_bounds_rect = Rect2(0, 0, viewport_actual_size.x, viewport_actual_size.y)
	target_is_overview_mode = true
	target_zoom_scalar = overview_zoom_level
	self.zoom = Vector2(target_zoom_scalar, target_zoom_scalar) 
	self.global_position = game_bounds_rect.get_center()  
	_clamp_camera_position() 
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	level_node_ref = get_parent() as Node2D
	level_node_ref.connect("countdown_started", Callable(self, "_on_level_countdown_started"))
	level_node_ref.connect("countdown_go", Callable(self, "_on_level_countdown_go"))
	level_node_ref.connect("game_over_or_win_initiated", Callable(self, "_request_overview_state"))
	level_node_ref.connect("boss_fight_starting", Callable(self, "_request_overview_state"))
	SceneLoader.connect("upgrade_ui_displayed", Callable(self, "_request_overview_state"))
	call_deferred("_find_player")

func _find_player():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players")
	if not target_is_overview_mode:
		global_position = player.global_position
		_clamp_camera_position()

func _request_overview_state():
	if target_zoom_scalar != overview_zoom_level or not target_is_overview_mode:
		target_is_overview_mode = true
		target_zoom_scalar = overview_zoom_level
		process_state = InternalCameraProcessState.TRANSITIONING

func _request_gameplay_follow_state():
	if target_zoom_scalar != gameplay_zoom_level or target_is_overview_mode:
		target_is_overview_mode = false
		target_zoom_scalar = gameplay_zoom_level
		process_state = InternalCameraProcessState.TRANSITIONING

func _on_level_countdown_started(_initial_value: int):
	_request_overview_state() 

func _on_level_countdown_go():
	_request_gameplay_follow_state() 

func _process(delta: float):
	if process_state == InternalCameraProcessState.TRANSITIONING:
		var current_zoom_component = self.zoom.x 
		var new_zoom_component = lerpf(current_zoom_component, target_zoom_scalar, delta * zoom_transition_speed)
		self.zoom = Vector2(new_zoom_component, new_zoom_component)
		if abs(new_zoom_component - target_zoom_scalar) < 0.01:
			self.zoom = Vector2(target_zoom_scalar, target_zoom_scalar)
			process_state = InternalCameraProcessState.IDLE
	var desired_position: Vector2
	if target_is_overview_mode: 
		desired_position = game_bounds_rect.get_center()
	elif is_instance_valid(player): 
		desired_position = player.global_position
	else: 
		desired_position = game_bounds_rect.get_center()
	global_position = global_position.lerp(desired_position, delta * follow_smoothing)
	_clamp_camera_position()

func _clamp_camera_position():
	var camera_visible_world_width = viewport_actual_size.x / self.zoom.x
	var camera_visible_world_height = viewport_actual_size.y / self.zoom.y
	var camera_view_half_width = camera_visible_world_width / 2.0
	var camera_view_half_height = camera_visible_world_height / 2.0
	var min_x = game_bounds_rect.position.x + camera_view_half_width
	var max_x = game_bounds_rect.end.x - camera_view_half_width
	var min_y = game_bounds_rect.position.y + camera_view_half_height
	var max_y = game_bounds_rect.end.y - camera_view_half_height
	var new_pos = global_position
	new_pos.x = clamp(new_pos.x, min_x, max_x)
	new_pos.y = clamp(new_pos.y, min_y, max_y)
	global_position = new_pos
