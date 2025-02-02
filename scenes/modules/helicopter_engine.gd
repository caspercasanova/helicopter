class_name Helicopter_Engine_Module extends Helicopter_Module



var health = 10
var disabled = false

var current_power: float = 0.0
var current_engine_state: int
var max_power: float = 1000.0

var engine_temp: float = 40.0
var engine_overheating_threshold: float = 100
var max_engine_temp: float = 120.0


var ambient_temp: float =20.0
var friction_damage_rate: float = 0.2

var oil_system: Helicopter_Oil_Module
var fuel_system: Helicopter_Gas_Tank_Module

var helicopter: Helicopter


var current_output: int = 0 



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	oil_system.connect("oil_low", on_oil_low)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func engine_status():
	pass
	

func get_engine_load_factor() -> float:
	# 0.0 (idle) to 1.0 (full throttle)
	return current_power / max_power


func update_engine_temperature(delta: float):
	# If theres less oil or overheated oil, the engine runs hotter
	var oil_quantity_factor = clamp(oil_system.current_oil_quantity / oil_system.max_oil_quantity, 0, 1)
	# Example if oil is 100% engine cools normally. If oil is low, engine heats more quickly
	var cooling_efficiency = oil_quantity_factor
	var load = get_engine_load_factor()
	
	# Heat up based on load
	engine_temp += load * 5.0 * delta
	# attempt to cool
	engine_temp = lerp(engine_temp, float(ambient_temp), delta * cooling_efficiency)
	
	# If the oil is hot, we also add additional heat to the engine
	if oil_system.current_oil_temp > 100.0:
		engine_temp += (oil_system.current_oil_temp - 100.0) * 0.1 * delta 
	
	if engine_temp > max_engine_temp:
		# Could set current_engine state = OVERHEATING
		pass





func apply_power(delta: float):
	## Simple example: incrementally move current_power toward max based on user input
	## If input is "full throttle", we do:
	#if Input.is_action_pressed("throttle_up"):
		#current_power = lerp(current_power, max_power, 0.1)
	#else:
		#current_power = lerp(current_power, 0, 0.1)
	## Then apply that as a force to the vehicle if applicable
	
	# If the user tries to throttle up  with no fuel, maybe clamp power 
	if fuel_system.current_fuel_amount <= 0:
			current_power = 0
	
	


func check_for_damage(delta: float):
	# If there's no oil, friction damage accumulates quickly
	if oil_system.current_oil_quantity <= 0:
		engine_temp += friction_damage_rate * delta

 

func on_oil_low(quantity):
	print("Warning: Oil level is low! Quantity =", quantity)
	
func on_oil_overheated(temp):
	print("Warning: Oil is overheated! Tempurature=", temp)
	
func on_leak_detected():
	print("Oil leak detected!")
	
	
