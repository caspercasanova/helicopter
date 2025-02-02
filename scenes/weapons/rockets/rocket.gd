extends RigidBody3D


@onready var rocket_smoke: Node3D = $RocketSmoke
const BLAST_SPHERE = preload("res://scenes/weapons/blast/blast_sphere.tscn")
const EXPLOSION = preload("res://scenes/vfx/explosion.tscn")
var rocket_speed = 100
var max_speed = 100
var acceleration_step = 40
# Calculate a random deviation within the dispersion radius
var fuel = 1.5
var fuel_spend_per_delta = 1

var exploded = false
var stray_strength: float = 0.02      # How large the random "stray" is each frame
var collision_delay = 1
var collision_timer = 0 

var air_start_delay = .5
var air_start_timer = 0 
@onready var ray_cast_3d: RayCast3D = $RayCast3D


func _ready() -> void:
	set_collision_layer_value(1, false)
	#set_linear_velocity(global_transform.basis.z * rocket_speed)
	top_level = true
	pass
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	#print("instanced and going")
	collision_timer += delta 
	if collision_timer > collision_delay:
		#print("setting collision layer")
		set_collision_layer_value(1, true)
	
	fuel -= (delta * fuel_spend_per_delta)

	air_start_timer += delta
	
	if ray_cast_3d.is_colliding():
		explode()
		
	
	if (air_start_timer > air_start_delay and fuel > 0):
		if rocket_speed < max_speed:
			rocket_speed += acceleration_step
		
		# 1) Grab current orientation as a quaternion:
		var current_quat: Quaternion = transform.basis.get_rotation_quaternion()
		
		# 2) Create a small random rotation:
		var random_axis = Vector3(randf(), randf(), randf()).normalized() 
		var random_angle = stray_strength * delta
		# A small rotation around a random axis
		var stray_quat = Quaternion(random_axis, random_angle)

		# 3) Apply the stray rotation on top of our current orientation
		var new_quat = stray_quat * current_quat

		# 4) Update the rocket’s orientation
		transform.basis = Basis(new_quat)

		# 5) Keep flying forward along the rocket’s new forward axis (-Z):
		set_linear_velocity(transform.basis.z * rocket_speed)
	
	if fuel <= 0:
		rocket_smoke.stop()


func explode():
	if !exploded: 
		exploded = true
		var explosion_instance = EXPLOSION.instantiate()
		var blast_instance = BLAST_SPHERE.instantiate()
		add_child(explosion_instance)
		explosion_instance.top_level = true
		explosion_instance.explode()

		add_child(blast_instance)
		blast_instance.top_level = true
		blast_instance.apply_blast_impulse()
		
		print("Explode this shit")
		await get_tree().create_timer(.5).timeout
		queue_free()
	

func _on_area_3d_body_entered(body: Node3D) -> void:
	print("Area Collided:", body)
	explode()
	pass # Replace with function body.
