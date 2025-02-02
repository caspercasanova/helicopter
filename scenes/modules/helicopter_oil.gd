class_name Helicopter_Oil_Module extends Helicopter_Module

"""
Has Temp
Has Amount 
Feeds Engine Oil. 100% Health = 100 Engine Consumption Rate  
"""
var max_oil_quantity: float = 10
var current_oil_quantity: float = 10


var max_oil_temp: float = 150.0  # in Celsius
var current_oil_temp: float = 20.0
var ambient_temp: float = 20.0   # external environment temperature

var is_leaking: bool = false
var leak_rate: float = 0.0

var helicopter_parent: Helicopter


signal oil_low(quantity)
signal oil_overheated(temp)
signal leak_detected()
signal leak_stopped()


func handle_leak(delta: float):
	if is_leaking:
		var lost_oil = leak_rate * delta
		current_oil_quantity = max(current_oil_quantity - lost_oil, 0.0)
		if current_oil_quantity <= 0:
			current_oil_quantity = 0
	# Possibly emit an event or just let the engine see that oil is at 0
	# If the leak is patched in your game logic, is_leaking = false, emit_signal("leak_stopped")


## WARNING Subject to change
func update_oil(delta: float):
	var load = helicopter.get_engine_load_factor()
	current_oil_temp += (load * 10) * delta
	
	# Natural cooling back to ambient:
	var cooling_rate = 1.0
	if current_oil_temp > ambient_temp:
		current_oil_temp = lerp(current_oil_temp, float(ambient_temp), delta * cooling_rate)
	
	# Check if overheated
	if current_oil_temp > max_oil_temp:
		emit_signal("oil_overheated", current_oil_temp)


func _check_oil_levels():
	if current_oil_quantity < 1.0:
		emit_signal("oil_low", current_oil_quantity)



func induce_leak(rate: float):
	if not is_leaking:
		is_leaking = true
		leak_rate = rate
		emit_signal("leak_detected")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
