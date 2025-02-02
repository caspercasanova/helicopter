class_name Blast_Sphere extends Node3D

@onready var blast_sphere: Node3D = $"."
@onready var area_3d: Area3D = $Area3D
@onready var blast_collision: CollisionShape3D = $Area3D/BlastCollision

@export var blast_force: float = 1000000.0
@export var blast_radius: float = 10.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	blast_collision.shape.radius = blast_radius



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func physics_process(delta):
	# We can apply the blast impulses immediately in _ready(), or you could
	# call apply_blast_impulse() externally. This example calls it directly:
	apply_blast_impulse()
	# Optionally queue_free the explosion node if it’s a one-shot effect:
	queue_free()


func apply_blast_impulse() -> void:
	print("applying blast")
	# Get all bodies in the blast radius
	var bodies = area_3d.get_overlapping_bodies()
	print(bodies)
	var origin = area_3d.global_transform.origin

	for body in bodies:
		
		# If it’s a RigidBody, we can call apply_impulse directly
		if body is RigidBody3D:
			_apply_rigidbody_blast(body, origin)

		# If it’s a CharacterBody3D, you might set its velocity or snap it
		elif body is CharacterBody3D:
			_apply_character_blast(body, origin)

		# If it’s a VehicleBody3D or something else you want to handle,
		# you can do so with additional checks

		# else, if it's a StaticBody3D or an unhandled type, do nothing
		# or add other specialized logic here as needed

func _apply_rigidbody_blast(rigidbody: RigidBody3D, blast_origin: Vector3) -> void:
	var to_body = (rigidbody.global_transform.origin - blast_origin)
	var distance = to_body.length()

	# Only apply impulse if within radius
	if distance <= blast_radius:
		var direction = to_body.normalized()
		var falloff = 1.0 - (distance / blast_radius)
		# The impulse magnitude scales by falloff so it's stronger near center
		var impulse_vector = direction * (blast_force * falloff)
		print("hey blast", impulse_vector)
		rigidbody.apply_impulse(impulse_vector)

func _apply_character_blast(character: CharacterBody3D, blast_origin: Vector3) -> void:
	var to_body = (character.global_transform.origin - blast_origin)
	var distance = to_body.length()

	if distance <= blast_radius:
		var direction = to_body.normalized()
		var falloff = 1.0 - (distance / blast_radius)
		# For a CharacterBody, you might set velocity or call move_and_slide
		# directly. Here, we just give it an instant velocity change.
		character.velocity = direction * (blast_force * 0.1 * falloff)
