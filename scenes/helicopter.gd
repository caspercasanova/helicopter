#@tool
extends RigidBody3D
class_name Helicopter 
## An attempt at making a fun physics based helicopter 
## 
## Still plenty to do, Note that flight is currently super unstable 
## and speeds/drag are not implemented properly if at all. 
## 
## @tutorial(Reading Resource 1	): https://www.copters.com/aero/torque.html
## @experimental

"""
TODOS in Order of Priority

TODO: Overall flight feels lame still and hard

TODO: Systematic Clean Cohesive Refiend and Organized Helicopter Modules
	- Need integrating Curves might be more useful  
	- Need to figure out if typed dictionaries are a shareable type for 4.4 
	- Need to be able to manipulate stats easily, it is currently hard to navigate   


TODO: Reactive Destruction Health System
	- TODO: Cleaner version of prop damage -> Component Damage "System"

TODO: Wear and Tear - "Machines Breakdown". IE Fuel, but for modules
	- Durabilities for Engine, Rotor, 
	- TODO: Boost
		- Boosting for too long damages aircraft 
TODO: Hover mode for picking things up
	- Balances Helicopter
	- Limits Yaw and Pitch to 5 degrees or something 
TODO: Weapon Crosshairs / Mouse Flight ? (Prob Not)

TODO: Changes Everything [Mouse Flight](https://github.com/brihernandez/MouseFlight)



TODO: Variables Needed. 
	- AoA 
	- Sea Level Altitude



TODO: Aerodynamics
	- Add some kind of vortex condition where if the current velocity is opposite of the updaward velocity, then reduce upward coefficient 
	- Roll / Pitch control factors?
	- TODO: Proper Conditions where rotor speed falls and increases (currently we hardcode based on whether we increase collective to above 80%)
	- TODO: [x] Engine Spool Down / Turn Off 
		- Double check math
	- TODO: We need to somehow apply a damping Anti Torque from the tail rotor, or some kind of auto leveling force so hitting "Q/E" doesn't send u spinning
	- TODO: Translational Lift / Movement
		- Adding a dead zone is may be the right move
	- TODO: Understand and implement induced drag? 
	- TODO: Understand and implement vortex ring state
	- TODO: Understand and implement retreating blade stall
	- TODO: Refactor to an engine Engine Curve?
	- TODO: Ground Effect?
	- TODO: Autorotation?
	- TODO: VRS?
	- TODO: Maybe split the lift vector by the prop count and apply every revolution? (maybe not idk) "Force-Per-Prop" Lite™ Implementation


TODO: Solve Joint Bouncyness [May get solved with 4.4]
TODO: Clean + Polished UI Elements
TODO: Better Loadout Experience 


TODO: Add an option so we can instiantiate from a flying state. 


---
Dream TODOs:
TODO: Rigid body AI Implementation?
	- We could maybe limit the AI to hard set amount of degrees of rotational freedom to keep flight super stable. Maybe IDK. 

TODO: Make shareable DEMO

"""
# TODO: Change this to a helicopter state variable
# Loading, Landing, Repairing, Injured, Green Light
enum HELICOPTER_LIGHT_STATES {
	LANDED,
	REPAIRING,
	CARRYING_OBJECT,
	GREEN_LIGHT,
	CRITICAL,
}



@onready var ui_controller: Node3D = $UI_Controller

@export var helicopter_camera_base: Helicopter_Camera_Base
@export var tail_rotor_marker: Marker3D
@onready var main_rotor_shaft: Marker3D = $MainRotorShaft
@onready var main_rotor_shaft_mesh: MeshInstance3D = $MainRotorShaft/MainRotorShaftMesh
@onready var cursor_pointer: MeshInstance3D = $CursorPointer
@export var tail_rotor_mesh: Node3D
@onready var engine_light: MeshInstance3D = $EngineLight
@onready var sky_hook_attachment: MeshInstance3D = $Sky_Hook_Attachment
@onready var loadout_gui: Node3D = $UI_Controller/LoadoutGUI


const ROPE = preload("res://scenes/Rope.tscn")
var rope_instance: JoltPinJoint3D

### --- Exported Variables ---
@export var weight_in_lbs: float = 10000.0


### Debug and state flags
var debug: bool = false


### --- Constants ---
var GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity")
const LBS_TO_KG: float = 0.454
const TAIL_ROTOR_MAX_FORCE: float = 100000.0
const PITCH_FORCE_COEFFICIENT: float = 100000.0
const ROLL_FORCE_COEFFICIENT: float = 30000.0

var weight: float


### State Variables
var is_landed = false
var landing_progress = 0
var landing_timer = 0.0
var is_on_helipad = false
var landing_time_threshold = 5

var move: Vector3 = Vector3.ZERO
var sky_hook_deployed: bool = false
var hover_mode: bool = false
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
var speed_magnitude: float:
	get:
		return linear_velocity.length()

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

# Boost - This is a want, but might need to do with jet instead
var is_boosting: bool = false
var power_addend = 1
var boosting_timer: float = 0.0
var boost_time_till_damage = 5.0
var boost_damage: float = 0.0
func apply_boost(delta: float):
	# speed += 10
	boosting_timer += delta
	if boosting_timer >= boost_time_till_damage:
		# module.take_damage()
		pass
	

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
var drag_coefficient: float = 100

var ground_effect_multiplier: float:
	get():
		var altitude_ratio = relative_altitude / main_rotor_radius
		var multiplier = 1.0
		
		if altitude_ratio < 1.0:  # Ground effect is strongest within one rotor radius from the ground
			multiplier = 1.0 + (1.0 - altitude_ratio) * 0.1  # Amplifies the lift by up to 50%
		return multiplier



### Aerodynamics / Control Factor
### Control factor can essentially be "Aero dynamics"
@export var max_tilt_angle: float = 60.0  # Maximum allowed tilt angle before control reduces
@export var max_speed_for_control: float = 10.0  # Maximum speed before control authority is reduced





### UI
enum current_UI {
	
}





func _ready():
	weight = weight_in_lbs * LBS_TO_KG
	self.mass = weight
	cursor_pointer.top_level = true
	apply_modules_to_ship()
	

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()
	

func _input(_event: InputEvent):
	if Input.is_action_pressed("F"):
		toggle_sky_hook()
	if Input.is_action_pressed("C"):
		toggle_hover_mode()
	#if Input.is_action_pressed("T"):
		#if current_helicopter_hud == ENUM_HELICOPTER_HUDS.LOADOUT_MENU:
			#current_helicopter_hud = ENUM_HELICOPTER_HUDS.HELICOPTER_HUD
			#helicopter_ui.visible = true
			#loadout_menu.visible = false
		#else:
			#current_helicopter_hud = ENUM_HELICOPTER_HUDS.LOADOUT_MENU
			#loadout_menu.visible = true
			#helicopter_ui.visible = false
	
	if Input.is_action_just_pressed("TAB") and is_landed:
		toggle_loadout_camera()

func toggle_loadout_camera():
	helicopter_camera_base.toggle_loudout_camera_state()
	ui_controller.toggle_helicopter_hud()
	ui_controller.toggle_loadout_gui()


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
	
	determine_if_landed(delta)
	
	
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
	
	apply_drag_force(delta)
	#apply_tilt_based_force(delta)
	#calculate_translational_lift()
	#apply_parasitic_drag()
 

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




func apply_tail_rotor_force(delta: float):
	# Calculate the main rotor torque
	var tail_rotor_force = (main_rotor_torque / tail_rotor_radius)

	var tail_rotor_torque_vector = tail_rotor_marker.global_transform.basis.y * tail_rotor_force * delta

	if move.z != 0:
		# Convert player input into a vector to modify the tail rotor force
		var player_input_force = tail_rotor_marker.global_transform.basis.y * (move.z * TAIL_ROTOR_MAX_FORCE * delta)
		# Adjust tail rotor force with player input for yaw control
		tail_rotor_torque_vector += player_input_force

	apply_torque(-tail_rotor_torque_vector)


func apply_drag_force(delta: float) -> void:
	# Calculate speed as the magnitude of the linear velocity
	var speed = linear_velocity.length()

	# Adjust drag to increase with the square or cube of speed for stronger high-speed resistance
	var drag_force_magnitude = 0.5 * air_density * pow(speed, 3) * drag_coefficient * reference_area
	
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
	

func toggle_hover_mode():
	if !hover_mode:
		hover_mode = true
	else:
		hover_mode = false


func determine_if_landed(delta: float) -> void:
	# Here, is_on_ground is a flag you would set based on your collision or raycast checks
	if is_on_ground:
		landing_timer += delta
		landing_progress += 1  # From your snippet; you can decide how you use landing_progress %%
		
		if landing_timer >= landing_time_threshold:
			# Ship/plane has been on the ground for at least 'landing_time_threshold' seconds
			# This is where you’d confirm the landing logic or trigger a “landed” state
			print("Landing complete. Landed for ", landing_timer, " seconds.")
			is_landed = true
	else:
		# Reset the timer if not on ground
		landing_timer = 0.0
		is_landed = false
		
		





#region Loadout
### Vehicle Components & Weapon Systems
"""
Almost somewhat there, still need typed dictionaries though

Loadouts
toggle right / left weapons subsystem
(mid slot, small slot)
Set Small Slot 
- Gun A
- Gun A x2
- Gun B
Set Medium Slot
- Rocket Pod A
- Rocket Pod B
"""
@export_group("Vehicle Loadout")
## This is the list of "breakable" components to a vehicle
var vehicle_components: Array[Helicopter_Component]

@export var left_weapon_subsystem_point: Node3D
@export var right_weapon_subsystem_point: Node3D

const LEFT_WEAPON_SUBSYSTEM = preload("res://scenes/weapons/left_weapon_subsystem.tscn")
const RIGHT_WEAPON_SUBSYSTEM = preload("res://scenes/weapons/right_weapon_subsystem.tscn")

const GUN_A = preload("res://scenes/weapons/gun_a.tscn")
const GUN_B = preload("res://scenes/weapons/gun_b.tscn")
const GUN_C = preload("res://scenes/weapons/gun_c.tscn")

enum SMALL_WEAPONS_MODULE_NAMES {
	NONE,
	GUN_A,
	GUN_B,
	GUN_C,
}

var small_weapons_modules = {
	SMALL_WEAPONS_MODULE_NAMES.GUN_A: GUN_A,
	SMALL_WEAPONS_MODULE_NAMES.GUN_B: GUN_B,
	SMALL_WEAPONS_MODULE_NAMES.GUN_C: GUN_C,
}

const ROCKET_POD_A = preload("res://scenes/weapons/rocket_pod_a.tscn")
const ROCKET_POD_B = preload("res://scenes/weapons/rocket_pod_b.tscn")

enum MEDIUM_WEAPONS_MODULE_NAMES {
	NONE,
	ROCKET_POD_A,
	ROCKET_POD_B
}

var medium_weapons_modules = {
	MEDIUM_WEAPONS_MODULE_NAMES.ROCKET_POD_A: ROCKET_POD_A,
	MEDIUM_WEAPONS_MODULE_NAMES.ROCKET_POD_B: ROCKET_POD_B
}




## Adds the Left weapon system to the helicopter
## TODO: Figure out better optional tooling functionality later
@export var has_left_subsystem: bool = false:
	set(val):
		has_left_subsystem = val
		notify_property_list_changed()
var left_weapon_subsystem: Helicopter_Weapon_Subsystem

## Adds the Right weapon system to the helicopter
@export var has_right_subsystem: bool = false:
	set(val):
		has_right_subsystem = val
		notify_property_list_changed()
var right_weapon_subsystem: Helicopter_Weapon_Subsystem


@export var left_weapon_system_small_slot_a: SMALL_WEAPONS_MODULE_NAMES = SMALL_WEAPONS_MODULE_NAMES.NONE
@export var left_weapon_system_medium_slot_b: MEDIUM_WEAPONS_MODULE_NAMES = MEDIUM_WEAPONS_MODULE_NAMES.NONE
@export var right_weapon_system_small_slot_a: SMALL_WEAPONS_MODULE_NAMES = SMALL_WEAPONS_MODULE_NAMES.NONE
@export var right_weapon_system_medium_slot_b: MEDIUM_WEAPONS_MODULE_NAMES = MEDIUM_WEAPONS_MODULE_NAMES.NONE



func update_weapon_subsystem_to_helo(subsystem_side: Helicopter_Weapon_Subsystem.SIDE):
	if subsystem_side == Helicopter_Weapon_Subsystem.SIDE.LEFT:
		var node = LEFT_WEAPON_SUBSYSTEM.instantiate()
		left_weapon_subsystem_point.add_child(node)
		node.joint.node_a = self.get_path()
		left_weapon_subsystem = node
		print("add_weapon_subsystem_to_helo", node.joint)
	else:
		var node = RIGHT_WEAPON_SUBSYSTEM.instantiate()
		right_weapon_subsystem_point.add_child(node)
		node.joint.node_a = self.get_path()
		right_weapon_subsystem = node
		print("add_weapon_subsystem_to_helo", node.joint)

func remove_subsystem_from_helo(subsystem_side: Helicopter_Weapon_Subsystem.SIDE):
	if subsystem_side == Helicopter_Weapon_Subsystem.SIDE.LEFT:
		for nodes in left_weapon_subsystem_point.get_children():
			nodes.queue_free()
	else:
		for nodes in right_weapon_subsystem_point.get_children():
			nodes.queue_free()


func update_subsystem_small_slot(side: Helicopter_Weapon_Subsystem.SIDE, item: SMALL_WEAPONS_MODULE_NAMES):
	if side == Helicopter_Weapon_Subsystem.SIDE.LEFT:
		assert(has_left_subsystem, "Need to have a left subsystem to add weapon")
		for nodes in left_weapon_subsystem.small_slot_a.get_children():
			nodes.queue_free()
		
		if item == SMALL_WEAPONS_MODULE_NAMES.NONE:
			return
		
		var node = small_weapons_modules[item].instantiate()
		left_weapon_subsystem.small_slot_a.add_child(node) 
	elif side == Helicopter_Weapon_Subsystem.SIDE.RIGHT:
		assert(has_right_subsystem, "Need to have a left subsystem to add weapon")
		for nodes in right_weapon_subsystem.small_slot_a.get_children():
			nodes.queue_free()
		
		if item == SMALL_WEAPONS_MODULE_NAMES.NONE:
			return
		
		var node = small_weapons_modules[item].instantiate()
		right_weapon_subsystem.small_slot_a.add_child(node) 
	return

func update_subsystem_medium_slot(side: Helicopter_Weapon_Subsystem.SIDE, item: MEDIUM_WEAPONS_MODULE_NAMES):
	if side == Helicopter_Weapon_Subsystem.SIDE.LEFT:
		assert(has_left_subsystem, "Need to have a left subsystem to add weapon")
		for nodes in left_weapon_subsystem.medium_slot_a.get_children():
			nodes.queue_free()
		
		if item == MEDIUM_WEAPONS_MODULE_NAMES.NONE:
			return
		
		var node = medium_weapons_modules[item].instantiate()
		left_weapon_subsystem.medium_slot_a.add_child(node)
		
	elif side == Helicopter_Weapon_Subsystem.SIDE.RIGHT:
		assert(has_right_subsystem, "Need to have a left subsystem to add weapon")
		for nodes in right_weapon_subsystem.medium_slot_a.get_children():
			nodes.queue_free()
		
		if item == MEDIUM_WEAPONS_MODULE_NAMES.NONE:
			return
		
		var node = medium_weapons_modules[item].instantiate()
		right_weapon_subsystem.medium_slot_a.add_child(node) 
	return



func apply_modules_to_ship():
	"""
	Either here or somewhere be able to allow a single function that makes a helicopter with everything applied
	"""
	if has_left_subsystem:
		update_weapon_subsystem_to_helo(Helicopter_Weapon_Subsystem.SIDE.LEFT)
		update_subsystem_small_slot(Helicopter_Weapon_Subsystem.SIDE.LEFT, left_weapon_system_small_slot_a)
		update_subsystem_medium_slot(Helicopter_Weapon_Subsystem.SIDE.LEFT, left_weapon_system_medium_slot_b)
	
	if has_right_subsystem:
		update_weapon_subsystem_to_helo(Helicopter_Weapon_Subsystem.SIDE.RIGHT)
		update_subsystem_small_slot(Helicopter_Weapon_Subsystem.SIDE.RIGHT, right_weapon_system_small_slot_a)
		update_subsystem_medium_slot(Helicopter_Weapon_Subsystem.SIDE.RIGHT, right_weapon_system_medium_slot_b)
		

### return to this when I need to turn into a tool, but not for now
#func _get_property_list():
	#var property_usage = PROPERTY_USAGE_NO_EDITOR
	#
	#if Engine.is_editor_hint():
		#var properties: Array[Dictionary] = []
		#
	## Conditionally show the texture property
		#if (has_left_subsystem):
			#properties.append({
				#"name": "Left Weapon System Small Slot A",
				#"type": TYPE_INT,   
				#"hint": PROPERTY_HINT_ENUM,
				#"hint_string": "NONE,GUN_A,GUN_B,GUN_C",
			#})
		#return properties
#
## The value argument must be a variant, which we can't explicitly tell through static typing.
## This function must return true if the property actually exists.
#func _set(prop_name: StringName, val) -> bool:
	## Assume the property exists
	#var return_value: bool = true
	#
	#match prop_name:
		#"Left Weapon System Small Slot A":
			#left_weapon_system_small_slot_a = val
		#
		#"Right Weapon System Small Slot A":
			#right_weapon_system_small_slot_a = val
		#
		#_:
			## If here, trying to set a property we are not manually dealing with.
			#return_value = false
	#
	#return return_value
#
## This function must return a value, which is basically the one related to the property name.
## However it is a variant, which we can't define explicitly through static typing.
#func _get(prop_name: StringName):
	#match prop_name:
		#"Left Weapon System Small Slot A":
			#return left_weapon_system_small_slot_a
		#
		#"Right Weapon System Small Slot A":
			#return right_weapon_system_small_slot_a
	#
	#return null



#endregion


 
#region Damage & Impact Forces
"""
TODO: Need to hold health / status of each component 
TODO: Apply Tail Rotor Health
TODO: Health Bars above each component 

"""

@export_group("Damage & Impact Forces")
const DAMAGE_SPEED_THRESHOLD = 100
@export var health: int = 100








func _on_body_entered(body: Node) -> void:
	print('Collision detected with body:', body)

	# Check if the body has a linear_velocity (indicating it's a PhysicsBody3D)
	if body.has_method("linear_velocity"):
		var relative_speed = (body.linear_velocity - linear_velocity).length()

		# Calculate and inflict damage if relative speed exceeds threshold
		if relative_speed > DAMAGE_SPEED_THRESHOLD:
			inflict_damage(relative_speed)
			print('Destroying joint due to high-speed impact.')
			
			for node in vehicle_components:
				if node.joint:
					node.joint.queue_free()
					node.joint=null
	else:
		# For bodies without linear_velocity (e.g., StaticBody3D or other nodes), use impact velocity and mass
		print('Taking damage from collision with static or unmovable body.')

		# Calculate the collision normal
		var collision_normal = (global_transform.origin - body.global_transform.origin).normalized()

		# Calculate the component of velocity in the direction of the collision normal
		var impact_velocity = linear_velocity.dot(collision_normal)
		impact_velocity = abs(impact_velocity)  # Ensure positive impact velocity
		
		# Compute the impact force
		var impact_force = mass * impact_velocity

		# Inflict damage if impact force exceeds threshold
		if impact_force > DAMAGE_SPEED_THRESHOLD:
			inflict_damage(impact_force)
			
			for node in vehicle_components:
				if node.joint:
					node.joint.queue_free()
					node.joint=null




func inflict_damage(impact_force: float) -> void:
	# Custom logic to apply damage based on impact force
	print("Damage inflicted with force:", impact_force)


@onready var prop_1: Area3D = $MainRotorShaft/MainRotorShaftMesh/Prop1
@onready var prop_2: Area3D = $MainRotorShaft/MainRotorShaftMesh/Prop2

@onready var ski_collider: CollisionShape3D = $Ski_Collider


@export var prop1_health: float = 100.0  # Example health for the propellers
@export var prop2_health: float = 100.0  # Example health for the propellers
var prop_damage_threshold: float = 10.0  # Minimum impact force to cause damage
var prop_destroy_threshold: float = 50.0  # Impact force needed to destroy the prop






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

func react_to_damage():
	# prop damage reduces prop output
	# engine power is has a engine health coefficient
	pass


#endregion
