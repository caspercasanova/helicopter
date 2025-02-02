extends Node3D

const SPEED : float = 40.0
@onready var ray_cast_3d: RayCast3D = $RayCast3D
const BULLET_HOLE_DECAL = preload("res://scenes/weapons/bullets/Bullet_Hole_Decal.tscn")
var origin: Vector3

func _ready():
	top_level = true
	origin = global_position

func _process(delta):
	position += transform.basis * Vector3(0,0, - SPEED) * delta
	
	if ray_cast_3d.is_colliding():
		var hit_node = ray_cast_3d.get_collider()
		spawn_decal(ray_cast_3d.get_collision_point(), ray_cast_3d.get_collision_normal())
		queue_free()

func _on_timer_timeout():
	queue_free()

func spawn_decal(spawn_position: Vector3, normal: Vector3):
	var decal = BULLET_HOLE_DECAL.instantiate()
	get_tree().get_root().add_child(decal)
	decal.global_transform.origin = spawn_position
	
	# Check if normal is not down or up then we do look at
	if normal != Vector3.UP and normal != Vector3.DOWN:
		decal.look_at(spawn_position + normal,Vector3.UP)
		decal.transform = decal.transform.rotated_local(Vector3.RIGHT, PI/2.0)
	# Else we check if its up and we do a 180 to get it to rotate correctly!
	elif normal == Vector3.UP:
		decal.transform = decal.transform.rotated_local(Vector3.RIGHT, PI)
		
	decal.rotate(normal, randf_range(0, 2*PI))
	
	get_tree().create_timer(10).timeout.connect(func destory_decal(): decal.queue_free())
