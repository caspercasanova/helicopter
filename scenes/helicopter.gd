class_name Helicopter extends RigidBody3D

@onready var tail_rotor: Marker3D = $TailRotor
@onready var main_rotor: Marker3D = $MainRotor
@onready var cursor_pointer: MeshInstance3D = $CursorPointer

### --- Exported Variables ---
@export var weight_in_lbs: float = 10.0

### --- Constants ---
const LBS_TO_KG: float = 0.454
const TAIL_ROTOR_IDLE_FORCE: float = 660.0
const TAIL_ROTOR_MAX_FORCE: float = 10.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")





# State Variables
var weight: float
var move: Vector3 = Vector3.ZERO
# Throttle and movement parameters
var throttle: float = 0.0
var throttle_acceleration: float = 100.0  # How fast the rotor speeds up
var max_throttle: float = 100.0  # Max throttle value
var min_throttle: float = 0.0  # Min throttle value
# Rotor state
var rotor_speed: float = 0.0
var max_rotor_speed: float = 30.0
var lift_force: float = 0.0
var air_density: float = 1.225  # kg/m³ (air density at sea level)
var rotor_area: float = 3.0  # Example rotor area in m²
var reference_area: float = 5.0  # m² (frontal area exposed to the air)
var lift_coefficient: float = 2.0  # Example coefficient of lift
var drag_coefficient: float = 0.3
var tail_rotor_coefficient: float = 0.5
var main_rotor_radius: float = 5.0  # meters (adjust based on your helicopter model)
var tail_rotor_radius: float = 1.0  # meters (distance from the center of the tail rotor to the blade tip)
var main_rotor_torque  = 0
var forward_force: float = 200.0
var roll_force: float = 200.0
var hover_mode: bool = false
var hover_thrust: Vector3 = Vector3.ZERO
# Debug and state flags
var debug: bool = true
var loaded = false


func _ready():
	weight = weight_in_lbs * LBS_TO_KG
	self.mass = weight
	cursor_pointer.top_level = true
	loaded = true


func _process(delta):
	UI.send_helicopter_update(self)
	update_rotor_speed(delta)

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _input(event: InputEvent):
	if !hover_mode:
		move.x = Input.get_action_strength("D") - Input.get_action_strength("A")
		move.y = Input.get_action_strength("W") - Input.get_action_strength("S")
		move.z = Input.get_action_strength("E") - Input.get_action_strength("Q")
	
	if Input.is_action_just_pressed("F"):  # Bind this action in the input map (e.g., "ui_hover_toggle" = "H" key)
		toggle_hover_mode()

func _physics_process(delta: float) -> void:
	if !loaded:
		return
	if hover_mode:
		var hover_vector = calculate_hover_vector()
		apply_central_force(hover_vector)
	else: 
		apply_main_rotor_thrust(delta)
		apply_tail_rotor_force(delta)
		handle_pitch(delta)
		handle_roll(delta)
		#handle_pitch2(delta)
		#handle_roll2(delta)
		apply_parasitic_drag()


func apply_main_rotor_thrust(delta: float):
	lift_force = 0.5 * air_density * pow(rotor_speed, 2) * rotor_area * lift_coefficient
	
	var lift_vector = main_rotor.global_transform.basis.y * lift_force * delta
	apply_central_force(lift_vector)
	
	#apply_force()
	#apply_force(lift_vector)

	#main_rotor_torque = main_rotor.global_transform.basis.y * lift_force * main_rotor_radius / 60
	main_rotor_torque = Vector3(0,0,0) * lift_force * main_rotor_radius / 60
	apply_torque(main_rotor_torque)
	
	if debug:
		print("Lift Force: ", lift_force)

func apply_tail_rotor_force(delta: float):
   # Calculate the stabilizing force needed from the tail rotor to counteract main rotor torque
	var equalizing_tail_rotor_force = main_rotor_torque / tail_rotor_radius * tail_rotor_coefficient * 2

	var tail_rotor_force_vector = tail_rotor.global_transform.basis.y * equalizing_tail_rotor_force * delta
	
	if move.z == 0:
		# stabilize by apply damping to reduce rotational speed over time 
		apply_yaw_damping()
	else: 
		# Calculate the player's control input for yaw (left/right rotation)
		var player_input_force = move.z * TAIL_ROTOR_MAX_FORCE

		# Add player input force to the tail rotor force vector
		tail_rotor_force_vector += tail_rotor.global_transform.basis.y * player_input_force
		print("Tail Rotor Force with Player Input: ", tail_rotor_force_vector)
	
	# Debugging information
	print("Main Rotor Torque: ", main_rotor_torque)
	print("Equalizing Tail Rotor Force: ", equalizing_tail_rotor_force)

	# Apply the tail rotor force as torque to counter the main rotor's torque and allow yaw control
	apply_torque(-tail_rotor_force_vector)

# Calculate and apply parasitic drag to the helicopter
func apply_parasitic_drag() -> void:
	var velocity = linear_velocity
	var speed = velocity.length()

	var drag_force_magnitude = 0.5 * air_density * pow(speed, 2) * drag_coefficient * reference_area
	var drag_force = -velocity.normalized() * drag_force_magnitude
	
	apply_central_force(drag_force)



# Dampen to reduce helicopter's yaw speed over time
func apply_yaw_damping():
	var yaw_damping_factor = 0.95  # smaller equals greater dampen
	angular_velocity.y *= yaw_damping_factor
	set_angular_velocity(angular_velocity)




# TODO: Lets not have these apply torque, these should simply tilt the main rotor into different angles 
func handle_pitch(delta: float) -> void:
	var main_rotor_force_vector = main_rotor.global_transform.basis.x * move.y * forward_force * delta
	apply_torque(main_rotor_force_vector)

func handle_roll(delta: float):
	var main_rotor_force_vector = main_rotor.global_transform.basis.z * move.x * roll_force * delta
	apply_torque(main_rotor_force_vector)


func handle_pitch2(delta: float) -> void:
	var pitch_angle_change = move.y * forward_force * delta
	var new_rotation_x = main_rotor.rotation.x + deg_to_rad(pitch_angle_change)
	main_rotor.rotation.x = clamp(new_rotation_x, deg_to_rad(-15.0), deg_to_rad(15.0))  # Clamp in radians

func handle_roll2(delta: float):
	var roll_angle_change = move.x * roll_force * delta
	var new_rotation_z = main_rotor.rotation.z + deg_to_rad(roll_angle_change)
	main_rotor.rotation.z = clamp(new_rotation_z, deg_to_rad(-15.0), deg_to_rad(15.0))


func update_rotor_speed(delta: float):
	if Input.is_action_pressed("Shift"):
		throttle += throttle_acceleration * delta 
	if Input.is_action_pressed("Ctrl"):
		throttle -= throttle_acceleration * delta

	throttle = clamp(throttle, min_throttle, max_throttle)
	# Smoothly adjust rotor speed based on throttle
	rotor_speed = throttle / 2
	rotor_speed = clamp(rotor_speed, 0, max_rotor_speed)

	"""
		we should lerp in due time... but not yet... 
		need to make throttle and engine output a proportion
		rotor_speed = lerp(rotor_speed, max_rotor_speed, delta)
	"""
	
	if debug:
		print("Rotor Speed: ", rotor_speed, " Throttle: ", throttle)



func toggle_hover_mode():
	hover_mode = !hover_mode
	if hover_mode:
		print("Hover mode enabled")
	else:
		print("Hover mode disabled")


# TODO: This is hardcoding values, instead we should calculate 
# the values and set the thrust to whatever the hover force is
func calculate_hover_vector() -> Vector3:
	var gravity_force = weight * gravity
	# The hover thrust should be equal to the gravity force but applied in the opposite direction
	hover_thrust = global_transform.basis.y * gravity_force 
	return hover_thrust
