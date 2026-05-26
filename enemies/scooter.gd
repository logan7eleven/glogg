extends EnemyBase

# --- Movement Variables ---
enum State { RESTING, DASHING }
var current_state: State = State.RESTING

var rest_timer: float = 0.0
const REST_TIME: float = 2.0

var target_position: Vector2 = Vector2.ZERO
var dash_speed: float = 0.0

# --- Shield Variable ---
var has_shield: bool = false

func _ready():
	# 1. ALWAYS call super._ready() so EnemyBase can set up hitboxes and visual managers!
	super._ready() 
	
	# 2. Set the base variables inherited from EnemyBase
	health = 5.0 
	
	_enter_rest_state()

# We override the built-in EnemyBase movement hook. 
# This means the scooter will automatically freeze during 'hitstop' or stuns!
func _perform_movement(delta: float, speed_multiplier: float):
	match current_state:
		State.RESTING:
			rest_timer -= delta
			if rest_timer <= 0.0:
				_start_dash()
				
		State.DASHING:
			_process_dash(delta, speed_multiplier)

# ==========================================
# STATE LOGIC
# ==========================================

func _enter_rest_state():
	current_state = State.RESTING
	rest_timer = REST_TIME
	velocity = Vector2.ZERO
	
	# Activate Shield
	has_shield = true
	modulate = Color.GOLD 

func _start_dash():
	current_state = State.DASHING
	
	# Drop Shield
	has_shield = false
	modulate = Color.WHITE 
	
	# Lock onto the player's current position (player is already tracked by EnemyBase!)
	if is_instance_valid(player):
		target_position = player.global_position
		
		var base_player_speed = player.get("speed") if "speed" in player else 300.0 
		dash_speed = base_player_speed * 2.0
		
		var direction = global_position.direction_to(target_position)
		velocity = direction * dash_speed
	else:
		_enter_rest_state() # Failsafe if the player is dead/missing

func _process_dash(delta: float, speed_multiplier: float):
	var current_speed = dash_speed * speed_multiplier
	
	# 1. Constantly aim at the target so we slide AROUND walls to reach it
	velocity = global_position.direction_to(target_position) * current_speed
	
	# 2. Check if we arrived
	if global_position.distance_to(target_position) <= (current_speed * delta):
		global_position = target_position
		_enter_rest_state()
		return
		
	# 3. Use Godot's native physics sliding
	move_and_slide()
	
	# 4. Check what we bumped into
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If it's an enemy, resolve the bump and stop
		if collider and collider.is_in_group("enemies"):
			handle_physics_collision(collision)
			_enter_rest_state()
			return
			
	# 5. THE STUCK CHECK: If a wall completely stops us from moving, reset!
	if get_real_velocity().length() < 10.0:
		_enter_rest_state()
