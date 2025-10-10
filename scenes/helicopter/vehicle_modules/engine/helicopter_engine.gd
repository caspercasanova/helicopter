class_name Helicopter_Engine_Module extends Helicopter_Module


var current_engine_state: int

# Might moves these up to the module_class 
var initial_health = 100
var health = 100
var critical_health_threshold = 25
var disabled = false

var current_engine_power: float = 0.0
var max_engine_power: float = 1000.0

var engine_temp: float = 40.0
var engine_overheating_threshold: float = 100
var overheating_damage: float = 5
var engine_explosion_temp: float = 120.0


var ambient_temp: float = 20.0
var friction_damage_rate: float = 0.2

@export var oil_system: Helicopter_Oil_Module
@export var fuel_system: Helicopter_Gas_Tank_Module





 
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



#func _ready() -> void:
	#oil_system.connect("oil_low", on_oil_low)
	#pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func engine_status():
	pass
	



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


func get_engine_load_factor(): 
	# 0.0 (idle) to 1.0 (full throttle)
	return current_engine_power / max_engine_power



func update_engine(delta: float):
	if fuel_system.current_fuel_amount <= 0:
			current_engine_power = 0
	# If theres less oil or overheated oil, the engine runs hotter
	# Example if oil is 100% engine cools normally. If oil is low, engine heats more quickly
	var cooling_efficiency = clamp(oil_system.current_oil_quantity / oil_system.max_oil_quantity, 0, 1)

	var engine_load_factor = get_engine_load_factor()
	
	# Heat up based on load
	engine_temp += engine_load_factor * 5.0 * delta
	# attempt to cool
	engine_temp = lerp(engine_temp, float(ambient_temp), delta * cooling_efficiency)
	
	# If the oil is hot, we also add additional heat to the engine
	if oil_system.current_oil_temp > 100.0:
		engine_temp += (oil_system.current_oil_temp - 100.0) * 0.1 * delta 
	
	if engine_temp > engine_explosion_temp:
		# Could set current_engine state = OVERHEATING
		health -= overheating_damage * delta
		pass
		
	if oil_system.current_oil_quantity <= 0:
		engine_temp += friction_damage_rate * delta





#func on_oil_low(quantity):
	#print("Warning: Oil level is low! Quantity =", quantity)
	#
#func on_oil_overheated(temp):
	#print("Warning: Oil is overheated! Tempurature=", temp)
	#
#func on_leak_detected():
	#print("Oil leak detected!")
	
	
