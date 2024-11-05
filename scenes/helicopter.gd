class_name Helicopter extends RigidBody3D
## An attempt at making a fun physics based helicopter 
## 
## Still plenty to do, Note that flight is currently super unstable 
## and speeds/drag are not implemented properly if at all. 
## 
## @tutorial(Reading Resource 1	): https://www.copters.com/aero/torque.html
## @experimental

"""
Num of TODO's as of 11/5/2024: 25-35-ish


Add some kind of vortex condition where if the current velocity is opposite of he updaward velocity, then reduce upward coefficient 

TODO: Proper Conditions where rotor speed falls and increases (currently we hardcode based on whether we increase collective to above 80%)
TODO: [x] Engine Spool Down / Turn Off 
	- Double check math
	- Can probably reduce the number of variables there are too many currently

TODO: Translational Lift / Movement
TODO: Understand and implement Drag? 
TODO: Refactor to an engine Engine Curve?
TODO: Ground Effect?
TODO: Autorotation?
TODO: Cleaner version of prop damage -> Component Damage "System"
TODO: Maybe split the lift vector by the prop count and apply every revolution? (maybe not idk) "Force-Per-Prop" Lite™ Implementation
TODO: Aerodynamics
	- Roll  / Pitch control factors?
TODO: Hover mode for picking things up

TODO: Overall flight feels lame still and hard

TODO: Solve Joint Bouncyness


TODO: Cohesive Helicopter Module / Health System 

TODO: Variables Needed. 
	- AoA 
	- Sea Level Altitude

TODO: Clean the rest of these variables, refactor and reorganize 

---
Dream TODOs:
TODO: Rigid body AI Implementation?
	- We could maybe limit the AI to hard set amount of degrees of rotational freedom to keep flight super stable. Maybe IDK. 

TODO: Clean + Polished UI
TODO: Make shareable DEMO

"""
# TODO: Change this to a helicopter state variable
# Loading, Landing, Repairing, Injured, Green Light
enum HELICOPTER_STATE {
	LANDED,
	REPAIRING,
	CARRYING_OBJECT,
	GREEN_LIGHT,
	CRITICAL,
}

@onready var tail_rotor: Marker3D = $Tail_Boom/TailRotor
@onready var main_rotor_shaft: Marker3D = $MainRotorShaft
@onready var main_rotor_shaft_mesh: MeshInstance3D = $MainRotorShaft/MainRotorShaftMesh
@onready var cursor_pointer: MeshInstance3D = $CursorPointer
@onready var tail_rotor_mesh: Node3D = $Tail_Boom/TailRotor/TailRotorMesh
@onready var engine_light: MeshInstance3D = $EngineLight
@onready var sky_hook_attachment: MeshInstance3D = $Sky_Hook_Attachment


const ROPE = preload("res://scenes/Rope.tscn")
var rope_instance: JoltPinJoint3D

### --- Exported Variables ---
@export var weight_in_lbs: float = 10000.0


### Debug and state flags
var debug: bool = false
var loaded = false


### --- Constants ---
const LBS_TO_KG: float = 0.454
const TAIL_ROTOR_MAX_FORCE: float = 100000.0
var GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity")

const PITCH_FORCE_COEFFICIENT: float = 100000.0
const ROLL_FORCE_COEFFICIENT: float = 30000.0



### State Variables
var weight: float
var move: Vector3 = Vector3.ZERO
var sky_hook_deployed: bool = false
var relative_altitude: float = 0.0
var is_on_ground: bool = false:
	get():
		# might need to do something smarter here
		return relative_altitude <= 1
var speed_km: float = 0:
	get():
		return linear_velocity.length() * 3.6
var g_force: float = 0.0
var previous_velocity: Vector3 = Vector3.ZERO

# Calculate the pitch angle of the helicopter relative to the world
var pitch_angle: float:
	get():
		var forward_vector = global_transform.basis.z  
		var world_up = Vector3.UP                      
		
		# Project the forward vector onto the horizontal plane (XZ plane)
		var forward_projected = forward_vector - forward_vector.dot(world_up) * world_up
		forward_projected = forward_projected.normalized()

		# Dot product to calculate the cosine of the pitch angle
		var cos_pitch = forward_vector.dot(forward_projected)
		cos_pitch = clamp(cos_pitch, -1.0, 1.0)  # Ensure valid range for acos
		# Calculate the pitch angle (in radians)
		var _angle = acos(cos_pitch)

		# Use cross product to determine the sign of the pitch angle
		var right_vector = global_transform.basis.x  # Helicopter's right vector
		if right_vector.dot(world_up.cross(forward_vector)) < 0:
			_angle = -_angle

		return _angle

# Calculate the roll angle of the helicopter relative to the world, accounting for upside-down state
var roll_angle: float:
	get():
		var up_vector = global_transform.basis.y  
		var forward_vector = global_transform.basis.z 
		var world_up = Vector3.UP
		
		# Project the up vector onto the horizontal plane defined by the world up vector
		var up_projected = (up_vector - up_vector.dot(world_up) * world_up).normalized()
		
		# Calculate the roll angle as the angle between the up vector and its projection
		var cos_roll = up_vector.dot(world_up)
		cos_roll = clamp(cos_roll, -1.0, 1.0)  # Ensure acos is within valid range
		var angle = acos(cos_roll)

		# Determine the sign of the roll using the forward vector
		if forward_vector.dot(world_up.cross(up_vector)) < 0:
			angle = -angle

		# Adjust for upside-down state if the helicopter is inverted
		if up_vector.dot(world_up) < 0:
			angle = PI - angle if angle > 0 else -PI - angle

		return angle





### Engine
@export var engine_power_curve: Curve
var current_engine_power: float = 0.0
var max_engine_power: float = 1000.0  
 

var engine_on: bool = false
var engine_spool_up_complete:bool = false
var engine_spool_down_complete: bool = false
var engine_startup_time: float = 5.0
var engine_shut_off_timer: float = 0

var engine_spool_up_timer: float = 0.0 
var engine_spool_down_timer: float = 0.0

var is_engine_spooling_up: bool = false  
var engine_startup_progress: float = 0.0  # Progress through the startup sequence (0.0 to 1.0)

var engine_spool_down_time: float = 0.0 
var is_engine_spooling_down: bool = false
var engine_spool_down_progress: float = 0.0

var engine_health: float = 100.0  # Starts at 100, degrades over events
var engine_health_threshold: float = 25.0  # Threshold below which health is critical




### Rotor state
var collective_pitch_response: float = .01  # Speed of pitch adjustment
var collective_pitch: float = 0.0  # Range from 0.0 to 1.0, where 1.0 is max pitch
var collective_acceleration: float = 1.0  # How fast the rotor speeds up

var main_rotor_torque  = 0
var main_rotor_speed: float = 0.0  # Angular velocity in radians per second
var main_rotor_radius: float = 7.0  # meters (adjust based on your helicopter model)
var tail_rotor_radius: float = 1.0  # meters (distance from the center of the tail rotor to the blade tip)
var main_rotor_area: float = 168.0  # Example rotor area in m²
var main_rotor_rpm: float:
	get():
		return (main_rotor_speed / TAU) * 60.0

var max_rotor_angular_velocity: float = 5.4 * TAU  # Max angular velocity in radians per second (40 revolutions per second)
var tip_velocity: float:
	get():
		return main_rotor_speed * main_rotor_radius







### Lift Forces
@export var total_drag_curve: Curve

@export var max_lift_coefficient: float = 1.5  # Maximum lift at full collective pitch

var main_rotor_lift_force: float = 0.0
var air_density: float = 1.225  # kg/m³ (air density at sea level)
var reference_area: float = 5.0  # m² (frontal area exposed to the air)
var lift_coefficient: float = 1.5  # Example coefficient of lift
var drag_coefficient: float = 0.3

var ground_effect_multiplier: float:
	get():
		var altitude_ratio = relative_altitude / main_rotor_radius
		var multiplier = 1.0
		
		if altitude_ratio < 1.0:  # Ground effect is strongest within one rotor radius from the ground
			multiplier = 1.0 + (1.0 - altitude_ratio) * 0.5  # Amplifies the lift by up to 50%
		return multiplier



### Aerodynamics / Control Factor
### Control factor can essentially be "Aero dynamics"
@export var max_tilt_angle: float = 60.0  # Maximum allowed tilt angle before control reduces
@export var max_speed_for_control: float = 30.0  # Maximum speed before control authority is reduced










func _ready():
	weight = weight_in_lbs * LBS_TO_KG
	self.mass = weight
	cursor_pointer.top_level = true
	loaded = true



func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _input(_event: InputEvent):
	if Input.is_action_pressed("F"):
		toggle_sky_hook()




func _process(delta):
	UI.send_helicopter_update(self)
	update_rotor_speed(delta)
	spin_rotors(delta)

	update_engine_light(delta)
	
	if Input.is_action_pressed("Shift"):
		if(!engine_on):
			start_engine()
		collective_pitch += collective_pitch_response
	elif Input.is_action_pressed("Ctrl"):
		collective_pitch -= collective_pitch_response
		if (engine_on and is_on_ground and collective_pitch <= 0):
			engine_shut_off_timer += delta
			print("Spooling down progres", engine_shut_off_timer)
			if engine_shut_off_timer >= 5:
				engine_shutoff()
		else: 
			engine_shut_off_timer = 0

		
	collective_pitch = clamp(collective_pitch, 0.0, 1.0)
	


	move.x = Input.get_action_strength("D") - Input.get_action_strength("A")
	move.y = Input.get_action_strength("W") - Input.get_action_strength("S")
	move.z = Input.get_action_strength("E") - Input.get_action_strength("Q")


func _physics_process(delta: float) -> void:
	if !loaded:
		return
	
	if is_engine_spooling_up: 
		engine_spool_up(delta)
	elif is_engine_spooling_down:
		engine_spool_down(delta)
	

	calculate_relative_altitude()
	calculate_g_force(delta)
	

	
	apply_main_rotor_thrust(delta)
	apply_tail_rotor_force(delta)
	
	handle_pitch(delta)
	handle_roll(delta)
	
	#apply_tilt_based_force(delta)

	#calculate_translational_lift()
	#apply_parasitic_drag()
	#apply_drag_force(delta)
 

# Perhaps these need to take into account the current velocity vector? 
func handle_pitch(delta: float) -> void:
	var main_rotor_force_vector = main_rotor_shaft.global_transform.basis.x * move.y * PITCH_FORCE_COEFFICIENT * delta
	apply_torque(main_rotor_force_vector)


func handle_roll(delta: float):
	# Adjust the roll moment based on the helicopter's roll angle (reduced control authority at extreme roll angles)
	var control_factor = cos(roll_angle)  # Reduces authority as roll_angle approaches ±90 degrees

	var roll_moment = move.x * ROLL_FORCE_COEFFICIENT * control_factor
	var main_rotor_force_vector = main_rotor_shaft.global_transform.basis.z * roll_moment * delta
	
	apply_torque(main_rotor_force_vector)
	
	





func start_engine():
	engine_spool_up_timer = 0.0
	engine_on = true
	is_engine_spooling_up = true
	current_engine_power = 0.0


func engine_shutoff(): 
	engine_on = false
	is_engine_spooling_down = true
	return

func engine_spool_up(delta: float) -> void:
	engine_spool_up_timer += delta
	
	# Calculate progress as a percentage of startup time, clamped between 0.0 and 1.0
	engine_startup_progress = clamp(engine_spool_up_timer / engine_startup_time, 0.0, 1.0)
	
	# Lerp current engine power towards max engine power based on startup progress
	current_engine_power = lerp(0.0, max_engine_power, engine_startup_progress)

	print("Spooling Up: ", round(engine_startup_progress * 100), "%")

	# Check if the startup process is complete
	if engine_startup_progress >= 1:
		is_engine_spooling_up = false
		engine_spool_up_complete = true
		current_engine_power = max_engine_power
		print("Engine startup complete. Reached full power.")


func engine_spool_down(delta: float) -> void:
	# TODO: There are division by zero bugs in here sometimes
	print('engine spool down process')
	engine_spool_down_timer += delta

	engine_spool_down_progress = clamp(engine_spool_down_timer / engine_spool_down_time, 0.0, 1.0)
	# Lerp current engine power towards 0 based on time
	current_engine_power = lerp(current_engine_power, 0.0, engine_spool_down_progress)
	# Check if the startup process is complete
	
	print("Spooling Down: ", round(engine_spool_down_progress * 100), "%")
	
	if engine_spool_down_progress >= 1:
		is_engine_spooling_down = false
		engine_spool_down_complete = true
		current_engine_power = 0.0
		print("Engine shutoff complete. Reached zero power.")
	
pass



func update_rotor_speed(delta: float):
	# Target rotor speed is proportional to engine power
	var target_rotor_speed = (current_engine_power / max_engine_power) * max_rotor_angular_velocity
	
		# Apply a reduction to rotor speed if collective pitch exceeds 80%
	if collective_pitch > 0.8:
		var load_factor = 1.0 - ((collective_pitch - 0.8) * 0.2)  # Reduce rotor speed slightly based on excess pitch
		target_rotor_speed *= load_factor
	
	# Smoothly interpolate rotor speed towards the target rotor speed
	var interpolation_speed = 3.0  
	main_rotor_speed = lerp(main_rotor_speed, target_rotor_speed, interpolation_speed * delta)
	# Clamp the rotor speed to ensure it doesn't exceed the max allowed speed
	main_rotor_speed = clamp(main_rotor_speed, 0.0, max_rotor_angular_velocity)

   # Calculate RPM for debug purposes
	if debug:
		print("Main Rotor Speed (rad/s): ", main_rotor_speed)
		print("Main Rotor RPM: ", main_rotor_rpm)




func apply_main_rotor_thrust(delta: float):
	var effective_lift_coefficient = max_lift_coefficient * collective_pitch
	
	# Calculate the total lift force based on rotor speed
	var lift_force = 0.5 * air_density * pow(tip_velocity, 2) * main_rotor_area * effective_lift_coefficient
	

	# Adjust the lift force based on the helicopter's tilt angle (use pitch and roll combined if applicable)
	# Not sure this is appropriate
	var tilt_adjustment = cos(pitch_angle) * cos(roll_angle)
	var adjusted_lift_force = lift_force * tilt_adjustment

	# Apply ground effect to the adjusted lift force
	adjusted_lift_force *= ground_effect_multiplier
	
	var main_rotor_vector = main_rotor_shaft.global_transform.basis.y.normalized()
	var upward_lift_vector = main_rotor_vector * adjusted_lift_force * delta
	apply_central_force(upward_lift_vector)


	# Calculate the torque generated by the main rotor
	main_rotor_torque = global_transform.basis.y  * main_rotor_radius * delta
	apply_torque(main_rotor_torque)



#region Currrent Code Experimentation

@export var tilt_dead_zone: float = 0.05  # Dead zone for pitch and roll angles to prevent drift
@export var translational_lift_coefficient: float = 100.0  # General translational force coefficient
@export var translational_force_multiplier: float = 2.0  # Additional multiplier for more responsive control


# Adding a dead zone is probably the right move
# Must account for front and back left and right
func apply_tilt_based_force(delta: float) -> void:
	# Get the main rotor's up vector to determine the rotor tilt
	var rotor_up_vector = main_rotor_shaft.global_transform.basis.y.normalized()

	# Determine if the helicopter is upside down by checking the dot product with the world up vector
	var is_upside_down = rotor_up_vector.dot(Vector3.UP) < 0

	# Project the rotor up vector onto the XZ plane to get the horizontal component of tilt
	var horizontal_tilt_vector = rotor_up_vector - rotor_up_vector.dot(Vector3.UP) * Vector3.UP

	# Check if horizontal_tilt_vector is effectively zero to prevent unintended force
	if horizontal_tilt_vector.length() < tilt_dead_zone:
		print("In dead zone")
		horizontal_tilt_vector = Vector3.ZERO  # Set to zero if within dead zone

	# Normalize the horizontal tilt vector if it's not zero
	horizontal_tilt_vector = horizontal_tilt_vector.normalized() if horizontal_tilt_vector.length() > 0 else Vector3.ZERO

	# Invert the horizontal tilt vector if the helicopter is upside down
	if is_upside_down:
		horizontal_tilt_vector = -horizontal_tilt_vector

	# Calculate the translational force based on the tilt vector
	var translational_force = horizontal_tilt_vector * translational_lift_coefficient * current_engine_power * translational_force_multiplier

	# Zero out any unintended vertical component
	translational_force.y = 0

	# Apply ground effect multiplier when close to the ground
	translational_force *= ground_effect_multiplier

	# Debug output to confirm the calculated forces
	print("Horizontal tilt vector:", horizontal_tilt_vector)
	print("Translational force applied:", translational_force)

	# Apply the translational force at the center of mass to move the helicopter
	apply_central_force(translational_force * delta)

#endregion




func apply_tail_rotor_force(delta: float):
	# Calculate the main rotor torque
	var tail_rotor_force = (main_rotor_torque / tail_rotor_radius)

	var tail_rotor_torque_vector = tail_rotor.global_transform.basis.y * tail_rotor_force * delta

	if move.z != 0:
		# Convert player input into a vector to modify the tail rotor force
		var player_input_force = tail_rotor.global_transform.basis.y * (move.z * TAIL_ROTOR_MAX_FORCE * delta)
		# Adjust tail rotor force with player input for yaw control
		tail_rotor_torque_vector += player_input_force

	apply_torque(-tail_rotor_torque_vector)




func apply_drag_force(delta: float) -> void:
	# Calculate the helicopter's forward velocity component
	var forward_velocity = linear_velocity.dot(global_transform.basis.z)
	
	# Sample the drag value from the total drag curve based on normalized forward speed
	var drag_value = total_drag_curve.sample(forward_velocity / max_speed_for_control)
	
	# Calculate the drag force magnitude directly
	var drag_force_magnitude = 0.5 * air_density * pow(forward_velocity, 2) * drag_coefficient * reference_area * drag_value
	
	# Apply the drag force in the opposite direction of movement
	apply_central_force(-linear_velocity.normalized() * drag_force_magnitude * delta)



# Might need something like this in the future
func update_dynamic_coefficients() -> void:
	# Calculate the helicopter's tilt angle (relative to the world up vector)
	var up_vector = main_rotor_shaft.global_transform.basis.y.normalized()
	var world_up = Vector3.UP  # This is the global up direction (0, 1, 0)

	# Dot product between the helicopter's up vector and the world's up vector gives the cosine of the tilt angle
	var cos_tilt_angle = up_vector.dot(world_up)

	# Calculate the angle of attack (in radians)
	#var angle_of_attack = acos(cos_tilt_angle)

	# Dynamically adjust the lift coefficient based on the tilt angle
	lift_coefficient = max(0.0, 2.0 * cos_tilt_angle)  # Example: Lift decreases with tilt
	drag_coefficient = 0.3 + (1.0 - cos_tilt_angle)  # Example: Drag increases with tilt
	# Adjust the translational lift coefficient based on tilt angle and other conditions
	#translational_lift_coefficient = max(0.0, 0.1 * cos_tilt_angle)






# TODO: Move this to global variables or make useful
# Gradually reduce control authority based on angle and speed
func calculate_control_factor(angle: float, speed: float) -> float:
	# Calculate the factor by which control is reduced
	var angle_factor = 1.0 - clamp(angle / deg_to_rad(max_tilt_angle), 0.0, 1.0)
	var speed_factor = 1.0 - clamp(speed / max_speed_for_control, 0.0, 1.0)
	
	# Return the lesser of the two factors
	return angle_factor * speed_factor






func calculate_g_force(delta: float):
	# Calculate acceleration based on change in velocity and delta time
	var acceleration = (linear_velocity - previous_velocity).length() / delta
	g_force = acceleration / GRAVITY
	previous_velocity = linear_velocity  # Update previous velocity for the next frame

	if debug:
		print("G-force:  ", g_force)
	
	return g_force



func calculate_relative_altitude() -> void:
	var max_altitude = 1000.0
	var space_state = get_world_3d().direct_space_state
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
		relative_altitude = global_transform.origin.distance_to(hit_position)
	else:
		# If no collision, assume helicopter is above the maximum altitude check distance
		relative_altitude = max_altitude






func spin_rotors(delta: float):
   # Convert radians per second (main_rotor_speed) to degrees per second
	var degrees_per_second = main_rotor_speed * (180 / PI)

	main_rotor_shaft_mesh.rotation_degrees.y += degrees_per_second * delta

	# Assuming the tail rotor spins at a faster rate than the main rotor (based on helicopter design),
	# you may want to multiply the main rotor speed by a constant to simulate the faster tail rotor spin.
	var tail_rotor_multiplier = 6.0 
	var tail_degrees_per_second = main_rotor_speed * tail_rotor_multiplier * (180 / PI)

	tail_rotor_mesh.rotation_degrees.x += tail_degrees_per_second * delta



# Light color states
var green_color = Color(0, 1, 0)
var red_color = Color(1, 0, 0)
var orange_color = Color(0.945, 0.557, 0.02)
var flashing_red = false
var flash_timer: float = 0.0
var flash_duration: float = 0.5  # Half a second for flashing interval

func update_engine_light(delta: float):
	if engine_health > engine_health_threshold and engine_spool_up_complete and sky_hook_deployed:
		engine_light.mesh.material.albedo_color = orange_color
	elif engine_health < engine_health_threshold:
		# Flashing red light for critical engine health
		flash_timer += delta
		if flash_timer >= flash_duration:
			flashing_red = !flashing_red  # Toggle flashing state
			flash_timer = 0.0
		engine_light.mesh.material.albedo_color = red_color if flashing_red else Color(1, 1, 1)  # Flash red and white
	elif engine_spool_up_complete:
		# Set the engine light to green when engine power is sufficient for lift
		engine_light.mesh.material.albedo_color = green_color
	else:
		# Set the engine light to red when the engine is still starting up
		engine_light.mesh.material.albedo_color = red_color


func toggle_sky_hook():
	if !sky_hook_deployed:
		var instance = ROPE.instantiate()
		rope_instance = instance
		rope_instance.node_a = self.get_path()
		sky_hook_attachment.add_child(instance)
		instance.global_position = sky_hook_attachment.global_position
		sky_hook_deployed = true
	else:
		rope_instance.queue_free()
		rope_instance = null
		sky_hook_deployed = false
	



 
#region Damage & Impact Forces


@onready var prop_1: Area3D = $MainRotorShaft/MainRotorShaftMesh/Prop1
@onready var prop_2: Area3D = $MainRotorShaft/MainRotorShaftMesh/Prop2

@onready var ski_collider: CollisionShape3D = $Ski_Collider


@export var prop1_health: float = 100.0  # Example health for the propellers
@export var prop2_health: float = 100.0  # Example health for the propellers
var prop_damage_threshold: float = 10.0  # Minimum impact force to cause damage
var prop_destroy_threshold: float = 50.0  # Impact force needed to destroy the prop


# Track impact forces for each collision area
var impact_forces = {}





func _on_prop_1_body_entered(body: Node3D) -> void:
	print("Damage to Prop 1")
	apply_damage_to_props(body, prop_1)

func _on_prop_2_body_entered(body: Node3D) -> void:
	print("Damage to Prop 2")
	apply_damage_to_props(body, prop_2)

func apply_damage_to_props(_body: Node3D, prop: Area3D) -> void:
	# TODO: apply damage to other other items it impacts
	print("Applying Simplified Damage to props")
	# Simplified calculation of impact force
	var impact_force = tip_velocity  

	# Check if the impact force is significant enough to cause damage
	if impact_force > prop_damage_threshold:
		# TODO: Calculate damage based on impact force
		# var damage = impact_force - prop_damage_threshold

		# If the impact force exceeds the destroy threshold, destroy the propeller
		if impact_force > prop_destroy_threshold:
			prop.queue_free()
	



#endregion
