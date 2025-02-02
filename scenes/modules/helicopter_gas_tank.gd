class_name Helicopter_Gas_Tank_Module extends Helicopter_Module


# 600 seconds worth of fuel

var max_fuel_capacity: float = 100.0
var current_fuel_amount: float = 100.0

var base_consumption_rate: float = 0.1  # liters per second at full throttle

var is_leaking: bool = false
var leak_rate: float = 0.0             # liters per second if there's a fuel tank leak

var is_on_fire: bool = false
var fire_damage_rate: float = 0.0
var fuel_burn_rate: float = 0.0
@export var helicopter: Helicopter

signal fuel_low(fuel_left)
signal fuel_empty()
signal fuel_leak_detected()
signal fuel_leak_stopped()
signal fuel_is_on_fire()
signal fuel_is_on_fire_stopped()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



#func update(delta: float):
	#_handle_fuel_consumption(delta)
	#_handle_leak(delta)



func handle_fuel_consumption(delta: float):
	# If the owner provides an engine load factor or throttle
	var load_factor = helicopter.get_engine_load_factor()
	var consumption = load_factor * base_consumption_rate * delta
	current_fuel_amount = max(current_fuel_amount - consumption, 0.0)

	if current_fuel_amount <= 0.0:
		current_fuel_amount = 0.0
		emit_signal("fuel_empty")

	# Check for low fuel threshold
	if current_fuel_amount < (max_fuel_capacity * 0.1): # < 10%
		emit_signal("fuel_low", current_fuel_amount)


func handle_leak(delta: float):
	if is_leaking:
		var lost_fuel = leak_rate * delta
		current_fuel_amount = max(current_fuel_amount - lost_fuel, 0.0)
		if current_fuel_amount <= 0.0:
			current_fuel_amount = 0.0
			is_leaking = false
			leak_rate = 0.0
			emit_signal("fuel_leak_stopped")



func handle_gas_tank_fire():
	is_on_fire = true
	if is_on_fire:
		print("on fire")
	pass
	
func gas_tank_explosion():
	pass
