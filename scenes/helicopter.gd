class_name Helicopter extends RigidBody3D


"""
Weird bug, Setting the project's linear dampening to "0.1", thrust THEN add lateral torque("Q", "E"), the helicopter will fly crazy out of control. 

I was testing with linear dampening set to 1.0, but after changing it I noticed that there was some behavior that I was looking for, so I need to tweak the dampening a bit more to find that sweet spot. 

Also I would like to change the apply_main_rotor_thrust2 & handleRoll & handlePitch functions so that we can actually pitch and roll the propellors. (I should at least test it a bit)  


Can probably introduce Curves to engine output eventually
@export var engine_power_curve: Curve 
@export var total_drag_curve: Curve
"""

@onready var tail_rotor: Marker3D = $TailRotor
@onready var main_rotor: Marker3D = $MainRotor
@onready var cursor_pointer: MeshInstance3D = $CursorPointer
@onready var tail_rotor_mesh: Node3D = $TailRotor/TailRotorMesh
@onready var main_rotor_mesh: Node3D = $MainRotor/MainRotorMesh
### --- Exported Variables ---
@export var weight_in_lbs: float = 5000.0
@export var engine_power_curve: Curve 

### --- Constants ---
const LBS_TO_KG: float = 0.454
const TAIL_ROTOR_MAX_FORCE: float = 100000.0
var GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity")

const FORWARD_FORCE: float = 90000.0
const ROLL_FORCE: float = 50000.0

# State Variables
var weight: float
var engine_power: float = 320
var move: Vector3 = Vector3.ZERO
# Throttle and movement parameters
var throttle: float = 0.0
var throttle_acceleration: float = 100.0  # How fast the rotor speeds up
var max_throttle: float = 100.0  # Max throttle value
var min_throttle: float = 0.0  # Min throttle value
# Rotor state
var main_rotor_torque  = 0
var main_rotor_speed: float = 0.0
var max_rotor_speed: float = 400.0

var lift_force: float = 0.0
var air_density: float = 1.225  # kg/m³ (air density at sea level)
var rotor_area: float = 3.0  # Example rotor area in m²
var reference_area: float = 5.0  # m² (frontal area exposed to the air)
var lift_coefficient: float = 2.0  # Example coefficient of lift
var drag_coefficient: float = 0.3
var translational_lift_coefficient:float = 1.0
var main_rotor_radius: float = 5.0  # meters (adjust based on your helicopter model)
var tail_rotor_radius: float = 1.0  # meters (distance from the center of the tail rotor to the blade tip)
var hover_mode: bool = false
var hover_thrust: Vector3 = Vector3.ZERO
var altitude: float = 0.0
# Debug and state flags
var debug: bool = true
var loaded = false



"""
Factors in flight


Rotor Speed provides lift?
Autorotation ? 
"""


# Translational lift and blowback variables
var translational_lift_factor: float = 0.0  # Amount of lift gained from forward movement
#var blowback_angle: float = 0.0  # Angle by which the nose pitches up due to translational lift
var translational_lift_speed_threshold: float = 5.0  # Minimum forward speed where translational lift begins
var max_translational_lift_speed: float = 24.0  # Speed where translational lift reaches its peak


@export var max_tilt_angle: float = 60.0  # Maximum allowed tilt angle before control reduces
@export var max_speed_for_control: float = 30.0  # Maximum speed before control authority is reduced



func _ready():
	linear_damp = .2
	weight = weight_in_lbs * LBS_TO_KG
	self.mass = weight
	cursor_pointer.top_level = true
	loaded = true


func _process(delta):
	UI.send_helicopter_update(self)
	update_rotor_speed(delta)
	spin_rotors(delta)

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _input(_event: InputEvent):
	if !hover_mode:
		move.x = Input.get_action_strength("D") - Input.get_action_strength("A")
		move.y = Input.get_action_strength("W") - Input.get_action_strength("S")
		move.z = Input.get_action_strength("E") - Input.get_action_strength("Q")
	
	if Input.is_action_just_pressed("F"): 
		toggle_hover_mode()

func _physics_process(delta: float) -> void:
	if !loaded:
		return
	
	update_dynamic_coefficients()
	update_altitude()
	#calculate_translational_lift()
	
	if hover_mode:
		update_hover_vector()
		apply_central_force(hover_thrust)
	else: 

		apply_main_rotor_thrust(delta)
		apply_tail_rotor_force(delta)
		handle_pitch(delta)
		handle_roll(delta)

		#apply_parasitic_drag()




func apply_main_rotor_thrust(delta: float):
	# Calculate the total lift force based on rotor speed
	lift_force = 0.5 * air_density * pow(main_rotor_speed, 2) * rotor_area * lift_coefficient * engine_power
	
	# Calculate the tilt angle (pitch) based on the helicopter's orientation
	var up_vector = main_rotor.global_transform.basis.y.normalized()
	var forward_vector = main_rotor.global_transform.basis.z.normalized()
	var world_up = Vector3.UP
	
	# The dot product between the helicopter's up vector and the world up vector gives the cosine of the tilt angle
	var cos_tilt_angle = up_vector.dot(world_up)
	
	# Calculate the tilt angle in radians
	var tilt_angle = acos(cos_tilt_angle)

	# Now calculate how much of the lift should be redirected forward (sin of the tilt angle)
	# Forward thrust increases with tilt (the more you tilt, the more forward movement)
	var forward_thrust_factor = sin(tilt_angle)  # Forward thrust depends on tilt angle
	var upward_thrust_factor = cos(tilt_angle)   # Remaining lift acts upwards

	# Calculate the forward and upward components of the lift
	var forward_lift = forward_thrust_factor * lift_force
	var upward_lift = upward_thrust_factor * lift_force

	# Apply the upward lift (to keep the helicopter airborne)
	var upward_lift_vector = up_vector * upward_lift * delta

	# Apply the forward lift (to move the helicopter forward)
	var forward_lift_vector = forward_vector * forward_lift * delta
	
	# Apply both forces to the helicopter
	apply_central_force(upward_lift_vector + forward_lift_vector)

	# Optionally, apply torque to simulate the rotor's effect
	# TODO: add torque & compensate appropriately based on main rotors rotation 
	main_rotor_torque = global_transform.basis.y * lift_force * main_rotor_radius * delta
	apply_torque(main_rotor_torque)
	
	if debug:
		print("Tilt Angle (radians): ", tilt_angle)
		print("Forward Lift: ", forward_lift)
		print("Upward Lift: ", upward_lift)





"""
https://www.copters.com/aero/torque.html
Compensation for torque in the single main rotor helicopter is accomplished by 
means of a variable pitch antitorque rotor (tail rotor) located on the end of 
a tail boom extension at the rear of the fuselage. Driven by the main rotor at 
a constant ratio, the tail rotor produces thrust in a horizontal plane opposite 
to torque reaction developed by the main rotor. Since torque effect varies during 
flight when power changes are made, it is necessary to vary the thrust of the 
tail rotor. Antitorque pedals enable the pilot to compensate for torque variance. 
A significant part of the engine power is required to drive the tail rotor, especially 
during operations when maximum power is used. From 5 to 30 percent of the available 
engine power may be needed to drive the tail rotor depending on helicopter size and design. 
Normally, larger helicopters use a higher percent of engine power to counteract 
torque than do smaller aircraft. A helicopter with 9,500 horsepower might require 
1,200 horsepower to drive the tail rotor, while a 200 horsepower aircraft might 
require only 10 horsepower for torque correction. 
"""
func apply_tail_rotor_force(delta: float):
	# Calculate the torque produced by the main rotor
	var main_rotor_torque_non_shadow = lift_force * main_rotor_radius

	# Calculate the tail rotor force required to counteract the main rotor's torque
	var tail_rotor_force = main_rotor_torque_non_shadow / tail_rotor_radius

	# Apply player input for yaw (left/right rotation)
	if move.z != 0:
		var player_input_force = move.z * TAIL_ROTOR_MAX_FORCE
		tail_rotor_force += player_input_force  # Add player input force to the tail rotor force

	# Convert the tail rotor force into torque (to counteract the main rotor torque)
	var tail_rotor_torque_vector = tail_rotor.global_transform.basis.y * tail_rotor_force * delta

	# Apply the counter torque to stabilize the helicopter
	apply_torque(-tail_rotor_torque_vector)

	if debug:
		print("Main Rotor Torque: ", main_rotor_torque)
		print("Tail Rotor Force: ", tail_rotor_force)
		print("Tail Rotor Torque Vector: ", tail_rotor_torque_vector)
		





"""
https://www.copters.com/aero/translational.html
"""
func calculate_translational_lift():
	var forward_speed = calculate_forward_speed()
	
	# If forward speed is greater than the translational lift speed threshold, apply translational lift
	if forward_speed > translational_lift_speed_threshold:
		# Translational lift factor increases with forward speed, clamped by the max translational lift speed
		var normalized_speed = clamp((forward_speed - translational_lift_speed_threshold) / (max_translational_lift_speed - translational_lift_speed_threshold), 0.0, 1.0)
		translational_lift_factor = normalized_speed  # Factor representing how much extra lift we gain
		
		# Add extra lift based on translational lift factor
		var additional_lift = translational_lift_factor * lift_force
		apply_central_force(Vector3.UP * additional_lift)
		
		if debug:
			print("Translational Lift Factor: ", translational_lift_factor, " Additional Lift: ", additional_lift)
	else:
		translational_lift_factor = 0.0  # No translational lift if speed is below the threshold


func apply_parasitic_drag() -> void:
	var velocity = linear_velocity
	var speed = velocity.length()
	var drag_force_magnitude = 0.5 * air_density * pow(speed, 2) * drag_coefficient * reference_area
	var drag_force = -velocity.normalized() * drag_force_magnitude
	apply_central_force(drag_force)


# TODO: Maybe lets not have these apply torques?, these should simply tilt the main rotor into different angles?
# Perhaps these need to take into account the current velocity vector? 
func handle_pitch(delta: float) -> void:
	var main_rotor_force_vector = main_rotor.global_transform.basis.x * move.y * FORWARD_FORCE * delta
	apply_torque(main_rotor_force_vector)

func handle_roll(delta: float):
	var main_rotor_force_vector = main_rotor.global_transform.basis.z * move.x * ROLL_FORCE * delta
	apply_torque(main_rotor_force_vector)

func handle_pitch_with_factor(delta: float) -> void:
	var pitch_angle = calculate_pitch_angle()
	var forward_speed = calculate_forward_speed()
	
	# Calculate the control factor based on speed and tilt angle
	var control_factor = calculate_control_factor(pitch_angle, forward_speed)
	
	# Apply pitch based on control factor
	var main_rotor_force_vector = main_rotor.global_transform.basis.x * move.y * FORWARD_FORCE * delta * control_factor
	apply_torque(main_rotor_force_vector)

func handle_roll_with_factor(delta: float):
	var roll_angle = calculate_roll_angle()
	var forward_speed = calculate_forward_speed()
	
	# Calculate the control factor based on speed and tilt angle
	var control_factor = calculate_control_factor(roll_angle, forward_speed)
	
	# Apply roll based on control factor
	var main_rotor_force_vector = main_rotor.global_transform.basis.z * move.x * ROLL_FORCE * delta * control_factor
	apply_torque(main_rotor_force_vector)



func update_dynamic_coefficients() -> void:
	# Calculate the helicopter's tilt angle (relative to the world up vector)
	var up_vector = main_rotor.global_transform.basis.y.normalized()
	var world_up = Vector3.UP  # This is the global up direction (0, 1, 0)

	# Dot product between the helicopter's up vector and the world's up vector gives the cosine of the tilt angle
	var cos_tilt_angle = up_vector.dot(world_up)

	# Calculate the angle of attack (in radians)
	var angle_of_attack = acos(cos_tilt_angle)

	# Dynamically adjust the lift coefficient based on the tilt angle
	lift_coefficient = max(0.0, 2.0 * cos_tilt_angle)  # Example: Lift decreases with tilt
	drag_coefficient = 0.3 + (1.0 - cos_tilt_angle)  # Example: Drag increases with tilt
	# Adjust the translational lift coefficient based on tilt angle and other conditions
	translational_lift_coefficient = max(0.0, 0.1 * cos_tilt_angle)


	if debug:
		print("Angle of Attack (radians): ", angle_of_attack)
		print("Dynamic Lift Coefficient: ", lift_coefficient)
		print("Dynamic Drag Coefficient: ", drag_coefficient)


func update_rotor_speed(delta: float):
	if Input.is_action_pressed("Shift"):
		throttle += throttle_acceleration * delta 
	if Input.is_action_pressed("Ctrl"):
		throttle -= throttle_acceleration * delta

	throttle = clamp(throttle, min_throttle, max_throttle)
	# Smoothly adjust rotor speed based on throttle
	main_rotor_speed = throttle / 2
	
	# TODO add negative rotor speed for auto rotation??
	# Could make landing an injured helo interesting
	main_rotor_speed = clamp(main_rotor_speed, 0, max_rotor_speed)

	"""
		we should lerp in due time... but not yet... 
		need to make throttle and engine output a proportion
		rotor_speed = lerp(rotor_speed, max_rotor_speed, delta)
	"""
	
	if debug:
		print("Rotor Speed: ", main_rotor_speed, " Throttle: ", throttle)



func toggle_hover_mode():
	hover_mode = !hover_mode
	if hover_mode:
		print("Hover mode enabled")
	else:
		print("Hover mode disabled")


# TODO: This is hardcoding values, instead we should calculate 
# the values and set the thrust to whatever the hover force is
func update_hover_vector() -> void:
	var gravity_force = weight * GRAVITY
	# The hover thrust should be equal to the gravity force but applied in the opposite direction
	hover_thrust = global_transform.basis.y * gravity_force 


func spin_rotors(delta: float):
	main_rotor_mesh.rotation_degrees.y += main_rotor_speed / 10 * delta * 360.0  # 360 degrees per second at full speed
	tail_rotor_mesh.rotation_degrees.x += main_rotor_speed / 10 * delta * 360.0  # 360 degrees per second at full speed


func update_altitude() -> void:
	var max_altitude = 1000.0
	var space_state = get_world_3d().direct_space_state
	# Define the raycast parameters
	var query = PhysicsRayQueryParameters3D.create(global_transform.origin, global_transform.origin + Vector3(0, -max_altitude, 0))
	query.exclude = [self]
	query.collision_mask = 1
	#query.from = global_transform.origin  # Ray starts from the helicopter's current position
	#query.to = global_transform.origin + Vector3(0, -max_altitude, 0)  # Raycast downwards
	#query.collision_mask = 1  # Define a collision mask if needed (e.g., 1 for default collision layers)
	
	# Perform the raycast query
	var result = space_state.intersect_ray(query)
	
	# If we hit something, calculate the altitude
	if result.size() > 0:
		var hit_position: Vector3 = result["position"]
		altitude = global_transform.origin.distance_to(hit_position)
	else:
		# If no collision, assume helicopter is above the maximum altitude check distance
		altitude = max_altitude



# TODO: move these to global variables
# Calculate the pitch angle of the helicopter relative to the world
# Gradually reduce control authority based on angle and speed
func calculate_control_factor(angle: float, speed: float) -> float:
	# Calculate the factor by which control is reduced
	var angle_factor = 1.0 - clamp(angle / deg_to_rad(max_tilt_angle), 0.0, 1.0)
	var speed_factor = 1.0 - clamp(speed / max_speed_for_control, 0.0, 1.0)
	
	# Return the lesser of the two factors
	return angle_factor * speed_factor
# Calculate the pitch angle of the helicopter relative to the world
func calculate_pitch_angle() -> float:
	var forward_vector = global_transform.basis.z
	var world_up = Vector3.UP
	var cos_pitch = forward_vector.dot(world_up)
	var pitch_angle = acos(cos_pitch)
	return pitch_angle

# Calculate the roll angle of the helicopter relative to the world
func calculate_roll_angle() -> float:
	var right_vector = global_transform.basis.x
	var world_up = Vector3.UP
	var cos_roll = right_vector.dot(world_up)
	var roll_angle = acos(cos_roll)
	return roll_angle

# Calculate the current forward speed
func calculate_forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)
