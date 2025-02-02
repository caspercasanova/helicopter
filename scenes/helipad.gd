extends Node3D

"""
Things to look at:
	- Respawn functionality 
		- Might need to think about a higher level logic process / obserable for this 
"""

var helicopter_is_on_pad = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	#if body is HeavyItem:
		#body.queue_free()
		#print("You earned 1 point")
		#print('Send UI Resposne')
	
	if body is Helicopter:
		helicopter_is_on_pad = true
		body.is_on_helipad = true
		print("Helicopter is on pad")




func _on_area_3d_body_exited(body: Node3D) -> void:
	
	if body is Helicopter:
		helicopter_is_on_pad = false
		body.is_on_helipad = false
		print("Helicopter has left the pad")



func replenish():
	pass
