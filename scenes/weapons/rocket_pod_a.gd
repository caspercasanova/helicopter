extends Node3D

const ROCKET = preload("res://scenes/weapons/rockets/rocket.tscn")
@export var fire_rate_per_second := 2.0
@onready var marker_3d: Marker3D = $Marker3D


var busy := false
func set_busy(val):
	busy = val


func call_delayed(callable: Callable, delay: float):
	get_tree().create_timer(delay, false).connect('timeout', callable)

func fire():
	if busy:
		return
	print('Firing')
	var instance = ROCKET.instantiate()
	
	instance.position = marker_3d.position

	
	marker_3d.add_child(instance)
	busy = true
	call_delayed(func(): set_busy(false), fire_rate_per_second)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
