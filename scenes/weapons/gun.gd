extends Node3D
const ROCKET = preload("res://scenes/weapons/rockets/rocket.tscn")
const BULLET_RAYCAST = preload("res://scenes/weapons/bullets/bullet_raycast.tscn")
@onready var muzzle: Marker3D = $Muzzle
@export var fire_rate_per_minute := 600

@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D

var busy := false
func set_busy(val):
	busy = val

func fire():
	if busy:
		return
	print('Firing')
	var instance = BULLET_RAYCAST.instantiate()
	
	instance.position = muzzle.position
	# TODO 
	# this currently creates a square shaped spread distribution of x,y points
	# we need a circular shaaped spread so might need to clamp
	# _could_ also memoize a 10 random points and reuse those so 
	# there no need of re-randomization of bullet spread is needed
	#calculate_spread()
	#instance.rotate_x(deg_to_rad(spread.x))
	#instance.rotate_y(deg_to_rad(spread.y))
	
	muzzle.add_child(instance)
	audio_stream_player_3d.play()
	busy = true
	call_delayed(func(): set_busy(false), 1 / (fire_rate_per_minute / 60.0))




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func call_delayed(callable: Callable, delay: float):
	get_tree().create_timer(delay, false).connect('timeout', callable)
