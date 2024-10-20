extends CanvasLayer

@onready var throttle: Label = $VBoxContainer/throttle
@onready var lift_force: Label = $VBoxContainer/lift_force
@onready var rotor_speed: Label = $VBoxContainer/rotor_speed
@onready var altitude: Label = $VBoxContainer/altitude
@onready var hover_mode: Label = $"RightBox/hover mode"


var vehicle_node: Helicopter = null

func _init():
	UI.connect("helicopter_vehicle_updated", _vehicle_changed)
	

func _vehicle_changed(data):
	vehicle_node = data


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !vehicle_node:
		return
	#assert(vehicle_speed, "The Humvee UI must have a vehicle_speed")
	altitude.text=("Altitude: " + str(vehicle_node.altitude))
	hover_mode.text=("hover_mode: " + str(vehicle_node.hover_mode))
	#health.text=("Health: " + str(vehicle_node.health))
	throttle.text=("Throttle" + str(vehicle_node.throttle))
	lift_force.text=("Lift_force" + str(vehicle_node.lift_force))
	rotor_speed.text=("rotor_speed" + str(vehicle_node.main_rotor_speed))
