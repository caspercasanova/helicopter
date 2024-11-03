class_name FixedJoint extends Node3D

@export var body_a: RigidBody3D
@export var body_b: RigidBody3D
#@export var joint_position: Vector3 = Vector3.ZERO

func _physics_process(delta):
	if not body_a or not body_b:
		return

	# World positions of the joint
	#var world_joint_pos_a = body_a.global_transform.origin + joint_position
	var world_joint_pos_a = body_a.global_transform.origin + global_position
	var world_joint_pos_b = body_b.global_transform.origin

	# Calculate position error (displacement between the two joint points)
	var position_error = world_joint_pos_a - world_joint_pos_b
	var correction_force = -position_error * body_a.mass / delta  # Proportional to the error

	# Apply force to body_b to move it back into position
	body_b.apply_central_force(correction_force)
	body_a.apply_central_force(-correction_force)

	# Calculate rotation correction
	var desired_rotation = body_a.global_transform.basis
	var current_rotation = body_b.global_transform.basis
	var rotation_error = desired_rotation.get_rotation_quaternion().inverse() * current_rotation.get_rotation_quaternion()
	var torque_correction = rotation_error.get_euler() * body_a.mass / delta

	# Apply torque to correct rotation
	body_b.apply_torque(torque_correction)
	body_a.apply_torque(-torque_correction)
