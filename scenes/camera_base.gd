class_name Helicopter_Camera_Base extends Node3D
@export var helicopter: Helicopter
@export var FLIGHT_CAMERA_CONTROLLER : Camera3D
@export var LOADOUT_CAMERA_1 : Camera3D
@export var MOUSE_SENSITIVITY := 0.5
@export var TILT_LOWER_LIMIT := deg_to_rad(-90)
@export var TILT_UPPER_LIMIT := deg_to_rad(90)
@onready var flight_camera_base: Node3D = $Flight_Camera_Base

var _mouse_input := false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float
var _player_rotation : Vector3
var _camera_rotation : Vector3


enum CAMERA_STATES {
	LOADOUT_MENU,
	FLIGHT
}

var camera_current_state: CAMERA_STATES = CAMERA_STATES.FLIGHT

func toggle_loudout_camera_state():
	if camera_current_state == CAMERA_STATES.FLIGHT:
		set_camera_state_to_loadout()
	else:
		set_camera_state_to_flight()

func set_camera_state_to_loadout():
	FLIGHT_CAMERA_CONTROLLER.current = false
	LOADOUT_CAMERA_1.current = true
	camera_current_state = CAMERA_STATES.LOADOUT_MENU
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func set_camera_state_to_flight():
	LOADOUT_CAMERA_1.current = false
	FLIGHT_CAMERA_CONTROLLER.current = true
	camera_current_state = CAMERA_STATES.FLIGHT
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)	



func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY


func _physics_process(delta: float) -> void:
	
	if camera_current_state == CAMERA_STATES.FLIGHT: 
		_update_camera(delta)
		_cast_ray_from_camera()
	pass


func _update_camera(delta):
	# Rotate Camera using Euler
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta
	
	_player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)
	_camera_rotation = Vector3(_mouse_rotation.x, 0.0, 0.0)
	
	FLIGHT_CAMERA_CONTROLLER.transform.basis = Basis.from_euler(_camera_rotation)
	#CAMERA_CONTROLLER.rotation.z = 0.0
	
	flight_camera_base.global_transform.basis = Basis.from_euler(_player_rotation)
	
	_rotation_input = 0.0
	_tilt_input = 0.0 

func _cast_ray_from_camera():
	var mouse_pos = get_viewport().get_mouse_position()
	var origin = FLIGHT_CAMERA_CONTROLLER.project_ray_origin(mouse_pos)
	var end = origin + FLIGHT_CAMERA_CONTROLLER.project_ray_normal(mouse_pos) * 100

	var col = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, helicopter.collision_mask, [helicopter, FLIGHT_CAMERA_CONTROLLER]))
	
	if col.is_empty():
		helicopter.cursor_pointer.set_position(end)
	else:
		helicopter.cursor_pointer.set_position(col.position)
