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
@onready var hover_mode: Label = $RightBox/hover_mode
@onready var engine_modules: VBoxContainer = $"Engine Modules"


var helicopter_node: Helicopter = null

func _init():
	UI.connect("helicopter_vehicle_updated", _vehicle_changed)
	

func _vehicle_changed(data: Helicopter):
	helicopter_node = data


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !helicopter_node:
		return
	# TODO: Need Total Altitude as well 
	# TODO: Delta Altitude
	relative_altitude.text=("relative_altitude: " + str(floor(helicopter_node.relative_altitude)))
	collective.text=("collective" + str(helicopter_node.collective_pitch))
	rotor_speed.text=("ROTOR RPM" + str(floor(helicopter_node.main_rotor_rpm)))
	# investigate Smooth step for this?
	#lift_force.text=("Lift_force" + str(floor(vehicle_node.lift_force)))
	engine_power.text=("Engine Power" +str(helicopter_node.current_engine_power))
	ground_force.text=("Ground Force Boost: " +str(helicopter_node.ground_effect_multiplier))
	sky_hook.text=("Sky Hook Deployed: " + str(helicopter_node.sky_hook_deployed))
	pitch_angle.text=("Pitch Angle: " +str(helicopter_node.pitch_angle))
	roll_angle.text=("Roll Angle: " +str(helicopter_node.roll_angle))
	g_force.text = (str(round(helicopter_node.g_force)) + "  G")
	speed.text = (str(round(helicopter_node.speed_km)) + "km/h")
	hover_mode.text = ("Hover Mode Engaged: "+ str(helicopter_node.hover_mode))
