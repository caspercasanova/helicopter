extends CanvasLayer

@onready var collective: Label = $VBoxContainer/collective
@onready var lift_force: Label = $VBoxContainer/lift_force
@onready var rotor_speed: Label = $VBoxContainer/rotor_speed
@onready var relative_altitude: Label = $VBoxContainer/relative_altitude
@onready var engine_power: Label = $"VBoxContainer/Engine Power"
@onready var ground_force: Label = $VBoxContainer/ground_force
@onready var sky_hook: Label = $RightBox/sky_hook
@onready var pitch_angle: Label = $VBoxContainer/pitch_angle
@onready var roll_angle: Label = $VBoxContainer/roll_angle
@onready var g_force: Label = $"VBoxContainer/g force"
@onready var speed: Label = $VBoxContainer/speed


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
	# TODO: Need Total Altitude as well 
	# TODO: Delta Altitude
	relative_altitude.text=("relative_altitude: " + str(floor(vehicle_node.relative_altitude)))
	collective.text=("collective" + str(vehicle_node.collective_pitch))
	rotor_speed.text=("ROTOR RPM" + str(floor(vehicle_node.main_rotor_rpm)))
	# investigate Smooth step for this?
	#lift_force.text=("Lift_force" + str(floor(vehicle_node.lift_force)))
	engine_power.text=("Engine Power" +str(vehicle_node.current_engine_power))
	ground_force.text=("Ground Force Boost: " +str(vehicle_node.ground_effect_multiplier))
	sky_hook.text=("Sky Hook Deployed: " + str(vehicle_node.sky_hook_deployed))
	pitch_angle.text=("Pitch Angle: " +str(vehicle_node.pitch_angle))
	roll_angle.text=("Roll Angle: " +str(vehicle_node.roll_angle))
	g_force.text = (str(round(vehicle_node.g_force)) + "  G")
	speed.text = (str(round(vehicle_node.speed_km)) + "km/h")
	
