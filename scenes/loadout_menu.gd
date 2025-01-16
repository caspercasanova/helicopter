extends CanvasLayer




func _on_left_weapon_subsystem_slot_a_item_selected(index: int) -> void:
	match index:
		0: print("Selected O - left slot a")
		1: print("Selected 1 - left slot a")
		2: print("Selected 2 - left slot a")
		3: print("Selected 3 - left slot a")
	pass # Replace with function body.


func _on_right_weapon_subsystem_slot_a_item_selected(index: int) -> void:
	match index:
		0: print("Selected O - right slot a")
		1: print("Selected 1 - right slot a")
		2: print("Selected 2 - right slot a")
		3: print("Selected 3 - right slot a")
	pass # Replace with function body.


func _on_left_weapon_subsystem_slot_b_item_selected(index: int) -> void:
	match index:
		0: print("Selected O - left slot b")
		1: print("Selected 1 - left slot b")
		2: print("Selected 2 - left slot b")
		3: print("Selected 3 - left slot b")
	pass # Replace with function body.


func _on_right_weapon_subsystem_slot_b_item_selected(index: int) -> void:
	match index:
		0: print("Selected O - right slot b")
		1: print("Selected 1 - right slot b")
		2: print("Selected 2 - right slot b")
		3: print("Selected 3 - right slot b")
	pass # Replace with function body.
