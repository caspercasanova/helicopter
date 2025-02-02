extends RayCast3D

const DEBUG_SPHERE = preload("res://scenes/armor_penetration/debug_sphere.tscn")


@export var offset_distance := .1
@export var debug_prints := true
@export var penetration_distance := 100

var debug_points: Penetration_Debugging_Points = Penetration_Debugging_Points.new()

func _ready() -> void:
	debug_points.add_to_scene(self)
	debug_points.update_debug_mesh_color([get_magma_color_for_usage(1, 4), get_magma_color_for_usage(2, 4)])
	pass


func _process(delta: float) -> void:
	var penetration_points = get_penetation_points()
	debug_points.update_debug_points(penetration_points)
	



 
func get_penetation_points() -> Array[Vector3]:
	var penetration_points: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	# Make sure the RayCast3D is enabled.
	if not is_enabled():
		set_enabled(true)
	
	# Force this RayCast3D to refresh collision data before we read it.
	force_raycast_update()

	# If we have no collision for the first/entry ray, there's no "exit" to find.
	if not is_colliding():
		if debug_prints:
			print("No collision found; no exit point.")
		return penetration_points

	# 1) Gather the first (entry) collision data from RayCast3D
	var entry_position = get_collision_point()
	var entry_normal = get_collision_normal() # Will be used for things like richochet
	print(entry_normal)
	var entry_collider = get_collider()

	# Convert your RayCast3D local target_position to global coords
	var global_start = global_transform.origin
	var global_end = global_transform.origin + (global_transform.basis * target_position)
	print("global_end first", global_end)
	# 2) Move a tiny bit "inside" the object, so our second ray doesn't immediately re-hit the same face.
	var inside_position = offset_in_ray_direction(entry_position, global_start, global_end, offset_distance)
	penetration_points[0] = inside_position

	# 3) Create a second ray using direct_space_state to find the "exit" intersection.
	var world_state = get_world_3d().direct_space_state
	
	# Convert the node's local 'target_position' to a global endpoint.a
	var query = PhysicsRayQueryParameters3D.create(inside_position, global_end * penetration_distance)
		
	# Mirror the RayCast3D collision flags by assigning them as properties (Godot 4.3).
	query.hit_from_inside = hit_from_inside
	query.collide_with_areas = collide_with_areas
	query.collide_with_bodies = collide_with_bodies
	query.hit_back_faces = hit_back_faces
	query.exclude = [self]
	
	# Perform the second raycast
	var exit_result = world_state.intersect_ray(query)

	if exit_result:
		# If the collider is the same, assume this is our exit point.
		if debug_prints:
			if exit_result.collider == entry_collider:
				print("Second intersection hit SAME collider: ", exit_result.position)
				print(exit_result)
			else:
				print("Second intersection hit DIFFERENT collider: ", exit_result.collider)

		penetration_points[1] = exit_result.position
		return penetration_points
	else:
		if debug_prints:
			print("No second intersection found.")
		return penetration_points







func offset_in_ray_direction(entry_position: Vector3, global_start: Vector3, global_end: Vector3, offset_distance: float) -> Vector3:
	# 1) Compute the direction of the original ray
	var ray_direction = (global_end - global_start).normalized()

	# 2) Offset by that direction
	var inside_position = entry_position + (ray_direction * offset_distance)

	return inside_position





func get_entities_in_line_of_sight(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Array[Node3D]:
	const MAX_COLLISIONS: int = 20
	var entities: Array[Node3D] = []
	var world_state:  PhysicsDirectSpaceState3D = get_world_3d().get_direct_space_state()
	for i in MAX_COLLISIONS:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.set_exclude(exclude)
		var result: Dictionary = world_state.intersect_ray(query)
		if result:
			entities.append(result.collider)
			exclude.append(result.rid)
			from = result.position
		else:
			break
	return entities




class Penetration_Debugging_Points: 
	var penetration_points: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var entry_mesh = null
	var exit_mesh = null
	
	func _init():
		self.entry_mesh = DEBUG_SPHERE.instantiate()
		self.exit_mesh = DEBUG_SPHERE.instantiate()
		self.entry_mesh.mesh.top_radius = self.entry_mesh.mesh.top_radius * .75
		  
	func add_to_scene(node):
		node.add_child(entry_mesh)
		node.add_child(exit_mesh)
	
	func clean_up():
		self.penetration_points = [Vector3.ZERO, Vector3.ZERO]
		self.entry_mesh = null
		self.exit_mesh = null 
	
	func update_debug_points(points: Array[Vector3]):
		var entry_point = points[0]
		var exit_point = points[1]
		if entry_point == Vector3.ZERO:
			entry_mesh.visible = false
			exit_mesh.visible = false
		else: 
			entry_mesh.global_position = entry_point
			entry_mesh.visible = true
			exit_mesh.global_position = exit_point
			exit_mesh.visible = true
		
	func update_debug_mesh_color(colors: Array[Color]):
		self.entry_mesh.mesh.material.albedo_color = colors[0]
		self.exit_mesh.mesh.material.albedo_color = colors[1]
		
		


var usage_count = 0
const MAX_USAGE = 6

var MAGMA_COLORS = [
	Color(0.047, 0.012, 0.271),  # Darkest purple
	# Color(0.159, 0.046, 0.274),  # Deep purple
	#Color(0.282, 0.045, 0.384),  # Purple -> Magenta
	Color(0.546, 0.089, 0.603),  # Magenta -> Pink
	Color(0.860, 0.365, 0.627),  # Pink -> Orange
	Color(0.977, 0.652, 0.286),  # Orange
	Color(0.992, 0.906, 0.145)   # Lightest yellow
]

func get_magma_color_for_ratio(ratio: float) -> Color:
	# Clamps the ratio between 0.0 and 1.0
	var r = clamp(ratio, 0.0, 1.0)
	
	# Scale ratio to the range of indices in MAGMA_COLORS
	var scaled = r * float(MAGMA_COLORS.size() - 1)
	
	# Find lower and upper indices to interpolate between
	var lower_index = int(floor(scaled))
	var upper_index = int(min(lower_index + 1, MAGMA_COLORS.size() - 1))
	
	# Local ratio between the two color stops
	var local_ratio = scaled - float(lower_index)
	
	# Interpolate between the two colors
	return MAGMA_COLORS[lower_index].lerp(MAGMA_COLORS[upper_index], local_ratio)


func get_magma_color_for_usage(usage: int, max_usage: int) -> Color:
	# Convert usage into a ratio, then reuse our ratio-based function
	if max_usage <= 0:
		return MAGMA_COLORS[0]
	var ratio = float(usage) / float(max_usage)
	return get_magma_color_for_ratio(ratio)
