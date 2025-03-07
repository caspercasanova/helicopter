@tool
extends Node3D


# Called when the node enters the scene tree for the first time.

func _ready():
	var from = Vector3(0, 1, 0)
	var to   = Vector3(0, 1, 10)

	var collisions = get_all_area_collisions(from, to)

	# Print sorted collisions (entry → exit order).
	for col in collisions:
		prints(col)
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func get_all_area_collisions(from: Vector3, to: Vector3) -> Array:
	# Create a thin capsule or cylinder shape matching the ray distance
	var distance = (to - from).length()
	if distance <= 0.00001:
		return []

	# Use either a CapsuleShape3D or CylinderShape3D.
	# A capsule is sometimes more convenient for line-like queries.
	var shape = CapsuleShape3D.new()
	shape.radius = 0.01
	shape.height = distance  # The "height" in Godot is basically the body, ignoring the caps.

	# Build a transform that positions & orients the shape along (from -> to)
	var center = from.lerp(to, 0.5)
	var basis = Transform3D()
	# We'll create a transform that looks along the line. 
	# By default, a capsule shape is oriented along the local Y axis in Godot 4.
	basis = basis.looking_at(to - from, Vector3.UP)

	# The shape's "center" will be in the middle, so let's place it at 'center'
	basis.origin = center

	# Prepare the shape query
	var query_params = PhysicsShapeQueryParameters3D.new()
	query_params.shape_rid = shape.get_rid()
	query_params.transform = basis
	query_params.collide_with_areas = true
	query_params.collide_with_bodies = false
	query_params.max_results = 32  # or however many collisions you expect

	# Perform the intersect_shape() query
	var space_state = get_world_3d().direct_space_state
	var results = space_state.intersect_shape(query_params)

	# Sort collisions by distance from 'from' to get a nice entry->exit order
	results.sort_custom(func(a, b):
		var dist_a = (a.position - from).length()
		var dist_b = (b.position - from).length()
		return dist_a < dist_b
	)

	return results
