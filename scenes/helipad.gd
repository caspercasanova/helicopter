extends Node3D



var helicopter_is_on_pad = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is HeavyItem:
		body.queue_free()
		print("You earned 1 point")
		print('Send UI Resposne')
	
	if body is Helicopter:
		helicopter_is_on_pad = true
		print("Helicopter is on pad")
	pass # Replace with function body.




func _on_area_3d_body_exited(body: Node3D) -> void:
	helicopter_is_on_pad = false
	pass # Replace with function body.



func replenish():
	pass
