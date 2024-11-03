extends JoltPinJoint3D

@onready var connection_joint: JoltPinJoint3D = $Rope_Rigid/JoltPinJoint3D/Rope_Rigid/JoltPinJoint3D/Rope_Rigid/JoltPinJoint3D/Connection_Point/Connection_Joint

var has_object = false

func _on_connection_point_area_body_entered(body: Node3D) -> void:
	if !has_object and body is RigidBody3D and body.name != "Connection_Point" and body.name != "Rope_Rigid":
		print("Attaching to point: ", body)
		var path = body.get_path()
		connection_joint.node_b = path
		connection_joint.enabled=true
		has_object = true
	pass
