class_name Helicopter_Component extends RigidBody3D


# Should probably change this to Helicopter_Attachment
# Thinking being, extra armor attachments, or gun pods etc... 

const COLLISION_DAMAGE_SPEED_THRESHOLD = 0.01
@export var health: int = 100
@onready var joint: JoltHingeJoint3D = $Joint



func _on_body_entered(body: Node) -> void:
	print('Collision detected with body:', body)

	# Check if the body has a linear_velocity (indicating it's a PhysicsBody3D)
	if body.has_method("linear_velocity"):
		var relative_speed = (body.linear_velocity - linear_velocity).length()

		# Calculate and inflict damage if relative speed exceeds threshold
		if relative_speed > COLLISION_DAMAGE_SPEED_THRESHOLD:
			inflict_damage(relative_speed)
			print('Destroying joint due to high-speed impact.')
			if joint:
				joint.queue_free()
				joint = null
	else:
		# For bodies without linear_velocity (e.g., StaticBody3D or other nodes), use impact velocity and mass
		print('Taking damage from collision with static or unmovable body.')

		# Calculate the collision normal
		var collision_normal = (global_transform.origin - body.global_transform.origin).normalized()

		# Calculate the component of velocity in the direction of the collision normal
		var impact_velocity = linear_velocity.dot(collision_normal)
		impact_velocity = abs(impact_velocity)  # Ensure positive impact velocity
		print(impact_velocity)
		# Compute the impact force
		var impact_force = mass * impact_velocity

		# Inflict damage if impact force exceeds threshold
		if impact_force > COLLISION_DAMAGE_SPEED_THRESHOLD:
			inflict_damage(impact_force)
			if joint:
				joint.queue_free()
				joint=null


func inflict_damage(impact_force: float) -> void:
	# Custom logic to apply damage based on impact force
	print("Damage inflicted with force:", impact_force)
